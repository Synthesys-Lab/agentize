import type { Memento } from 'vscode';
import type { AppState, PlanSession, PlanState, RefineRun, SessionStatus, WidgetState } from './types';

const STORAGE_KEY = 'agentize.planState';
const MAX_LOG_LINES = 1000;
const SESSION_SCHEMA_VERSION = 2;
const WIDGET_ROLE_PLAN_TERMINAL = 'plan-terminal';
const WIDGET_ROLE_PROMPT = 'prompt';

const DEFAULT_PLAN_STATE: PlanState = {
  sessions: [],
  draftInput: '',
};

export class SessionStore {
  private state: PlanState;

  constructor(private readonly memento: Memento) {
    this.state = this.load();
  }

  getAppState(): AppState {
    return {
      activeTab: 'plan',
      plan: this.getPlanState(),
      repo: {},
      impl: {},
      settings: {},
    };
  }

  getPlanState(): PlanState {
    return {
      sessions: this.state.sessions.map((session) => this.cloneSession(session)),
      draftInput: this.state.draftInput,
    };
  }

  getSession(id: string): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    return session ? this.cloneSession(session) : undefined;
  }

  createSession(prompt: string): PlanSession {
    const now = Date.now();
    const trimmed = prompt.trim();
    const promptWidget: WidgetState = {
      id: this.createWidgetId('text'),
      type: 'text',
      content: [trimmed],
      metadata: { role: WIDGET_ROLE_PROMPT },
      createdAt: now,
    };

    const session: PlanSession = {
      id: this.createSessionId(),
      title: this.deriveTitle(trimmed),
      collapsed: false,
      status: 'idle',
      prompt: trimmed,
      issueNumber: undefined,
      issueState: undefined,
      planPath: undefined,
      prUrl: undefined,
      implStatus: 'idle',
      implLogs: [],
      implCollapsed: false,
      refineRuns: [],
      logs: [],
      version: SESSION_SCHEMA_VERSION,
      widgets: [promptWidget],
      phase: 'idle',
      activeTerminalHandle: undefined,
      createdAt: now,
      updatedAt: now,
    };

    this.state.sessions = [...this.state.sessions, session];
    this.persist();
    return this.cloneSession(session);
  }

  updateSession(id: string, update: Partial<PlanSession>): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    Object.assign(session, update, { updatedAt: Date.now() });
    this.persist();
    return this.cloneSession(session);
  }

  appendSessionLogs(id: string, lines: string[]): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    session.logs = this.trimLogs([...session.logs, ...lines]);
    this.appendLinesToActiveWidget(session, lines);
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  appendImplLogs(id: string, lines: string[]): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    const existing = session.implLogs ?? [];
    session.implLogs = this.trimLogs([...existing, ...lines]);
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  addRefineRun(id: string, run: RefineRun): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    const existingRuns = Array.isArray(session.refineRuns) ? session.refineRuns : [];
    session.refineRuns = [...existingRuns, this.cloneRefineRun(run)];
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  appendRefineRunLogs(id: string, runId: string, lines: string[]): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    const runs = Array.isArray(session.refineRuns) ? session.refineRuns : [];
    session.refineRuns = runs.map((run) => {
      if (run.id !== runId) {
        return this.cloneRefineRun(run);
      }
      const existing = Array.isArray(run.logs) ? run.logs : [];
      return this.cloneRefineRun({
        ...run,
        logs: this.trimLogs([...existing, ...lines]),
        updatedAt: Date.now(),
      });
    });
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  appendWidgetLines(id: string, widgetId: string, lines: string[]): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session || !session.widgets) {
      return undefined;
    }

    let updatedWidget = false;
    session.widgets = session.widgets.map((widget) => {
      if (widget.id !== widgetId || widget.type !== 'terminal') {
        return widget;
      }
      const existing = Array.isArray(widget.content) ? widget.content : [];
      updatedWidget = true;
      return {
        ...widget,
        content: this.trimLogs([...existing, ...lines]),
      };
    });

    if (!updatedWidget) {
      return undefined;
    }

    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  addWidget(id: string, widget: Omit<WidgetState, 'id' | 'createdAt'> & { id?: string; createdAt?: number }):
    | WidgetState
    | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    if (!session.widgets) {
      session.widgets = [];
    }

    const created: WidgetState = {
      ...widget,
      id: widget.id ?? this.createWidgetId(widget.type),
      createdAt: widget.createdAt ?? Date.now(),
    };
    session.widgets = [...session.widgets, created];
    if (created.type === 'terminal' && created.metadata?.role === WIDGET_ROLE_PLAN_TERMINAL) {
      session.activeTerminalHandle = created.id;
    }
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneWidget(created);
  }

  updateWidgetMetadata(id: string, widgetId: string, metadata: Record<string, unknown>): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    if (!session.widgets) {
      return this.cloneSession(session);
    }

    session.widgets = session.widgets.map((widget) => {
      if (widget.id !== widgetId) {
        return widget;
      }
      return {
        ...widget,
        metadata: { ...(widget.metadata ?? {}), ...metadata },
      };
    });
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  updateRefineRunStatus(id: string, runId: string, status: SessionStatus): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    const runs = Array.isArray(session.refineRuns) ? session.refineRuns : [];
    session.refineRuns = runs.map((run) => {
      if (run.id !== runId) {
        return this.cloneRefineRun(run);
      }
      return this.cloneRefineRun({
        ...run,
        status,
        updatedAt: Date.now(),
      });
    });
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  toggleRefineRunCollapse(id: string, runId: string): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    const runs = Array.isArray(session.refineRuns) ? session.refineRuns : [];
    session.refineRuns = runs.map((run) => {
      if (run.id !== runId) {
        return this.cloneRefineRun(run);
      }
      return this.cloneRefineRun({
        ...run,
        collapsed: !run.collapsed,
        updatedAt: Date.now(),
      });
    });
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  toggleSessionCollapse(id: string): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    session.collapsed = !session.collapsed;
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  toggleImplCollapse(id: string): PlanSession | undefined {
    const session = this.state.sessions.find((item) => item.id === id);
    if (!session) {
      return undefined;
    }

    session.implCollapsed = !session.implCollapsed;
    session.updatedAt = Date.now();
    this.persist();
    return this.cloneSession(session);
  }

  deleteSession(id: string): void {
    this.state.sessions = this.state.sessions.filter((item) => item.id !== id);
    this.persist();
  }

  updateDraftInput(value: string): void {
    this.state.draftInput = value;
    this.persist();
  }

  private load(): PlanState {
    const stored = this.memento.get<PlanState>(STORAGE_KEY);
    if (!stored) {
      return { ...DEFAULT_PLAN_STATE };
    }

    let migrated = false;
    const sessions = Array.isArray(stored.sessions)
      ? stored.sessions.map((session) => {
          const version = typeof session.version === 'number' ? session.version : 1;
          if (version < SESSION_SCHEMA_VERSION) {
            migrated = true;
            return this.migrateSession(session);
          }
          return this.cloneSession(session);
        })
      : [];
    const draftInput = typeof stored.draftInput === 'string' ? stored.draftInput : '';
    const state = { sessions, draftInput };
    if (migrated) {
      this.state = state;
      this.persist();
    }
    return state;
  }

  private persist(): void {
    void this.memento.update(STORAGE_KEY, this.state);
  }

  private createSessionId(): string {
    return `plan-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  }

  private createWidgetId(type: string): string {
    return `${type}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  }

  private deriveTitle(prompt: string): string {
    if (!prompt) {
      return 'New Plan';
    }

    const trimmed = prompt.replace(/\s+/g, ' ').trim();
    return trimmed.length <= 20 ? trimmed : `${trimmed.slice(0, 20)}...`;
  }

  private trimLogs(lines: string[]): string[] {
    if (lines.length <= MAX_LOG_LINES) {
      return lines;
    }

    return lines.slice(lines.length - MAX_LOG_LINES);
  }

  private cloneSession(session: PlanSession): PlanSession {
    const runs = Array.isArray(session.refineRuns) ? session.refineRuns : [];
    const refineRuns: RefineRun[] = runs.map((run) => this.cloneRefineRun(run));
    const widgets = Array.isArray(session.widgets) ? session.widgets.map((widget) => this.cloneWidget(widget)) : [];
    return {
      ...session,
      logs: Array.isArray(session.logs) ? [...session.logs] : [],
      implStatus: session.implStatus ?? 'idle',
      implLogs: session.implLogs ? [...session.implLogs] : [],
      implCollapsed: session.implCollapsed ?? false,
      version: typeof session.version === 'number' ? session.version : undefined,
      widgets,
      phase: session.phase,
      activeTerminalHandle: session.activeTerminalHandle,
      planPath: session.planPath,
      prUrl: session.prUrl,
      refineRuns,
    };
  }

  private cloneWidget(widget: WidgetState): WidgetState {
    return {
      id: widget.id ?? this.createWidgetId('widget'),
      type: widget.type,
      title: widget.title,
      content: Array.isArray(widget.content) ? [...widget.content] : undefined,
      metadata: widget.metadata ? { ...widget.metadata } : undefined,
      createdAt: widget.createdAt ?? Date.now(),
    };
  }

  private cloneRefineRun(run: RefineRun): RefineRun {
    return {
      ...run,
      prompt: run.prompt ?? '',
      status: run.status ?? 'idle',
      logs: Array.isArray(run.logs) ? [...run.logs] : [],
      collapsed: Boolean(run.collapsed),
      createdAt: run.createdAt ?? Date.now(),
      updatedAt: run.updatedAt ?? Date.now(),
    };
  }

  private appendLinesToActiveWidget(session: PlanSession, lines: string[]): void {
    if (!session.widgets) {
      session.widgets = [];
    }

    if (!session.activeTerminalHandle) {
      const existing = session.widgets.find(
        (widget) => widget.type === 'terminal' && widget.metadata?.role === WIDGET_ROLE_PLAN_TERMINAL,
      );
      if (existing) {
        session.activeTerminalHandle = existing.id;
      }
    }

    if (!session.activeTerminalHandle) {
      const widgetId = this.createWidgetId('terminal');
      session.widgets = [
        ...session.widgets,
        {
          id: widgetId,
          type: 'terminal',
          title: 'Plan Log',
          content: [],
          metadata: { role: WIDGET_ROLE_PLAN_TERMINAL },
          createdAt: Date.now(),
        },
      ];
      session.activeTerminalHandle = widgetId;
    }

    session.widgets = session.widgets.map((widget) => {
      if (widget.id !== session.activeTerminalHandle || widget.type !== 'terminal') {
        return widget;
      }
      const existing = Array.isArray(widget.content) ? widget.content : [];
      return {
        ...widget,
        content: this.trimLogs([...existing, ...lines]),
      };
    });
  }

  private migrateSession(session: PlanSession): PlanSession {
    const migrated = this.cloneSession(session);
    const widgets = Array.isArray(migrated.widgets) ? migrated.widgets : [];
    let activeTerminalHandle = migrated.activeTerminalHandle;

    const hasPromptWidget = widgets.some((widget) => widget.metadata?.role === WIDGET_ROLE_PROMPT);
    if (!hasPromptWidget && migrated.prompt) {
      widgets.unshift({
        id: this.createWidgetId('text'),
        type: 'text',
        content: [migrated.prompt],
        metadata: { role: WIDGET_ROLE_PROMPT },
        createdAt: migrated.createdAt ?? Date.now(),
      });
    }

    if (widgets.length === 0 && migrated.logs.length > 0) {
      const widgetId = this.createWidgetId('terminal');
      widgets.push({
        id: widgetId,
        type: 'terminal',
        title: 'Plan Log',
        content: [...migrated.logs],
        metadata: { role: WIDGET_ROLE_PLAN_TERMINAL },
        createdAt: Date.now(),
      });
      activeTerminalHandle = widgetId;
    }

    const phase = this.derivePhase(migrated);

    return {
      ...migrated,
      version: SESSION_SCHEMA_VERSION,
      widgets,
      phase,
      activeTerminalHandle,
    };
  }

  private derivePhase(session: PlanSession): import('./types').PlanSessionPhase {
    const hasRefineRunning = Array.isArray(session.refineRuns)
      ? session.refineRuns.some((run: import('./types').RefineRun) => run.status === 'running')
      : false;

    if (session.implStatus === 'running') {
      return 'implementing';
    }
    if (session.implStatus === 'success' || session.implStatus === 'error') {
      return 'completed';
    }
    if (hasRefineRunning) {
      return 'refining';
    }
    if (session.status === 'running') {
      return 'planning';
    }
    if (session.status === 'success' || session.status === 'error') {
      return 'plan-completed';
    }
    return 'idle';
  }
}

export const PLAN_LOG_LIMIT = MAX_LOG_LINES;
