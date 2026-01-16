#!/usr/bin/env bash
# Test: server runtime configuration loading and precedence
# Tests load_runtime_config, search behavior, validation, and precedence resolution

source "$(dirname "$0")/../common.sh"

test_info "server runtime configuration loading and precedence"

# Create temporary directory for tests
TMP_DIR=$(make_temp_dir "runtime-config-test")

# Test 1: load_runtime_config returns empty dict when file not found
test_no_file=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from pathlib import Path
from agentize.server.runtime_config import load_runtime_config

config, path = load_runtime_config(Path('/nonexistent/path'))
print(f'{config} {path}')
" 2>/dev/null)

if [ "$test_no_file" != "{} None" ]; then
  test_fail "load_runtime_config should return ({}, None) when file not found, got: $test_no_file"
fi

# Test 2: load_runtime_config parses nested server, telegram, workflows sections
cat > "$TMP_DIR/.agentize.local.yaml" <<'EOF'
server:
  period: 5m
  num_workers: 3

telegram:
  token: "test-token"
  chat_id: "12345"

workflows:
  impl:
    model: opus
  refine:
    model: sonnet
  dev_req:
    model: sonnet
  rebase:
    model: haiku
EOF

test_parse=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from pathlib import Path
from agentize.server.runtime_config import load_runtime_config

config, path = load_runtime_config(Path('$TMP_DIR'))

# Check server section
server_period = config.get('server', {}).get('period', '')
server_workers = config.get('server', {}).get('num_workers', 0)

# Check telegram section
tg_token = config.get('telegram', {}).get('token', '')
tg_chat_id = config.get('telegram', {}).get('chat_id', '')

# Check workflows section
impl_model = config.get('workflows', {}).get('impl', {}).get('model', '')
refine_model = config.get('workflows', {}).get('refine', {}).get('model', '')
rebase_model = config.get('workflows', {}).get('rebase', {}).get('model', '')

print(f'{server_period}|{server_workers}|{tg_token}|{tg_chat_id}|{impl_model}|{refine_model}|{rebase_model}')
" 2>/dev/null)

if [ "$test_parse" != "5m|3|test-token|12345|opus|sonnet|haiku" ]; then
  test_fail "load_runtime_config should parse all sections correctly, got: $test_parse"
fi

# Test 3: load_runtime_config searches parent directories
mkdir -p "$TMP_DIR/subdir/nested"
test_parent_search=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from pathlib import Path
from agentize.server.runtime_config import load_runtime_config

# Search from nested directory, should find config in TMP_DIR
config, path = load_runtime_config(Path('$TMP_DIR/subdir/nested'))
# Config should be found in parent
found = path is not None and 'test-token' in config.get('telegram', {}).get('token', '')
print('True' if found else 'False')
" 2>/dev/null)

if [ "$test_parent_search" != "True" ]; then
  test_fail "load_runtime_config should search parent directories, got: $test_parent_search"
fi

# Test 4: load_runtime_config raises ValueError for unknown top-level key
cat > "$TMP_DIR/invalid/.agentize.local.yaml" <<'EOF'
server:
  period: 5m
unknown_section:
  foo: bar
EOF
mkdir -p "$TMP_DIR/invalid"
cat > "$TMP_DIR/invalid/.agentize.local.yaml" <<'EOF'
server:
  period: 5m
unknown_section:
  foo: bar
EOF

test_invalid=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from pathlib import Path
from agentize.server.runtime_config import load_runtime_config

try:
    config, path = load_runtime_config(Path('$TMP_DIR/invalid'))
    print('no-error')
except ValueError as e:
    if 'unknown' in str(e).lower():
        print('ValueError-unknown')
    else:
        print(f'ValueError-other: {e}')
except Exception as e:
    print(f'other-error: {type(e).__name__}: {e}')
" 2>/dev/null)

if [ "$test_invalid" != "ValueError-unknown" ]; then
  test_fail "load_runtime_config should raise ValueError for unknown key, got: $test_invalid"
fi

# Test 5: Precedence helper - CLI takes precedence over config
test_precedence_cli=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.runtime_config import resolve_precedence

# CLI argument provided - should take precedence
result = resolve_precedence(cli_value='10m', env_value=None, config_value='5m', default='1m')
print(result)
" 2>/dev/null)

if [ "$test_precedence_cli" != "10m" ]; then
  test_fail "resolve_precedence should prefer CLI over config, got: $test_precedence_cli"
fi

# Test 6: Precedence helper - env takes precedence over config for TG
test_precedence_env=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.runtime_config import resolve_precedence

# Env provided - should take precedence over config
result = resolve_precedence(cli_value=None, env_value='env-token', config_value='config-token', default=None)
print(result)
" 2>/dev/null)

if [ "$test_precedence_env" != "env-token" ]; then
  test_fail "resolve_precedence should prefer env over config, got: $test_precedence_env"
fi

# Test 7: Precedence helper - config takes precedence over default
test_precedence_config=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.runtime_config import resolve_precedence

# Only config and default provided
result = resolve_precedence(cli_value=None, env_value=None, config_value='from-config', default='from-default')
print(result)
" 2>/dev/null)

if [ "$test_precedence_config" != "from-config" ]; then
  test_fail "resolve_precedence should prefer config over default, got: $test_precedence_config"
fi

# Test 8: Precedence helper - default used when nothing else provided
test_precedence_default=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.runtime_config import resolve_precedence

# Only default provided
result = resolve_precedence(cli_value=None, env_value=None, config_value=None, default='default-value')
print(result)
" 2>/dev/null)

if [ "$test_precedence_default" != "default-value" ]; then
  test_fail "resolve_precedence should use default when nothing else provided, got: $test_precedence_default"
fi

# Test 9: Extract workflow models helper
test_workflow_models=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from pathlib import Path
from agentize.server.runtime_config import load_runtime_config, extract_workflow_models

config, _ = load_runtime_config(Path('$TMP_DIR'))
models = extract_workflow_models(config)

# Check all workflow keys
impl = models.get('impl', '')
refine = models.get('refine', '')
dev_req = models.get('dev_req', '')
rebase = models.get('rebase', '')

print(f'{impl}|{refine}|{dev_req}|{rebase}')
" 2>/dev/null)

if [ "$test_workflow_models" != "opus|sonnet|sonnet|haiku" ]; then
  test_fail "extract_workflow_models should return all workflow models, got: $test_workflow_models"
fi

# Test 10: Empty workflows section returns empty dict
cat > "$TMP_DIR/no-workflows/.agentize.local.yaml" <<'EOF'
server:
  period: 5m
EOF
mkdir -p "$TMP_DIR/no-workflows"
cat > "$TMP_DIR/no-workflows/.agentize.local.yaml" <<'EOF'
server:
  period: 5m
EOF

test_empty_workflows=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from pathlib import Path
from agentize.server.runtime_config import load_runtime_config, extract_workflow_models

config, _ = load_runtime_config(Path('$TMP_DIR/no-workflows'))
models = extract_workflow_models(config)

print(len(models))
" 2>/dev/null)

if [ "$test_empty_workflows" != "0" ]; then
  test_fail "extract_workflow_models should return empty dict when no workflows section, got: $test_empty_workflows"
fi

# Cleanup
cleanup_dir "$TMP_DIR"

test_pass "server runtime configuration loading and precedence work correctly"
