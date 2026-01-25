# Python Tests

This directory contains pytest tests for the `agentize.server` Python modules.

## Purpose

These tests validate server-side functionality including:
- Worker status file operations
- GitHub API filtering and discovery functions
- Runtime configuration loading
- Telegram notification formatting
- Session lookup utilities
- Module exports and imports

## Running Tests

**Install dependencies:**
```bash
python -m pip install -r python/requirements-dev.txt
```

**Run all pytest tests:**
```bash
pytest python/tests
```

**Run with verbose output:**
```bash
pytest python/tests -v
```

**Run a specific test file:**
```bash
pytest python/tests/test_workers.py
```

Tests are also run automatically via `make test` and `make test-fast`.

## Test Organization

| File | Coverage |
|------|----------|
| `test_workers.py` | Worker status operations, dead PID cleanup |
| `test_github_filtering.py` | Issue/PR filtering, ready state checks |
| `test_github_discovery.py` | Candidate discovery, status queries |
| `test_runtime_config.py` | Config loading, precedence resolution, handsoff section |
| `test_local_config.py` | YAML config lookup, env override, type coercion |
| `test_notify.py` | Telegram message formatting |
| `test_session.py` | Session lookup and state retrieval |
| `test_module_exports.py` | Module imports and re-exports |

## Fixtures

The `conftest.py` file provides:
- `project_root`: Path to the repository root
- Automatic `PYTHONPATH` setup for imports

## Writing Tests

1. Create test files matching `test_*.py`
2. Use `unittest.mock` for mocking subprocess and external calls
3. Use pytest fixtures (`tmp_path`, `monkeypatch`, `capfd`) as needed
4. Follow existing test patterns for consistency
