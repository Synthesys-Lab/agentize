#!/usr/bin/env bash
# Test: server load_config remote_url fallback to git remote

source "$(dirname "$0")/../common.sh"

test_info "server load_config remote_url fallback"

TEMP_DIR=$(make_temp_dir)

# Setup: Create a minimal git repo for testing
setup_git_repo() {
  local repo_dir="$1"
  local remote_url="$2"

  cd "$repo_dir" || exit 1
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  # Set up remote origin
  git remote add origin "$remote_url"

  # Create minimal .agentize.yaml without remote_url
  cat > .agentize.yaml << 'EOF'
project:
  id: 3
  org: TestOrg
  name: testrepo
EOF
}

# Test 1: load_config falls back to git remote when remote_url not configured
test_dir="$TEMP_DIR/test1"
mkdir -p "$test_dir"
setup_git_repo "$test_dir" "https://github.com/FallbackOrg/FallbackRepo.git"

output=$(cd "$test_dir" && PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.github import load_config

org, project_id, remote_url = load_config()

# Should fall back to git remote get-url origin
assert remote_url == 'https://github.com/FallbackOrg/FallbackRepo.git', \
    f'Expected fallback URL, got: {remote_url}'
assert org == 'TestOrg', f'Expected TestOrg, got: {org}'
assert project_id == 3, f'Expected 3, got: {project_id}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "load_config fallback to git remote: $output"
fi

# Test 2: load_config prefers explicit remote_url when configured
test_dir2="$TEMP_DIR/test2"
mkdir -p "$test_dir2"

cd "$test_dir2" || exit 1
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git remote add origin "https://github.com/GitRemote/Repo.git"

# Create .agentize.yaml WITH explicit remote_url
cat > .agentize.yaml << 'EOF'
project:
  id: 5
  org: ExplicitOrg
  name: explicitrepo

git:
  remote_url: https://github.com/ExplicitOrg/ExplicitRepo
EOF

output=$(cd "$test_dir2" && PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.github import load_config

org, project_id, remote_url = load_config()

# Should use explicit remote_url, not git remote
assert remote_url == 'https://github.com/ExplicitOrg/ExplicitRepo', \
    f'Expected explicit URL, got: {remote_url}'
assert org == 'ExplicitOrg', f'Expected ExplicitOrg, got: {org}'
assert project_id == 5, f'Expected 5, got: {project_id}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "load_config prefers explicit remote_url: $output"
fi

# Test 3: SSH format fallback works
test_dir3="$TEMP_DIR/test3"
mkdir -p "$test_dir3"
setup_git_repo "$test_dir3" "git@github.com:SSHOrg/SSHRepo.git"

output=$(cd "$test_dir3" && PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.github import load_config

org, project_id, remote_url = load_config()

# Should fall back to SSH git remote URL
assert remote_url == 'git@github.com:SSHOrg/SSHRepo.git', \
    f'Expected SSH URL, got: {remote_url}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "load_config SSH fallback: $output"
fi

# Cleanup
cleanup_dir "$TEMP_DIR"

test_pass "server load_config remote_url fallback works correctly"
