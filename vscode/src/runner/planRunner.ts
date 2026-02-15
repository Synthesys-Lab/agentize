import { spawn } from 'child_process';
import * as path from 'path';
import * as readline from 'readline';
import type { RunCommandType, RunEvent, RunPlanInput } from './types';

interface CommandSpec {
  command: string;
  args: string[];
  display: string;
}

export class PlanRunner {
  private processes = new Map<string, ReturnType<typeof spawn>>();

  run(input: RunPlanInput, onEvent: (event: RunEvent) => void): boolean {
    const key = this.getProcessKey(input.sessionId, input.command);
    if (this.processes.has(key)) {
      return false;
    }

    const spec = this.buildCommand(input);
    const startedAt = Date.now();

    let child: ReturnType<typeof spawn>;
    try {
      child = spawn(spec.command, spec.args, {
        cwd: input.cwd,
        env: process.env,
        shell: false,
      });
    } catch (error) {
      onEvent({
        type: 'stderr',
        sessionId: input.sessionId,
        commandType: input.command,
        line: this.formatSpawnError(error, spec.command),
        runId: input.runId,
        timestamp: Date.now(),
      });
      onEvent({
        type: 'exit',
        sessionId: input.sessionId,
        commandType: input.command,
        code: 1,
        signal: null,
        runId: input.runId,
        timestamp: Date.now(),
      });
      return false;
    }

    this.processes.set(key, child);
    onEvent({
      type: 'start',
      sessionId: input.sessionId,
      command: spec.display,
      commandType: input.command,
      cwd: input.cwd,
      runId: input.runId,
      timestamp: startedAt,
    });

    let exitEmitted = false;

    const emitExit = (code: number | null, signal: NodeJS.Signals | null) => {
      if (exitEmitted) {
        return;
      }
      exitEmitted = true;
      this.processes.delete(key);
      onEvent({
        type: 'exit',
        sessionId: input.sessionId,
        commandType: input.command,
        code,
        signal,
        runId: input.runId,
        timestamp: Date.now(),
      });
    };

    if (child.stdout) {
      this.attachLineReaders(child.stdout, (line) => {
        onEvent({
          type: 'stdout',
          sessionId: input.sessionId,
          commandType: input.command,
          line,
          runId: input.runId,
          timestamp: Date.now(),
        });
      });
    }

    if (child.stderr) {
      this.attachLineReaders(child.stderr, (line) => {
        onEvent({
          type: 'stderr',
          sessionId: input.sessionId,
          commandType: input.command,
          line,
          runId: input.runId,
          timestamp: Date.now(),
        });
      });
    }

    child.on('error', (error) => {
      onEvent({
        type: 'stderr',
        sessionId: input.sessionId,
        commandType: input.command,
        line: this.formatSpawnError(error, spec.command),
        runId: input.runId,
        timestamp: Date.now(),
      });
      emitExit(1, null);
    });

    child.on('exit', (code, signal) => {
      emitExit(code, signal);
    });

    return true;
  }

  stop(sessionId: string): boolean {
    let stopped = false;
    for (const [key, child] of this.processes.entries()) {
      if (!key.startsWith(`${sessionId}:`)) {
        continue;
      }
      child.kill();
      this.processes.delete(key);
      stopped = true;
    }
    return stopped;
  }

  isRunning(sessionId: string, commandType?: RunCommandType): boolean {
    if (commandType) {
      return this.processes.has(this.getProcessKey(sessionId, commandType));
    }

    for (const key of this.processes.keys()) {
      if (key.startsWith(`${sessionId}:`)) {
        return true;
      }
    }
    return false;
  }

  private buildCommand(input: RunPlanInput): CommandSpec {
    const command = 'node';
    const wrapperPath = path.join(__dirname, '..', '..', 'bin', 'lol-wrapper.js');
    if (input.command === 'impl') {
      const issueNumber = input.issueNumber ?? '';
      const args = [wrapperPath, 'impl', issueNumber];
      const display = `lol impl ${this.quoteArg(issueNumber)}`.trim();
      return { command, args, display };
    }

    const prompt = input.prompt ?? '';
    const args = [wrapperPath, 'plan'];
    let display = 'lol plan';

    if (input.command === 'refine') {
      const issueNumber = input.refineIssueNumber ?? NaN;
      args.push('--refine', String(issueNumber), prompt);
      display = `${display} --refine ${issueNumber} ${this.quoteArg(prompt)}`.trim();
    } else {
      args.push(prompt);
      display = `${display} ${this.quoteArg(prompt)}`.trim();
    }
    return { command, args, display };
  }

  private attachLineReaders(stream: NodeJS.ReadableStream, onLine: (line: string) => void): void {
    const reader = readline.createInterface({
      input: stream,
      crlfDelay: Infinity,
    });

    reader.on('line', onLine);
    stream.on('close', () => reader.close());
  }

  private quoteArg(value: string): string {
    if (!value) {
      return '""';
    }

    if (/[^A-Za-z0-9_./-]/.test(value)) {
      return JSON.stringify(value);
    }

    return value;
  }

  private formatSpawnError(error: unknown, command: string): string {
    const err = error as NodeJS.ErrnoException | undefined;
    if (err?.code === 'ENOENT') {
      return `Command not found: ${command}. Ensure the Agentize CLI is installed and on your PATH.`;
    }

    const message = error instanceof Error ? error.message : String(error);
    return `Failed to start: ${message}`;
  }

  private getProcessKey(sessionId: string, commandType: RunCommandType): string {
    return `${sessionId}:${commandType}`;
  }
}
