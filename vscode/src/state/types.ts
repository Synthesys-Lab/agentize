export type SessionStatus = 'idle' | 'running' | 'success' | 'error';

export interface RefineRun {
  id: string;
  prompt: string;
  status: SessionStatus;
  logs: string[];
  collapsed: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface PlanSession {
  id: string;
  title: string;
  collapsed: boolean;
  status: SessionStatus;
  prompt: string;
  command?: string;
  issueNumber?: string;
  issueState?: 'open' | 'closed' | 'unknown';
  implStatus?: SessionStatus;
  implLogs?: string[];
  implCollapsed?: boolean;
  refineRuns: RefineRun[];
  logs: string[];
  createdAt: number;
  updatedAt: number;
}

export interface PlanState {
  sessions: PlanSession[];
  draftInput: string;
}

export type RepoState = Record<string, never>;
export type ImplState = Record<string, never>;
export type SettingsState = Record<string, never>;

export interface AppState {
  activeTab: 'plan' | 'repo' | 'impl' | 'settings';
  plan: PlanState;
  repo: RepoState;
  impl: ImplState;
  settings: SettingsState;
}
