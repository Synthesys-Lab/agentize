import { execFile } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { promisify } from 'util';
import * as vscode from 'vscode';
import type { PlanSession, PlanSessionPhase, WidgetState } from '../state/types';
import { SessionStore } from '../state/sessionStore';
import { PlanRunner } from '../runner/planRunner';
import type { RunCommandType, RunEvent } from '../runner/types';

interface IncomingMessage {
  type: string;
  sessionId?: string;
  prompt?: string;
  value?: string;
  issueNumber?: string;
  runId?: string;
  url?: string;
  path?: string;
}

interface SessionUpdateMessage {
  type: 'plan/sessionUpdated';
  sessionId: string;
  session?: PlanSession;
  deleted?: boolean;
}

interface WidgetButton {
  id: string;
  label: string;
  action: string;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  disabled?: boolean;
}

interface WidgetAppendMessage {
  type: 'widget/append';
  sessionId: string;
  widget: WidgetState;
}

type WidgetUpdatePayload =
  | { type: 'appendLines'; lines: string[] }
  | { type: 'replaceButtons'; buttons: WidgetButton[] }
  | { type: 'complete' }
  | { type: 'metadata'; metadata: Record<string, unknown> };

interface WidgetUpdateMessage {
  type: 'widget/update';
  sessionId: string;
  widgetId: string;
  update: WidgetUpdatePayload;
}

const execFileAsync = promisify(execFile);

const WIDGET_ROLES = {
  prompt: 'prompt',
  planTerminal: 'plan-terminal',
  planProgress: 'plan-progress',
  implTerminal: 'impl-terminal',
  implProgress: 'impl-progress',
  refineTerminal: 'refine-terminal',
  refineProgress: 'refine-progress',
  actions: 'session-actions',
} as const;

export class UnifiedViewProvider implements vscode.WebviewViewProvider {
  static readonly viewType = 'agentize.unifiedView';
  private static readonly skeletonPlaceholder = '{{SKELETON_ERROR}}';

  private view?: vscode.WebviewView;

  constructor(
    private readonly extensionUri: vscode.Uri,
    private readonly store: SessionStore,
    private readonly runner: PlanRunner,
    private readonly output: vscode.OutputChannel,
  ) {}

