#!/usr/bin/env node

const fs = require('fs');
const http = require('http');
const path = require('path');
const { execFileSync, spawn } = require('child_process');

const TEST_NAME = 'test-session-append';
const PLAN_PROMPT = 'test prompt, end this asap';
const REFINE_PROMPT = 'test prompt, end this asap';
const SERVER_PORT = Number(process.env.PLAYWRIGHT_SOFT_PORT || '4173');

const scriptDir = __dirname;
const vscodeDir = path.resolve(scriptDir, '..', '..');
const worktreeRoot = path.resolve(vscodeDir, '..');
const treesDir = path.resolve(worktreeRoot, '..');
const repoRoot = path.basename(treesDir) === 'trees' ? path.resolve(treesDir, '..') : treesDir;
const worktreeRelativeToRepo = path.relative(repoRoot, worktreeRoot).split(path.sep).join('/');

const tmpDir = path.join(worktreeRoot, '.tmp');
const reportPath = path.join(tmpDir, `${TEST_NAME}-report.txt`);

const readPlaywright = async () => {
  try {
    return require('playwright');
  } catch (error) {
    throw new Error(
      `Missing playwright dependency. Install it with: npm --prefix ${vscodeDir} install --save-dev playwright`,
    );
  }
};

const toUrlPath = (targetPath) => {
  const relative = path.relative(repoRoot, targetPath).split(path.sep).join('/');
  return `/${relative}`.replace(/\/+/g, '/');
};

const waitForServer = async (port, timeoutMs = 10000) => {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const ok = await new Promise((resolve) => {
      const req = http.get({ hostname: '127.0.0.1', port, path: '/' }, (res) => {
        res.resume();
        resolve(res.statusCode >= 200 && res.statusCode < 500);
      });
      req.on('error', () => resolve(false));
      req.setTimeout(1000, () => {
        req.destroy();
        resolve(false);
      });
    });
    if (ok) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error(`Server at 127.0.0.1:${port} did not become ready in ${timeoutMs}ms`);
};

const cleanupPreviousScreenshots = () => {
  fs.mkdirSync(tmpDir, { recursive: true });
  const entries = fs.readdirSync(tmpDir);
  entries.forEach((entry) => {
    if (/^test-session-append-\d+\.png$/.test(entry)) {
      fs.rmSync(path.join(tmpDir, entry), { force: true });
    }
  });
};

const button = (id, label, action, variant, disabled) => ({
  id,
  label,
  action,
  variant,
  disabled,
});

