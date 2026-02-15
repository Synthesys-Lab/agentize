import type { PlanImplMessage, PlanToggleImplCollapseMessage } from './types';

// Provided by VS Code in the webview environment.
declare function acquireVsCodeApi(): { postMessage(message: unknown): void };

(() => {
  const statusEl = document.getElementById('plan-skeleton-status');
  if (statusEl) {
    statusEl.textContent = 'Webview script executing...';
  }

  let vscode: { postMessage(message: unknown): void } | undefined;
  try {
    vscode = acquireVsCodeApi();
  } catch (error) {
    if (statusEl) {
      statusEl.textContent = `Failed to initialize VS Code webview API: ${String(error)}`;
    }
    return;
  }
  const MAX_LOG_LINES = 1000;

  const root = document.getElementById('plan-root');
  if (!root) {
    if (statusEl) {
      statusEl.textContent = 'Missing #plan-root element in webview HTML.';
    }
    return;
  }

  if (statusEl) {
    statusEl.textContent = 'Rendering webview UI...';
  }

  root.innerHTML = `
    <div class="toolbar">
      <button id="new-plan" class="primary">New Plan</button>
    </div>
    <div id="plan-input" class="plan-input hidden">
      <label class="input-label" for="plan-textarea">Plan prompt</label>
      <textarea id="plan-textarea" rows="6" placeholder="Describe the plan you want to run..."></textarea>
      <div class="input-actions">
        <button id="plan-run" class="primary">Run Plan</button>
        <button id="plan-cancel">Cancel</button>
        <span class="hint">Cmd+Enter / Ctrl+Enter to run</span>
      </div>
    </div>
    <div id="session-list" class="session-list"></div>
  `;

  vscode.postMessage({ type: 'webview/ready' });

  const newPlanButton = document.getElementById('new-plan');
  const inputPanel = document.getElementById('plan-input');
  const textarea = document.getElementById('plan-textarea') as HTMLTextAreaElement;
  const runButton = document.getElementById('plan-run');
  const cancelButton = document.getElementById('plan-cancel');
  const sessionList = document.getElementById('session-list');

  const sessionNodes = new Map<string, {
    container: HTMLElement;
    toggleButton: HTMLElement;
    title: HTMLElement;
    status: HTMLElement;
    prompt: HTMLElement;
    logs: HTMLElement;
    implLogs?: HTMLElement;
    body: HTMLElement;
    refineButton?: HTMLButtonElement;
    refineThread?: HTMLElement;
    refineComposer?: HTMLElement;
    refineTextarea?: HTMLTextAreaElement;
    stepIndicators?: HTMLElement;
    rawLogsBody?: HTMLElement;
    rawLogsToggle?: HTMLElement;
    implLogsBox?: HTMLElement;
    implLogsBody?: HTMLElement;
    implLogsToggle?: HTMLElement;
    implButton?: HTMLButtonElement;
  }>();
  const logBuffers = new Map<string, string[]>();
  const implLogBuffers = new Map<string, string[]>();
  const refineLogBuffers = new Map<string, string[]>(); // key: `${sessionId}:${runId}`
  const stepStates = new Map<string, StepState[]>();
  const refineStepStates = new Map<string, StepState[]>(); // key: `${sessionId}:${runId}`
  const logsCollapsedState = new Map<string, boolean>();
  const refineLogsCollapsedState = new Map<string, boolean>(); // key: `${sessionId}:${runId}`
  const issueNumbers = new Map<string, string>();
  const sessionCache = new Map<string, SessionSummary>();

  type RefineRunNode = {
    container: HTMLElement;
    focus: HTMLElement;
    stepIndicators: HTMLElement;
    logsBox: HTMLElement;
    logsBody: HTMLElement;
    logsToggle: HTMLButtonElement;
    logs: HTMLElement;
  };

  const refineRunNodes = new Map<string, RefineRunNode>(); // key: `${sessionId}:${runId}`

  interface StepState {
    stage: number;
    endStage?: number;
    total: number;
    name: string;
    provider: string;
    model: string;
    status: 'pending' | 'running' | 'completed';
    startTime: number;
    endTime?: number;
  }

  const postMessage = (message: unknown) => vscode.postMessage(message);
  const postImplMessage = (message: PlanImplMessage | PlanToggleImplCollapseMessage) => postMessage(message);

  const showInputPanel = () => {
    inputPanel?.classList.remove('hidden');
    textarea?.focus();
  };

  const hideInputPanel = () => {
    inputPanel?.classList.add('hidden');
  };

  const submitPlan = () => {
    const prompt = textarea?.value.trim();
    if (!prompt) {
      return;
    }

    postMessage({ type: 'plan/new', prompt });
    if (textarea) textarea.value = '';
    postMessage({ type: 'plan/updateDraft', value: '' });
    hideInputPanel();
  };

  newPlanButton?.addEventListener('click', () => {
    showInputPanel();
  });

  runButton?.addEventListener('click', () => {
    submitPlan();
  });

  cancelButton?.addEventListener('click', () => {
    hideInputPanel();
  });

  textarea?.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      submitPlan();
    }
  });

  let draftTimer: ReturnType<typeof setTimeout> | undefined;
  textarea?.addEventListener('input', () => {
    if (draftTimer) {
      clearTimeout(draftTimer);
    }
    draftTimer = setTimeout(() => {
      postMessage({ type: 'plan/updateDraft', value: textarea.value });
    }, 150);
  });

  // Parse stage line: "Stage N/5: Running {name} ({provider}:{model})" or "Stage M-N/5: ..."
  // Parallel stages format: "Stage M-N/5: Running {name with spaces} ({provider}:{model}, {provider}:{model})"
  const parseStageLine = (line: string): StepState | null => {
    // Match stage number, name (with possible spaces), and provider info (supports parallel backends)
    const match = line.match(/Stage\s+(\d+)(?:-(\d+))?\/5:\s+Running\s+(.+?)\s*\(([^)]+)\)/);
    if (!match) return null;

    const [, stageStr, endStageStr, name, providerInfo] = match;
    // For parallel stages, use the first provider:model pair
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
  };

  // Update step states based on new log line
  const updateStepStatesIn = (stateMap: Map<string, StepState[]>, sessionId: string, line: string): boolean => {
    const newStep = parseStageLine(line);
    if (!newStep) return false;

    let steps = stateMap.get(sessionId) || [];

    // Mark any running step as completed
    steps = steps.map((step): StepState => {
      if (step.status === 'running') {
        return { ...step, status: 'completed' as const, endTime: Date.now() };
      }
      return step;
    });

    // Add new running step
    steps.push(newStep);
    stateMap.set(sessionId, steps);
    return true;
  };

  // Mark all steps as completed (called on process exit)
  const completeAllStepsIn = (stateMap: Map<string, StepState[]>, sessionId: string): void => {
    const steps = stateMap.get(sessionId) || [];
    const updated = steps.map((step): StepState => {
      if (step.status === 'running') {
        return { ...step, status: 'completed' as const, endTime: Date.now() };
      }
      return step;
    });
    stateMap.set(sessionId, updated);
  };

  // Format elapsed time in seconds
  const formatElapsed = (startTime: number, endTime: number): string => {
    const elapsed = Math.max(0, Math.round((endTime - startTime) / 1000));
    return `${elapsed}s`;
  };

  // Render step indicators
  const renderStepIndicatorsFrom = (stateMap: Map<string, StepState[]>, sessionId: string, className = 'step-indicators'): HTMLElement => {
    const steps = stateMap.get(sessionId) || [];
    const container = document.createElement('div');
    container.className = className;

    steps.forEach(step => {
      const indicator = document.createElement('div');
      indicator.className = `step-indicator ${step.status}`;

      const stageText = step.endStage
        ? `Stage ${step.stage}-${step.endStage}/${step.total}`
        : `Stage ${step.stage}/${step.total}`;

      const elapsedText = step.status === 'completed' && step.endTime
        ? `done in ${formatElapsed(step.startTime, step.endTime)}`
        : '<span class="loading-dots"></span>';

      indicator.innerHTML = `
        <span class="step-number">${stageText}</span>
        <span class="step-name">${escapeHtml(step.name)}</span>
        <span class="step-model">${escapeHtml(step.provider)}:${escapeHtml(step.model)}</span>
        <span class="step-status">${elapsedText}</span>
      `;
      container.appendChild(indicator);
    });

    return container;
  };

  // Escape HTML special characters
  const escapeHtml = (text: string): string => {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  };

  // Detect and render clickable links
  const renderLinks = (text: string): string => {
    // GitHub issue URLs: https://github.com/owner/repo/issues/N
    const githubRegex = /https:\/\/github\.com\/([^\/\s]+)\/([^\/\s]+)\/issues\/(\d+)/g;

    // Local markdown paths: .tmp/issue-N.md or /path/to/file.md
    const mdPathRegex = /(?<=\s|^)(\.tmp\/[^\s\n]+\.md|[\w\-\/]+\.tmp\/[^\s\n]+\.md)(?=\s|$)/g;

    let result = escapeHtml(text);

    // Replace GitHub URLs with clickable links
    result = result.replace(githubRegex, (match, owner, repo, issue) => {
      return `<a href="#" data-link-type="github" data-url="${escapeHtml(match)}">${escapeHtml(match)}</a>`;
    });

    // Replace local markdown paths with clickable links
    result = result.replace(mdPathRegex, (match) => {
      return `<a href="#" data-link-type="local" data-path="${escapeHtml(match)}">${escapeHtml(match)}</a>`;
    });

    return result;
  };

  const extractIssueNumber = (line: string): string | null => {
    const placeholderMatch = /Created placeholder issue #(\d+)/.exec(line);
    if (placeholderMatch) {
      return placeholderMatch[1];
    }

    const urlMatch = /https:\/\/github\.com\/[^/]+\/[^/]+\/issues\/(\d+)/.exec(line);
    if (urlMatch) {
      return urlMatch[1];
    }

    return null;
  };

  // Handle link click
  const handleLinkClick = (event: Event): void => {
    const target = event.target as HTMLElement;
    const anchor = target.closest('a[data-link-type]') as HTMLAnchorElement;
    if (!anchor) return;

    event.preventDefault();
    const linkType = anchor.dataset.linkType;

    if (linkType === 'github') {
      const url = anchor.dataset.url;
      if (url) {
        postMessage({ type: 'link/openExternal', url });
      }
    } else if (linkType === 'local') {
      const path = anchor.dataset.path;
      if (path) {
        postMessage({ type: 'link/openFile', path });
      }
    }
  };

  const updateImplControls = (sessionId: string, session?: SessionSummary): void => {
    const current = session ?? sessionCache.get(sessionId);
    const node = sessionNodes.get(sessionId);
    if (!current || !node) {
      return;
    }

    if (current.issueNumber) {
      issueNumbers.set(sessionId, current.issueNumber);
    }

    const issueNumber = current.issueNumber || issueNumbers.get(sessionId);
    const showButton = current.status === 'success' && Boolean(issueNumber);
    if (node.implButton) {
      node.implButton.classList.toggle('hidden', !showButton);
      node.implButton.disabled = current.implStatus === 'running';
      node.implButton.dataset.issueNumber = issueNumber ?? '';
    }

    const hasImplLogs = Array.isArray(current.implLogs) && current.implLogs.length > 0;
    const implStatus = current.implStatus ?? 'idle';
    const showImplLogs = hasImplLogs || (implStatus !== 'idle');
    if (node.implLogsBox) {
      node.implLogsBox.classList.toggle('hidden', !showImplLogs);
    }

    if (node.implLogsBody) {
      const isCollapsed = current.implCollapsed ?? false;
      node.implLogsBody.classList.toggle('collapsed', isCollapsed);
      if (node.implLogsToggle) {
        node.implLogsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';
      }
    }
  };

  const updateRefineControls = (sessionId: string, session?: SessionSummary): void => {
    const current = session ?? sessionCache.get(sessionId);
    const node = sessionNodes.get(sessionId);
    if (!current || !node) {
      return;
    }

    if (current.issueNumber) {
      issueNumbers.set(sessionId, current.issueNumber);
    }

    const issueNumber = current.issueNumber || issueNumbers.get(sessionId);
    const showButton = (current.status === 'success' || current.status === 'error') && Boolean(issueNumber);
    if (node.refineButton) {
      node.refineButton.classList.toggle('hidden', !showButton);
      node.refineButton.dataset.issueNumber = issueNumber ?? '';
    }
  };

  type RefineRunSummary = {
    id: string;
    prompt: string;
    status?: string;
    logs?: string[];
    collapsed?: boolean;
  };

  const refineRunKey = (sessionId: string, runId: string): string => `${sessionId}:${runId}`;

  const ensureRefineRunNode = (sessionId: string, thread: HTMLElement, run: RefineRunSummary): RefineRunNode => {
    const key = refineRunKey(sessionId, run.id);
    const existing = refineRunNodes.get(key);
    if (existing) {
      return existing;
    }

    const container = document.createElement('div');
    container.className = 'refine-run';
    container.dataset.runId = run.id;

    const focus = document.createElement('div');
    focus.className = 'refine-focus';
    focus.textContent = `Refine focus: ${run.prompt}`;

    const stepIndicators = document.createElement('div');
    stepIndicators.className = 'step-indicators refine-step-indicators hidden';

    const logsBox = document.createElement('div');
    logsBox.className = 'raw-logs-box refine-logs-box hidden';

    const logsHeader = document.createElement('div');
    logsHeader.className = 'raw-logs-header refine-logs-header';

    const logsToggle = document.createElement('button');
    logsToggle.className = 'raw-logs-toggle refine-logs-toggle';
    logsToggle.textContent = '[▼]';

    const logsTitle = document.createElement('span');
    logsTitle.className = 'raw-logs-title refine-logs-title';
    logsTitle.textContent = 'Refine Console Log';

    logsHeader.appendChild(logsToggle);
    logsHeader.appendChild(logsTitle);

    const logsBody = document.createElement('div');
    logsBody.className = 'raw-logs-body refine-logs-body';

    const logs = document.createElement('pre');
    logs.className = 'logs refine-logs';

    logsBody.appendChild(logs);
    logsBox.appendChild(logsHeader);
    logsBox.appendChild(logsBody);

    logsToggle.addEventListener('click', () => {
      const isCollapsed = logsBody.classList.toggle('collapsed');
      logsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';
      refineLogsCollapsedState.set(key, isCollapsed);
    });

    logs.addEventListener('click', handleLinkClick);

    container.appendChild(focus);
    container.appendChild(stepIndicators);
    container.appendChild(logsBox);

    thread.appendChild(container);

    const node: RefineRunNode = { container, focus, stepIndicators, logsBox, logsBody, logsToggle, logs };
    refineRunNodes.set(key, node);
    return node;
  };

  const recomputeRefineSteps = (key: string, logs: string[]): void => {
    // Rebuild from scratch so restored state renders correctly.
    refineStepStates.set(key, []);
    for (const line of logs) {
      if (line.startsWith('stderr: ')) {
        updateStepStatesIn(refineStepStates, key, line.slice('stderr: '.length));
      }
    }
  };

  const renderRefineThread = (sessionId: string, runs: RefineRunSummary[]): void => {
    const sessionNode = sessionNodes.get(sessionId);
    if (!sessionNode?.refineThread) {
      return;
    }

    const thread = sessionNode.refineThread;
    const seen = new Set<string>();
    for (const run of runs) {
      if (!run || !run.id) {
        continue;
      }
      const key = refineRunKey(sessionId, run.id);
      seen.add(key);
      const node = ensureRefineRunNode(sessionId, thread, run);
      node.focus.textContent = `Refine focus: ${run.prompt}`;

      const buffer = Array.isArray(run.logs) ? run.logs : [];
      refineLogBuffers.set(key, buffer.slice());

      // Restore collapsed state preference (webview-local overrides state).
      const isCollapsed = refineLogsCollapsedState.get(key) ?? Boolean(run.collapsed);
      node.logsBody.classList.toggle('collapsed', isCollapsed);
      node.logsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';

      if (buffer.length > 0) {
        node.logsBox.classList.remove('hidden');
        node.logs.innerHTML = buffer.map(l => renderLinks(l)).join('\n');
        if (!isCollapsed) {
          node.logsBody.scrollTop = node.logsBody.scrollHeight;
        }
        recomputeRefineSteps(key, buffer);
        const indicators = renderStepIndicatorsFrom(refineStepStates, key, 'step-indicators refine-step-indicators');
        node.stepIndicators.innerHTML = '';
        while (indicators.firstChild) {
          node.stepIndicators.appendChild(indicators.firstChild);
        }
        node.stepIndicators.classList.toggle('hidden', indicators.childElementCount === 0);
      } else {
        node.logsBox.classList.add('hidden');
        node.stepIndicators.classList.add('hidden');
      }
    }

    // Remove stale nodes.
    for (const [key, node] of refineRunNodes.entries()) {
      if (!key.startsWith(`${sessionId}:`)) {
        continue;
      }
      if (seen.has(key)) {
        continue;
      }
      node.container.remove();
      refineRunNodes.delete(key);
      refineLogBuffers.delete(key);
      refineStepStates.delete(key);
      refineLogsCollapsedState.delete(key);
    }
  };

  const ensureSessionNode = (session: { id: string; status: string; title?: string; prompt?: string; logs?: string[]; collapsed?: boolean }) => {
    if (sessionNodes.has(session.id)) {
      return sessionNodes.get(session.id)!;
    }

    const container = document.createElement('div');
    container.className = 'session';
    container.dataset.sessionId = session.id;

    const header = document.createElement('div');
    header.className = 'session-header';

    const toggleButton = document.createElement('button');
    toggleButton.className = 'toggle';

    const title = document.createElement('span');
    title.className = 'title';

    const status = document.createElement('span');
    status.className = 'status';

    const actions = document.createElement('div');
    actions.className = 'actions';

    const implButton = document.createElement('button');
    implButton.className = 'impl-button hidden';
    implButton.textContent = 'Implement';

    const refineButton = document.createElement('button');
    refineButton.className = 'refine hidden';
    refineButton.textContent = 'Refine';

    const remove = document.createElement('button');
    remove.className = 'delete';
    remove.textContent = '×';

    actions.appendChild(implButton);
    actions.appendChild(refineButton);
    actions.appendChild(remove);

    header.appendChild(toggleButton);
    header.appendChild(title);
    header.appendChild(status);
    header.appendChild(actions);

    const body = document.createElement('div');
    body.className = 'session-body';

    const prompt = document.createElement('div');
    prompt.className = 'prompt';

    const refineThread = document.createElement('div');
    refineThread.className = 'refine-thread';

    const refineComposer = document.createElement('div');
    refineComposer.className = 'refine-panel hidden';

    const refineLabel = document.createElement('div');
    refineLabel.className = 'refine-label';
    refineLabel.textContent = 'Refinement focus';

    const refineTextarea = document.createElement('textarea');
    refineTextarea.className = 'refine-textarea';
    refineTextarea.rows = 4;
    refineTextarea.placeholder = 'Type refinement focus, then press Cmd+Enter / Ctrl+Enter...';

    const refineHint = document.createElement('div');
    refineHint.className = 'refine-hint';
    refineHint.textContent = 'Cmd+Enter / Ctrl+Enter to run refinement';

    refineComposer.appendChild(refineLabel);
    refineComposer.appendChild(refineTextarea);
    refineComposer.appendChild(refineHint);

    // Step indicators container
    const stepIndicators = document.createElement('div');
    stepIndicators.className = 'step-indicators';

    // Raw logs box with collapsible header
    const rawLogsBox = document.createElement('div');
    rawLogsBox.className = 'raw-logs-box';

    const rawLogsHeader = document.createElement('div');
    rawLogsHeader.className = 'raw-logs-header';

    const rawLogsToggle = document.createElement('button');
    rawLogsToggle.className = 'raw-logs-toggle';
    rawLogsToggle.textContent = '[▼]';

    const rawLogsTitle = document.createElement('span');
    rawLogsTitle.className = 'raw-logs-title';
    rawLogsTitle.textContent = 'Raw Console Log';

    rawLogsHeader.appendChild(rawLogsToggle);
    rawLogsHeader.appendChild(rawLogsTitle);

    const rawLogsBody = document.createElement('div');
    rawLogsBody.className = 'raw-logs-body';

    const logs = document.createElement('pre');
    logs.className = 'logs';

    rawLogsBody.appendChild(logs);
    rawLogsBox.appendChild(rawLogsHeader);
    rawLogsBox.appendChild(rawLogsBody);

    const implLogsBox = document.createElement('div');
    implLogsBox.className = 'impl-logs-box hidden';

    const implLogsHeader = document.createElement('div');
    implLogsHeader.className = 'impl-logs-header';

    const implLogsToggle = document.createElement('button');
    implLogsToggle.className = 'impl-logs-toggle';
    implLogsToggle.textContent = '[▼]';

    const implLogsTitle = document.createElement('span');
    implLogsTitle.className = 'impl-logs-title';
    implLogsTitle.textContent = 'Implementation Log';

    implLogsHeader.appendChild(implLogsToggle);
    implLogsHeader.appendChild(implLogsTitle);

    const implLogsBody = document.createElement('div');
    implLogsBody.className = 'impl-logs-body';

    const implLogs = document.createElement('pre');
    implLogs.className = 'logs impl-logs';

    implLogsBody.appendChild(implLogs);
    implLogsBox.appendChild(implLogsHeader);
    implLogsBox.appendChild(implLogsBody);

    body.appendChild(prompt);
    body.appendChild(stepIndicators);
    body.appendChild(rawLogsBox);
    body.appendChild(implLogsBox);
    // Refinement UI lives at the end of the session body so it reads like a thread.
    body.appendChild(refineThread);
    body.appendChild(refineComposer);

    container.appendChild(header);
    container.appendChild(body);
    sessionList?.appendChild(container);

    toggleButton.addEventListener('click', () => {
      postMessage({ type: 'plan/toggleCollapse', sessionId: session.id });
    });

    remove.addEventListener('click', () => {
      console.log('[PlanPanel] Initiating delete for session:', session.id);
      postMessage({ type: 'plan/delete', sessionId: session.id });
    });

    implButton.addEventListener('click', () => {
      const issueNumber = implButton.dataset.issueNumber || '';
      if (!issueNumber) {
        return;
      }
      const message: PlanImplMessage = { type: 'plan/impl', sessionId: session.id, issueNumber };
      postImplMessage(message);
    });

    refineButton.addEventListener('click', () => {
      // Ensure the session is expanded so the inline refine textbox is visible.
      if (container.classList.contains('collapsed') || body.classList.contains('collapsed')) {
        postMessage({ type: 'plan/toggleCollapse', sessionId: session.id });
      }
      refineComposer.classList.remove('hidden');
      refineTextarea.focus();
    });

    refineTextarea.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
        event.preventDefault();
        const focus = refineTextarea.value.trim();
        if (!focus) {
          return;
        }
        const issueNumber = refineButton.dataset.issueNumber || '';
        const runId = `refine-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
        // Immediately transition UI from "editing" to "run/results" mode.
        refineTextarea.value = '';
        refineComposer.classList.add('hidden');
        const run: RefineRunSummary = { id: runId, prompt: focus, logs: [] };
        ensureRefineRunNode(session.id, refineThread, run);
        refineLogBuffers.set(refineRunKey(session.id, runId), []);
        refineStepStates.delete(refineRunKey(session.id, runId));
        postMessage({ type: 'plan/refine', sessionId: session.id, issueNumber, prompt: focus, runId });
      }
    });

    // Toggle raw logs collapse
    rawLogsToggle.addEventListener('click', () => {
      const isCollapsed = rawLogsBody.classList.toggle('collapsed');
      rawLogsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';
      logsCollapsedState.set(session.id, isCollapsed);
    });

    implLogsToggle.addEventListener('click', () => {
      const isCollapsed = implLogsBody.classList.toggle('collapsed');
      implLogsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';
      const message: PlanToggleImplCollapseMessage = { type: 'plan/toggleImplCollapse', sessionId: session.id };
      postImplMessage(message);
    });

    // Handle link clicks in logs
    logs.addEventListener('click', handleLinkClick);
    implLogs.addEventListener('click', handleLinkClick);

    const node = {
      container,
      toggleButton,
      title,
      status,
      prompt,
      logs,
      implLogs,
      body,
      stepIndicators,
      rawLogsBody,
      rawLogsToggle,
      implLogsBox,
      implLogsBody,
      implLogsToggle,
      implButton,
      refineButton,
      refineThread,
      refineComposer,
      refineTextarea,
    };
    sessionNodes.set(session.id, node);
    return node;
  };

  const updateSession = (session: SessionSummary) => {
    sessionCache.set(session.id, session);
    const node = ensureSessionNode(session);
    node.container.dataset.status = session.status;
    node.title.textContent = session.title || 'Untitled';
    node.status.textContent = session.status;
    node.prompt.textContent = session.prompt || '';

    node.toggleButton.textContent = session.collapsed ? '[▶]' : '[▼]';
    node.body.classList.toggle('collapsed', session.collapsed);

    // Restore logs collapsed state
    const isLogsCollapsed = logsCollapsedState.get(session.id);
    if (isLogsCollapsed !== undefined) {
      node.rawLogsBody?.classList.toggle('collapsed', isLogsCollapsed);
      if (node.rawLogsToggle) {
        node.rawLogsToggle.textContent = isLogsCollapsed ? '[▶]' : '[▼]';
      }
    }

    // Update step indicators
    if (node.stepIndicators) {
      const newIndicators = renderStepIndicatorsFrom(stepStates, session.id);
      node.stepIndicators.innerHTML = '';
      while (newIndicators.firstChild) {
        node.stepIndicators.appendChild(newIndicators.firstChild);
      }
    }

    if (Array.isArray(session.logs)) {
      logBuffers.set(session.id, session.logs.slice());
      // Re-render logs with link detection
      node.logs.innerHTML = session.logs.map(line => renderLinks(line)).join('\n');
    }

    if (!session.issueNumber && Array.isArray(session.logs)) {
      for (const line of session.logs) {
        const issueNumber = extractIssueNumber(line);
        if (issueNumber) {
          issueNumbers.set(session.id, issueNumber);
          break;
        }
      }
    }

    if (Array.isArray(session.implLogs) && node.implLogs) {
      implLogBuffers.set(session.id, session.implLogs.slice());
      node.implLogs.innerHTML = session.implLogs.map(line => renderLinks(line)).join('\n');
      if (node.implLogsBody) {
        node.implLogsBody.scrollTop = node.implLogsBody.scrollHeight;
      }
    }

    updateImplControls(session.id, session);
    updateRefineControls(session.id, session);
    renderRefineThread(session.id, Array.isArray(session.refineRuns) ? session.refineRuns : []);
  };

  const removeSession = (sessionId: string) => {
    const node = sessionNodes.get(sessionId);
    if (!node) {
      return;
    }
    node.container.remove();
    sessionNodes.delete(sessionId);
    logBuffers.delete(sessionId);
    implLogBuffers.delete(sessionId);
    stepStates.delete(sessionId);
    logsCollapsedState.delete(sessionId);
    issueNumbers.delete(sessionId);
    sessionCache.delete(sessionId);

    // Clear per-run refine state for this session.
    for (const key of Array.from(refineRunNodes.keys())) {
      if (key.startsWith(`${sessionId}:`)) {
        refineRunNodes.delete(key);
      }
    }
    for (const key of Array.from(refineLogBuffers.keys())) {
      if (key.startsWith(`${sessionId}:`)) {
        refineLogBuffers.delete(key);
      }
    }
    for (const key of Array.from(refineStepStates.keys())) {
      if (key.startsWith(`${sessionId}:`)) {
        refineStepStates.delete(key);
      }
    }
    for (const key of Array.from(refineLogsCollapsedState.keys())) {
      if (key.startsWith(`${sessionId}:`)) {
        refineLogsCollapsedState.delete(key);
      }
    }
  };

  const appendLogLine = (sessionId: string, line: string, stream?: string) => {
    const node = sessionNodes.get(sessionId);
    if (!node) {
      return;
    }

    const issueNumber = extractIssueNumber(line);
    if (issueNumber) {
      issueNumbers.set(sessionId, issueNumber);
      updateImplControls(sessionId);
      updateRefineControls(sessionId);
    }

    const prefix = stream === 'stderr' ? 'stderr: ' : '';
    const fullLine = `${prefix}${line}`;
    const buffer = logBuffers.get(sessionId) || [];
    buffer.push(fullLine);
    if (buffer.length > MAX_LOG_LINES) {
      buffer.splice(0, buffer.length - MAX_LOG_LINES);
    }
    logBuffers.set(sessionId, buffer);

    // Parse and update step states for stderr lines
    if (stream === 'stderr') {
      updateStepStatesIn(stepStates, sessionId, line);
      // Update step indicators UI
      if (node.stepIndicators) {
        const newIndicators = renderStepIndicatorsFrom(stepStates, sessionId);
        node.stepIndicators.innerHTML = '';
        while (newIndicators.firstChild) {
          node.stepIndicators.appendChild(newIndicators.firstChild);
        }
      }
    }

    // Re-render logs with link detection
    node.logs.innerHTML = buffer.map(l => renderLinks(l)).join('\n');

    // Auto-scroll to bottom
    if (node.rawLogsBody) {
      node.rawLogsBody.scrollTop = node.rawLogsBody.scrollHeight;
    }
  };

  const appendImplLogLine = (sessionId: string, line: string, stream?: string) => {
    const node = sessionNodes.get(sessionId);
    if (!node || !node.implLogs) {
      return;
    }

    const prefix = stream === 'stderr' ? 'stderr: ' : '';
    const fullLine = `${prefix}${line}`;
    const buffer = implLogBuffers.get(sessionId) || [];
    buffer.push(fullLine);
    if (buffer.length > MAX_LOG_LINES) {
      buffer.splice(0, buffer.length - MAX_LOG_LINES);
    }
    implLogBuffers.set(sessionId, buffer);

    node.implLogs.innerHTML = buffer.map(l => renderLinks(l)).join('\n');

    if (node.implLogsBody) {
      node.implLogsBody.scrollTop = node.implLogsBody.scrollHeight;
    }

    updateImplControls(sessionId);
  };

  const appendRefineLogLine = (sessionId: string, runId: string, line: string, stream?: string) => {
    const sessionNode = sessionNodes.get(sessionId);
    if (!sessionNode?.refineThread) {
      return;
    }

    const summary = sessionCache.get(sessionId)?.refineRuns?.find((run) => run.id === runId)
      ?? { id: runId, prompt: '(refine)' };
    const runNode = ensureRefineRunNode(sessionId, sessionNode.refineThread, summary);

    runNode.logsBox.classList.remove('hidden');

    const key = refineRunKey(sessionId, runId);
    const prefix = stream === 'stderr' ? 'stderr: ' : '';
    const fullLine = `${prefix}${line}`;
    const buffer = refineLogBuffers.get(key) || [];
    buffer.push(fullLine);
    if (buffer.length > MAX_LOG_LINES) {
      buffer.splice(0, buffer.length - MAX_LOG_LINES);
    }
    refineLogBuffers.set(key, buffer);

    if (stream === 'stderr') {
      updateStepStatesIn(refineStepStates, key, line);
      const newIndicators = renderStepIndicatorsFrom(refineStepStates, key, 'step-indicators refine-step-indicators');
      runNode.stepIndicators.innerHTML = '';
      while (newIndicators.firstChild) {
        runNode.stepIndicators.appendChild(newIndicators.firstChild);
      }
      runNode.stepIndicators.classList.toggle('hidden', runNode.stepIndicators.childElementCount === 0);
    }

    runNode.logs.innerHTML = buffer.map(l => renderLinks(l)).join('\n');

    const isCollapsed = refineLogsCollapsedState.get(key) ?? false;
    if (!isCollapsed) {
      runNode.logsBody.scrollTop = runNode.logsBody.scrollHeight;
    }
  };

  type SessionSummary = {
    id: string;
    status: string;
    title?: string;
    prompt?: string;
    logs?: string[];
    collapsed?: boolean;
    issueNumber?: string;
    implStatus?: string;
    implLogs?: string[];
    implCollapsed?: boolean;
    refineRuns?: RefineRunSummary[];
  };

  type PlanState = {
    draftInput?: string;
    sessions: SessionSummary[];
  };

  type AppState = {
    plan?: PlanState;
  };

  type RunEventData = {
    type?: string;
    sessionId?: string;
    line?: string;
    code?: number;
    commandType?: string;
    runId?: string;
  };

  type IncomingWebviewMessage = {
    type?: string;
    state?: AppState;
    sessionId?: string;
    deleted?: boolean;
    session?: SessionSummary;
    event?: RunEventData;
  };

  const renderState = (appState: AppState) => {
    if (!appState || !appState.plan) {
      return;
    }

    if (textarea) {
      textarea.value = appState.plan.draftInput || '';
    }

    const seen = new Set<string>();
    appState.plan.sessions.forEach((session) => {
      seen.add(session.id);
      updateSession(session);
    });

    Array.from(sessionNodes.keys()).forEach((sessionId) => {
      if (!seen.has(sessionId)) {
        removeSession(sessionId);
      }
    });
  };

  const initialState = (window as unknown as { __INITIAL_STATE__?: AppState }).__INITIAL_STATE__;
  if (initialState) {
    renderState(initialState);
  }

  window.addEventListener('message', (event) => {
    const message = event.data as IncomingWebviewMessage;
    if (!message || !message.type) {
      return;
    }

    switch (message.type) {
      case 'state/replace':
        renderState(message.state || { plan: { sessions: [] } });
        return;
      case 'plan/sessionUpdated': {
        if (message.deleted) {
          if (message.sessionId) {
            removeSession(message.sessionId);
          }
          return;
        }
        if (message.session) {
          updateSession(message.session);
        }
        return;
      }
      case 'plan/runEvent': {
        const eventData = message.event;
        if (!eventData) {
          return;
        }
        if (eventData.type === 'stdout' || eventData.type === 'stderr') {
          if (eventData.commandType === 'impl') {
            appendImplLogLine(eventData.sessionId || '', eventData.line || '', eventData.type);
          } else if (eventData.commandType === 'refine') {
            const sessionId = eventData.sessionId || '';
            const runId = eventData.runId || '';
            if (sessionId && runId) {
              appendRefineLogLine(sessionId, runId, eventData.line || '', eventData.type);
            }
          } else {
            appendLogLine(eventData.sessionId || '', eventData.line || '', eventData.type);
          }
        }
        if (eventData.type === 'exit') {
          if (eventData.commandType === 'refine' && eventData.sessionId && eventData.runId) {
            const key = refineRunKey(eventData.sessionId, eventData.runId);
            completeAllStepsIn(refineStepStates, key);
            const runNode = refineRunNodes.get(key);
            if (runNode) {
              const indicators = renderStepIndicatorsFrom(refineStepStates, key, 'step-indicators refine-step-indicators');
              runNode.stepIndicators.innerHTML = '';
              while (indicators.firstChild) {
                runNode.stepIndicators.appendChild(indicators.firstChild);
              }
              runNode.stepIndicators.classList.toggle('hidden', runNode.stepIndicators.childElementCount === 0);
            }
          }
          if (eventData.commandType !== 'impl' && eventData.commandType !== 'refine' && eventData.sessionId) {
            // Complete all running steps when process exits
            completeAllStepsIn(stepStates, eventData.sessionId);
            const node = sessionNodes.get(eventData.sessionId);
            if (node?.stepIndicators) {
              const newIndicators = renderStepIndicatorsFrom(stepStates, eventData.sessionId);
              node.stepIndicators.innerHTML = '';
              while (newIndicators.firstChild) {
                node.stepIndicators.appendChild(newIndicators.firstChild);
              }
            }
          }
        }
        return;
      }
      default:
        return;
    }
  });
})();
