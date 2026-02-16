# extension.ts

Extension entry point that wires the unified Activity Bar webview provider into VS Code.

## External Interface

### activate(context: vscode.ExtensionContext)
Registers the unified webview provider, instantiates state and runner services, and
exposes the tabbed Activity Bar view to the user.

The extension also creates an OutputChannel used for operational diagnostics. This keeps
webview failures debuggable without relying on webview devtools.

### deactivate()
Reserved for cleanup when the extension is deactivated.
