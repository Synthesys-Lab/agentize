import type { PlanImplMessage, WidgetButton, WidgetState } from './types.js';
import {
  appendButtons,
  appendInputWidget,
  appendPlainText,
  appendProgressWidget,
  appendStatusBadge,
  appendTerminalBox,
  clearWidgets,
  getWidgetHandle,
  registerSessionContainer,
  removeWidget,
  replaceButtons,
} from './widgets.js';
import type { ButtonsHandle, ProgressEventEntry, ProgressHandle, TerminalHandle } from './widgets.js';

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
      <div class="input-hint">Cmd+Enter / Ctrl+Enter to run, Esc to cancel.</div>
    </div>
    <div id="session-list" class="session-list"></div>
  `;

  vscode.postMessage({ type: 'webview/ready' });

  const newPlanButton = document.getElementById('new-plan');
  const inputPanel = document.getElementById('plan-input');
  const textarea = document.getElementById('plan-textarea') as HTMLTextAreaElement;
  const sessionList = document.getElementById('session-list');

  type SessionNode = {
    container: HTMLElement;
    toggleButton: HTMLElement;
    title: HTMLElement;
    status: HTMLElement;
    body: HTMLElement;
  };

  type SessionSummary = {
    id: string;
    status: string;
    title?: string;
    collapsed?: boolean;
    issueNumber?: string;
    issueState?: 'open' | 'closed' | 'unknown';
    planPath?: string;
    prUrl?: string;
    implStatus?: string;
    phase?: string;
    widgets?: WidgetState[];
  };

  type PlanState = {
    draftInput?: string;
    sessions: SessionSummary[];
  };

  type AppState = {
    plan?: PlanState;
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
    widget?: WidgetState;
    widgetId?: string;
    update?: WidgetUpdatePayload;
  };

  const postMessage = (message: unknown) => vscode?.postMessage(message);

  const sessionNodes = new Map<string, SessionNode>();
  const sessionCache = new Map<string, SessionSummary>();
  const WIDGET_ROLE_PLAN_TERMINAL = 'plan-terminal';

  const getPlanTerminalId = (session: SessionSummary): string | undefined => {
    const widgets = session.widgets;
    if (!Array.isArray(widgets)) {
      return undefined;
    }
    const terminal = widgets.find(
      (widget) => widget.type === 'terminal' && widget.metadata?.role === WIDGET_ROLE_PLAN_TERMINAL,
    );
    return terminal?.id;
  };

  const syncPlanStopButton = (session: SessionSummary): void => {
    const terminalId = getPlanTerminalId(session);
    if (!terminalId) {
      return;
    }
    const handle = getWidgetHandle(session.id, terminalId);
    if (!handle || handle.type !== 'terminal') {
      return;
    }
    const stopButton = handle.element.querySelector<HTMLButtonElement>('.terminal-stop-button');
    if (!stopButton) {
      return;
    }
    const shouldShow = session.status === 'running';
    if (shouldShow) {
      stopButton.classList.remove('hidden');
      if (stopButton.dataset.stopping !== 'true') {
        stopButton.disabled = false;
        stopButton.classList.remove('button-disabled');
        stopButton.textContent = 'Stop';
      }
      return;
    }
    stopButton.classList.add('hidden');
    stopButton.disabled = true;
    stopButton.classList.remove('button-disabled');
    stopButton.textContent = 'Stop';
    delete stopButton.dataset.stopping;
  };

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
    if (textarea) {
      textarea.value = '';
    }
    postMessage({ type: 'plan/updateDraft', value: '' });
    hideInputPanel();
  };

  newPlanButton?.addEventListener('click', () => {
    showInputPanel();
  });

  textarea?.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      submitPlan();
    }
    if (event.key === 'Escape') {
      event.preventDefault();
      hideInputPanel();
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

  const handleLinkClick = (event: Event): void => {
    const target = event.target as HTMLElement;
    const anchor = target.closest('a[data-link-type]') as HTMLAnchorElement | null;
    if (!anchor) {
      return;
    }

    event.preventDefault();
    const linkType = anchor.dataset.linkType;

    if (linkType === 'github') {
      const url = anchor.dataset.url;
      if (url) {
        postMessage({ type: 'link/openExternal', url });
      }
      return;
    }

    if (linkType === 'local') {
      const path = anchor.dataset.path;
      if (path) {
        postMessage({ type: 'link/openFile', path });
      }
    }
  };

  const mapButtonVariant = (variant?: WidgetButton['variant']): 'primary' | 'danger' | 'ghost' => {
    if (variant === 'danger') {
      return 'danger';
    }
    if (variant === 'ghost' || variant === 'secondary') {
      return 'ghost';
    }
    return 'primary';
  };

  const makeRunId = (): string => {
    return `refine-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  };

  const openRefineInput = (sessionId: string): void => {
    const widgetId = `refine-input-${sessionId}`;
    const existing = getWidgetHandle(sessionId, widgetId);
    if (existing?.type === 'input') {
      const input = existing.element.querySelector('textarea') as HTMLTextAreaElement | null;
      input?.focus();
      return;
    }

    const issueNumber = sessionCache.get(sessionId)?.issueNumber ?? '';
    appendInputWidget(
      sessionId,
      {
        label: 'Refinement focus',
        placeholder: 'Type refinement focus, then press Cmd+Enter / Ctrl+Enter...',
        hint: 'Cmd+Enter / Ctrl+Enter to run refinement, Esc to cancel.',
        onSubmit: (value) => {
          removeWidget(sessionId, widgetId);
          postMessage({
            type: 'plan/refine',
            sessionId,
            issueNumber,
            prompt: value,
            runId: makeRunId(),
          });
        },
        onCancel: () => {
          removeWidget(sessionId, widgetId);
        },
      },
      { widgetId },
    );
  };

  const mapButtons = (sessionId: string, buttons: WidgetButton[] | undefined) => {
    const sessionIssue = sessionCache.get(sessionId)?.issueNumber ?? '';
    return (buttons ?? []).map((button) => ({
      id: button.id,
      label: button.label,
      variant: mapButtonVariant(button.variant),
      disabled: button.disabled,
      onClick: () => {
        if (button.action === 'plan/refine') {
          openRefineInput(sessionId);
          return;
        }
        if (button.action === 'plan/impl') {
          const implMessage: PlanImplMessage = {
            type: 'plan/impl',
            sessionId,
            issueNumber: sessionIssue,
          };
          postMessage(implMessage);
          return;
        }
        if (button.action === 'plan/rerun') {
          postMessage({ type: 'plan/rerun', sessionId });
          return;
        }
        postMessage({ type: button.action, sessionId });
      },
    }));
  };

  const parseProgressEvents = (metadata: Record<string, unknown> | undefined): ProgressEventEntry[] => {
    const raw = metadata?.progressEvents;
    if (!Array.isArray(raw)) {
      return [];
    }
    const parsed: ProgressEventEntry[] = [];
    raw.forEach((entry) => {
      if (!entry || typeof entry !== 'object') {
        return;
      }
      const candidate = entry as { type?: string; line?: string; timestamp?: unknown };
      if (candidate.type !== 'stage' && candidate.type !== 'exit') {
        return;
      }
      if (typeof candidate.timestamp !== 'number' || !Number.isFinite(candidate.timestamp)) {
        return;
      }
      parsed.push({
        type: candidate.type,
        line: typeof candidate.line === 'string' ? candidate.line : undefined,
        timestamp: candidate.timestamp,
      });
    });
    return parsed;
  };

  const appendWidgetFromState = (sessionId: string, widget: WidgetState, allWidgets: WidgetState[]): void => {
    if (!widget?.id) {
      return;
    }

    const existing = getWidgetHandle(sessionId, widget.id);
    if (existing) {
      removeWidget(sessionId, widget.id);
    }

    switch (widget.type) {
      case 'text': {
        appendPlainText(sessionId, widget.content?.[0] ?? '', { widgetId: widget.id });
        return;
      }
      case 'terminal': {
        const isPlanTerminal = widget.metadata?.role === WIDGET_ROLE_PLAN_TERMINAL;
        const terminal = appendTerminalBox(sessionId, widget.title ?? 'Terminal', {
          widgetId: widget.id,
          collapsed: Boolean(widget.metadata?.collapsed),
          onLinkClick: handleLinkClick,
          onStop: isPlanTerminal
            ? () => {
                postMessage({ type: 'plan/stop', sessionId });
              }
            : undefined,
        });
        if (terminal && Array.isArray(widget.content)) {
          terminal.setLines(widget.content);
        }
        return;
      }
      case 'progress': {
        const terminalId = typeof widget.metadata?.terminalId === 'string' ? widget.metadata.terminalId : '';
        if (!terminalId) {
          return;
        }
        const terminalHandle = getWidgetHandle(sessionId, terminalId);
        if (!terminalHandle || terminalHandle.type !== 'terminal') {
          return;
        }
        const progress = appendProgressWidget(sessionId, terminalHandle as TerminalHandle, { widgetId: widget.id });
        if (progress) {
          const terminalState = allWidgets.find((entry) => entry.id === terminalId);
          progress.replay(
            Array.isArray(terminalState?.content) ? terminalState.content : [],
            parseProgressEvents(widget.metadata as Record<string, unknown> | undefined),
          );
        }
        return;
      }
      case 'buttons': {
        appendButtons(
          sessionId,
          mapButtons(sessionId, widget.metadata?.buttons as WidgetButton[] | undefined),
          { widgetId: widget.id },
        );
        return;
      }
      case 'status': {
        appendStatusBadge(sessionId, widget.content?.[0] ?? '', { widgetId: widget.id });
        return;
      }
      case 'input': {
        appendInputWidget(
          sessionId,
          {
            label: widget.metadata?.label as string | undefined,
            placeholder: widget.metadata?.placeholder as string | undefined,
            hint: widget.metadata?.hint as string | undefined,
            onSubmit: () => undefined,
          },
          { widgetId: widget.id },
        );
        return;
      }
      default:
        return;
    }
  };

  const applyWidgetState = (sessionId: string, widget: WidgetState, allWidgets: WidgetState[]): void => {
    const handle = getWidgetHandle(sessionId, widget.id);
    if (!handle) {
      appendWidgetFromState(sessionId, widget, allWidgets);
      return;
    }

    if (widget.type === 'text' && handle.type === 'text') {
      handle.element.textContent = widget.content?.[0] ?? '';
      return;
    }

    if (widget.type === 'status' && handle.type === 'status') {
      handle.element.textContent = widget.content?.[0] ?? '';
      return;
    }

    if (widget.type === 'terminal' && handle.type === 'terminal') {
      const terminal = handle as TerminalHandle;
      if (Array.isArray(widget.content)) {
        terminal.setLines(widget.content);
      }
      terminal.setCollapsed(Boolean(widget.metadata?.collapsed));
      return;
    }

    if (widget.type === 'buttons' && handle.type === 'buttons') {
      replaceButtons(
        handle as ButtonsHandle,
        mapButtons(sessionId, widget.metadata?.buttons as WidgetButton[] | undefined),
      );
      return;
    }

    if (widget.type === 'progress' && handle.type === 'progress') {
      // Keep live timing state stable once the progress widget is mounted.
      // Replaying on every session update resets elapsed time to ~0s.
      return;
    }

    appendWidgetFromState(sessionId, widget, allWidgets);
  };

  const syncWidgets = (sessionId: string, widgets: WidgetState[] | undefined): void => {
    if (!Array.isArray(widgets) || widgets.length === 0) {
      return;
    }

    const ordered = [...widgets].sort((a, b) => (a.createdAt ?? 0) - (b.createdAt ?? 0));
    for (const widget of ordered) {
      applyWidgetState(sessionId, widget, ordered);
    }
  };

  const ensureSessionNode = (session: SessionSummary): SessionNode => {
    const existing = sessionNodes.get(session.id);
    if (existing) {
      return existing;
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

    container.appendChild(header);
    container.appendChild(body);
    sessionList?.appendChild(container);

    toggleButton.addEventListener('click', () => {
      postMessage({ type: 'plan/toggleCollapse', sessionId: session.id });
    });

    remove.addEventListener('click', () => {
      postMessage({ type: 'plan/delete', sessionId: session.id });
    });

    registerSessionContainer(session.id, body);

    const node: SessionNode = {
      container,
      toggleButton,
      title,
      status,
      body,
    };
    sessionNodes.set(session.id, node);
    return node;
  };

  const updateSession = (session: SessionSummary): void => {
    sessionCache.set(session.id, session);
    const node = ensureSessionNode(session);

    node.container.dataset.status = session.status;
    node.title.textContent = session.title || 'Untitled';
    node.status.textContent = session.status;

    node.toggleButton.textContent = session.collapsed ? '[▶]' : '[▼]';
    node.body.classList.toggle('collapsed', Boolean(session.collapsed));

    registerSessionContainer(session.id, node.body);
    syncWidgets(session.id, session.widgets);
    syncPlanStopButton(session);
  };

  const removeSession = (sessionId: string): void => {
    const node = sessionNodes.get(sessionId);
    if (!node) {
      return;
    }

    node.container.remove();
    sessionNodes.delete(sessionId);
    sessionCache.delete(sessionId);
    clearWidgets(sessionId);
  };

  const renderState = (appState: AppState): void => {
    if (!appState?.plan) {
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
    if (!message?.type) {
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
      case 'widget/append': {
        const sessionId = message.sessionId ?? '';
        const widget = message.widget;
        if (!sessionId || !widget) {
          return;
        }

        const node = sessionNodes.get(sessionId);
        if (!node?.body) {
          return;
        }

        // Ignore duplicate append for existing widget ids; updates should come via
        // widget/update or state/session hydration paths.
        if (getWidgetHandle(sessionId, widget.id)) {
          return;
        }

        registerSessionContainer(sessionId, node.body);
        const allWidgets = sessionCache.get(sessionId)?.widgets ?? [widget];
        appendWidgetFromState(sessionId, widget, allWidgets);
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
            if (handle.type !== 'terminal') {
              return;
            }
            const terminalHandle = handle as TerminalHandle;
            (update.lines ?? []).forEach((line) => {
              const isStderr = line.startsWith('stderr: ');
              const clean = isStderr ? line.slice('stderr: '.length) : line;
              terminalHandle.appendLine(clean, isStderr ? 'stderr' : undefined);
            });
            return;
          }
          case 'replaceButtons': {
            if (handle.type !== 'buttons') {
              return;
            }
            replaceButtons(handle as ButtonsHandle, mapButtons(sessionId, update.buttons));
            return;
          }
          case 'complete': {
            if (handle.type !== 'progress') {
              return;
            }
            (handle as ProgressHandle).complete();
            return;
          }
          case 'metadata': {
            if (handle.type === 'terminal') {
              const collapsed = update.metadata?.collapsed;
              if (typeof collapsed === 'boolean') {
                (handle as TerminalHandle).setCollapsed(collapsed);
              }
            }
            return;
          }
          default:
            return;
        }
      }
      default:
        return;
    }
  });
})();
