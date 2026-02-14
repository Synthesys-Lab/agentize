export type RunCommandType = 'plan' | 'impl';

export interface RunPlanInput {
  sessionId: string;
  command: RunCommandType;
  prompt?: string;
  issueNumber?: string;
  cwd: string;
  refineIssueNumber?: number;
}

export type RunEvent =
  | {
      type: 'start';
      sessionId: string;
      command: string;
      commandType: RunCommandType;
      cwd: string;
      timestamp: number;
    }
  | {
      type: 'stdout';
      sessionId: string;
      commandType: RunCommandType;
      line: string;
      timestamp: number;
    }
  | {
      type: 'stderr';
      sessionId: string;
      commandType: RunCommandType;
      line: string;
      timestamp: number;
    }
  | {
      type: 'exit';
      sessionId: string;
      commandType: RunCommandType;
      code: number | null;
      signal: NodeJS.Signals | null;
      timestamp: number;
    };
