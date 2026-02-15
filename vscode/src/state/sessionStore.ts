import type { Memento } from 'vscode';
import type { AppState, PlanSession, PlanState, RefineRun, SessionStatus } from './types';

const STORAGE_KEY = 'agentize.planState';
const MAX_LOG_LINES = 1000;

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

    return {
      sessions: Array.isArray(stored.sessions) ? stored.sessions.map((session) => this.cloneSession(session)) : [],
      draftInput: typeof stored.draftInput === 'string' ? stored.draftInput : '',
    };
  }

  private persist(): void {
    void this.memento.update(STORAGE_KEY, this.state);
  }

  private createSessionId(): string {
    return `plan-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
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
    return {
      ...session,
      logs: [...session.logs],
      implStatus: session.implStatus ?? 'idle',
      implLogs: session.implLogs ? [...session.implLogs] : [],
      implCollapsed: session.implCollapsed ?? false,
      refineRuns,
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
}

export const PLAN_LOG_LIMIT = MAX_LOG_LINES;
