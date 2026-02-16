import type { Memento } from 'vscode';
import type { AppState, PlanSession, PlanState, RefineRun, SessionStatus, WidgetState } from './types';

const STORAGE_KEY = 'agentize.planState';
const MAX_LOG_LINES = 1000;
const SESSION_SCHEMA_VERSION = 2;

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
    const session: PlanSession = {
      id: this.createSessionId(),
      title: this.deriveTitle(trimmed),
      collapsed: false,
      status: 'idle',
      prompt: trimmed,
      issueNumber: undefined,
      issueState: undefined,
      implStatus: 'idle',
      implLogs: [],
      implCollapsed: false,
      refineRuns: [],
      logs: [],
      version: SESSION_SCHEMA_VERSION,
      widgets: [],
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
      const widgetId = this.createWidgetId('terminal');
      session.widgets = [
        ...session.widgets,
        {
          id: widgetId,
          type: 'terminal',
          title: 'Plan Log',
          content: [],
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

    if (widgets.length === 0 && migrated.logs.length > 0) {
      const widgetId = this.createWidgetId('terminal');
      widgets.push({
        id: widgetId,
        type: 'terminal',
        title: 'Plan Log',
        content: [...migrated.logs],
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

  private derivePhase(session: PlanSession): string {
    const hasRefineRunning = Array.isArray(session.refineRuns)
      ? session.refineRuns.some((run) => run.status === 'running')
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
