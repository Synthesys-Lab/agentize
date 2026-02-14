#!/usr/bin/env node

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const setupScript = path.join(repoRoot, 'setup.sh');
const fallbackScript = path.join(repoRoot, 'src', 'cli', 'lol.sh');
const args = process.argv.slice(2);

const scriptToSource = fs.existsSync(setupScript) ? setupScript : fallbackScript;
if (!fs.existsSync(scriptToSource)) {
  console.error('lol-wrapper: unable to locate setup.sh or src/cli/lol.sh.');
  process.exit(1);
}

const escapeForDoubleQuotes = (value) =>
  String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');

const repoRootEscaped = escapeForDoubleQuotes(repoRoot);
const scriptEscaped = escapeForDoubleQuotes(scriptToSource);

const envExport = 'export AGENTIZE_HOME="${AGENTIZE_HOME:-' + repoRootEscaped + '}"';
const sourceCommand = 'source "' + scriptEscaped + '"';
const shellCommand = `${envExport}; ${sourceCommand}; lol "$@"`;

let exited = false;

const child = spawn('bash', ['-lc', shellCommand, 'bash', ...args], {
  cwd: process.cwd(),
  env: process.env,
  stdio: 'inherit',
});

child.on('error', (error) => {
  if (exited) {
    return;
  }
  exited = true;
  console.error(`lol-wrapper: failed to start bash (${error.message}).`);
  process.exit(1);
});

child.on('exit', (code, signal) => {
  if (exited) {
    return;
  }
  exited = true;
  if (signal) {
    process.exit(1);
  }
  process.exit(code ?? 1);
});
