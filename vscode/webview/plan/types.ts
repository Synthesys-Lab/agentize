export interface PlanImplMessage {
  type: 'plan/impl';
  sessionId: string;
  issueNumber: string;
}

export interface PlanToggleImplCollapseMessage {
  type: 'plan/toggleImplCollapse';
  sessionId: string;
}
