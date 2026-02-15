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
    refinePanel?: HTMLElement;
    refineTextarea?: HTMLTextAreaElement;
    refineFocus?: HTMLElement;
    refineStepIndicators?: HTMLElement;
    refineLogsBox?: HTMLElement;
    refineLogsBody?: HTMLElement;
    refineLogsToggle?: HTMLElement;
    refineLogs?: HTMLElement;
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
  const refineLogBuffers = new Map<string, string[]>();
  const stepStates = new Map<string, StepState[]>();
  const refineStepStates = new Map<string, StepState[]>();
  const logsCollapsedState = new Map<string, boolean>();
  const refineLogsCollapsedState = new Map<string, boolean>();
  const issueNumbers = new Map<string, string>();
  const sessionCache = new Map<string, SessionSummary>();

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

    const refinePanel = document.createElement('div');
    refinePanel.className = 'refine-panel hidden';

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

    refinePanel.appendChild(refineLabel);
    refinePanel.appendChild(refineTextarea);
    refinePanel.appendChild(refineHint);

    const refineFocus = document.createElement('div');
    refineFocus.className = 'refine-focus hidden';

    const refineStepIndicators = document.createElement('div');
    refineStepIndicators.className = 'step-indicators refine-step-indicators hidden';

    const refineLogsBox = document.createElement('div');
    refineLogsBox.className = 'raw-logs-box refine-logs-box hidden';

    const refineLogsHeader = document.createElement('div');
    refineLogsHeader.className = 'raw-logs-header refine-logs-header';

    const refineLogsToggle = document.createElement('button');
    refineLogsToggle.className = 'raw-logs-toggle refine-logs-toggle';
    refineLogsToggle.textContent = '[▼]';

    const refineLogsTitle = document.createElement('span');
    refineLogsTitle.className = 'raw-logs-title refine-logs-title';
    refineLogsTitle.textContent = 'Refine Console Log';

    refineLogsHeader.appendChild(refineLogsToggle);
    refineLogsHeader.appendChild(refineLogsTitle);

    const refineLogsBody = document.createElement('div');
    refineLogsBody.className = 'raw-logs-body refine-logs-body';

    const refineLogs = document.createElement('pre');
    refineLogs.className = 'logs refine-logs';

    refineLogsBody.appendChild(refineLogs);
    refineLogsBox.appendChild(refineLogsHeader);
    refineLogsBox.appendChild(refineLogsBody);

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
    body.appendChild(refinePanel);
    body.appendChild(refineFocus);
    body.appendChild(refineLogsBox);
    body.appendChild(refineStepIndicators);
    body.appendChild(stepIndicators);
    body.appendChild(rawLogsBox);
    body.appendChild(implLogsBox);

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
      refinePanel.classList.remove('hidden');
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
        // Immediately transition UI from "editing" to "run/results" mode.
        refineTextarea.value = '';
        refinePanel.classList.add('hidden');
        refineFocus.textContent = `Refine focus: ${focus}`;
        refineFocus.classList.remove('hidden');
        refineLogs.innerHTML = '';
        refineLogsBox.classList.add('hidden');
        refineStepIndicators.classList.add('hidden');
        refineLogBuffers.set(session.id, []);
        refineStepStates.delete(session.id);
        postMessage({ type: 'plan/refine', sessionId: session.id, issueNumber, prompt: focus });
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

    refineLogsToggle.addEventListener('click', () => {
      const isCollapsed = refineLogsBody.classList.toggle('collapsed');
      refineLogsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';
      refineLogsCollapsedState.set(session.id, isCollapsed);
    });

    // Handle link clicks in logs
    logs.addEventListener('click', handleLinkClick);
    implLogs.addEventListener('click', handleLinkClick);
    refineLogs.addEventListener('click', handleLinkClick);

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
      refinePanel,
      refineTextarea,
      refineFocus,
      refineStepIndicators,
      refineLogsBox,
      refineLogsBody,
      refineLogsToggle,
      refineLogs,
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

    // Restore refine logs collapsed state (webview-local).
    const isRefineCollapsed = refineLogsCollapsedState.get(session.id);
    if (isRefineCollapsed !== undefined && node.refineLogsBody) {
      node.refineLogsBody.classList.toggle('collapsed', isRefineCollapsed);
      if (node.refineLogsToggle) {
        node.refineLogsToggle.textContent = isRefineCollapsed ? '[▶]' : '[▼]';
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

    if (typeof session.refinePrompt === 'string' && node.refineTextarea) {
      node.refineTextarea.value = session.refinePrompt;
    }

    const hasRefineLogs = Array.isArray(session.refineLogs) && session.refineLogs.length > 0;
    const refineStatus = session.refineStatus ?? 'idle';
    const showRefine = hasRefineLogs || refineStatus !== 'idle';
    if (showRefine) {
      if (typeof session.refinePrompt === 'string' && session.refinePrompt.trim() && node.refineFocus) {
        node.refineFocus.textContent = `Refine focus: ${session.refinePrompt.trim()}`;
        node.refineFocus.classList.remove('hidden');
      }
      node.refineLogsBox?.classList.toggle('hidden', !hasRefineLogs);
    }

    if (Array.isArray(session.refineLogs) && node.refineLogs) {
      refineLogBuffers.set(session.id, session.refineLogs.slice());
      node.refineLogs.innerHTML = session.refineLogs.map(line => renderLinks(line)).join('\n');
      if (node.refineLogsBody) {
        const isCollapsed = refineLogsCollapsedState.get(session.id) ?? (session.refineCollapsed ?? false);
        node.refineLogsBody.classList.toggle('collapsed', isCollapsed);
        if (node.refineLogsToggle) {
          node.refineLogsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';
        }
        if (!isCollapsed) {
          node.refineLogsBody.scrollTop = node.refineLogsBody.scrollHeight;
        }
      }
    }

    updateImplControls(session.id, session);
    updateRefineControls(session.id, session);
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
    refineLogBuffers.delete(sessionId);
    stepStates.delete(sessionId);
    refineStepStates.delete(sessionId);
    logsCollapsedState.delete(sessionId);
    refineLogsCollapsedState.delete(sessionId);
    issueNumbers.delete(sessionId);
    sessionCache.delete(sessionId);
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

  const appendRefineLogLine = (sessionId: string, line: string, stream?: string) => {
    const node = sessionNodes.get(sessionId);
    if (!node || !node.refineLogs || !node.refineLogsBody) {
      return;
    }

    // Reveal log panel once output starts streaming (textbox stays hidden).
    node.refineLogsBox?.classList.remove('hidden');

    const prefix = stream === 'stderr' ? 'stderr: ' : '';
    const fullLine = `${prefix}${line}`;
    const buffer = refineLogBuffers.get(sessionId) || [];
    buffer.push(fullLine);
    if (buffer.length > MAX_LOG_LINES) {
      buffer.splice(0, buffer.length - MAX_LOG_LINES);
    }
    refineLogBuffers.set(sessionId, buffer);

    if (stream === 'stderr') {
      updateStepStatesIn(refineStepStates, sessionId, line);
      if (node.refineStepIndicators) {
        node.refineStepIndicators.classList.remove('hidden');
        const newIndicators = renderStepIndicatorsFrom(refineStepStates, sessionId, 'step-indicators refine-step-indicators');
        node.refineStepIndicators.innerHTML = '';
        while (newIndicators.firstChild) {
          node.refineStepIndicators.appendChild(newIndicators.firstChild);
        }
      }
    }

    node.refineLogs.innerHTML = buffer.map(l => renderLinks(l)).join('\n');
    node.refineLogsBody.scrollTop = node.refineLogsBody.scrollHeight;
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
    refinePrompt?: string;
    refineStatus?: string;
    refineLogs?: string[];
    refineCollapsed?: boolean;
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
            appendRefineLogLine(eventData.sessionId || '', eventData.line || '', eventData.type);
          } else {
            appendLogLine(eventData.sessionId || '', eventData.line || '', eventData.type);
          }
        }
        if (eventData.type === 'exit') {
          if (eventData.commandType === 'refine' && eventData.sessionId) {
            // Complete all running steps when process exits
            completeAllStepsIn(refineStepStates, eventData.sessionId);
            const node = sessionNodes.get(eventData.sessionId);
            if (node?.refineStepIndicators) {
              const newIndicators = renderStepIndicatorsFrom(refineStepStates, eventData.sessionId, 'step-indicators refine-step-indicators');
              node.refineStepIndicators.innerHTML = '';
              while (newIndicators.firstChild) {
                node.refineStepIndicators.appendChild(newIndicators.firstChild);
              }
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
