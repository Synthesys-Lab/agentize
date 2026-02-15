import * as vscode from 'vscode';
import { PlanRunner } from './runner/planRunner';
import { SessionStore } from './state/sessionStore';
import { PlanViewProvider } from './view/planViewProvider';
import { SettingsViewProvider } from './view/settingsViewProvider';
import { WorktreeViewProvider } from './view/worktreeViewProvider';

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel('Agentize Plan');
  output.appendLine('[activate] Agentize Plan extension activating');
  const store = new SessionStore(context.workspaceState);
  const runner = new PlanRunner();
  const provider = new PlanViewProvider(context.extensionUri, store, runner, output);
  const worktreeProvider = new WorktreeViewProvider(context.extensionUri);
  const settingsProvider = new SettingsViewProvider(context.extensionUri);

  context.subscriptions.push(
    output,
    vscode.window.registerWebviewViewProvider(PlanViewProvider.viewType, provider),
    vscode.window.registerWebviewViewProvider(WorktreeViewProvider.viewType, worktreeProvider),
    vscode.window.registerWebviewViewProvider(SettingsViewProvider.viewType, settingsProvider),
  );
}

export function deactivate(): void {
  // No-op for now; reserved for future cleanup.
}
