This folder includes the templates for the supported language SDK.
Currently, supported languages are C, C++, and Python.
All the languages share a similar structure and interfaces with some language-specific files and folders.

All the templates has

- A `Makefile` in the root folder, which defines the following commands:
    - `make env-script`: Generates an `setup.sh` script to set up the environment variables for the SDK.
    - Because environment setup often involves the path to the project, creating the script upon initialization allows this flexibility.
    - `make build`: Builds the SDK.
    - `make clean`: Cleans all the build files.
    - `make test`: Runs the test cases.

- A `bootstrap.sh` script in the root folder, which initializes the SDK from the template.
    - This makes `make agentize` (see ../Makefile) as simple as copying this script to the target folder and run this script.
    - This script will make necessary modifications to the template files.
    - After it is done, it will delete itself.

