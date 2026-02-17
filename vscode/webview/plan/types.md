# types.ts

Message payload definitions for the Plan webview.

## External Interface

### PlanImplMessage
- `type`: `plan/impl`.
- `sessionId`: Plan session identifier.
- `issueNumber`: issue number to pass to `lol impl`.

### WidgetAppendMessage
- `type`: `widget/append`.
- `sessionId`: session identifier owning the widget.
- `widgetType`: widget type discriminator.
- `widgetId`: stable widget identifier for updates.
- `config`: widget-specific configuration payload.

### WidgetUpdateMessage
- `type`: `widget/update`.
- `sessionId`: session identifier owning the widget.
- `widgetId`: widget identifier to update.
- `update`: widget-specific update payload.

## Internal Helpers

No internal helpers; this module only exports types.
