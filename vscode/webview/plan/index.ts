import type { PlanImplMessage, PlanToggleImplCollapseMessage, WidgetState, WidgetButton } from './types.js';
import type { StepState } from './utils.js';
import {
  completeAllStepsIn,
  extractIssueNumber,
  renderLinks,
  renderStepIndicatorsFrom,
  updateStepStatesIn,
} from './utils.js';
import {
  appendPlainText,
  appendTerminalBox,
  appendProgressWidget,
  appendButtons,
  appendStatusBadge,
  registerSessionContainer,
  getWidgetHandle,
} from './widgets.js';
import type { TerminalHandle, ButtonsHandle, ProgressHandle } from './widgets.js';

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
      node.implButton.dataset.issueNumber = issueNumber ?? '';
      const isRunning = current.implStatus === 'running';
      const isClosed = current.issueState === 'closed';
      if (isRunning) {
        node.implButton.disabled = true;
        node.implButton.textContent = 'Running...';
        node.implButton.classList.remove('closed');
      } else if (isClosed) {
        node.implButton.disabled = true;
        node.implButton.textContent = 'Closed';
        node.implButton.classList.add('closed');
      } else {
        node.implButton.disabled = false;
        node.implButton.textContent = 'Implement';
        node.implButton.classList.remove('closed');
      }
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
    renderRefineThread(session.id, session.refineRuns);
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

    const summary = sessionCache.get(sessionId)?.refineRuns.find((run) => run.id === runId);
    if (!summary) {
      return;
    }
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
    issueState?: 'open' | 'closed' | 'unknown';
    implStatus?: string;
    implLogs?: string[];
    implCollapsed?: boolean;
    refineRuns: RefineRunSummary[];
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

  type WidgetUpdatePayload =
    | { type: 'appendLines'; lines: string[] }
    | { type: 'replaceButtons'; buttons: WidgetButton[] }
    | { type: 'complete' }
    | { type: 'metadata'; metadata: Record<string, unknown> };

  type IncomingWebviewMessage = {
    type?: string;
    state?: AppState;
    sessionId?: string;
    deleted?: boolean;
    session?: SessionSummary;
    event?: RunEventData;
    widget?: WidgetState;
    widgetId?: string;
    update?: WidgetUpdatePayload;
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
      case 'widget/append': {
        const sessionId = message.sessionId ?? '';
        const widget = message.widget;
        if (!sessionId || !widget) {
          return;
        }
        // Ensure session container is registered
        const node = sessionNodes.get(sessionId);
        if (node?.body) {
          registerSessionContainer(sessionId, node.body);
        }
        // Create the widget based on type
        switch (widget.type) {
          case 'text':
            appendPlainText(sessionId, widget.content?.[0] ?? '', { widgetId: widget.id });
            break;
          case 'terminal':
            appendTerminalBox(sessionId, widget.title ?? 'Terminal', {
              widgetId: widget.id,
              collapsed: (widget.metadata?.collapsed as boolean) ?? false,
            });
            break;
          case 'progress': {
            const terminalId = widget.metadata?.terminalId as string;
            if (terminalId) {
              const terminal = getWidgetHandle(sessionId, terminalId);
              if (terminal?.type === 'terminal') {
                appendProgressWidget(sessionId, terminal as TerminalHandle, { widgetId: widget.id });
              }
            }
            break;
          }
          case 'buttons':
            appendButtons(sessionId, (widget.metadata?.buttons as WidgetButton[])?.map((b) => ({
              id: b.id,
              label: b.label,
              variant: (b.variant === 'secondary' ? 'ghost' : b.variant) ?? 'primary',
              disabled: b.disabled,
              onClick: () => {
                postMessage({ type: b.action, sessionId });
              },
            })) ?? [], { widgetId: widget.id });
            break;
          case 'status':
            appendStatusBadge(sessionId, widget.content?.[0] ?? '', { widgetId: widget.id });
            break;
        }
        return;
      }
      case 'widget/update': {
        const sessionId = message.sessionId ?? '';
        const widgetId = message.widgetId ?? '';
        const update = message.update;
        if (!sessionId || !widgetId || !update) {
          return;
        }
        const handle = getWidgetHandle(sessionId, widgetId);
        if (!handle) {
          return;
        }
        switch (update.type) {
          case 'appendLines': {
            if (handle.type === 'terminal') {
              const terminalHandle = handle as TerminalHandle;
              update.lines?.forEach((line) => {
                const stream = line.startsWith('stderr: ') ? 'stderr' : undefined;
                const cleanLine = line.startsWith('stderr: ') ? line.slice('stderr: '.length) : line;
                terminalHandle.appendLine(cleanLine, stream);
              });
            }
            break;
          }
          case 'replaceButtons': {
            if (handle.type === 'buttons' && update.buttons) {
              const buttonsHandle = handle as ButtonsHandle;
              import('./widgets.js').then((widgets) => {
                widgets.replaceButtons(buttonsHandle, update.buttons?.map((b) => ({
                  id: b.id,
                  label: b.label,
                  variant: (b.variant === 'secondary' ? 'ghost' : b.variant) ?? 'primary',
                  disabled: b.disabled,
                  onClick: () => {
                    postMessage({ type: b.action, sessionId });
                  },
                })) ?? []);
              });
            }
            break;
          }
          case 'complete': {
            if (handle.type === 'progress') {
              const progressHandle = handle as ProgressHandle;
              progressHandle.complete();
            }
            break;
          }
        }
        return;
      }
      default:
        return;
    }
  });
})();
