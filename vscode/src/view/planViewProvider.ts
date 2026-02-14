import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import type { PlanSession } from '../state/types';
import { SessionStore } from '../state/sessionStore';
import { PlanRunner } from '../runner/planRunner';
import type { RunCommandType, RunEvent } from '../runner/types';

interface IncomingMessage {
  type: string;
  sessionId?: string;
  prompt?: string;
  value?: string;
  issueNumber?: string;
  url?: string;
  path?: string;
}

interface SessionUpdateMessage {
  type: 'plan/sessionUpdated';
  sessionId: string;
  session?: PlanSession;
  deleted?: boolean;
}

export class PlanViewProvider implements vscode.WebviewViewProvider {
  static readonly viewType = 'agentize.planView';

  private view?: vscode.WebviewView;

  constructor(
    private readonly extensionUri: vscode.Uri,
    private readonly store: SessionStore,
    private readonly runner: PlanRunner,
  ) {}

  resolveWebviewView(view: vscode.WebviewView): void {
    this.view = view;

    view.webview.options = {
      enableScripts: true,
      localResourceRoots: [vscode.Uri.joinPath(this.extensionUri, 'webview')],
    };

    view.webview.html = this.buildHtml(view.webview);

    view.webview.onDidReceiveMessage((message: IncomingMessage) => {
      this.handleMessage(message);
    });

    view.onDidChangeVisibility(() => {
      if (view.visible) {
        this.postState();
      }
    });

    setTimeout(() => this.postState(), 0);
  }

