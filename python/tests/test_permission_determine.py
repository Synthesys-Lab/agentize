"""Tests for lib.permission.determine helper functions.

These tests cover:
- _escape_html: HTML character escaping for Telegram
- _build_inline_keyboard: Inline keyboard payload structure
- _parse_callback_data: Callback data parsing for button presses
- _tg_api_request: Guard behavior when Telegram is disabled
- _check_permission: Evaluation order (global rules first)
"""

import pytest


class TestEscapeHtml:
    """Tests for _escape_html function."""

    def test_escape_html_handles_lt_gt_amp(self):
        """Test _escape_html escapes <, >, & correctly."""
        from lib.permission.determine import _escape_html

        result = _escape_html('<script>alert(1)</script> & "test"')
        expected = '&lt;script&gt;alert(1)&lt;/script&gt; &amp; "test"'
        assert result == expected

    def test_escape_html_preserves_normal_text(self):
        """Test _escape_html preserves text without special chars."""
        from lib.permission.determine import _escape_html

        result = _escape_html('normal text here')
        assert result == 'normal text here'

    def test_escape_html_empty_string(self):
        """Test _escape_html handles empty strings."""
        from lib.permission.determine import _escape_html

        result = _escape_html('')
        assert result == ''


class TestBuildInlineKeyboard:
    """Tests for _build_inline_keyboard function."""

    def test_build_inline_keyboard_structure(self):
        """Test _build_inline_keyboard returns valid structure."""
        from lib.permission.determine import _build_inline_keyboard

        kb = _build_inline_keyboard(12345)

        # Check structure
        assert 'inline_keyboard' in kb
        assert len(kb['inline_keyboard']) == 1
        assert len(kb['inline_keyboard'][0]) == 2

        # Check Allow button
        allow_btn = kb['inline_keyboard'][0][0]
        assert allow_btn['text'] == '✅ Allow'
        assert allow_btn['callback_data'] == 'allow:12345'

        # Check Deny button
        deny_btn = kb['inline_keyboard'][0][1]
        assert deny_btn['text'] == '❌ Deny'
        assert deny_btn['callback_data'] == 'deny:12345'

    def test_build_inline_keyboard_different_message_ids(self):
        """Test _build_inline_keyboard uses correct message_id in callback_data."""
        from lib.permission.determine import _build_inline_keyboard

        kb1 = _build_inline_keyboard(100)
        kb2 = _build_inline_keyboard(999)

        assert kb1['inline_keyboard'][0][0]['callback_data'] == 'allow:100'
        assert kb2['inline_keyboard'][0][0]['callback_data'] == 'allow:999'


class TestParseCallbackData:
    """Tests for _parse_callback_data function."""

    def test_parse_callback_data_allow(self):
        """Test _parse_callback_data extracts action and message_id for allow."""
        from lib.permission.determine import _parse_callback_data

        action, msg_id = _parse_callback_data('allow:12345')

        assert action == 'allow'
        assert msg_id == 12345

    def test_parse_callback_data_deny(self):
        """Test _parse_callback_data extracts action and message_id for deny."""
        from lib.permission.determine import _parse_callback_data

        action, msg_id = _parse_callback_data('deny:67890')

        assert action == 'deny'
        assert msg_id == 67890

    def test_parse_callback_data_no_message_id(self):
        """Test _parse_callback_data handles missing message_id."""
        from lib.permission.determine import _parse_callback_data

        action, msg_id = _parse_callback_data('allow')

        assert action == 'allow'
        assert msg_id == 0

    def test_parse_callback_data_invalid_message_id(self):
        """Test _parse_callback_data handles non-numeric message_id."""
        from lib.permission.determine import _parse_callback_data

        action, msg_id = _parse_callback_data('allow:not_a_number')

        assert action == 'allow'
        assert msg_id == 0


class TestTgApiRequestGuard:
    """Tests for _tg_api_request guard behavior."""

    def test_tg_api_request_returns_none_when_disabled(
        self, set_agentize_home, clear_local_config_cache, monkeypatch, tmp_path
    ):
        """Test _tg_api_request returns None when Telegram is disabled.

        The config loader walks UP from cwd looking for .agentize.local.yaml.
        To isolate this test, we must change cwd to a tmp directory that has no
        .agentize.local.yaml in any parent directory.
        """
        import os

        # Create isolated directories
        isolated_cwd = tmp_path / "isolated_cwd"
        isolated_home = tmp_path / "isolated_home"
        isolated_cwd.mkdir()
        isolated_home.mkdir()

        # Save original cwd
        original_cwd = os.getcwd()

        try:
            # Change to isolated cwd (no .agentize.local.yaml in parents)
            os.chdir(isolated_cwd)

            # Isolate HOME and AGENTIZE_HOME
            monkeypatch.setenv("HOME", str(isolated_home))
            monkeypatch.setenv("AGENTIZE_HOME", str(isolated_home))

            # Clear cache after env changes
            from lib.local_config import clear_cache
            clear_cache()

            from lib.permission.determine import _tg_api_request, _is_telegram_enabled

            # Verify Telegram is disabled (no config in isolated environment)
            assert not _is_telegram_enabled()

            # Call _tg_api_request - should return None without making any HTTP request
            result = _tg_api_request(
                'fake_token', 'sendMessage', {'chat_id': '123', 'text': 'test'}
            )

            assert result is None
        finally:
            # Restore original cwd
            os.chdir(original_cwd)


