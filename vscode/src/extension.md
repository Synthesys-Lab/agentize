# extension.ts

Extension entry point that wires the Plan Activity Bar webview provider into VS Code.

## External Interface

### activate(context: vscode.ExtensionContext)
Registers the Plan webview view provider, instantiates state and runner services, and
exposes the Activity Bar view to the user.

### deactivate()
Reserved for cleanup when the extension is deactivated.

## Internal Helpers

### createPlanProvider()
Constructs the PlanViewProvider with the shared SessionStore and PlanRunner so the
extension entry point stays minimal and composable.