  resolveWebviewView(view: vscode.WebviewView): void {
    this.view = view;

    this.output.appendLine(`[unifiedView] resolveWebviewView: extensionUri=${this.extensionUri.toString()}`);

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
        void this.refreshIssueStates();
      }
    });

    setTimeout(() => {
      this.postState();
      void this.refreshIssueStates();
    }, 0);
  }

  private async handleMessage(message: IncomingMessage): Promise<void> {
    switch (message.type) {
      case 'webview/ready': {
        this.output.appendLine('[unifiedView] webview ready');
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
        const issueState = await this.checkIssueState(issueNumber);
        const updated = this.store.updateSession(sessionId, { issueState });
        if (updated) {
          this.postSessionUpdate(updated.id, updated);
        }
        if (issueState === 'closed') {
          this.appendSystemLog(sessionId, `Issue #${issueNumber} is closed.`, true, 'impl');
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

        const focus = message.prompt?.trim() ?? '';
        if (!focus) {
          return;
        }

        const runId = message.runId ?? '';
        const now = Date.now();
        const afterRun = this.store.addRefineRun(sessionId, {
          id: runId,
          prompt: focus,
          status: 'idle',
          logs: [],
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        });
        if (afterRun) {
          this.postSessionUpdate(afterRun.id, afterRun);
        }
        this.ensureRefineWidgets(sessionId, runId, focus);

        const issueCandidate = (message.issueNumber ?? baseSession.issueNumber ?? '').trim();
        if (!/^\d+$/.test(issueCandidate)) {
          this.store.updateRefineRunStatus(sessionId, runId, 'error');
          this.appendRefineLines(sessionId, runId, ['Missing issue number for refinement.']);
          const updated = this.store.getSession(sessionId);
          if (updated) {
            this.postSessionUpdate(updated.id, updated);
          }
          this.syncActionButtons(sessionId);
          return;
        }

        const refineIssueNumber = Number(issueCandidate);
        if (!Number.isInteger(refineIssueNumber) || refineIssueNumber <= 0) {
          this.store.updateRefineRunStatus(sessionId, runId, 'error');
          this.appendRefineLines(sessionId, runId, ['Invalid issue number for refinement.']);
          const updated = this.store.getSession(sessionId);
          if (updated) {
            this.postSessionUpdate(updated.id, updated);
          }
          this.syncActionButtons(sessionId);
          return;
        }

        this.store.updateSession(sessionId, { issueNumber: issueCandidate });
        const prepped = this.store.getSession(sessionId);
        if (prepped) {
          this.postSessionUpdate(prepped.id, prepped);
        }
        this.syncActionButtons(sessionId);

        this.startRun(prepped ?? baseSession, 'refine', undefined, refineIssueNumber, focus, runId);
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
          const terminal = this.findWidgetByRole(session, WIDGET_ROLES.implTerminal, 'terminal');
          if (terminal) {
            this.postWidgetUpdate(session.id, terminal.id, {
              type: 'metadata',
              metadata: { collapsed: session.implCollapsed ?? false },
            });
          }
        }
        return;
      }
      case 'plan/delete': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        console.log('[UnifiedViewProvider] Handling plan/delete for:', sessionId);
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
      case 'plan/view-plan': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        const session = this.store.getSession(sessionId);
        if (!session) {
          return;
        }
        const planPath = this.resolvePlanPath(session);
        if (planPath) {
          void this.openLocalFile(planPath);
        }
        return;
      }
      case 'plan/view-pr': {
        const sessionId = message.sessionId ?? '';
        if (!sessionId) {
          return;
        }
        const session = this.store.getSession(sessionId);
        if (!session || !session.prUrl) {
          return;
        }
        void vscode.env.openExternal(vscode.Uri.parse(session.prUrl));
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

      const workspaceRoot = workspaceFolders[0].uri.fsPath;
      const candidates: string[] = [];

      if (path.isAbsolute(filePath)) {
        candidates.push(filePath);
      } else {
        candidates.push(path.join(workspaceRoot, filePath));
        const planRoot = this.resolvePlanCwd();
        if (planRoot && planRoot !== workspaceRoot) {
          candidates.push(path.join(planRoot, filePath));
        }
      }

      const fullPath = candidates.find((candidate) => fs.existsSync(candidate)) ?? candidates[0];
      if (!fullPath) {
        return;
      }

      const document = await vscode.workspace.openTextDocument(fullPath);
      await vscode.window.showTextDocument(document);
    } catch (error) {
      console.error('[UnifiedViewProvider] Failed to open file:', filePath, error);
    }
  }

  private resolvePlanPath(session: PlanSession): string | null {
    const planPath = session.planPath?.trim();
    if (planPath) {
      return planPath;
    }
    return null;
  }

  private startRun(
    session: PlanSession,
    commandType: RunCommandType,
    issueNumber?: string,
    refineIssueNumber?: number,
    promptOverride?: string,
    runId?: string,
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
    if (commandType === 'refine' && this.runner.isRunning(session.id, 'refine')) {
      if (runId) {
        this.store.updateRefineRunStatus(session.id, runId, 'error');
        this.store.appendRefineRunLogs(session.id, runId, ['Refinement already running.']);
        const updated = this.store.getSession(session.id);
        if (updated) {
          this.postSessionUpdate(updated.id, updated);
        }
      }
      return;
    }

    const cwd = this.resolvePlanCwd();
    if (!cwd) {
      if (commandType === 'impl') {
        this.appendSystemLog(session.id, 'Missing workspace or trees/main path.', false, commandType);
        this.store.updateSession(session.id, { implStatus: 'error', phase: 'completed' });
      } else if (commandType === 'refine') {
        if (runId) {
          this.store.updateRefineRunStatus(session.id, runId, 'error');
          this.appendRefineLines(session.id, runId, ['Missing workspace or trees/main path.']);
        } else {
          this.appendSystemLog(session.id, 'Missing workspace or trees/main path.', false, 'plan');
        }
        this.store.updateSession(session.id, { phase: 'plan-completed' });
      } else {
        this.appendSystemLog(session.id, 'Missing workspace or trees/main path.', false, commandType);
        this.store.updateSession(session.id, { status: 'error', phase: 'plan-completed' });
      }
      const updated = this.store.getSession(session.id);
      if (updated) {
        this.postSessionUpdate(updated.id, updated);
      }
      this.syncActionButtons(session.id);
      return;
    }

    if (commandType === 'plan') {
      this.ensurePlanWidgets(session.id);
      this.store.updateSession(session.id, {
        implStatus: 'idle',
        implCollapsed: false,
        phase: 'planning',
      });
    } else if (commandType === 'refine') {
      this.store.updateSession(session.id, {
        issueNumber: typeof refineIssueNumber === 'number' ? refineIssueNumber.toString() : session.issueNumber,
        phase: 'refining',
      });
    } else {
      this.ensureImplWidgets(session.id);
      const resolvedIssueNumber = issueNumber ?? session.issueNumber;
      this.store.updateSession(session.id, {
        issueNumber: resolvedIssueNumber,
        issueState: resolvedIssueNumber === session.issueNumber ? session.issueState : undefined,
        implStatus: 'idle',
        implCollapsed: false,
        phase: 'implementing',
      });
    }
    const prepped = this.store.getSession(session.id);
    if (prepped) {
      this.postSessionUpdate(prepped.id, prepped);
    }
    this.syncActionButtons(session.id);

    const started = this.runner.run(
      {
        sessionId: session.id,
        command: commandType,
        prompt:
          commandType === 'plan' ? session.prompt :
          commandType === 'refine' ? (promptOverride ?? '') :
          undefined,
        issueNumber: commandType === 'impl' ? issueNumber : undefined,
        cwd,
        refineIssueNumber: commandType === 'refine' ? refineIssueNumber : undefined,
        runId,
      },
      (event) => this.handleRunEvent(event),
    );

    if (!started) {
      if (commandType === 'impl') {
        this.appendSystemLog(session.id, 'Unable to start session.', false, commandType);
        this.store.updateSession(session.id, { implStatus: 'error', phase: 'completed' });
      } else if (commandType === 'refine') {
        if (runId) {
          this.store.updateRefineRunStatus(session.id, runId, 'error');
          this.appendRefineLines(session.id, runId, ['Unable to start refinement.']);
        } else {
          this.appendSystemLog(session.id, 'Unable to start refinement.', false, 'plan');
        }
        this.store.updateSession(session.id, { phase: 'plan-completed' });
      } else {
        this.appendSystemLog(session.id, 'Unable to start session.', false, commandType);
        this.store.updateSession(session.id, { status: 'error', phase: 'plan-completed' });
      }
      const updated = this.store.getSession(session.id);
      if (updated) {
        this.postSessionUpdate(updated.id, updated);
      }
      this.syncActionButtons(session.id);
    }
  }

  private handleRunEvent(event: RunEvent): void {
    const session = this.store.getSession(event.sessionId);
    if (!session) {
      return;
    }

    const isImpl = event.commandType === 'impl';
    const isRefine = event.commandType === 'refine';
    const runId = (event.runId ?? '').trim();

    switch (event.type) {
      case 'start': {
        if (isRefine && runId) {
          this.store.updateRefineRunStatus(event.sessionId, runId, 'running');
          this.appendRefineLines(event.sessionId, runId, [`> ${event.command}`]);
        } else if (isImpl) {
          this.appendImplLines(event.sessionId, [`> ${event.command}`]);
        } else {
          this.appendPlanLines(event.sessionId, [`> ${event.command}`]);
        }

        const update: Partial<PlanSession> = isImpl
          ? { implStatus: 'running', phase: 'implementing' }
          : isRefine
          ? { phase: 'refining' }
          : { status: 'running', command: event.command, phase: 'planning' };
        const updated = this.store.updateSession(event.sessionId, update);
        if (updated) {
          this.postSessionUpdate(updated.id, updated);
        }
        this.syncActionButtons(event.sessionId);
        this.postRunEvent(event);
        return;
      }
      case 'stdout': {
        if (isImpl) {
          this.appendImplLines(event.sessionId, [event.line]);
          this.capturePrUrl(event.sessionId, event.line);
        } else if (isRefine) {
          if (runId) {
            this.appendRefineLines(event.sessionId, runId, [event.line]);
          }
          this.capturePlanPath(event.sessionId, event.line);
        } else {
          this.appendPlanLines(event.sessionId, [event.line]);
          this.captureIssueNumber(event.sessionId, event.line);
          this.capturePlanPath(event.sessionId, event.line);
        }
        this.postRunEvent(event);
        return;
      }
      case 'stderr': {
        const storedLine = `stderr: ${event.line}`;
        if (isImpl) {
          this.appendImplLines(event.sessionId, [storedLine]);
          this.capturePrUrl(event.sessionId, event.line);
        } else if (isRefine) {
          if (runId) {
            this.appendRefineLines(event.sessionId, runId, [storedLine]);
          }
          this.capturePlanPath(event.sessionId, event.line);
        } else {
          this.appendPlanLines(event.sessionId, [storedLine]);
          this.captureIssueNumber(event.sessionId, event.line);
          this.capturePlanPath(event.sessionId, event.line);
        }
        this.postRunEvent(event);
        return;
      }
      case 'exit': {
        const status = event.code === 0 ? 'success' : 'error';
        const refinePhase: PlanSessionPhase =
          session.implStatus === 'success' || session.implStatus === 'error'
            ? 'completed'
            : 'plan-completed';
        const update: Partial<PlanSession> = isImpl
          ? { implStatus: status, phase: 'completed' }
          : isRefine
          ? { phase: refinePhase }
          : { status, phase: 'plan-completed' };
        const line = `Exit code: ${event.code ?? 'null'}`;
        if (isImpl) {
          this.appendImplLines(event.sessionId, [line]);
          this.completeProgress(event.sessionId, WIDGET_ROLES.implProgress);
        } else if (isRefine) {
          if (runId) {
            this.store.updateRefineRunStatus(event.sessionId, runId, status);
            this.appendRefineLines(event.sessionId, runId, [line]);
            this.completeProgress(event.sessionId, WIDGET_ROLES.refineProgress, runId);
          }
        } else {
          this.appendPlanLines(event.sessionId, [line]);
          this.completeProgress(event.sessionId, WIDGET_ROLES.planProgress);
        }
        const updated = this.store.updateSession(event.sessionId, update);
        if (updated) {
          this.postSessionUpdate(updated.id, updated);
        }
        this.syncActionButtons(event.sessionId);
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
    runId?: string,
  ): void {
    if (commandType === 'impl') {
      this.appendImplLines(sessionId, [line]);
    } else if (commandType === 'refine') {
      if (runId) {
        this.appendRefineLines(sessionId, runId, [line]);
      } else {
        this.appendPlanLines(sessionId, [line]);
      }
    } else {
      this.appendPlanLines(sessionId, [line]);
    }
    if (broadcast) {
      this.postRunEvent({
        type: 'stdout',
        sessionId,
        commandType,
        line,
        runId,
        timestamp: Date.now(),
      });
    }
  }

  private captureIssueNumber(sessionId: string, line: string): void {
    const issueNumber = this.extractIssueNumber(line);
    if (!issueNumber) {
      return;
    }

    const updated = this.store.updateSession(sessionId, { issueNumber, issueState: undefined });
    if (updated) {
      this.postSessionUpdate(updated.id, updated);
    }
    this.syncActionButtons(sessionId);
  }

  private async refreshIssueStates(): Promise<void> {
    if (!this.view || !this.view.visible) {
      return;
    }

    const sessions = this.store.getPlanState().sessions;
    const withIssues = sessions.filter((session) => Boolean(session.issueNumber?.trim()));
    if (withIssues.length === 0) {
      return;
    }

    await Promise.all(
      withIssues.map(async (session) => {
        const issueNumber = session.issueNumber?.trim();
        if (!issueNumber) {
          return;
        }
        const issueState = await this.checkIssueState(issueNumber);
        if (issueState === session.issueState) {
          return;
        }
        const updated = this.store.updateSession(session.id, { issueState });
        if (updated) {
          this.postSessionUpdate(updated.id, updated);
        }
        this.syncActionButtons(session.id);
      }),
    );
  }

  private async checkIssueState(issueNumber: string): Promise<'open' | 'closed' | 'unknown'> {
    const cwd = this.resolvePlanCwd();
    if (!cwd) {
      return 'unknown';
    }

    try {
      const { stdout } = await execFileAsync(
        'gh',
        ['issue', 'view', issueNumber, '--json', 'state', '--jq', '.state'],
        { cwd },
      );
      const state = stdout.trim().toLowerCase();
      if (state === 'closed') {
        return 'closed';
      }
      if (state === 'open') {
        return 'open';
      }
      return 'unknown';
    } catch (error) {
      this.output.appendLine(
        `[unifiedView] issue state check failed for #${issueNumber}: ${String(error)}`,
      );
      return 'unknown';
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

  private capturePlanPath(sessionId: string, line: string): void {
    const planPath = this.extractPlanPath(line);
    if (!planPath) {
      return;
    }

    const current = this.store.getSession(sessionId);
    if (current?.planPath === planPath) {
      return;
    }

    const updated = this.store.updateSession(sessionId, { planPath });
    if (updated) {
      this.postSessionUpdate(updated.id, updated);
    }
    this.syncActionButtons(sessionId);
  }

  private extractPlanPath(line: string): string | null {
    const localMatch = /See the full plan locally at:\s+(.+)$/.exec(line);
    if (localMatch) {
      return localMatch[1].trim();
    }

    const dumpMatch = /consensus dumped to\s+(.+)$/.exec(line);
    if (dumpMatch) {
      return dumpMatch[1].trim();
    }

    return null;
  }

  private capturePrUrl(sessionId: string, line: string): void {
    const prUrl = this.extractPrUrl(line);
    if (!prUrl) {
      return;
    }

    const current = this.store.getSession(sessionId);
    if (current?.prUrl === prUrl) {
      return;
    }

    const updated = this.store.updateSession(sessionId, { prUrl });
    if (updated) {
      this.postSessionUpdate(updated.id, updated);
    }
    this.syncActionButtons(sessionId);
  }

  private extractPrUrl(line: string): string | null {
    const match = /https:\/\/github\.com\/[^/]+\/[^/]+\/pull\/\d+/.exec(line);
    return match ? match[0] : null;
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

    const sessions = this.store.getPlanState().sessions;
    sessions.forEach((session) => {
      this.syncActionButtons(session.id);
    });

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

  private postWidgetAppend(sessionId: string, widget: WidgetState): void {
    if (!this.view) {
      return;
    }

    const message: WidgetAppendMessage = {
      type: 'widget/append',
      sessionId,
      widget,
    };
    this.view.webview.postMessage(message);
  }

  private postWidgetUpdate(sessionId: string, widgetId: string, update: WidgetUpdateMessage['update']): void {
    if (!this.view) {
      return;
    }

    const message: WidgetUpdateMessage = {
      type: 'widget/update',
      sessionId,
      widgetId,
      update,
    };
    this.view.webview.postMessage(message);
  }

  private findWidgetByRole(session: PlanSession, role: string, type?: WidgetState['type']): WidgetState | undefined {
    if (!Array.isArray(session.widgets)) {
      return undefined;
    }
    return session.widgets.find((widget) => {
      if (type && widget.type !== type) {
        return false;
      }
      return widget.metadata?.role === role;
    });
  }

  private findWidgetByRoleAndRunId(
    session: PlanSession,
    role: string,
    runId: string,
    type?: WidgetState['type'],
  ): WidgetState | undefined {
    if (!Array.isArray(session.widgets)) {
      return undefined;
    }
    return session.widgets.find((widget) => {
      if (type && widget.type !== type) {
        return false;
      }
      return widget.metadata?.role === role && widget.metadata?.runId === runId;
    });
  }

  private ensurePlanWidgets(sessionId: string): void {
    const session = this.store.getSession(sessionId);
    if (!session) {
      return;
    }

    let terminal = this.findWidgetByRole(session, WIDGET_ROLES.planTerminal, 'terminal');
    if (!terminal) {
      terminal = this.store.addWidget(sessionId, {
        type: 'terminal',
        title: 'Plan Console Log',
        content: [],
        metadata: { role: WIDGET_ROLES.planTerminal },
      });
      if (terminal) {
        this.postWidgetAppend(sessionId, terminal);
      }
    }

    if (terminal) {
      const progress = this.findWidgetByRole(session, WIDGET_ROLES.planProgress, 'progress');
      if (!progress) {
        const widget = this.store.addWidget(sessionId, {
          type: 'progress',
          metadata: { role: WIDGET_ROLES.planProgress, terminalId: terminal.id },
        });
        if (widget) {
          this.postWidgetAppend(sessionId, widget);
        }
      }
    }
  }

  private ensureImplWidgets(sessionId: string): void {
    const session = this.store.getSession(sessionId);
    if (!session) {
      return;
    }

    let terminal = this.findWidgetByRole(session, WIDGET_ROLES.implTerminal, 'terminal');
    if (!terminal) {
      terminal = this.store.addWidget(sessionId, {
        type: 'terminal',
        title: 'Implementation Log',
        content: [],
        metadata: { role: WIDGET_ROLES.implTerminal, collapsed: session.implCollapsed ?? false },
      });
      if (terminal) {
        this.postWidgetAppend(sessionId, terminal);
      }
    }

    if (terminal) {
      const progress = this.findWidgetByRole(session, WIDGET_ROLES.implProgress, 'progress');
      if (!progress) {
        const widget = this.store.addWidget(sessionId, {
          type: 'progress',
          metadata: { role: WIDGET_ROLES.implProgress, terminalId: terminal.id },
        });
        if (widget) {
          this.postWidgetAppend(sessionId, widget);
        }
      }
    }
  }

  private ensureRefineWidgets(sessionId: string, runId: string, focus: string): void {
    const session = this.store.getSession(sessionId);
    if (!session) {
      return;
    }

    let terminal = this.findWidgetByRoleAndRunId(session, WIDGET_ROLES.refineTerminal, runId, 'terminal');
    if (!terminal) {
      terminal = this.store.addWidget(sessionId, {
        type: 'terminal',
        title: 'Refinement Log',
        content: [],
        metadata: { role: WIDGET_ROLES.refineTerminal, runId, focus },
      });
      if (terminal) {
        this.postWidgetAppend(sessionId, terminal);
      }
    }

    if (terminal) {
      const progress = this.findWidgetByRoleAndRunId(session, WIDGET_ROLES.refineProgress, runId, 'progress');
      if (!progress) {
        const widget = this.store.addWidget(sessionId, {
          type: 'progress',
          metadata: { role: WIDGET_ROLES.refineProgress, terminalId: terminal.id, runId },
        });
        if (widget) {
          this.postWidgetAppend(sessionId, widget);
        }
      }
    }
  }

  private ensureActionWidget(sessionId: string, session: PlanSession): WidgetState | undefined {
    const existing = this.findWidgetByRole(session, WIDGET_ROLES.actions, 'buttons');
    if (existing) {
      return existing;
    }
    const buttons = this.buildActionButtons(session);
    const widget = this.store.addWidget(sessionId, {
      type: 'buttons',
      metadata: { role: WIDGET_ROLES.actions, buttons },
    });
    if (widget) {
      this.postWidgetAppend(sessionId, widget);
    }
    return widget ?? undefined;
  }

  private buildActionButtons(session: PlanSession): WidgetButton[] {
    const hasPlanPath = Boolean(session.planPath?.trim());
    const planDone = session.status === 'success' || session.status === 'error';
    const planSuccess = session.status === 'success';
    const implRunning = session.implStatus === 'running';
    const implSuccess = session.implStatus === 'success';
    const implError = session.implStatus === 'error';
    const issueClosed = session.issueState === 'closed';
    const isPlanning = session.phase === 'planning';
    const isRefining = session.phase === 'refining';
    const isImplementing = session.phase === 'implementing';

    const buttons: WidgetButton[] = [];

    if (hasPlanPath) {
      buttons.push({
        id: 'view-plan',
        label: 'View Plan',
        action: 'plan/view-plan',
        variant: 'secondary',
        disabled: false,
      });
    }

    const implLabel = implRunning ? 'Running...' : implError ? 'Re-implement' : issueClosed ? 'Closed' : 'Implement';
    const implDisabled = !planSuccess || issueClosed || isPlanning || isRefining || implRunning;
    buttons.push({
      id: 'implement',
      label: implLabel,
      action: 'plan/impl',
      variant: 'primary',
      disabled: implDisabled,
    });

    const refineDisabled = !planDone || isPlanning || isImplementing || session.phase === 'refining';
    buttons.push({
      id: 'refine',
      label: 'Refine',
      action: 'plan/refine',
      variant: 'secondary',
      disabled: refineDisabled,
    });

    if (implSuccess) {
      buttons.push({
        id: 'view-pr',
        label: 'View PR',
        action: 'plan/view-pr',
        variant: 'primary',
        disabled: false,
      });
    }

    return buttons;
  }

  private syncActionButtons(sessionId: string): PlanSession | undefined {
    const session = this.store.getSession(sessionId);
    if (!session) {
      return undefined;
    }

    const actionWidget = this.ensureActionWidget(sessionId, session);
    if (!actionWidget) {
      return session;
    }

    const buttons = this.buildActionButtons(session);
    this.store.updateWidgetMetadata(sessionId, actionWidget.id, { buttons });
    this.postWidgetUpdate(sessionId, actionWidget.id, { type: 'replaceButtons', buttons });
    return this.store.getSession(sessionId) ?? session;
  }

  private appendPlanLines(sessionId: string, lines: string[]): void {
    this.ensurePlanWidgets(sessionId);
    const updated = this.store.appendSessionLogs(sessionId, lines);
    if (!updated) {
      return;
    }
    const terminal = this.findWidgetByRole(updated, WIDGET_ROLES.planTerminal, 'terminal');
    if (terminal) {
      this.postWidgetUpdate(sessionId, terminal.id, { type: 'appendLines', lines });
    }
  }

  private appendImplLines(sessionId: string, lines: string[]): void {
    this.ensureImplWidgets(sessionId);
    const updated = this.store.appendImplLogs(sessionId, lines);
    if (!updated) {
      return;
    }
    const terminal = this.findWidgetByRole(updated, WIDGET_ROLES.implTerminal, 'terminal');
    if (terminal) {
      this.store.appendWidgetLines(sessionId, terminal.id, lines);
      this.postWidgetUpdate(sessionId, terminal.id, { type: 'appendLines', lines });
    }
  }

  private appendRefineLines(sessionId: string, runId: string, lines: string[]): void {
    const session = this.store.getSession(sessionId);
    const focus = session?.refineRuns.find((run) => run.id === runId)?.prompt ?? 'Refinement';
    this.ensureRefineWidgets(sessionId, runId, focus);
    const updated = this.store.appendRefineRunLogs(sessionId, runId, lines);
    if (!updated) {
      return;
    }
    const terminal = this.findWidgetByRoleAndRunId(updated, WIDGET_ROLES.refineTerminal, runId, 'terminal');
    if (terminal) {
      this.store.appendWidgetLines(sessionId, terminal.id, lines);
      this.postWidgetUpdate(sessionId, terminal.id, { type: 'appendLines', lines });
    }
  }

  private completeProgress(sessionId: string, role: string, runId?: string): void {
    const session = this.store.getSession(sessionId);
    if (!session) {
      return;
    }
    const widget = runId
      ? this.findWidgetByRoleAndRunId(session, role, runId, 'progress')
      : this.findWidgetByRole(session, role, 'progress');
    if (!widget) {
      return;
    }
    this.postWidgetUpdate(sessionId, widget.id, { type: 'complete' });
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
    const planScriptPath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'plan', 'out', 'index.js');
    const planStylePath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'plan', 'styles.css');
    const worktreeScriptPath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'worktree', 'out', 'index.js');
    const worktreeStylePath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'worktree', 'styles.css');
    const settingsScriptPath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'settings', 'out', 'index.js');
    const settingsStylePath = vscode.Uri.joinPath(this.extensionUri, 'webview', 'settings', 'styles.css');
    const planScriptUri = webview.asWebviewUri(planScriptPath);
    const planStyleUri = webview.asWebviewUri(planStylePath);
    const worktreeScriptUri = webview.asWebviewUri(worktreeScriptPath);
    const worktreeStyleUri = webview.asWebviewUri(worktreeStylePath);
    const settingsScriptUri = webview.asWebviewUri(settingsScriptPath);
    const settingsStyleUri = webview.asWebviewUri(settingsStylePath);
    const nonce = this.getNonce();
    const planScriptFsPath = path.join(this.extensionUri.fsPath, 'webview', 'plan', 'out', 'index.js');
    const planStyleFsPath = path.join(this.extensionUri.fsPath, 'webview', 'plan', 'styles.css');
    const worktreeScriptFsPath = path.join(this.extensionUri.fsPath, 'webview', 'worktree', 'out', 'index.js');
    const worktreeStyleFsPath = path.join(this.extensionUri.fsPath, 'webview', 'worktree', 'styles.css');
    const settingsScriptFsPath = path.join(this.extensionUri.fsPath, 'webview', 'settings', 'out', 'index.js');
    const settingsStyleFsPath = path.join(this.extensionUri.fsPath, 'webview', 'settings', 'styles.css');
    const hasPlanScript = fs.existsSync(planScriptFsPath);
    const hasPlanStyle = fs.existsSync(planStyleFsPath);
    const hasWorktreeScript = fs.existsSync(worktreeScriptFsPath);
    const hasWorktreeStyle = fs.existsSync(worktreeStyleFsPath);
    const hasSettingsScript = fs.existsSync(settingsScriptFsPath);
    const hasSettingsStyle = fs.existsSync(settingsStyleFsPath);
    const hasPlanAssets = hasPlanScript && hasPlanStyle;
    const hasWorktreeAssets = hasWorktreeScript && hasWorktreeStyle;
    const hasSettingsAssets = hasSettingsScript && hasSettingsStyle;

    if (!hasPlanAssets) {
      this.output.appendLine(
        `[unifiedView] missing plan webview assets: script=${hasPlanScript ? 'ok' : planScriptFsPath} style=${hasPlanStyle ? 'ok' : planStyleFsPath}`,
      );
    }
    if (!hasWorktreeAssets) {
      this.output.appendLine(
        `[unifiedView] missing worktree webview assets: script=${hasWorktreeScript ? 'ok' : worktreeScriptFsPath} style=${hasWorktreeStyle ? 'ok' : worktreeStyleFsPath}`,
      );
    }
    if (!hasSettingsAssets) {
      this.output.appendLine(
        `[unifiedView] missing settings webview assets: script=${hasSettingsScript ? 'ok' : settingsScriptFsPath} style=${hasSettingsStyle ? 'ok' : settingsStyleFsPath}`,
      );
    }

    let initialState = '{}';
    try {
      initialState = JSON.stringify(this.store.getAppState())
        .replace(/</g, '\\u003c')
        .replace(/\u2028/g, '\\u2028')
        .replace(/\u2029/g, '\\u2029');
    } catch (error) {
      this.output.appendLine(`[unifiedView] failed to serialize initial state: ${String(error)}`);
    }

    const planSkeleton = this.buildPlanSkeleton(hasPlanAssets);
    const worktreeSkeleton = this.buildPlaceholderSkeleton('Worktree', 'worktree-skeleton-status', hasWorktreeAssets);
    const settingsSkeleton = this.buildPlaceholderSkeleton('Settings', 'settings-skeleton-status', hasSettingsAssets);

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} https: data:; font-src ${webview.cspSource}; style-src ${webview.cspSource} 'unsafe-inline'; script-src ${webview.cspSource} 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="${planStyleUri}" rel="stylesheet" />
  <link href="${worktreeStyleUri}" rel="stylesheet" />
  <link href="${settingsStyleUri}" rel="stylesheet" />
  <style>
    .unified-view {
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }

    .unified-tabs {
      display: flex;
      gap: 8px;
      padding: 12px 16px 0;
      position: sticky;
      top: 0;
      z-index: 2;
      background: var(--bg-start);
    }

    .unified-tab {
      border: 1px solid var(--border);
      border-bottom: none;
      background: var(--panel);
      color: #928779;
      padding: 8px 12px;
      border-radius: 8px 8px 0 0;
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      box-shadow: none;
    }

    .unified-tab.is-active {
      color: var(--text);
      background: var(--panel);
      box-shadow: var(--shadow);
    }

    .unified-panel {
      display: none;
    }

    .unified-panel.is-active {
      display: block;
    }
  </style>
  <title>Agentize</title>
