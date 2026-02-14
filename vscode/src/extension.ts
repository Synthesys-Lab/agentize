import * as vscode from 'vscode';
import { PlanRunner } from './runner/planRunner';
import { SessionStore } from './state/sessionStore';
import { PlanViewProvider } from './view/planViewProvider';

export function activate(context: vscode.ExtensionContext): void {
  const store = new SessionStore(context.workspaceState);
  const runner = new PlanRunner();
  const provider = new PlanViewProvider(context.extensionUri, store, runner);

  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider(PlanViewProvider.viewType, provider),
  );
}

export function deactivate(): void {
  // No-op for now; reserved for future cleanup.
}
