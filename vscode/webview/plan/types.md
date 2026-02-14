# types.ts

Message payload definitions for the Plan webview.

## External Interface

### PlanImplMessage
- `type`: `plan/impl`.
- `sessionId`: Plan session identifier.
- `issueNumber`: issue number to pass to `lol impl`.

### PlanToggleImplCollapseMessage
- `type`: `plan/toggleImplCollapse`.
- `sessionId`: Plan session identifier.

## Internal Helpers

No internal helpers; this module only exports types.
