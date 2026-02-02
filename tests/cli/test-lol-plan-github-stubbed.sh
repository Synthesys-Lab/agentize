#!/usr/bin/env bash
# Test: GitHub issue create/publish flow with stubbed gh for lol plan

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "Pipeline publishes plan with stubbed gh"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"
source "$PLANNER_CLI"
source "$LOL_CLI"

TMP_DIR=$(make_temp_dir "test-lol-plan-github-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

CALL_LOG="$TMP_DIR/gh-calls.log"
touch "$CALL_LOG"

# Stub gh CLI
STUB_GH="$TMP_DIR/gh"
cat > "$STUB_GH" <<'STUBEOF'
#!/usr/bin/env bash
set -e

LOG_FILE="${GH_CALL_LOG:?}"

case "$1" in
    auth)
        exit 0
        ;;
    issue)
        shift
        case "$1" in
            create)
                echo "issue create $*" >> "$LOG_FILE"
                echo "https://github.com/example/repo/issues/123"
                exit 0
                ;;
            view)
                issue_no="$2"
                shift 2
                if echo "$*" | grep -q ".body"; then
                    echo "# Implementation Plan: Stub Body"
                    exit 0
                fi
                if echo "$*" | grep -q ".url"; then
                    echo "https://github.com/example/repo/issues/${issue_no}"
                    exit 0
                fi
                echo "{}"
                exit 0
                ;;
            edit)
                echo "issue edit $*" >> "$LOG_FILE"
                exit 0
                ;;
        esac
        ;;
    *)
        echo "unexpected gh args: $*" >> "$LOG_FILE"
        exit 1
        ;;
esac
STUBEOF
chmod +x "$STUB_GH"
export GH_CALL_LOG="$CALL_LOG"
export PATH="$TMP_DIR:$PATH"

# Stub acw for Python backend
ACW_LOG="$TMP_DIR/acw-calls.log"
touch "$ACW_LOG"
STUB_ACW="$TMP_DIR/acw-stub.sh"
cat > "$STUB_ACW" <<'STUBEOF'
#!/usr/bin/env bash
acw() {
    local provider="$1"
    local model="$2"
    local input_file="$3"
    local output_file="$4"

    echo "acw $provider $model $input_file $output_file" >> "${PLANNER_ACW_CALL_LOG:?}"

    if echo "$output_file" | grep -q "understander"; then
        echo "# Context Summary: Test Feature" > "$output_file"
    elif echo "$output_file" | grep -q "bold"; then
        echo "# Bold Proposal: Test Feature" > "$output_file"
    elif echo "$output_file" | grep -q "critique"; then
        echo "# Proposal Critique: Test Feature" > "$output_file"
    elif echo "$output_file" | grep -q "reducer"; then
        echo "# Simplified Proposal: Test Feature" > "$output_file"
    else
        echo "# Unknown Stage Output" > "$output_file"
    fi
    return 0
}
STUBEOF
chmod +x "$STUB_ACW"
export PLANNER_ACW_CALL_LOG="$ACW_LOG"
export PLANNER_ACW_SCRIPT="$STUB_ACW"

# Stub external consensus script
STUB_CONSENSUS_DIR="$TMP_DIR/consensus-stub"
mkdir -p "$STUB_CONSENSUS_DIR"
STUB_CONSENSUS="$STUB_CONSENSUS_DIR/external-consensus.sh"
cat > "$STUB_CONSENSUS" <<'STUBEOF'
#!/usr/bin/env bash
# Stub consensus script
REPORT_BASENAME=$(basename "$1")
ISSUE_NUMBER=""
if [[ "$REPORT_BASENAME" =~ issue-([0-9]+)- ]]; then
    ISSUE_NUMBER="${BASH_REMATCH[1]}"
fi
if [ -z "$ISSUE_NUMBER" ]; then
    ISSUE_NUMBER="000"
fi
CONSENSUS_FILE=".tmp/issue-${ISSUE_NUMBER}-consensus.md"
mkdir -p .tmp
echo "# Implementation Plan: Test Plan Title" > "$CONSENSUS_FILE"
echo "Stub consensus output" >> "$CONSENSUS_FILE"
echo "$CONSENSUS_FILE"
exit 0
STUBEOF
chmod +x "$STUB_CONSENSUS"
export _PLANNER_CONSENSUS_SCRIPT="$STUB_CONSENSUS"

export PLANNER_NO_ANIM=1

FEATURE_DESC="Add GitHub publish flow with placeholder trimming for plan pipeline output"

output=$(
    cd "$TMP_DIR" && \
    lol plan "$FEATURE_DESC" 2>&1
) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan exited with non-zero status"
}

# Validate placeholder issue creation title
EXPECTED_SHORT="${FEATURE_DESC:0:50}..."
EXPECTED_TITLE="[plan] placeholder: ${EXPECTED_SHORT}"
grep -Fq -- "${EXPECTED_TITLE}" "$CALL_LOG" || {
    echo "Call log contents:" >&2
    cat "$CALL_LOG" >&2
    test_fail "Expected placeholder issue title not found"
}

# Validate issue publish title and label
EXPECTED_PUBLISH="--title [plan] [#123] Test Plan Title"
grep -Fq -- "${EXPECTED_PUBLISH}" "$CALL_LOG" || {
    echo "Call log contents:" >&2
    cat "$CALL_LOG" >&2
    test_fail "Expected issue publish title not found"
}

grep -Fq -- "--add-label agentize:plan" "$CALL_LOG" || {
    echo "Call log contents:" >&2
    cat "$CALL_LOG" >&2
    test_fail "Expected agentize:plan label to be added"
}

# Validate consensus path is printed
echo "$output" | grep -q "See the full plan locally" || {
    echo "Pipeline output: $output" >&2
    test_fail "Expected local consensus path output"
}

test_pass "Pipeline publishes plan with stubbed gh"
