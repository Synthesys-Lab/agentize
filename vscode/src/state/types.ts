export type SessionStatus = 'idle' | 'running' | 'success' | 'error';

export type WidgetType = 'text' | 'terminal' | 'progress' | 'buttons' | 'input' | 'status';

export type PlanSessionPhase = 'idle' | 'planning' | 'plan-completed' | 'refining' | 'implementing' | 'completed';

export interface WidgetState {
  id: string;
  type: WidgetType;
  title?: string;
  content?: string[];
  metadata?: Record<string, unknown>;
  createdAt: number;
}

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
  planPath?: string;
  prUrl?: string;
  implStatus?: SessionStatus;
  refineRuns: RefineRun[];
  version?: number;
  widgets?: WidgetState[];
  phase?: PlanSessionPhase;
  activeTerminalHandle?: string;
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