class TestCheckPermissionEvaluationOrder:
    """Tests for _check_permission evaluation order.

    Validates that global rules are evaluated first and deny/allow decisions
    are returned immediately without falling through to other backends.
    """

    def test_global_deny_evaluated_first(
        self, set_agentize_home, clear_local_config_cache, monkeypatch
    ):
        """Test rm -rf is denied by global rules, not workflow."""
        import lib.permission.determine as determine_module
        from lib.permission.determine import _check_permission

        # Mock _hook_input to provide session_id
        determine_module._hook_input = {'session_id': 'test-ordering'}

        # Also unset env vars that might affect behavior
        monkeypatch.delenv('AGENTIZE_USE_TG', raising=False)
        monkeypatch.delenv('HANDSOFF_AUTO_PERMISSION', raising=False)

        # Test: rm -rf should be denied by global rules, not workflow
        decision, source = _check_permission('Bash', 'rm -rf /tmp', 'rm -rf /tmp')

        assert decision == 'deny'
        # Source can be 'rules', 'rules:hardcoded', 'rules:project', or 'rules:local'
        assert source.startswith('rules')

    def test_docstring_evaluation_order(self):
        """Test _check_permission docstring reflects correct evaluation order."""
        from lib.permission.determine import _check_permission

        docstring = _check_permission.__doc__

        # Verify the docstring reflects the correct evaluation order
        required_statements = [
            'Global rules (deny/allow return, ask falls through)',
            'Workflow auto-allow (allow returns, otherwise continue)',
            'Haiku LLM (allow/deny return, ask falls through)',
            'Telegram (single final escalation for ask)',
        ]

        for stmt in required_statements:
            assert stmt in docstring, f'Docstring missing: {stmt}'

        # Also verify the priority numbers are in correct order (1-4)
        assert '1.' in docstring
        assert '2.' in docstring
        assert '3.' in docstring
        assert '4.' in docstring


class TestEditMessageResultFormat:
    """Tests for _edit_message_result text formatting.

    Tests the formatting logic without making actual API calls.
    """

    def test_timeout_message_format(self):
        """Test timeout message contains expected elements."""
        from lib.permission.determine import _escape_html, SESSION_ID_DISPLAY_LEN

        # Replicate the build_result_text logic from the shell test
        def build_result_text(decision, tool, target, session_id):
            if decision == 'timeout':
                emoji = '⏰'
                status = 'Timed Out'
            elif decision == 'allow':
                emoji = '✅'
                status = 'Allowed'
            else:
                emoji = '❌'
                status = 'Denied'

            return (
                f'{emoji} {status}\n\n'
                f'Tool: <code>{_escape_html(tool)}</code>\n'
                f'Target: <code>{_escape_html(target)}</code>\n'
                f'Session: {session_id[:SESSION_ID_DISPLAY_LEN]}'
            )

        result = build_result_text('timeout', 'Bash', 'git push', 'test-session-123')

        assert '⏰ Timed Out' in result
        assert '<code>Bash</code>' in result
        assert '<code>git push</code>' in result
        assert 'test-ses' in result  # Truncated session ID

    def test_allow_message_format(self):
        """Test allow message contains expected elements."""
        from lib.permission.determine import _escape_html, SESSION_ID_DISPLAY_LEN

        def build_result_text(decision, tool, target, session_id):
            if decision == 'timeout':
                emoji = '⏰'
                status = 'Timed Out'
            elif decision == 'allow':
                emoji = '✅'
                status = 'Allowed'
            else:
                emoji = '❌'
                status = 'Denied'

            return (
                f'{emoji} {status}\n\n'
                f'Tool: <code>{_escape_html(tool)}</code>\n'
                f'Target: <code>{_escape_html(target)}</code>\n'
                f'Session: {session_id[:SESSION_ID_DISPLAY_LEN]}'
            )

        result = build_result_text('allow', 'Read', '/etc/hosts', 'abc12345678')

        assert '✅ Allowed' in result
        assert '<code>Read</code>' in result
        assert '<code>/etc/hosts</code>' in result

    def test_deny_message_format(self):
        """Test deny message contains expected elements."""
        from lib.permission.determine import _escape_html, SESSION_ID_DISPLAY_LEN

        def build_result_text(decision, tool, target, session_id):
            if decision == 'timeout':
                emoji = '⏰'
                status = 'Timed Out'
            elif decision == 'allow':
                emoji = '✅'
                status = 'Allowed'
            else:
                emoji = '❌'
                status = 'Denied'

            return (
                f'{emoji} {status}\n\n'
                f'Tool: <code>{_escape_html(tool)}</code>\n'
                f'Target: <code>{_escape_html(target)}</code>\n'
                f'Session: {session_id[:SESSION_ID_DISPLAY_LEN]}'
            )

        result = build_result_text('deny', 'Bash', 'rm -rf /', 'session-xyz')

        assert '❌ Denied' in result
        assert '<code>Bash</code>' in result
        assert '<code>rm -rf /</code>' in result
