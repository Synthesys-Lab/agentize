export interface RunPlanInput {
  sessionId: string;
  prompt: string;
  cwd: string;
}

export type RunEvent =
  | {
      type: 'start';
      sessionId: string;
      command: string;
      cwd: string;
      timestamp: number;
    }
  | {
      type: 'stdout';
      sessionId: string;
      line: string;
      timestamp: number;
    }
  | {
      type: 'stderr';
      sessionId: string;
      line: string;
      timestamp: number;
    }
  | {
      type: 'exit';
      sessionId: string;
      code: number | null;
      signal: NodeJS.Signals | null;
      timestamp: number;
    };