const postSessionUpdate = async (page, sessionId, session) => {
  await page.evaluate(
    ({ messageSessionId, messageSession }) => {
      window.postMessage(
        {
          type: 'plan/sessionUpdated',
          sessionId: messageSessionId,
          session: messageSession,
        },
        '*',
      );
    },
    { messageSessionId: sessionId, messageSession: session },
  );
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const run = async () => {
  const { chromium } = await readPlaywright();

  cleanupPreviousScreenshots();
  fs.writeFileSync(reportPath, `${TEST_NAME} report\n`, 'utf8');

  const harnessScript = path.join(vscodeDir, 'bin', 'render-plan-harness.js');
  execFileSync('node', [harnessScript], { cwd: worktreeRoot, stdio: 'inherit' });

  const harnessPath = path.join(tmpDir, 'plan-dev-harness.html');
  const harnessUrl = `http://127.0.0.1:${SERVER_PORT}${toUrlPath(harnessPath)}`;

  const server = spawn('python', ['-m', 'http.server', String(SERVER_PORT), '--directory', repoRoot], {
    cwd: worktreeRoot,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  server.stdout.on('data', (chunk) => {
    process.stdout.write(`[soft-server] ${chunk}`);
  });
  server.stderr.on('data', (chunk) => {
    process.stderr.write(`[soft-server] ${chunk}`);
  });

  let browser;
  const reportLines = [];
  let stepIndex = 0;

  const addReport = (line) => {
    reportLines.push(line);
    fs.writeFileSync(reportPath, `${TEST_NAME} report\n${reportLines.join('\n')}\n`, 'utf8');
  };

  const nextScreenshotPath = () => {
    stepIndex += 1;
    return path.join(tmpDir, `${TEST_NAME}-${stepIndex}.png`);
  };

  const softCheck = async (name, fn) => {
    try {
      await fn();
      addReport(`PASS: ${name}`);
    } catch (error) {
      addReport(`WARN: ${name} -> ${String(error)}`);
    }
  };

  try {
    await waitForServer(SERVER_PORT);

    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ viewport: { width: 1440, height: 1800 } });
    const page = await context.newPage();

    await page.goto(harnessUrl, { waitUntil: 'networkidle' });
    await page.waitForSelector('#new-plan', { timeout: 10000 });
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    await page.click('#new-plan');
    await page.waitForSelector('#plan-textarea', { timeout: 10000 });
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    const hintText = await page.locator('.input-hint').textContent();
    if (!hintText || !hintText.includes('Esc to cancel')) {
      throw new Error(`Plan input hint text missing Esc guidance: ${hintText || 'empty'}`);
    }

    const planButtonCount = await page.locator('#plan-input button').count();
    if (planButtonCount !== 0) {
      throw new Error(`Plan input should not include buttons; found ${planButtonCount}`);
    }

    await page.press('#plan-textarea', 'Escape');
    await page.waitForFunction(() => {
      const panel = document.getElementById('plan-input');
      return Boolean(panel && panel.classList.contains('hidden'));
    }, { timeout: 10000 });
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    await page.click('#new-plan');
    await page.waitForSelector('#plan-textarea', { timeout: 10000 });

    await page.fill('#plan-textarea', PLAN_PROMPT);
    const submitShortcut = process.platform === 'darwin' ? 'Meta+Enter' : 'Control+Enter';
    await page.press('#plan-textarea', submitShortcut);
    await page.waitForFunction(() => {
      const panel = document.getElementById('plan-input');
      return Boolean(panel && panel.classList.contains('hidden'));
    }, { timeout: 10000 });
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    const sessionId = 'plan-soft-session-append';
    const t0 = Date.now();

    const promptWidget = {
      id: 'text-prompt',
      type: 'text',
      content: [PLAN_PROMPT],
      metadata: { role: 'prompt' },
      createdAt: t0,
    };

    const planTerminalRunning = {
      id: 'terminal-plan',
      type: 'terminal',
      title: 'Plan Console Log',
      content: ['stderr: Stage 1/5: Running understander (kimi:default)'],
      metadata: { role: 'plan-terminal' },
      createdAt: t0 + 1,
    };

    const planProgressRunning = {
      id: 'progress-plan',
      type: 'progress',
      metadata: {
        role: 'plan-progress',
        terminalId: 'terminal-plan',
        progressEvents: [
          {
            type: 'stage',
            line: 'Stage 1/5: Running understander (kimi:default)',
            timestamp: t0 + 1000,
          },
        ],
      },
      createdAt: t0 + 2,
    };

    const actionRunning = {
      id: 'actions-1',
      type: 'buttons',
      metadata: {
        role: 'session-actions',
        buttons: [
          button('view-plan', 'View Plan', 'plan/view-plan', 'secondary', true),
          button('view-issue', 'View Issue', 'plan/view-issue', 'secondary', true),
          button('implement', 'Implement', 'plan/impl', 'primary', true),
          button('refine', 'Refine', 'plan/refine', 'secondary', true),
          button('rerun', 'Rerun', 'plan/rerun', 'secondary', true),
        ],
      },
      createdAt: t0 + 3,
    };

    await postSessionUpdate(page, sessionId, {
      id: sessionId,
      title: 'test prompt, end this...',
      collapsed: false,
      status: 'running',
      prompt: PLAN_PROMPT,
      issueNumber: undefined,
      issueState: 'unknown',
      planPath: undefined,
      prUrl: undefined,
      implStatus: 'idle',
      refineRuns: [],
      version: 3,
      widgets: [promptWidget, planTerminalRunning, planProgressRunning, actionRunning],
      phase: 'planning',
      actionMode: 'default',
      rerun: undefined,
      createdAt: t0,
      updatedAt: t0 + 3,
    });

    await page.waitForSelector('.session');
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    await sleep(600);

    const planTerminalDone = {
      ...planTerminalRunning,
      content: [
        'stderr: Stage 1/5: Running understander (kimi:default)',
        'stderr: Stage 2/5: Running bold-proposer (kimi:default)',
        'stderr: Stage 3-4/5: Running critique and reducer in parallel (kimi:default)',
        'stderr: Stage 5/5: Running consensus (kimi:default)',
        'Created placeholder issue #934',
        'See the full plan locally at: .tmp/issue-934-plan.md',
        'Exit code: 0',
      ],
    };

    const planProgressDone = {
      ...planProgressRunning,
      metadata: {
        role: 'plan-progress',
        terminalId: 'terminal-plan',
        progressEvents: [
          {
            type: 'stage',
            line: 'Stage 1/5: Running understander (kimi:default)',
            timestamp: t0 + 1000,
          },
          {
            type: 'stage',
            line: 'Stage 2/5: Running bold-proposer (kimi:default)',
            timestamp: t0 + 4000,
          },
          {
            type: 'stage',
            line: 'Stage 3-4/5: Running critique and reducer in parallel (kimi:default)',
            timestamp: t0 + 9000,
          },
          {
            type: 'stage',
            line: 'Stage 5/5: Running consensus (kimi:default)',
            timestamp: t0 + 15000,
          },
          {
            type: 'exit',
            timestamp: t0 + 22000,
          },
        ],
      },
    };

    const actionPlanDone = {
      ...actionRunning,
      metadata: {
        role: 'session-actions',
        buttons: [
          button('view-plan', 'View Plan', 'plan/view-plan', 'secondary', false),
          button('view-issue', 'View Issue', 'plan/view-issue', 'secondary', false),
          button('implement', 'Implement', 'plan/impl', 'primary', false),
          button('refine', 'Refine', 'plan/refine', 'secondary', false),
          button('rerun', 'Rerun', 'plan/rerun', 'secondary', true),
        ],
      },
    };

    await postSessionUpdate(page, sessionId, {
      id: sessionId,
      title: 'test prompt, end this...',
      collapsed: false,
      status: 'success',
      prompt: PLAN_PROMPT,
      issueNumber: '934',
      issueState: 'open',
      planPath: '.tmp/issue-934-plan.md',
      prUrl: undefined,
      implStatus: 'idle',
      refineRuns: [],
      version: 3,
      widgets: [promptWidget, planTerminalDone, planProgressDone, actionPlanDone],
      phase: 'plan-completed',
      actionMode: 'default',
      rerun: {
        commandType: 'refine',
        prompt: PLAN_PROMPT,
        issueNumber: '934',
        lastExitCode: 0,
        updatedAt: t0 + 22000,
      },
      createdAt: t0,
      updatedAt: t0 + 22000,
    });

    const lastRow = page.locator('.widget-buttons').last();
    await lastRow.locator('button:has-text("Implement")').waitFor({ timeout: 10000 });

    await softCheck('plan completed -> Implement enabled', async () => {
      const disabled = await lastRow.locator('button:has-text("Implement")').isDisabled();
      if (disabled) {
        throw new Error('Implement is still disabled');
      }
    });

    await softCheck('plan completed -> Refine enabled', async () => {
      const disabled = await lastRow.locator('button:has-text("Refine")').isDisabled();
      if (disabled) {
        throw new Error('Refine is still disabled');
      }
    });

    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    await lastRow.locator('button:has-text("Refine")').click();
    const refineInput = page.locator('.widget-input-textarea').last();
    await refineInput.waitFor({ timeout: 10000 });
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    await refineInput.fill(REFINE_PROMPT);
    await refineInput.press(submitShortcut);

    const refineTerminalRunning = {
      id: 'terminal-refine-1',
      type: 'terminal',
      title: 'Refinement Log',
      content: ['stderr: Stage 1/5: Running understander (kimi:default)'],
      metadata: { role: 'refine-terminal', runId: 'refine-soft-1', focus: REFINE_PROMPT },
      createdAt: t0 + 23000,
    };

    const refineProgressRunning = {
      id: 'progress-refine-1',
      type: 'progress',
      metadata: {
        role: 'refine-progress',
        terminalId: 'terminal-refine-1',
        runId: 'refine-soft-1',
        progressEvents: [
          {
            type: 'stage',
            line: 'Stage 1/5: Running understander (kimi:default)',
            timestamp: t0 + 23500,
          },
        ],
      },
      createdAt: t0 + 23001,
    };

    const actionRefineRunning = {
      ...actionPlanDone,
      metadata: {
        role: 'session-actions',
        buttons: [
          button('refine', 'Running...', 'plan/refine', 'secondary', true),
        ],
      },
    };

    await postSessionUpdate(page, sessionId, {
      id: sessionId,
      title: 'test prompt, end this...',
      collapsed: false,
      status: 'success',
      prompt: PLAN_PROMPT,
      issueNumber: '934',
      issueState: 'open',
      planPath: '.tmp/issue-934-plan.md',
      prUrl: undefined,
      implStatus: 'idle',
      refineRuns: [
        {
          id: 'refine-soft-1',
          prompt: REFINE_PROMPT,
          status: 'running',
          logs: ['stderr: Stage 1/5: Running understander (kimi:default)'],
          collapsed: false,
          createdAt: t0 + 23000,
          updatedAt: t0 + 23500,
        },
      ],
      version: 3,
      widgets: [
        promptWidget,
        planTerminalDone,
        planProgressDone,
        actionRefineRunning,
        refineTerminalRunning,
        refineProgressRunning,
      ],
      phase: 'refining',
      actionMode: 'refine',
      rerun: {
        commandType: 'refine',
        prompt: REFINE_PROMPT,
        issueNumber: '934',
        updatedAt: t0 + 23500,
      },
      createdAt: t0,
      updatedAt: t0 + 23500,
    });

    await page.waitForSelector('.widget-buttons button:has-text("Running...")', { timeout: 10000 });
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    await sleep(600);

    const refineTerminalDone = {
      ...refineTerminalRunning,
      content: [
        'stderr: Stage 1/5: Running understander (kimi:default)',
        'stderr: Stage 2/5: Running bold-proposer (kimi:default)',
        'stderr: Stage 3-4/5: Running critique and reducer in parallel (kimi:default)',
        'stderr: Stage 5/5: Running consensus (kimi:default)',
        'Exit code: 0',
      ],
    };

    const refineProgressDone = {
      ...refineProgressRunning,
      metadata: {
        role: 'refine-progress',
        terminalId: 'terminal-refine-1',
        runId: 'refine-soft-1',
        progressEvents: [
          {
            type: 'stage',
            line: 'Stage 1/5: Running understander (kimi:default)',
            timestamp: t0 + 23500,
          },
          {
            type: 'stage',
            line: 'Stage 2/5: Running bold-proposer (kimi:default)',
            timestamp: t0 + 27000,
          },
          {
            type: 'stage',
            line: 'Stage 3-4/5: Running critique and reducer in parallel (kimi:default)',
            timestamp: t0 + 32000,
          },
          {
            type: 'stage',
            line: 'Stage 5/5: Running consensus (kimi:default)',
            timestamp: t0 + 38000,
          },
          {
            type: 'exit',
            timestamp: t0 + 43000,
          },
        ],
      },
    };

    const actionRefinedArchived = {
      ...actionPlanDone,
      metadata: {
        role: 'session-actions-archived',
        buttons: [
          button('refined', 'Refined', 'plan/refine', 'secondary', true),
        ],
        archivedAt: t0 + 43100,
      },
    };

    const actionFresh = {
      id: 'actions-2',
      type: 'buttons',
      metadata: {
        role: 'session-actions',
        buttons: [
          button('view-plan', 'View Plan', 'plan/view-plan', 'secondary', false),
          button('view-issue', 'View Issue', 'plan/view-issue', 'secondary', false),
          button('implement', 'Implement', 'plan/impl', 'primary', false),
          button('refine', 'Refine', 'plan/refine', 'secondary', false),
          button('rerun', 'Rerun', 'plan/rerun', 'secondary', true),
        ],
      },
      createdAt: t0 + 43101,
    };

    await postSessionUpdate(page, sessionId, {
      id: sessionId,
      title: 'test prompt, end this...',
      collapsed: false,
      status: 'success',
      prompt: PLAN_PROMPT,
      issueNumber: '934',
      issueState: 'open',
      planPath: '.tmp/issue-934-plan.md',
      prUrl: undefined,
      implStatus: 'idle',
      refineRuns: [
        {
          id: 'refine-soft-1',
          prompt: REFINE_PROMPT,
          status: 'success',
          logs: refineTerminalDone.content,
          collapsed: false,
          createdAt: t0 + 23000,
          updatedAt: t0 + 43000,
        },
      ],
      version: 3,
      widgets: [
        promptWidget,
        planTerminalDone,
        planProgressDone,
        actionRefinedArchived,
        refineTerminalDone,
        refineProgressDone,
        actionFresh,
      ],
      phase: 'plan-completed',
      actionMode: 'default',
      rerun: {
        commandType: 'refine',
        prompt: REFINE_PROMPT,
        issueNumber: '934',
        lastExitCode: 0,
        updatedAt: t0 + 43000,
      },
      createdAt: t0,
      updatedAt: t0 + 43101,
    });

    const latestRow = page.locator('.widget-buttons').last();
    await latestRow.locator('button:has-text("Refine")').waitFor({ timeout: 10000 });

    await softCheck('refine completed -> latest row has enabled Implement', async () => {
      const disabled = await latestRow.locator('button:has-text("Implement")').isDisabled();
      if (disabled) {
        throw new Error('Implement is disabled in latest action row');
      }
    });

    await softCheck('refine completed -> latest row has enabled Refine', async () => {
      const disabled = await latestRow.locator('button:has-text("Refine")').isDisabled();
      if (disabled) {
        throw new Error('Refine is disabled in latest action row');
      }
    });

    await softCheck('refine completed -> old row archived as Refined', async () => {
      const visible = await page.locator('.widget-buttons').first().locator('button:has-text("Refined")').isVisible();
      if (!visible) {
        throw new Error('Archived Refined marker not visible in old action row');
      }
    });

    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    const implTerminalRunning = {
      id: 'terminal-impl-1',
      type: 'terminal',
      title: 'Implementation Log',
      content: ['stderr: Stage 1/5: Running coder (kimi:default)'],
      metadata: { role: 'impl-terminal' },
      createdAt: t0 + 44000,
    };

    const implProgressRunning = {
      id: 'progress-impl-1',
      type: 'progress',
      metadata: {
        role: 'impl-progress',
        terminalId: 'terminal-impl-1',
        progressEvents: [
          {
            type: 'stage',
            line: 'Stage 1/5: Running coder (kimi:default)',
            timestamp: t0 + 44500,
          },
        ],
      },
      createdAt: t0 + 44001,
    };

    const actionImplementRunning = {
      ...actionFresh,
      metadata: {
        role: 'session-actions',
        buttons: [
          button('implement', 'Running...', 'plan/impl', 'primary', true),
        ],
      },
    };

    await postSessionUpdate(page, sessionId, {
      id: sessionId,
      title: 'test prompt, end this...',
      collapsed: false,
      status: 'success',
      prompt: PLAN_PROMPT,
      issueNumber: '934',
      issueState: 'open',
      planPath: '.tmp/issue-934-plan.md',
      prUrl: undefined,
      implStatus: 'running',
      refineRuns: [
        {
          id: 'refine-soft-1',
          prompt: REFINE_PROMPT,
          status: 'success',
          logs: refineTerminalDone.content,
          collapsed: false,
          createdAt: t0 + 23000,
          updatedAt: t0 + 43000,
        },
      ],
      version: 3,
      widgets: [
        promptWidget,
        planTerminalDone,
        planProgressDone,
        actionRefinedArchived,
        refineTerminalDone,
        refineProgressDone,
        actionImplementRunning,
        implTerminalRunning,
        implProgressRunning,
      ],
      phase: 'implementing',
      actionMode: 'implement',
      rerun: {
        commandType: 'impl',
        issueNumber: '934',
        updatedAt: t0 + 44500,
      },
      createdAt: t0,
      updatedAt: t0 + 44500,
    });

    await page.waitForSelector('.widget-buttons button:has-text("Running...")', { timeout: 10000 });
    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    const implTerminalDone = {
      ...implTerminalRunning,
      content: [
        'stderr: Stage 1/5: Running coder (kimi:default)',
        'Issue-934 implementation is done',
        'Find the PR at: https://github.com/Synthesys-Lab/agentize/pull/940',
        'Exit code: 0',
      ],
    };

    const implProgressDone = {
      ...implProgressRunning,
      metadata: {
        role: 'impl-progress',
        terminalId: 'terminal-impl-1',
        progressEvents: [
          {
            type: 'stage',
            line: 'Stage 1/5: Running coder (kimi:default)',
            timestamp: t0 + 44500,
          },
          {
            type: 'exit',
            timestamp: t0 + 50000,
          },
        ],
      },
    };

    const actionImplementedArchived = {
      ...actionFresh,
      metadata: {
        role: 'session-actions-archived',
        buttons: [
          button('implemented', 'Implemented', 'plan/impl', 'primary', true),
        ],
        archivedAt: t0 + 50001,
      },
    };

    const actionAfterImpl = {
      id: 'actions-3',
      type: 'buttons',
      metadata: {
        role: 'session-actions',
        buttons: [
          button('view-plan', 'View Plan', 'plan/view-plan', 'secondary', false),
          button('view-issue', 'View Issue', 'plan/view-issue', 'secondary', false),
          button('implement', 'Implement', 'plan/impl', 'primary', false),
          button('refine', 'Refine', 'plan/refine', 'secondary', false),
          button('rerun', 'Rerun', 'plan/rerun', 'secondary', true),
          button('view-pr', 'View PR', 'plan/view-pr', 'primary', false),
        ],
      },
      createdAt: t0 + 50002,
    };

    await postSessionUpdate(page, sessionId, {
      id: sessionId,
      title: 'test prompt, end this...',
      collapsed: false,
      status: 'success',
      prompt: PLAN_PROMPT,
      issueNumber: '934',
      issueState: 'open',
      planPath: '.tmp/issue-934-plan.md',
      prUrl: 'https://github.com/Synthesys-Lab/agentize/pull/940',
      implStatus: 'success',
      refineRuns: [
        {
          id: 'refine-soft-1',
          prompt: REFINE_PROMPT,
          status: 'success',
          logs: refineTerminalDone.content,
          collapsed: false,
          createdAt: t0 + 23000,
          updatedAt: t0 + 43000,
        },
      ],
      version: 3,
      widgets: [
        promptWidget,
        planTerminalDone,
        planProgressDone,
        actionRefinedArchived,
        refineTerminalDone,
        refineProgressDone,
        actionImplementedArchived,
        implTerminalDone,
        implProgressDone,
        actionAfterImpl,
      ],
      phase: 'completed',
      actionMode: 'default',
      rerun: {
        commandType: 'impl',
        issueNumber: '934',
        lastExitCode: 0,
        updatedAt: t0 + 50000,
      },
      createdAt: t0,
      updatedAt: t0 + 50002,
    });

    const latestAfterImpl = page.locator('.widget-buttons').last();
    await latestAfterImpl.locator('button:has-text("View PR")').waitFor({ timeout: 10000 });

    await softCheck('implement completed -> old row archived as Implemented', async () => {
      const archivedCount = await page.locator('.widget-buttons button:has-text("Implemented")').count();
      if (archivedCount < 1) {
        throw new Error('Archived Implemented marker not found');
      }
    });

    await softCheck('implement completed -> latest row has View PR', async () => {
      const disabled = await latestAfterImpl.locator('button:has-text("View PR")').isDisabled();
      if (disabled) {
        throw new Error('View PR is disabled in latest action row');
      }
    });

    await softCheck('implement completed -> fresh action row appended at the tail', async () => {
      const isTailButtons = await page.evaluate(() => {
        const body = document.querySelector('.session .session-body');
        if (!body) {
          return false;
        }
        const last = body.lastElementChild;
        if (!last || !last.classList.contains('widget-buttons')) {
          return false;
        }
        return Array.from(last.querySelectorAll('button')).some((btn) => btn.textContent?.trim() === 'View PR');
      });
      if (!isTailButtons) {
        throw new Error('Latest action row is not appended at the end of the session timeline');
      }
    });

    await page.screenshot({ path: nextScreenshotPath(), fullPage: true });

    addReport(`INFO: harnessUrl=${harnessUrl}`);
    addReport(`INFO: screenshots=.tmp/${TEST_NAME}-1.png ... .tmp/${TEST_NAME}-${stepIndex}.png`);
  } finally {
    if (browser) {
      await browser.close().catch(() => undefined);
    }
    if (!server.killed) {
      server.kill('SIGTERM');
    }
  }
};

run()
  .then(() => {
    process.stdout.write(`[${TEST_NAME}] completed.\n`);
  })
  .catch((error) => {
    process.stderr.write(`[${TEST_NAME}] failed: ${String(error)}\n`);
    process.exitCode = 1;
  });
