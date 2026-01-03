- When writing any scripts, **AVOID** being shell-specific.
  - Particularly, avoid using `BASH_SOURCE[0]` or `$0` between zsh and bash to get the current script name.
  - Bash arrays are 0-based, while zsh arrays are 1-based.
    - Avoid writing any code that `${a[0]}` to get the first element of an array. Instead, this typically happen when parsing positional arguments. So extract the arguments along with the traversal to corresponding variables!
  - Use `AGTENTIZE_HOME` to refer to a path to relative to a script in this repository.
- Further, to differentiate `AGTENTIZE_HOME` and `PROJECT_ROOT`:
  - `AGENTIZE_HOME` (static) refers to the root of this framework, which is exported by `setup.sh` made by `make setup`.
  - `PROJECT_ROOT` (dynamic) refers to the root of the project that uses this framework, which should be found by
    `git rev-parse --common-dir` or `git rev-parse --show-toplevel`.
