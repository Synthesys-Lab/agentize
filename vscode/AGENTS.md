# VS Code Extension Agent Notes

Run all commands with `cwd` in the `vscode/` folder.

## Build

To build this plugin, run:

```bash
make build
```

## Playwright Render Screenshot to worktree `.tmp` (served from `agentize.git`)

To test the frontend rendering, use Playwright.

1) Install Playwright:

```bash
npm install --save-dev playwright
```

2) Generate harness HTML with shared skeleton template:

```bash
node bin/render-plan-harness.js
```

3) Capture a screenshot by serving `agentize.git` (`vscode/../../..`) while writing artifacts to this worktree `../.tmp`:

```bash
mkdir -p ../.tmp
WORKTREE_REL="$(python -c 'import os; print(os.path.relpath(os.path.abspath(\"..\"), os.path.abspath(\"../../..\")).replace(os.sep, \"/\"))')"
python -m http.server 4173 --directory ../../.. > ../.tmp/http-server.log 2>&1 & server_pid=$!; sleep 1; npx --yes playwright@1.51.1 screenshot --wait-for-selector "#new-plan" --timeout 10000 "http://127.0.0.1:4173/${WORKTREE_REL}/.tmp/plan-dev-harness.html" "../.tmp/plan-render-$(date +%Y%m%d-%H%M%S).png"; rc=$?; kill $server_pid; wait $server_pid 2>/dev/null; exit $rc
```

## Check Latest Render Figure in `.tmp`

Print the latest screenshot path:

```bash
ls -t ../.tmp/plan-render-*.png | head -n 1
```

Then open that image in your viewer, or pass the absolute path to Codex for image analysis.
