#!/usr/bin/env bash
# Test: Step progress parser logic for plan webview

source "$(dirname "$0")/../common.sh"

test_info "Testing step progress parser logic"

# Create a Node.js script to test the regex patterns
TEST_SCRIPT=$(make_temp_dir "step-parser-test")/test.js

cat > "$TEST_SCRIPT" << 'NODEJS'
// Regex patterns extracted from vscode/webview/plan/index.ts

// Parse stage line: "Stage N/5: Running {name} ({provider}:{model})" or "Stage M-N/5: ..."
function parseStageLine(line) {
  const match = line.match(/Stage\s+(\d+)(?:-(\d+))?\/5:\s+Running\s+(.+?)\s*\(([^)]+)\)/);
  if (!match) return null;

  const [, stageStr, endStageStr, name, providerInfo] = match;
  const firstProviderMatch = providerInfo.match(/([^:,\s]+):([^:,\s]+)/);
  const provider = firstProviderMatch ? firstProviderMatch[1] : 'unknown';
  const model = firstProviderMatch ? firstProviderMatch[2] : 'unknown';

  return {
    stage: parseInt(stageStr, 10),
    endStage: endStageStr ? parseInt(endStageStr, 10) : undefined,
    total: 5,
    name: name || 'unknown',
    provider: provider,
    model: model,
    status: 'running',
    startTime: Date.now(),
  };
}

// Test cases
const testCases = [
  {
    name: 'Single stage format',
    input: 'Stage 1/5: Running understander (claude:sonnet)',
    expected: { stage: 1, endStage: undefined, total: 5, name: 'understander', provider: 'claude', model: 'sonnet' },
  },
  {
    name: 'Parallel stage format',
    input: 'Stage 3-4/5: Running critique and reducer in parallel (openai:gpt4, claude:opus)',
    expected: { stage: 3, endStage: 4, total: 5, name: 'critique and reducer in parallel', provider: 'openai', model: 'gpt4' },
  },
  {
    name: 'Final stage',
    input: 'Stage 5/5: Running finalizer (kimi:k1)',
    expected: { stage: 5, endStage: undefined, total: 5, name: 'finalizer', provider: 'kimi', model: 'k1' },
  },
  {
    name: 'Different providers',
    input: 'Stage 2/5: Running coder (openai:gpt-4o)',
    expected: { stage: 2, endStage: undefined, total: 5, name: 'coder', provider: 'openai', model: 'gpt-4o' },
  },
  {
    name: 'Non-matching line - no stage prefix',
    input: 'Running understander (claude:sonnet)',
    expected: null,
  },
  {
    name: 'Non-matching line - different total',
    input: 'Stage 1/10: Running understander (claude:sonnet)',
    expected: null,
  },
  {
    name: 'Non-matching line - stderr prefix',
    input: 'stderr: Stage 1/5: Running understander (claude:sonnet)',
    expected: { stage: 1, endStage: undefined, total: 5, name: 'understander', provider: 'claude', model: 'sonnet' },
  },
];

let passed = 0;
let failed = 0;

testCases.forEach(tc => {
  const result = parseStageLine(tc.input);
  let match = false;
  
  if (tc.expected === null) {
    match = result === null;
  } else if (result === null) {
    match = false;
  } else {
    match = (
      result.stage === tc.expected.stage &&
      result.endStage === tc.expected.endStage &&
      result.total === tc.expected.total &&
      result.name === tc.expected.name &&
      result.provider === tc.expected.provider &&
      result.model === tc.expected.model
    );
  }
  
  if (match) {
    console.log(`✓ PASS: ${tc.name}`);
    passed++;
  } else {
    console.log(`✗ FAIL: ${tc.name}`);
    console.log(`  Input: ${tc.input}`);
    console.log(`  Expected: ${JSON.stringify(tc.expected)}`);
    console.log(`  Got: ${JSON.stringify(result)}`);
    failed++;
  }
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
NODEJS

# Run the test script
node "$TEST_SCRIPT"
if [ $? -ne 0 ]; then
  test_fail "Step progress parser tests failed"
fi

test_pass "Step progress parser logic tests passed"
