export type SessionStatus = 'idle' | 'running' | 'success' | 'error';

export interface PlanSession {
  id: string;
  title: string;
  collapsed: boolean;
  status: SessionStatus;
  prompt: string;
  command?: string;
  issueNumber?: string;
  implStatus?: SessionStatus;
  implLogs?: string[];
  implCollapsed?: boolean;
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
