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
  const textarea = document.getElementById('plan-textarea');
  const runButton = document.getElementById('plan-run');
  const cancelButton = document.getElementById('plan-cancel');
  const sessionList = document.getElementById('session-list');

  const sessionNodes = new Map();
  const logBuffers = new Map();

  const postMessage = (message) => vscode.postMessage(message);

  const showInputPanel = () => {
    inputPanel.classList.remove('hidden');
    textarea.focus();
  };

  const hideInputPanel = () => {
    inputPanel.classList.add('hidden');
  };

  const submitPlan = () => {
    const prompt = textarea.value.trim();
    if (!prompt) {
      return;
    }

    postMessage({ type: 'plan/new', prompt });
    textarea.value = '';
    postMessage({ type: 'plan/updateDraft', value: '' });
    hideInputPanel();
  };

  newPlanButton.addEventListener('click', () => {
    showInputPanel();
  });

  runButton.addEventListener('click', () => {
    submitPlan();
  });

  cancelButton.addEventListener('click', () => {
    hideInputPanel();
  });

  textarea.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      submitPlan();
    }
  });

  let draftTimer;
  textarea.addEventListener('input', () => {
    if (draftTimer) {
      clearTimeout(draftTimer);
    }
    draftTimer = setTimeout(() => {
      postMessage({ type: 'plan/updateDraft', value: textarea.value });
    }, 150);
  });

  const ensureSessionNode = (session) => {
    if (sessionNodes.has(session.id)) {
      return sessionNodes.get(session.id);
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

    const run = document.createElement('button');
    run.className = 'run';

    const remove = document.createElement('button');
    remove.className = 'delete';
    remove.textContent = '[x]';

    actions.appendChild(run);
    actions.appendChild(remove);

    header.appendChild(toggleButton);
    header.appendChild(title);
    header.appendChild(status);
    header.appendChild(actions);

    const body = document.createElement('div');
    body.className = 'session-body';

    const prompt = document.createElement('div');
    prompt.className = 'prompt';

    const logs = document.createElement('pre');
    logs.className = 'logs';

    body.appendChild(prompt);
    body.appendChild(logs);

    container.appendChild(header);
    container.appendChild(body);
    sessionList.appendChild(container);

    toggleButton.addEventListener('click', () => {
      postMessage({ type: 'plan/toggleCollapse', sessionId: session.id });
    });

    run.addEventListener('click', () => {
      postMessage({ type: 'plan/run', sessionId: session.id });
    });

    remove.addEventListener('click', () => {
      const confirmed = window.confirm('Delete this session? Running sessions will be stopped.');
      if (!confirmed) {
        return;
      }
      postMessage({ type: 'plan/delete', sessionId: session.id });
    });

    const node = { container, toggleButton, title, status, run, prompt, logs, body };
    sessionNodes.set(session.id, node);
    return node;
  };

  const updateSession = (session) => {
    const node = ensureSessionNode(session);
    node.container.dataset.status = session.status;
    node.title.textContent = session.title;
    node.status.textContent = session.status;
    node.prompt.textContent = session.prompt;

    node.toggleButton.textContent = session.collapsed ? '[>]' : '[v]';
    node.body.classList.toggle('collapsed', session.collapsed);

    node.run.textContent = session.status === 'error' ? 'Retry' : 'Run';
    node.run.disabled = session.status === 'running';

    if (Array.isArray(session.logs)) {
      logBuffers.set(session.id, session.logs.slice());
      node.logs.textContent = session.logs.join('\n');
    }
  };

  const removeSession = (sessionId) => {
    const node = sessionNodes.get(sessionId);
    if (!node) {
      return;
    }
    node.container.remove();
    sessionNodes.delete(sessionId);
    logBuffers.delete(sessionId);
  };

  const appendLogLine = (sessionId, line, stream) => {
    const node = sessionNodes.get(sessionId);
    if (!node) {
      return;
    }

    const prefix = stream === 'stderr' ? 'stderr: ' : '';
    const buffer = logBuffers.get(sessionId) || [];
    buffer.push(`${prefix}${line}`);
    if (buffer.length > MAX_LOG_LINES) {
      buffer.splice(0, buffer.length - MAX_LOG_LINES);
    }
    logBuffers.set(sessionId, buffer);
    node.logs.textContent = buffer.join('\n');
  };

  const renderState = (appState) => {
    if (!appState || !appState.plan) {
      return;
    }

    textarea.value = appState.plan.draftInput || '';

    const seen = new Set();
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

  const initialState = window.__INITIAL_STATE__;
  if (initialState) {
    renderState(initialState);
  }

  window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || !message.type) {
      return;
    }

    switch (message.type) {
      case 'state/replace':
        renderState(message.state);
        return;
      case 'plan/sessionUpdated': {
        if (message.deleted) {
          removeSession(message.sessionId);
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
          appendLogLine(eventData.sessionId, eventData.line, eventData.type);
        }
        return;
      }
      default:
        return;
    }
  });
})();