</head>
<body>
  <div class="unified-view">
    <div class="unified-tabs" role="tablist" aria-label="Agentize panels">
      <button id="tab-plan" class="unified-tab is-active" type="button" role="tab" aria-selected="true" aria-controls="panel-plan" data-tab="plan">Plan</button>
      <button id="tab-worktree" class="unified-tab" type="button" role="tab" aria-selected="false" aria-controls="panel-worktree" data-tab="worktree">Worktree</button>
      <button id="tab-settings" class="unified-tab" type="button" role="tab" aria-selected="false" aria-controls="panel-settings" data-tab="settings">Settings</button>
    </div>
    <section id="panel-plan" class="unified-panel is-active" role="tabpanel" aria-labelledby="tab-plan" data-panel="plan">
      <div id="plan-root" class="plan-root">
        ${planSkeleton}
      </div>
    </section>
    <section id="panel-worktree" class="unified-panel" role="tabpanel" aria-labelledby="tab-worktree" data-panel="worktree">
      <div id="worktree-root" class="worktree-root">
        ${worktreeSkeleton}
      </div>
    </section>
    <section id="panel-settings" class="unified-panel" role="tabpanel" aria-labelledby="tab-settings" data-panel="settings">
      <div id="settings-root" class="settings-root">
        ${settingsSkeleton}
      </div>
    </section>
  </div>
  <script nonce="${nonce}">window.__INITIAL_STATE__ = ${initialState};</script>
  <script nonce="${nonce}">
    (function() {
      const tabs = Array.from(document.querySelectorAll('.unified-tab'));
      const panels = Array.from(document.querySelectorAll('.unified-panel'));

      const setActive = (tabId) => {
        tabs.forEach((tab) => {
          const isActive = tab.dataset.tab === tabId;
          tab.classList.toggle('is-active', isActive);
          tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
        });
        panels.forEach((panel) => {
          panel.classList.toggle('is-active', panel.dataset.panel === tabId);
        });
      };

      tabs.forEach((tab) => {
        tab.addEventListener('click', () => {
          if (tab.dataset.tab) {
            setActive(tab.dataset.tab);
          }
        });
      });
    })();
  </script>
  <script nonce="${nonce}">
    (function() {
      const loadPanelScript = (statusId, scriptUri) => {
        const statusEl = document.getElementById(statusId);
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
        script.src = scriptUri;
        script.type = 'module';
        script.nonce = "${nonce}";
        script.onload = () => {
          setStatusIfUnchanged('Webview script loaded; waiting for init...');
          setTimeout(() => {
            setStatusIfUnchanged('Webview script loaded but did not initialize.');
          }, 2000);
        };
        script.onerror = () => setStatus('Failed to load webview script.');
        document.body.appendChild(script);
      };

      loadPanelScript('plan-skeleton-status', "${planScriptUri}");
      loadPanelScript('worktree-skeleton-status', "${worktreeScriptUri}");
      loadPanelScript('settings-skeleton-status', "${settingsScriptUri}");
    })();
  </script>