  private handleMessage(message: IncomingMessage): void {
    switch (message.type) {
      case 'plan/new': {
        const prompt = message.prompt?.trim() ?? '';
        if (!prompt) {
          return;
        }
        const session = this.store.createSession(prompt);
        this.store.updateDraftInput('');
        this.postSessionUpdate(session.id, session);
        this.startRun(session, 'plan');
        return;
      }
      case 'plan/run': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        const session = this.store.getSession(sessionId);
        if (!session) {
          return;
        }
        this.startRun(session, 'plan');
        return;
      }
      case 'plan/impl': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        const session = this.store.getSession(sessionId);
        if (!session) {
          return;
        }
        if (session.status !== 'success') {
          this.appendSystemLog(sessionId, 'Plan must succeed before implementation can start.', true, 'impl');
          return;
        }
        if (session.implStatus === 'running' || this.runner.isRunning(sessionId, 'impl')) {
          this.appendSystemLog(sessionId, 'Implementation already running.', true, 'impl');
          return;
        }
        const issueNumber = (message.issueNumber ?? session.issueNumber ?? '').trim();
        if (!issueNumber) {
          this.appendSystemLog(sessionId, 'Missing issue number for implementation.', true, 'impl');
          return;
        }
        this.startRun(session, 'impl', issueNumber);
        return;
      }
      case 'plan/toggleCollapse': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        const session = this.store.toggleSessionCollapse(sessionId);
        if (session) {
          this.postSessionUpdate(session.id, session);
        }
        return;
      }
      case 'plan/toggleImplCollapse': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        const session = this.store.toggleImplCollapse(sessionId);
        if (session) {
          this.postSessionUpdate(session.id, session);
        }
        return;
      }
      case 'plan/delete': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        console.log('[PlanViewProvider] Handling plan/delete for:', sessionId);
        if (this.runner.isRunning(sessionId)) {
          this.runner.stop(sessionId);
        }
        this.store.deleteSession(sessionId);
        this.postSessionDeleted(sessionId);
        return;
      }
      case 'plan/updateDraft': {
        this.store.updateDraftInput(message.value ?? '');
        return;
      }
      case 'link/openExternal': {
        const url = message.url ?? '';
        if (this.isValidGitHubUrl(url)) {
          void vscode.env.openExternal(vscode.Uri.parse(url));
        }
        return;
      }
      case 'link/openFile': {
        const filePath = message.path ?? '';
        if (filePath) {
          void this.openLocalFile(filePath);
        }
        return;
      }
      default:
        return;
    }
  }

  private isValidGitHubUrl(url: string): boolean {
    // Validate GitHub issue URLs: https://github.com/owner/repo/issues/N
    return /^https:\/\/github\.com\/[^/]+\/[^/]+\/issues\/\d+$/.test(url);
  }

  private async openLocalFile(filePath: string): Promise<void> {
    try {
      const workspaceFolders = vscode.workspace.workspaceFolders;
      if (!workspaceFolders || workspaceFolders.length === 0) {
        return;
      }

      // Resolve path relative to workspace root
      const workspaceRoot = workspaceFolders[0].uri.fsPath;
      const fullPath = path.isAbsolute(filePath)
        ? filePath
        : path.join(workspaceRoot, filePath);

      const document = await vscode.workspace.openTextDocument(fullPath);
      await vscode.window.showTextDocument(document);
    } catch (error) {
      console.error('[PlanViewProvider] Failed to open file:', filePath, error);
    }
  }

  private startRun(session: PlanSession, commandType: RunCommandType, issueNumber?: string): void {
    if (this.runner.isRunning(session.id)) {
      this.appendSystemLog(session.id, 'Session already running.', true, commandType);
      return;
    }
    if (commandType === 'plan' && session.status === 'running') {
      this.appendSystemLog(session.id, 'Session already running.', true, commandType);
      return;
    }
    if (commandType === 'impl' && session.implStatus === 'running') {
      this.appendSystemLog(session.id, 'Implementation already running.', true, commandType);
      return;
    }

    const cwd = this.resolvePlanCwd();
    if (!cwd) {
      const update: Partial<PlanSession> =
        commandType === 'impl' ? { implStatus: 'error' } : { status: 'error' };
      this.appendSystemLog(session.id, 'Missing workspace or trees/main path.', false, commandType);
      this.store.updateSession(session.id, update);
      const updated = this.store.getSession(session.id);
      if (updated) {
        this.postSessionUpdate(updated.id, updated);
      }
      return;
    }

    if (commandType === 'plan') {
      this.store.updateSession(session.id, {
        issueNumber: undefined,
        implStatus: 'idle',
        implLogs: [],
      });
    } else {
      this.store.updateSession(session.id, {
        issueNumber: issueNumber ?? session.issueNumber,
        implStatus: 'idle',
        implLogs: [],
      });
    }
    const prepped = this.store.getSession(session.id);
    if (prepped) {
      this.postSessionUpdate(prepped.id, prepped);
    }

    const started = this.runner.run(
      {
        sessionId: session.id,
        command: commandType,
        prompt: commandType === 'plan' ? session.prompt : undefined,
        issueNumber: commandType === 'impl' ? issueNumber : undefined,
        cwd,
      },
      (event) => this.handleRunEvent(event),
    );

    if (!started) {
      const update: Partial<PlanSession> =
        commandType === 'impl' ? { implStatus: 'error' } : { status: 'error' };
      this.appendSystemLog(session.id, 'Unable to start session.', false, commandType);
      this.store.updateSession(session.id, update);
      const updated = this.store.getSession(session.id);
      if (updated) {
        this.postSessionUpdate(updated.id, updated);
      }
    }
  }

  private handleRunEvent(event: RunEvent): void {
    const session = this.store.getSession(event.sessionId);
    if (!session) {
      return;
    }

    const isImpl = event.commandType === 'impl';

    switch (event.type) {
      case 'start': {
        const update: Partial<PlanSession> = isImpl
          ? { implStatus: 'running' }
          : { status: 'running', command: event.command };
        const updated = this.store.updateSession(event.sessionId, update);
        this.appendSystemLog(event.sessionId, `> ${event.command}`, false, event.commandType);
        if (updated) {
          this.postSessionUpdate(updated.id, updated);
        }
        this.postRunEvent(event);
        return;
      }
      case 'stdout': {
        if (isImpl) {
          this.store.appendImplLogs(event.sessionId, [event.line]);
        } else {
          this.store.appendSessionLogs(event.sessionId, [event.line]);
          this.captureIssueNumber(event.sessionId, event.line);
        }
        this.postRunEvent(event);
        return;
      }
      case 'stderr': {
        const storedLine = `stderr: ${event.line}`;
        if (isImpl) {
          this.store.appendImplLogs(event.sessionId, [storedLine]);
        } else {
          this.store.appendSessionLogs(event.sessionId, [storedLine]);
          this.captureIssueNumber(event.sessionId, event.line);
        }
        this.postRunEvent(event);
        return;
      }
      case 'exit': {
        const status = event.code === 0 ? 'success' : 'error';
        const update: Partial<PlanSession> = isImpl ? { implStatus: status } : { status };
        const line = `Exit code: ${event.code ?? 'null'}`;
        if (isImpl) {
          this.store.appendImplLogs(event.sessionId, [line]);
        } else {
          this.store.appendSessionLogs(event.sessionId, [line]);
        }
        const updated = this.store.updateSession(event.sessionId, update);
        if (updated) {
          this.postSessionUpdate(updated.id, updated);
        }
        this.postRunEvent(event);
        return;
      }
      default:
        return;
    }
  }

  private appendSystemLog(
    sessionId: string,
    line: string,
    broadcast: boolean,
    commandType: RunCommandType = 'plan',
  ): void {
    if (commandType === 'impl') {
      this.store.appendImplLogs(sessionId, [line]);
    } else {
      this.store.appendSessionLogs(sessionId, [line]);
    }
    if (broadcast) {
      this.postRunEvent({
        type: 'stdout',
        sessionId,
        commandType,
        line,
        timestamp: Date.now(),
      });
    }
  }

  private captureIssueNumber(sessionId: string, line: string): void {
    const issueNumber = this.extractIssueNumber(line);
    if (!issueNumber) {
      return;
    }

    const updated = this.store.updateSession(sessionId, { issueNumber });
    if (updated) {
      this.postSessionUpdate(updated.id, updated);
    }
  }

  private extractIssueNumber(line: string): string | null {
    const placeholderMatch = /Created placeholder issue #(\d+)/.exec(line);
    if (placeholderMatch) {
      return placeholderMatch[1];
    }

    const urlMatch = /https:\/\/github\.com\/[^/]+\/[^/]+\/issues\/(\d+)/.exec(line);
    if (urlMatch) {
      return urlMatch[1];
    }

    return null;
  }

  private resolvePlanCwd(): string | null {
    const workspaces = vscode.workspace.workspaceFolders;
    if (!workspaces || workspaces.length === 0) {
      return null;
    }

    // Prefer the shared "trees/main" layout (workspace root is a meta-repo that
    // contains multiple worktrees under ./trees).
    for (const workspace of workspaces) {
      const planRoot = path.join(workspace.uri.fsPath, 'trees', 'main');
      if (fs.existsSync(planRoot)) {
        return planRoot;
      }
    }

    // Fallback: if the user opened a single worktree (e.g. ./trees/issue-866),
    // run planning in that workspace root directly.
    for (const workspace of workspaces) {
      const root = workspace.uri.fsPath;
      if (this.looksLikeWorktreeRoot(root)) {
        return root;
      }
    }

    return null;
  }

  private looksLikeWorktreeRoot(root: string): boolean {
    // Keep this heuristic simple and cheap: we just need a directory that
    // resembles an Agentize working tree where `setup.sh` and the CLI sources live.
    return (
      fs.existsSync(path.join(root, 'setup.sh')) &&
      fs.existsSync(path.join(root, 'Makefile')) &&
      fs.existsSync(path.join(root, 'src'))
    );
  }

  private postState(): void {
    if (!this.view) {
      return;
    }

    this.view.webview.postMessage({
      type: 'state/replace',
      state: this.store.getAppState(),
    });
  }

  private postSessionUpdate(sessionId: string, session: PlanSession): void {
    if (!this.view) {
      return;
    }

    const message: SessionUpdateMessage = {
      type: 'plan/sessionUpdated',
      sessionId,
      session,
    };
    this.view.webview.postMessage(message);
  }

  private postSessionDeleted(sessionId: string): void {
    if (!this.view) {
      return;
    }

    const message: SessionUpdateMessage = {
      type: 'plan/sessionUpdated',
      sessionId,
      deleted: true,
    };
    this.view.webview.postMessage(message);
  }

  private postRunEvent(event: RunEvent): void {
    if (!this.view) {
      return;
    }

    this.view.webview.postMessage({
      type: 'plan/runEvent',
      event,
    });
  }

  private buildHtml(webview: vscode.Webview): string {
    // The webview runs in a browser context and must load JavaScript, not TypeScript.
    // `npm --prefix vscode run compile` compiles `webview/plan/index.ts` to `webview/plan/out/index.js`.
    const scriptPath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'plan', 'out', 'index.js');
    const stylePath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'plan', 'styles.css');
    const scriptUri = webview.asWebviewUri(scriptPath);
    const styleUri = webview.asWebviewUri(stylePath);
    const nonce = this.getNonce();
    const initialState = JSON.stringify(this.store.getAppState()).replace(/</g, '\\u003c');

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource}; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="${styleUri}" rel="stylesheet" />
  <title>Plan</title>
</head>
<body>
  <div id="plan-root" class="plan-root"></div>
  <script nonce="${nonce}">window.__INITIAL_STATE__ = ${initialState};</script>
  <script nonce="${nonce}" src="${scriptUri}"></script>
</body>
</html>`;
  }

  private getNonce(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let value = '';
    for (let i = 0; i < 32; i += 1) {
      value += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return value;
  }
}

export const PlanViewProviderMessages = {
  incoming: [
    'plan/new',
    'plan/run',
    'plan/impl',
    'plan/toggleCollapse',
    'plan/toggleImplCollapse',
    'plan/delete',
    'plan/updateDraft',
    'link/openExternal',
    'link/openFile',
  ],
  outgoing: ['state/replace', 'plan/sessionUpdated', 'plan/runEvent'],
};
