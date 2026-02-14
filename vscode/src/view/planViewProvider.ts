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
    private readonly output: vscode.OutputChannel,
  ) {}

  resolveWebviewView(view: vscode.WebviewView): void {
    this.view = view;

    this.output.appendLine(`[planView] resolveWebviewView: extensionUri=${this.extensionUri.toString()}`);

    view.webview.options = {
      enableScripts: true,
      localResourceRoots: [vscode.Uri.joinPath(this.extensionUri, 'webview')],
    };

    view.webview.html = this.buildHtml(view.webview);

    view.webview.onDidReceiveMessage((message: IncomingMessage) => {
      void this.handleMessage(message);
    });

    view.onDidChangeVisibility(() => {
      if (view.visible) {
        this.postState();
      }
    });

    setTimeout(() => this.postState(), 0);
  }

  private async handleMessage(message: IncomingMessage): Promise<void> {
    switch (message.type) {
      case 'webview/ready': {
        this.output.appendLine('[planView] webview ready');
        return;
      }
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
      case 'plan/refine': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        const baseSession = this.store.getSession(sessionId);
        if (!baseSession || (baseSession.status !== 'success' && baseSession.status !== 'error')) {
          return;
        }

        let refineIssueNumber: number | null = null;
        const candidate = (message.issueNumber ?? baseSession.issueNumber ?? '').trim();
        if (/^\d+$/.test(candidate)) {
          const parsed = Number(candidate);
          if (Number.isInteger(parsed) && parsed > 0) {
            refineIssueNumber = parsed;
          }
        }
        if (!refineIssueNumber) {
          refineIssueNumber = await this.promptForRefineIssueNumber();
          if (!refineIssueNumber) {
            return;
          }
        }

        const focus = await this.promptForRefineFocus();
        if (!focus) {
          return;
        }

        const session = this.store.createSession(focus);
        this.postSessionUpdate(session.id, session);
        this.startRun(session, 'plan', undefined, refineIssueNumber);
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

  private startRun(
    session: PlanSession,
    commandType: RunCommandType,
    issueNumber?: string,
    refineIssueNumber?: number,
  ): void {
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
        issueNumber: typeof refineIssueNumber === 'number' ? refineIssueNumber.toString() : undefined,
        implStatus: 'idle',
        implLogs: [],
        implCollapsed: false,
      });
    } else {
      this.store.updateSession(session.id, {
        issueNumber: issueNumber ?? session.issueNumber,
        implStatus: 'idle',
        implLogs: [],
        implCollapsed: false,
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
        refineIssueNumber: commandType === 'plan' ? refineIssueNumber : undefined,
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

  private async promptForRefineIssueNumber(): Promise<number | null> {
    const issueInput = await vscode.window.showInputBox({
      prompt: 'Enter the issue number to refine',
      placeHolder: 'e.g. 882',
      ignoreFocusOut: true,
      validateInput: (value) => {
        const trimmed = value.trim();
        if (!trimmed) {
          return 'Issue number is required.';
        }
        if (!/^\d+$/.test(trimmed)) {
          return 'Issue number must be numeric.';
        }
        const parsed = Number(trimmed);
        if (!Number.isInteger(parsed) || parsed <= 0) {
          return 'Issue number must be a positive integer.';
        }
        return undefined;
      },
    });

    if (!issueInput) {
      return null;
    }

    const parsed = Number(issueInput.trim());
    if (!Number.isInteger(parsed) || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  private async promptForRefineFocus(): Promise<string | null> {
    const focusInput = await vscode.window.showInputBox({
      prompt: 'Enter refinement focus or instructions',
      placeHolder: 'e.g. Clarify success criteria or reduce scope',
      ignoreFocusOut: true,
      validateInput: (value) => {
        if (!value.trim()) {
          return 'Refinement focus is required.';
        }
        return undefined;
      },
    });

    if (!focusInput) {
      return null;
    }

    const trimmed = focusInput.trim();
    if (!trimmed) {
      return null;
    }

    return trimmed;
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
    const scriptFsPath = path.join(this.extensionUri.fsPath, 'webview', 'plan', 'out', 'index.js');
    const styleFsPath = path.join(this.extensionUri.fsPath, 'webview', 'plan', 'styles.css');
    const hasScript = fs.existsSync(scriptFsPath);
    const hasStyle = fs.existsSync(styleFsPath);

    if (!hasScript || !hasStyle) {
      this.output.appendLine(
        `[planView] missing webview assets: script=${hasScript ? 'ok' : scriptFsPath} style=${hasStyle ? 'ok' : styleFsPath}`,
      );
    }

    let initialState = '{}';
    try {
      initialState = JSON.stringify(this.store.getAppState())
        .replace(/</g, '\\u003c')
        .replace(/\u2028/g, '\\u2028')
        .replace(/\u2029/g, '\\u2029');
    } catch (error) {
      this.output.appendLine(`[planView] failed to serialize initial state: ${String(error)}`);
    }

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} https: data:; font-src ${webview.cspSource}; style-src ${webview.cspSource} 'unsafe-inline'; script-src ${webview.cspSource} 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="${styleUri}" rel="stylesheet" />
  <title>Agentize</title>
</head>
<body>
  <div id="plan-root" class="plan-root">
    <div class="plan-skeleton">
      <div class="plan-skeleton-title">Agentize</div>
      <div id="plan-skeleton-status" class="plan-skeleton-subtitle">Loading webview UI...</div>
      ${hasScript && hasStyle ? '' : '<div class="plan-skeleton-error">Webview assets missing. Run <code>make vscode-plugin</code> and reload VS Code.</div>'}
    </div>
  </div>
  <script nonce="${nonce}">window.__INITIAL_STATE__ = ${initialState};</script>
  <script nonce="${nonce}">
    (function() {
      const statusEl = document.getElementById('plan-skeleton-status');
      const initialStatus = statusEl ? statusEl.textContent : '';
      const setStatus = (text) => {
        if (statusEl) statusEl.textContent = text;
      };
      const setStatusIfUnchanged = (text) => {
        if (!statusEl) return;
        if (statusEl.textContent === initialStatus) {
          statusEl.textContent = text;
        }
      };

      window.addEventListener('error', (event) => {
        const message = event && event.message ? event.message : 'Unknown error';
        setStatus('Webview error: ' + message);
      });

      window.addEventListener('unhandledrejection', (event) => {
        let reason = 'Unknown rejection';
        if (event && event.reason) {
          try { reason = String(event.reason); } catch (_) {}
        }
        setStatus('Webview rejection: ' + reason);
      });

      const script = document.createElement('script');
      script.src = "${scriptUri}";
      script.type = "module";
      script.nonce = "${nonce}";
      script.onload = () => {
        // Don't overwrite a more specific status written by the webview code.
        setStatusIfUnchanged('Webview script loaded; waiting for init...');
        setTimeout(() => {
          setStatusIfUnchanged('Webview script loaded but did not initialize.');
        }, 2000);
      };
      script.onerror = () => setStatus('Failed to load webview script.');
      document.body.appendChild(script);
    })();
  </script>
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
    'plan/refine',
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