</body>
</html>`;
  }

  private buildPlanSkeleton(hasAssets: boolean): string {
    const templatePath = path.join(this.extensionUri.fsPath, 'webview', 'plan', 'skeleton.html');
    const fallbackTemplate = [
      '<div class="plan-skeleton">',
      '  <div class="plan-skeleton-title">Agentize</div>',
      '  <div id="plan-skeleton-status" class="plan-skeleton-subtitle">Loading webview UI...</div>',
      `  ${UnifiedViewProvider.skeletonPlaceholder}`,
      '</div>',
    ].join('\n');
    const errorHtml = hasAssets
      ? ''
      : '<div class="plan-skeleton-error">Webview assets missing. Run <code>make vscode-plugin</code> and reload VS Code.</div>';

    let template = fallbackTemplate;
    try {
      template = fs.readFileSync(templatePath, 'utf8');
    } catch (error) {
      this.output.appendLine(`[unifiedView] failed to read skeleton template (${templatePath}): ${String(error)}`);
    }

    if (template.includes(UnifiedViewProvider.skeletonPlaceholder)) {
      return template.split(UnifiedViewProvider.skeletonPlaceholder).join(errorHtml);
    }

    return errorHtml ? `${template}\n${errorHtml}` : template;
  }

  private buildPlaceholderSkeleton(title: string, statusId: string, hasAssets: boolean): string {
    const errorHtml = hasAssets
      ? ''
      : '<div class="plan-skeleton-error">Webview assets missing. Run <code>make vscode-plugin</code> and reload VS Code.</div>';

    return [
      '<div class="plan-skeleton">',
      `  <div class="plan-skeleton-title">${title}</div>`,
      `  <div id="${statusId}" class="plan-skeleton-subtitle">Loading webview UI...</div>`,
      errorHtml ? `  ${errorHtml}` : '',
      '</div>',
    ]
      .filter(Boolean)
      .join('\n');
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

export const UnifiedViewProviderMessages = {
  incoming: [
    'webview/ready',
    'plan/new',
    'plan/run',
    'plan/refine',
    'plan/impl',
    'plan/toggleCollapse',
    'plan/toggleImplCollapse',
    'plan/delete',
    'plan/updateDraft',
    'plan/view-plan',
    'plan/view-pr',
    'link/openExternal',
    'link/openFile',
  ],
  outgoing: ['state/replace', 'plan/sessionUpdated', 'plan/runEvent', 'widget/append', 'widget/update'],
};
