export interface StepState {
  stage: number;
  endStage?: number;
  total: number;
  name: string;
  provider: string;
  model: string;
  status: 'pending' | 'running' | 'completed';
  startTime: number;
  endTime?: number;
}

// Parse stage line: "Stage N/5: Running {name} ({provider}:{model})" or "Stage M-N/5: ..."
// Parallel stages format: "Stage M-N/5: Running {name with spaces} ({provider}:{model}, {provider}:{model})"
export const parseStageLine = (line: string, at: number = Date.now()): StepState | null => {
  const match = line.match(/Stage\s+(\d+)(?:-(\d+))?\/5:\s+Running\s+(.+?)\s*\(([^)]+)\)/);
  if (!match) {
    return null;
  }

  const [, stageStr, endStageStr, name, providerInfo] = match;
  const firstProviderMatch = providerInfo.match(/([^:,\s]+):([^:,\s]+)/);
  const provider = firstProviderMatch ? firstProviderMatch[1] : 'unknown';
  const model = firstProviderMatch ? firstProviderMatch[2] : 'unknown';

  return {
    stage: parseInt(stageStr, 10),
    endStage: endStageStr ? parseInt(endStageStr, 10) : undefined,
    total: 5,
    name: name || 'unknown',
    provider,
    model,
    status: 'running',
    startTime: at,
  };
};

export const updateStepStatesIn = (
  stateMap: Map<string, StepState[]>,
  sessionId: string,
  line: string,
  at: number = Date.now(),
): boolean => {
  const newStep = parseStageLine(line, at);
  if (!newStep) {
    return false;
  }

  let steps = stateMap.get(sessionId) || [];

  steps = steps.map((step): StepState => {
    if (step.status === 'running') {
      return { ...step, status: 'completed' as const, endTime: at };
    }
    return step;
  });

  steps.push(newStep);
  stateMap.set(sessionId, steps);
  return true;
};

export const completeAllStepsIn = (stateMap: Map<string, StepState[]>, sessionId: string): void => {
  completeAllStepsInAt(stateMap, sessionId, Date.now());
};

export const completeAllStepsInAt = (
  stateMap: Map<string, StepState[]>,
  sessionId: string,
  at: number,
): void => {
  const steps = stateMap.get(sessionId) || [];
  const updated = steps.map((step): StepState => {
    if (step.status === 'running') {
      return { ...step, status: 'completed' as const, endTime: at };
    }
    return step;
  });
  stateMap.set(sessionId, updated);
};

export const formatElapsed = (startTime: number, endTime: number): string => {
  const elapsed = Math.max(0, Math.round((endTime - startTime) / 1000));
  return `${elapsed}s`;
};

export const escapeHtml = (text: string): string => {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
};

export const renderStepIndicatorsFrom = (
  stateMap: Map<string, StepState[]>,
  sessionId: string,
  className = 'step-indicators',
): HTMLElement => {
  const steps = stateMap.get(sessionId) || [];
  const container = document.createElement('div');
  container.className = className;

  steps.forEach((step) => {
    const indicator = document.createElement('div');
    indicator.className = `step-indicator ${step.status}`;

    const stageText = step.endStage
      ? `Stage ${step.stage}-${step.endStage}/${step.total}`
      : `Stage ${step.stage}/${step.total}`;

    const elapsedText = step.status === 'completed' && step.endTime
      ? `done in ${formatElapsed(step.startTime, step.endTime)}`
      : '<span class="loading-dots"></span>';

    indicator.innerHTML = `
      <span class="step-number">${stageText}</span>
      <span class="step-name">${escapeHtml(step.name)}</span>
      <span class="step-model">${escapeHtml(step.provider)}:${escapeHtml(step.model)}</span>
      <span class="step-status">${elapsedText}</span>
    `;
    container.appendChild(indicator);
  });

  return container;
};

export const renderLinks = (text: string): string => {
  const githubRegex = /https:\/\/github\.com\/([^\/\s]+)\/([^\/\s]+)\/issues\/(\d+)/g;
  const mdPathRegex = /(?<=\s|^)(\.tmp\/[^\s\n]+\.md|[\w\-\/]+\.tmp\/[^\s\n]+\.md)(?=\s|$)/g;

  let result = escapeHtml(text);

  result = result.replace(githubRegex, (match) => {
    return `<a href="#" data-link-type="github" data-url="${escapeHtml(match)}">${escapeHtml(match)}</a>`;
  });

  result = result.replace(mdPathRegex, (match) => {
    return `<a href="#" data-link-type="local" data-path="${escapeHtml(match)}">${escapeHtml(match)}</a>`;
  });

  return result;
};

export const extractIssueNumber = (line: string): string | null => {
  const placeholderMatch = /Created placeholder issue #(\d+)/.exec(line);
  if (placeholderMatch) {
    return placeholderMatch[1];
  }

  const urlMatch = /https:\/\/github\.com\/[^/]+\/[^/]+\/issues\/(\d+)/.exec(line);
  if (urlMatch) {
    return urlMatch[1];
  }

  return null;
};
