#!/usr/bin/env bash
# Test: Link detection for GitHub URLs and local markdown paths in plan webview

source "$(dirname "$0")/../common.sh"

test_info "Testing link detection patterns"

# Create a Node.js script to test the regex patterns
TEST_SCRIPT=$(make_temp_dir "link-detection-test")/test.js

cat > "$TEST_SCRIPT" << 'NODEJS'
// Regex patterns extracted from vscode/webview/plan/utils.ts

// Canonical GitHub issue/PR URLs inside log text.
const githubRegex = /https:\/\/github\.com\/[^/\s]+\/[^/\s]+\/(?:issues|pull)\/\d+(?=$|[^\w/?#])/g;

// Local markdown paths: .tmp/issue-N.md or /path/to/file.md
const mdPathRegex = /(?<=\s|^)(\.tmp\/[^\s\n]+\.md|[\w\-\/]+\.tmp\/[^\s\n]+\.md)(?=\s|$)/g;

// isValidGitHubUrl from vscode/src/view/unifiedViewProvider.ts
function isValidGitHubUrl(url) {
  return /^https:\/\/github\.com\/[^/]+\/[^/]+\/(?:issues|pull)\/\d+$/.test(url);
}

// Test cases for GitHub URL detection
const githubTestCases = [
  {
    name: 'Standard GitHub issue URL',
    input: 'Check https://github.com/owner/repo/issues/123 for details',
    expectedMatch: ['https://github.com/owner/repo/issues/123'],
  },
  {
    name: 'GitHub URL with numbers in owner name',
    input: 'See https://github.com/user123/repo-name/issues/456',
    expectedMatch: ['https://github.com/user123/repo-name/issues/456'],
  },
  {
    name: 'Multiple GitHub URLs',
    input: 'Issues: https://github.com/a/b/issues/1 and https://github.com/c/d/issues/2',
    expectedMatch: ['https://github.com/a/b/issues/1', 'https://github.com/c/d/issues/2'],
  },
  {
    name: 'GitHub PR URL',
    input: 'PR at https://github.com/owner/repo/pull/123',
    expectedMatch: ['https://github.com/owner/repo/pull/123'],
  },
  {
    name: 'GitHub non-issue URL',
    input: 'Visit https://github.com/owner/repo',
    expectedMatch: [],
  },
  {
    name: 'Non-GitHub URL',
    input: 'Visit https://example.com/some/path',
    expectedMatch: [],
  },
  {
    name: 'Invalid GitHub URL format',
    input: 'Check https://github.com/owner/issues/123 (no repo)',
    expectedMatch: [],
  },
  {
    name: 'GitHub PR URL with extra route segment',
    input: 'See https://github.com/owner/repo/pull/123/files',
    expectedMatch: [],
  },
];

// Test cases for host URL allowlist validation
const githubValidationCases = [
  {
    name: 'Canonical issue URL is valid',
    url: 'https://github.com/owner/repo/issues/123',
    expectedValid: true,
  },
  {
    name: 'Canonical PR URL is valid',
    url: 'https://github.com/owner/repo/pull/456',
    expectedValid: true,
  },
  {
    name: 'Unsupported GitHub route is invalid',
    url: 'https://github.com/owner/repo/actions/runs/1',
    expectedValid: false,
  },
  {
    name: 'PR URL with extra segment is invalid',
    url: 'https://github.com/owner/repo/pull/123/files',
    expectedValid: false,
  },
  {
    name: 'Non-GitHub URL is invalid',
    url: 'https://example.com/owner/repo/issues/1',
    expectedValid: false,
  },
];

// Test cases for local markdown path detection
const mdPathTestCases = [
  {
    name: 'Simple .tmp markdown path',
    input: 'See .tmp/issue-123.md for details',
    expectedMatch: ['.tmp/issue-123.md'],
  },
  {
    name: 'Multiple .tmp paths',
    input: 'Files: .tmp/issue-1.md and .tmp/issue-2.md here',
    expectedMatch: ['.tmp/issue-1.md', '.tmp/issue-2.md'],
  },
  {
    name: 'Path with subdirectory',
    input: 'Check .tmp/plans/feature-123.md',
    expectedMatch: ['.tmp/plans/feature-123.md'],
  },
  {
    name: 'Absolute path to .tmp',
    input: 'See /workspace/project/.tmp/issue-456.md for more',
    expectedMatch: ['/workspace/project/.tmp/issue-456.md'],
  },
  {
    name: 'Path at start of line',
    input: '.tmp/issue-789.md is the file',
    expectedMatch: ['.tmp/issue-789.md'],
  },
  {
    name: 'Non-markdown file in .tmp',
    input: 'File at .tmp/output.txt here',
    expectedMatch: [],
  },
  {
    name: 'Markdown file outside .tmp',
    input: 'See docs/file.md for details',
    expectedMatch: [],
  },
];

let passed = 0;
let failed = 0;

// Test GitHub URL detection
console.log('Testing GitHub URL detection:\n');
githubTestCases.forEach(tc => {
  const matches = [...tc.input.matchAll(githubRegex)].map(m => m[0]);

  if (JSON.stringify(matches) === JSON.stringify(tc.expectedMatch)) {
    console.log(`✓ PASS: ${tc.name}`);
    passed++;
  } else {
    console.log(`✗ FAIL: ${tc.name}`);
    console.log(`  Input: ${tc.input}`);
    console.log(`  Expected matches: ${JSON.stringify(tc.expectedMatch)}`);
    console.log(`  Got matches: ${JSON.stringify(matches)}`);
    failed++;
  }
});

// Test URL allowlist validation
console.log('\nTesting GitHub URL allowlist validation:\n');
githubValidationCases.forEach(tc => {
  const actual = isValidGitHubUrl(tc.url);
  if (actual === tc.expectedValid) {
    console.log(`✓ PASS: ${tc.name}`);
    passed++;
  } else {
    console.log(`✗ FAIL: ${tc.name}`);
    console.log(`  URL: ${tc.url}`);
    console.log(`  Expected valid: ${tc.expectedValid}`);
    console.log(`  Got valid: ${actual}`);
    failed++;
  }
});

// Test markdown path detection
console.log('\nTesting local markdown path detection:\n');
mdPathTestCases.forEach(tc => {
  const matches = [...tc.input.matchAll(mdPathRegex)].map(m => m[0]);
  
  if (JSON.stringify(matches) === JSON.stringify(tc.expectedMatch)) {
    console.log(`✓ PASS: ${tc.name}`);
    passed++;
  } else {
    console.log(`✗ FAIL: ${tc.name}`);
    console.log(`  Input: ${tc.input}`);
    console.log(`  Expected: ${JSON.stringify(tc.expectedMatch)}`);
    console.log(`  Got: ${JSON.stringify(matches)}`);
    failed++;
  }
});

console.log(`\nTotal: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
NODEJS

# Run the test script
node "$TEST_SCRIPT"
if [ $? -ne 0 ]; then
  test_fail "Link detection tests failed"
fi

test_pass "Link detection tests passed"
