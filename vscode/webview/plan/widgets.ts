import { completeAllStepsIn, renderLinks, renderStepIndicatorsFrom, updateStepStatesIn } from './utils.js';
import type { StepState } from './utils.js';

export type WidgetType = 'text' | 'terminal' | 'progress' | 'buttons' | 'input' | 'status';

export interface WidgetHandle {
  id: string;
  type: WidgetType;
  element: HTMLElement;
}

export interface TerminalHandle extends WidgetHandle {
  type: 'terminal';
  title: string;
  appendLine: (line: string, stream?: string) => void;
  setCollapsed: (collapsed: boolean) => void;
  setLines: (lines: string[]) => void;
  onLine?: (line: string, stream?: string) => void;
}

export interface ProgressHandle extends WidgetHandle {
  type: 'progress';
  replay: (lines: string[]) => void;
  complete: () => void;
}

export type ButtonVariant = 'primary' | 'danger' | 'ghost';

export interface ButtonConfig {
  id: string;
  label: string;
  variant?: ButtonVariant;
  disabled?: boolean;
  onClick?: () => void;
}

export interface ButtonsHandle extends WidgetHandle {
  type: 'buttons';
  buttons: Map<string, HTMLButtonElement>;
}

export interface InputWidgetConfig {
  label?: string;
  placeholder?: string;
  hint?: string;
  onSubmit: (value: string) => void;
  onCancel?: () => void;
}

export interface InputHandle extends WidgetHandle {
  type: 'input';
  textarea: HTMLTextAreaElement;
}

export interface TerminalWidgetOptions {
  widgetId?: string;
  collapsed?: boolean;
  maxLines?: number;
  onToggle?: (collapsed: boolean) => void;
  onLinkClick?: (event: Event) => void;
  hidden?: boolean;
}

export interface WidgetAppendOptions {
  widgetId?: string;
  hidden?: boolean;
}

const sessionContainers = new Map<string, HTMLElement>();
const sessionWidgets = new Map<string, Map<string, WidgetHandle>>();

