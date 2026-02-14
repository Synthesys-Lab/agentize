// Provided by VS Code in the webview environment.
declare function acquireVsCodeApi(): { postMessage(message: unknown): void };

(() => {
  const vscode = acquireVsCodeApi();
  const MAX_LOG_LINES = 1000;

  const root = document.getElementById('plan-root');
  if (!root) {
    return;
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
    body: HTMLElement;
    stepIndicators?: HTMLElement;
    rawLogsBody?: HTMLElement;
    rawLogsToggle?: HTMLElement;
  }>();
  const logBuffers = new Map<string, string[]>();
  const stepStates = new Map<string, StepState[]>();
  const logsCollapsedState = new Map<string, boolean>();

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
  const updateStepStates = (sessionId: string, line: string): boolean => {
    const newStep = parseStageLine(line);
    if (!newStep) return false;

    let steps = stepStates.get(sessionId) || [];

    // Mark any running step as completed
    steps = steps.map((step): StepState => {
      if (step.status === 'running') {
        return { ...step, status: 'completed' as const, endTime: Date.now() };
      }
      return step;
    });

    // Add new running step
    steps.push(newStep);
    stepStates.set(sessionId, steps);
    return true;
  };

  // Mark all steps as completed (called on process exit)
  const completeAllSteps = (sessionId: string): void => {
    const steps = stepStates.get(sessionId) || [];
    const updated = steps.map((step): StepState => {
      if (step.status === 'running') {
        return { ...step, status: 'completed' as const, endTime: Date.now() };
      }
      return step;
    });
    stepStates.set(sessionId, updated);
  };

  // Format elapsed time in seconds
  const formatElapsed = (startTime: number, endTime: number): string => {
    const elapsed = Math.max(0, Math.round((endTime - startTime) / 1000));
    return `${elapsed}s`;
  };

  // Render step indicators
  const renderStepIndicators = (sessionId: string): HTMLElement => {
    const steps = stepStates.get(sessionId) || [];
    const container = document.createElement('div');
    container.className = 'step-indicators';

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

    const remove = document.createElement('button');
    remove.className = 'delete';
    remove.textContent = '×';

    actions.appendChild(remove);

    header.appendChild(toggleButton);
    header.appendChild(title);
    header.appendChild(status);
    header.appendChild(actions);

    const body = document.createElement('div');
    body.className = 'session-body';

    const prompt = document.createElement('div');
    prompt.className = 'prompt';

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

    body.appendChild(prompt);
    body.appendChild(stepIndicators);
    body.appendChild(rawLogsBox);

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

    // Toggle raw logs collapse
    rawLogsToggle.addEventListener('click', () => {
      const isCollapsed = rawLogsBody.classList.toggle('collapsed');
      rawLogsToggle.textContent = isCollapsed ? '[▶]' : '[▼]';
      logsCollapsedState.set(session.id, isCollapsed);
    });

    // Handle link clicks in logs
    logs.addEventListener('click', handleLinkClick);

    const node = { container, toggleButton, title, status, prompt, logs, body, stepIndicators, rawLogsBody, rawLogsToggle };
    sessionNodes.set(session.id, node);
    return node;
  };

  const updateSession = (session: { id: string; status: string; title?: string; prompt?: string; logs?: string[]; collapsed?: boolean }) => {
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
      const newIndicators = renderStepIndicators(session.id);
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
  };

  const removeSession = (sessionId: string) => {
    const node = sessionNodes.get(sessionId);
    if (!node) {
      return;
    }
    node.container.remove();
    sessionNodes.delete(sessionId);
    logBuffers.delete(sessionId);
    stepStates.delete(sessionId);
    logsCollapsedState.delete(sessionId);
  };

  const appendLogLine = (sessionId: string, line: string, stream?: string) => {
    const node = sessionNodes.get(sessionId);
    if (!node) {
      return;
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
      updateStepStates(sessionId, line);
      // Update step indicators UI
      if (node.stepIndicators) {
        const newIndicators = renderStepIndicators(sessionId);
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

  type SessionSummary = {
    id: string;
    status: string;
    title?: string;
    prompt?: string;
    logs?: string[];
    collapsed?: boolean;
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
          appendLogLine(eventData.sessionId || '', eventData.line || '', eventData.type);
        }
        if (eventData.type === 'exit') {
          // Complete all running steps when process exits
          if (eventData.sessionId) {
            completeAllSteps(eventData.sessionId);
            const node = sessionNodes.get(eventData.sessionId);
            if (node?.stepIndicators) {
              const newIndicators = renderStepIndicators(eventData.sessionId);
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
