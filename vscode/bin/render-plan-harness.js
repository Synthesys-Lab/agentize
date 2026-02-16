#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const vscodeDir = path.resolve(__dirname, '..');
const worktreeRoot = path.resolve(vscodeDir, '..');
const treesDir = path.resolve(worktreeRoot, '..');
const repoRoot = path.basename(treesDir) === 'trees' ? path.resolve(treesDir, '..') : treesDir;
const worktreeRelativeToRepo = path.relative(repoRoot, worktreeRoot).split(path.sep).join('/');

const skeletonPath = path.join(vscodeDir, 'webview', 'plan', 'skeleton.html');
const outputPath = path.join(worktreeRoot, '.tmp', 'plan-dev-harness.html');
const styleHref = '../vscode/webview/plan/styles.css';
const scriptSrc = '../vscode/webview/plan/out/index.js';
const harnessUrlPath = `/${worktreeRelativeToRepo}/.tmp/plan-dev-harness.html`.replace(/\/+/g, '/');

const skeletonPlaceholder = '{{SKELETON_ERROR}}';

const fallbackSkeleton = [
  '<div class="plan-skeleton">',
  '  <div class="plan-skeleton-title">Agentize</div>',
  '  <div id="plan-skeleton-status" class="plan-skeleton-subtitle">Loading webview UI...</div>',
  `  ${skeletonPlaceholder}`,
  '</div>',
].join('\n');

const readSkeleton = () => {
  try {
    return fs.readFileSync(skeletonPath, 'utf8');
  } catch (error) {
    console.warn(`render-plan-harness: failed to read ${skeletonPath}: ${String(error)}`);
    return fallbackSkeleton;
  }
};

const skeletonHtml = readSkeleton().split(skeletonPlaceholder).join('');

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="${styleHref}" rel="stylesheet" />
  <title>Agentize</title>
</head>
<body>
  <div id="plan-root" class="plan-root">
    ${skeletonHtml}
  </div>
  <script>
    window.__INITIAL_STATE__ = { plan: { draftInput: '', sessions: [] } };
    window.acquireVsCodeApi = function() {
      return {
        postMessage(message) {
          console.log('[harness->extension]', message);
        },
      };
    };
  </script>
  <script type="module" src="${scriptSrc}"></script>
</body>
</html>
`;

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, html);

console.log(`render-plan-harness: generated ${outputPath}`);
console.log(`render-plan-harness: urlPath=${harnessUrlPath}`);
console.log(`render-plan-harness: style=${styleHref}`);
console.log(`render-plan-harness: script=${scriptSrc}`);
