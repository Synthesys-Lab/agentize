#!/usr/bin/env bash
# Test: server Telegram notification helpers for worker assignment

source "$(dirname "$0")/../common.sh"

test_info "server Telegram notification helpers"

# Test 1: _extract_repo_slug handles HTTPS URLs
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _extract_repo_slug

# HTTPS without .git
assert _extract_repo_slug('https://github.com/org/repo') == 'org/repo', 'HTTPS without .git'

# HTTPS with .git
assert _extract_repo_slug('https://github.com/org/repo.git') == 'org/repo', 'HTTPS with .git'

# SSH format
assert _extract_repo_slug('git@github.com:org/repo.git') == 'org/repo', 'SSH format'

# Invalid URLs return None
assert _extract_repo_slug('not-a-url') is None, 'Invalid URL'
assert _extract_repo_slug('') is None, 'Empty string'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_extract_repo_slug: $output"
fi

# Test 2: _format_worker_assignment_message escapes HTML special chars
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_assignment_message

# Test HTML escaping in title
msg = _format_worker_assignment_message(42, '<script>alert(1)</script>', 0, None)
assert '&lt;script&gt;' in msg, 'Should escape < and >'
assert '<script>' not in msg, 'Raw < should not appear'

# Test & escaping
msg = _format_worker_assignment_message(42, 'A & B', 0, None)
assert '&amp;' in msg, 'Should escape &'
assert ' & ' not in msg, 'Raw & should not appear in HTML context'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_assignment_message HTML escaping: $output"
fi

# Test 3: _format_worker_assignment_message includes link when URL provided
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_assignment_message

# With URL: should include href
msg = _format_worker_assignment_message(42, 'Test Title', 1, 'https://github.com/org/repo/issues/42')
assert 'href=\"https://github.com/org/repo/issues/42\"' in msg, f'Should include issue link. Got: {msg}'

# Without URL: should not include href
msg_no_url = _format_worker_assignment_message(42, 'Test Title', 1, None)
assert 'href=' not in msg_no_url, 'Should not include href when URL is None'
assert '#42' in msg_no_url, 'Should include issue number'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_assignment_message link handling: $output"
fi

# Test 4: Message includes worker ID and issue number
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_assignment_message

msg = _format_worker_assignment_message(123, 'My Issue', 5, None)
assert '#123' in msg, 'Should include issue number'
assert 'Worker: 5' in msg, 'Should include worker ID'
assert 'My Issue' in msg, 'Should include issue title'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_assignment_message content: $output"
fi

# Test 5: _format_worker_completion_message basic formatting
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_completion_message

# Basic completion message without URL
msg = _format_worker_completion_message(42, 1, None)
assert '#42' in msg, 'Should include issue number'
assert 'Worker: 1' in msg, 'Should include worker ID'
assert 'Completed' in msg or 'Complete' in msg, 'Should indicate completion'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_completion_message basic: $output"
fi

# Test 6: _format_worker_completion_message with URL
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_completion_message

# Completion message with URL
msg = _format_worker_completion_message(42, 1, 'https://github.com/org/repo/issues/42')
assert 'href=\"https://github.com/org/repo/issues/42\"' in msg, f'Should include issue link. Got: {msg}'

# Without URL
msg_no_url = _format_worker_completion_message(42, 1, None)
assert 'href=' not in msg_no_url, 'Should not include href when URL is None'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_completion_message link handling: $output"
fi

# Test 7: _format_worker_completion_message with PR URL
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_completion_message

# Completion message with both issue and PR URL
msg = _format_worker_completion_message(
    42, 1,
    'https://github.com/org/repo/issues/42',
    pr_url='https://github.com/org/repo/pull/123'
)
assert 'href=\"https://github.com/org/repo/issues/42\"' in msg, f'Should include issue link. Got: {msg}'
assert 'href=\"https://github.com/org/repo/pull/123\"' in msg, f'Should include PR link. Got: {msg}'
assert 'PR:' in msg or 'Pull Request' in msg, f'Should have PR label. Got: {msg}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_completion_message with PR URL: $output"
fi

# Test 8: _format_worker_completion_message with PR URL but no issue URL
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_completion_message

# Completion message with only PR URL
msg = _format_worker_completion_message(42, 1, None, pr_url='https://github.com/org/repo/pull/123')
assert '#42' in msg, f'Should include issue number. Got: {msg}'
assert 'href=\"https://github.com/org/repo/pull/123\"' in msg, f'Should include PR link. Got: {msg}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_completion_message PR without issue URL: $output"
fi

# Test 9: _format_worker_completion_message without PR URL
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _format_worker_completion_message

# Completion message without PR URL (pr_url=None)
msg = _format_worker_completion_message(42, 1, 'https://github.com/org/repo/issues/42', pr_url=None)
assert 'href=\"https://github.com/org/repo/issues/42\"' in msg, f'Should include issue link. Got: {msg}'
# Should not have a PR line when pr_url is None
assert '/pull/' not in msg, f'Should not include PR link when pr_url is None. Got: {msg}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_format_worker_completion_message without PR URL: $output"
fi

test_pass "server Telegram notification helpers work correctly"
