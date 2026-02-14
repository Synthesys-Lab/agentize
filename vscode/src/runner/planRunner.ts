import { spawn } from 'child_process';
import * as path from 'path';
import * as readline from 'readline';
import type { RunEvent, RunPlanInput } from './types';

interface CommandSpec {
  command: string;
  args: string[];
  display: string;
}

export class PlanRunner {
  private processes = new Map<string, ReturnType<typeof spawn>>();

  run(input: RunPlanInput, onEvent: (event: RunEvent) => void): boolean {
    if (this.processes.has(input.sessionId)) {
      return false;
    }

    const spec = this.buildCommand(input.prompt);
    const startedAt = Date.now();

    let child;
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
        line: this.formatSpawnError(error, spec.command),
        timestamp: Date.now(),
      });
      onEvent({
        type: 'exit',
        sessionId: input.sessionId,
        code: 1,
        signal: null,
        timestamp: Date.now(),
      });
      return false;
    }

    this.processes.set(input.sessionId, child);
    onEvent({
      type: 'start',
      sessionId: input.sessionId,
      command: spec.display,
      cwd: input.cwd,
      timestamp: startedAt,
    });

    let exitEmitted = false;

    const emitExit = (code: number | null, signal: NodeJS.Signals | null) => {
      if (exitEmitted) {
        return;
      }
      exitEmitted = true;
      this.processes.delete(input.sessionId);
      onEvent({
        type: 'exit',
        sessionId: input.sessionId,
        code,
        signal,
        timestamp: Date.now(),
      });
    };

    if (child.stdout) {
      this.attachLineReaders(child.stdout, (line) => {
        onEvent({
          type: 'stdout',
          sessionId: input.sessionId,
          line,
          timestamp: Date.now(),
        });
      });
    }

    if (child.stderr) {
      this.attachLineReaders(child.stderr, (line) => {
        onEvent({
          type: 'stderr',
          sessionId: input.sessionId,
          line,
          timestamp: Date.now(),
        });
      });
    }

    child.on('error', (error) => {
      onEvent({
        type: 'stderr',
        sessionId: input.sessionId,
        line: this.formatSpawnError(error, spec.command),
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
    const child = this.processes.get(sessionId);
    if (!child) {
      return false;
    }

    child.kill();
    this.processes.delete(sessionId);
    return true;
  }

  isRunning(sessionId: string): boolean {
    return this.processes.has(sessionId);
  }

  private buildCommand(prompt: string): CommandSpec {
    const command = 'node';
    const wrapperPath = path.join(__dirname, '..', '..', 'bin', 'lol-wrapper.js');
    const args = [wrapperPath, 'plan', prompt];
    const display = `lol plan ${this.quoteArg(prompt)}`.trim();
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
}