const createWidgetId = (type: string): string => {
  return `${type}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
};

const getWidgetMap = (sessionId: string): Map<string, WidgetHandle> => {
  const existing = sessionWidgets.get(sessionId);
  if (existing) {
    return existing;
  }
  const created = new Map<string, WidgetHandle>();
  sessionWidgets.set(sessionId, created);
  return created;
};

export const registerSessionContainer = (sessionId: string, container: HTMLElement): void => {
  sessionContainers.set(sessionId, container);
};

export const getWidgetHandle = (sessionId: string, widgetId: string): WidgetHandle | undefined => {
  return getWidgetMap(sessionId).get(widgetId);
};

export const clearWidgets = (sessionId: string): void => {
  const container = sessionContainers.get(sessionId);
  if (container) {
    container.innerHTML = '';
  }
  sessionWidgets.delete(sessionId);
};

const getWidgetContainer = (sessionId: string): HTMLElement | undefined => {
  const known = sessionContainers.get(sessionId);
  if (known) {
    return known;
  }
  const fallback = document.querySelector<HTMLElement>(`.session[data-session-id="${sessionId}"] .session-body`);
  if (fallback) {
    sessionContainers.set(sessionId, fallback);
    return fallback;
  }
  return undefined;
};

const registerWidget = (sessionId: string, handle: WidgetHandle): void => {
  const map = getWidgetMap(sessionId);
  const existing = map.get(handle.id);
  if (existing && existing.element !== handle.element) {
    existing.element.remove();
  }
  map.set(handle.id, handle);
};

export const removeWidget = (sessionId: string, widgetId: string): void => {
  const map = getWidgetMap(sessionId);
  const handle = map.get(widgetId);
  if (handle) {
    handle.element.remove();
    map.delete(widgetId);
  }
};

export const appendPlainText = (sessionId: string, text: string, options: WidgetAppendOptions = {}): WidgetHandle | undefined => {
  const container = getWidgetContainer(sessionId);
  if (!container) {
    return undefined;
  }

  const widget = document.createElement('div');
  widget.className = 'widget widget-text';
  if (options.hidden) {
    widget.classList.add('hidden');
  }
  widget.textContent = text;

  const id = options.widgetId ?? createWidgetId('text');
  container.appendChild(widget);

  const handle: WidgetHandle = { id, type: 'text', element: widget };
  registerWidget(sessionId, handle);
  return handle;
};

export const appendStatusBadge = (sessionId: string, text: string, options: WidgetAppendOptions = {}): WidgetHandle | undefined => {
  const container = getWidgetContainer(sessionId);
  if (!container) {
    return undefined;
  }

  const widget = document.createElement('div');
  widget.className = 'widget widget-status';
  if (options.hidden) {
    widget.classList.add('hidden');
  }
  widget.textContent = text;

  const id = options.widgetId ?? createWidgetId('status');
  container.appendChild(widget);

  const handle: WidgetHandle = { id, type: 'status', element: widget };
  registerWidget(sessionId, handle);
  return handle;
};

export const appendTerminalBox = (
  sessionId: string,
  title: string,
  options: TerminalWidgetOptions = {},
): TerminalHandle | undefined => {
  const container = getWidgetContainer(sessionId);
  if (!container) {
    return undefined;
  }

  const widget = document.createElement('div');
  widget.className = 'widget widget-terminal';
  if (options.hidden) {
    widget.classList.add('hidden');
  }

  const header = document.createElement('div');
  header.className = 'terminal-header';

  const toggle = document.createElement('button');
  toggle.className = 'terminal-toggle';
  toggle.textContent = '[▼]';

  const titleEl = document.createElement('span');
  titleEl.className = 'terminal-title';
  titleEl.textContent = title;

  header.appendChild(toggle);
  header.appendChild(titleEl);

  const body = document.createElement('div');
  body.className = 'terminal-body';

  const pre = document.createElement('pre');
  pre.className = 'logs terminal-logs';

  if (options.onLinkClick) {
    pre.addEventListener('click', options.onLinkClick);
  }

  body.appendChild(pre);
  widget.appendChild(header);
  widget.appendChild(body);

  const id = options.widgetId ?? createWidgetId('terminal');
  container.appendChild(widget);

  let buffer: string[] = [];
  const maxLines = options.maxLines ?? 1000;

  const renderBuffer = () => {
    pre.innerHTML = buffer.map((line) => renderLinks(line)).join('\n');
    if (!body.classList.contains('collapsed')) {
      body.scrollTop = body.scrollHeight;
    }
  };

  const handle: TerminalHandle = {
    id,
    type: 'terminal',
    title,
    element: widget,
    appendLine: (line: string, stream?: string) => {
      const prefix = stream === 'stderr' ? 'stderr: ' : '';
      const fullLine = `${prefix}${line}`;
      buffer = [...buffer, fullLine];
      if (buffer.length > maxLines) {
        buffer = buffer.slice(buffer.length - maxLines);
      }
      renderBuffer();
      if (handle.onLine) {
        handle.onLine(line, stream);
      }
    },
    setCollapsed: (collapsed: boolean) => {
      body.classList.toggle('collapsed', collapsed);
      toggle.textContent = collapsed ? '[▶]' : '[▼]';
    },
    setLines: (lines: string[]) => {
      buffer = lines.slice(Math.max(0, lines.length - maxLines));
      renderBuffer();
    },
  };

  toggle.addEventListener('click', () => {
    const collapsed = body.classList.toggle('collapsed');
    toggle.textContent = collapsed ? '[▶]' : '[▼]';
    if (options.onToggle) {
      options.onToggle(collapsed);
    }
  });

  if (typeof options.collapsed === 'boolean') {
    handle.setCollapsed(options.collapsed);
  }

  registerWidget(sessionId, handle);
  return handle;
};

export const appendProgressWidget = (
  sessionId: string,
  terminalHandle: TerminalHandle,
  options: WidgetAppendOptions = {},
): ProgressHandle | undefined => {
  const container = getWidgetContainer(sessionId);
  if (!container) {
    return undefined;
  }

  const widget = document.createElement('div');
  widget.className = 'widget widget-progress';
  if (options.hidden) {
    widget.classList.add('hidden');
  }

  const id = options.widgetId ?? createWidgetId('progress');
  container.appendChild(widget);

  const stepMap = new Map<string, StepState[]>();
  const key = id;
  const isExitLine = (line: string): boolean => /^Exit code:\s/.test(line.trim());

  const render = () => {
    const indicators = renderStepIndicatorsFrom(stepMap, key, 'step-indicators');
    widget.innerHTML = '';
    while (indicators.firstChild) {
      widget.appendChild(indicators.firstChild);
    }
    widget.classList.toggle('hidden', widget.childElementCount === 0);
  };

  const handleLine = (line: string, stream?: string) => {
    if (isExitLine(line)) {
      completeAllStepsIn(stepMap, key);
      render();
      return;
    }
    if (stream !== 'stderr') {
      return;
    }
    if (updateStepStatesIn(stepMap, key, line)) {
      render();
    }
  };

  const previous = terminalHandle.onLine;
  terminalHandle.onLine = (line: string, stream?: string) => {
    if (previous) {
      previous(line, stream);
    }
    handleLine(line, stream);
  };

  const replay = (lines: string[]) => {
    stepMap.set(key, []);
    let sawExit = false;
    for (const entry of lines) {
      const normalized = entry.startsWith('stderr: ') ? entry.slice('stderr: '.length) : entry;
      if (entry.startsWith('stderr: ')) {
        updateStepStatesIn(stepMap, key, normalized);
      }
      if (isExitLine(normalized)) {
        sawExit = true;
      }
    }
    if (sawExit) {
      completeAllStepsIn(stepMap, key);
    }
    render();
  };

  const complete = () => {
    completeAllStepsIn(stepMap, key);
    render();
  };

  const handle: ProgressHandle = {
    id,
    type: 'progress',
    element: widget,
    replay,
    complete,
  };

  registerWidget(sessionId, handle);
  return handle;
};

export const appendButtons = (
  sessionId: string,
  buttons: ButtonConfig[],
  options: WidgetAppendOptions = {},
): ButtonsHandle | undefined => {
  const container = getWidgetContainer(sessionId);
  if (!container) {
    return undefined;
  }

  const widget = document.createElement('div');
  widget.className = 'widget widget-buttons';
  if (options.hidden) {
    widget.classList.add('hidden');
  }

  const buttonMap = new Map<string, HTMLButtonElement>();
  renderButtons(widget, buttons, buttonMap);

  const id = options.widgetId ?? createWidgetId('buttons');
  container.appendChild(widget);

  const handle: ButtonsHandle = { id, type: 'buttons', element: widget, buttons: buttonMap };
  registerWidget(sessionId, handle);
  return handle;
};

export const replaceButtons = (handle: ButtonsHandle, buttons: ButtonConfig[]): void => {
  renderButtons(handle.element, buttons, handle.buttons);
};

export const updateButtonState = (
  sessionId: string,
  buttonId: string,
  state: { label?: string; disabled?: boolean; hidden?: boolean; variant?: ButtonVariant },
): boolean => {
  const map = sessionWidgets.get(sessionId);
  if (!map) {
    return false;
  }

  for (const handle of map.values()) {
    if (handle.type !== 'buttons') {
      continue;
    }
    const buttonsHandle = handle as ButtonsHandle;
    const button = buttonsHandle.buttons.get(buttonId);
    if (!button) {
      continue;
    }
    if (typeof state.label === 'string') {
      button.textContent = state.label;
    }
    if (typeof state.disabled === 'boolean') {
      button.disabled = state.disabled;
      button.classList.toggle('button-disabled', state.disabled);
    }
    if (typeof state.hidden === 'boolean') {
      button.classList.toggle('hidden', state.hidden);
    }
    if (state.variant) {
      button.classList.remove('widget-button-primary', 'widget-button-danger', 'widget-button-ghost');
      button.classList.add(`widget-button-${state.variant}`);
    }
    return true;
  }

  return false;
};

const renderButtons = (
  container: HTMLElement,
  buttons: ButtonConfig[],
  buttonMap: Map<string, HTMLButtonElement>,
): void => {
  container.innerHTML = '';
  buttonMap.clear();

  buttons.forEach((config) => {
    const button = document.createElement('button');
    button.textContent = config.label;
    button.dataset.buttonId = config.id;
    button.className = 'widget-button';
    if (config.variant) {
      button.classList.add(`widget-button-${config.variant}`);
    }
    if (config.disabled) {
      button.disabled = true;
      button.classList.add('button-disabled');
    }
    if (config.onClick) {
      button.addEventListener('click', () => {
        if (!button.disabled) {
          config.onClick?.();
        }
      });
    }
    container.appendChild(button);
    buttonMap.set(config.id, button);
  });
};

export const appendInputWidget = (
  sessionId: string,
  config: InputWidgetConfig,
  options: WidgetAppendOptions = {},
): InputHandle | undefined => {
  const container = getWidgetContainer(sessionId);
  if (!container) {
    return undefined;
  }

  const widget = document.createElement('div');
  widget.className = 'widget widget-input';
  if (options.hidden) {
    widget.classList.add('hidden');
  }

  if (config.label) {
    const label = document.createElement('div');
    label.className = 'widget-input-label';
    label.textContent = config.label;
    widget.appendChild(label);
  }

  const textarea = document.createElement('textarea');
  textarea.className = 'widget-input-textarea';
  textarea.rows = 4;
  if (config.placeholder) {
    textarea.placeholder = config.placeholder;
  }
  widget.appendChild(textarea);

  if (config.hint) {
    const hint = document.createElement('div');
    hint.className = 'widget-input-hint';
    hint.textContent = config.hint;
    widget.appendChild(hint);
  }

  textarea.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      event.preventDefault();
      config.onCancel?.();
      return;
    }
    if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      const value = textarea.value.trim();
      if (!value) {
        return;
      }
      config.onSubmit(value);
    }
  });

  const id = options.widgetId ?? createWidgetId('input');
  container.appendChild(widget);

  const handle: InputHandle = { id, type: 'input', element: widget, textarea };
  registerWidget(sessionId, handle);

  setTimeout(() => {
    textarea.focus();
  }, 0);

  return handle;
};
