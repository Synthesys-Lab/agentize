export interface PlanImplMessage {
  type: 'plan/impl';
  sessionId: string;
  issueNumber: string;
}

export type WidgetType = 'text' | 'terminal' | 'progress' | 'buttons' | 'input' | 'status';

export interface WidgetButton {
  id: string;
  label: string;
  action: string;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  disabled?: boolean;
}

export interface WidgetState {
  id: string;
  type: WidgetType;
  title?: string;
  content?: string[];
  metadata?: Record<string, unknown>;
  createdAt: number;
}

export interface WidgetAppendMessage {
  type: 'widget/append';
  sessionId: string;
  widget: WidgetState;
}

export type WidgetUpdatePayload =
  | { type: 'appendLines'; lines: string[] }
  | { type: 'replaceButtons'; buttons: WidgetButton[] }
  | { type: 'complete' }
  | { type: 'metadata'; metadata: Record<string, unknown> };

export interface WidgetUpdateMessage {
  type: 'widget/update';
  sessionId: string;
  widgetId: string;
  update: WidgetUpdatePayload;
}
