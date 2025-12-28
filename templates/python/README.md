# Python SDK

- `Makefile`: The Makefile defines the build commands for the Python SDK.
  - `make setup`: Generates a per-project `setup.sh` script to set up environment variables (e.g., PYTHONPATH) for this SDK project.
  - `make build`: No-op for Python (no compilation needed).
  - `make clean`: Removes Python cache files and directories.
  - `make test`: Runs the test cases for the Python SDK.
- `project_name/`: A folder containing the Python package (can be renamed via `AGENTIZE_PROJECT_NAME`).
  - `__init__.py`: The package initialization file which prints "Hello, World!" when imported.
- `tests/`: A folder containing test cases for the Python SDK.
  - `test_main.py`: A simple test case which imports the package and checks the output.
