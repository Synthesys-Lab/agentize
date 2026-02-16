import * as vscode from 'vscode';
import { PlanRunner } from './runner/planRunner';
import { SessionStore } from './state/sessionStore';
import { UnifiedViewProvider } from './view/unifiedViewProvider';

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel('Agentize Plan');
  output.appendLine('[activate] Agentize Plan extension activating');
  const store = new SessionStore(context.workspaceState);
  const runner = new PlanRunner();
  const provider = new UnifiedViewProvider(context.extensionUri, store, runner, output);

  context.subscriptions.push(
    output,
    vscode.window.registerWebviewViewProvider(UnifiedViewProvider.viewType, provider),
  );
}

export function deactivate(): void {
  // No-op for now; reserved for future cleanup.
}
