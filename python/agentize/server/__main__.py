#!/usr/bin/env python3
"""Polling server for GitHub Projects automation.

Polls GitHub Projects v2 for issues with "Plan Accepted" status and
`agentize:plan` label, then spawns worktrees for implementation.
"""

import argparse
import json
import signal
import subprocess
import sys
import time
from pathlib import Path


# GraphQL query for project items with Status field
GRAPHQL_QUERY = '''
query($org: String!, $projectNumber: Int!) {
  organization(login: $org) {
    projectV2(number: $projectNumber) {
      items(first: 100) {
        nodes {
          content {
            ... on Issue {
              number
              title
              labels(first: 10) {
                nodes { name }
              }
            }
          }
          fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue {
              name
            }
          }
        }
      }
    }
  }
}
'''


def parse_period(period_str: str) -> int:
    """Parse period string (e.g., '5m', '300s') to seconds."""
    if period_str.endswith('m'):
        return int(period_str[:-1]) * 60
    elif period_str.endswith('s'):
        return int(period_str[:-1])
    else:
        raise ValueError(f"Invalid period format: {period_str}. Use Nm or Ns.")


def load_config() -> tuple[str, int]:
    """Load project config from .agentize.yaml."""
    yaml_path = Path('.agentize.yaml')
    if not yaml_path.exists():
        # Search parent directories
        current = Path.cwd()
        while current != current.parent:
            yaml_path = current / '.agentize.yaml'
            if yaml_path.exists():
                break
            current = current.parent
        else:
            raise FileNotFoundError(".agentize.yaml not found")

    # Simple YAML parsing (no external deps)
    org = None
    project_id = None
    with open(yaml_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('org:'):
                org = line.split(':', 1)[1].strip()
            elif line.startswith('id:'):
                project_id = int(line.split(':', 1)[1].strip())

    if not org or not project_id:
        raise ValueError(".agentize.yaml missing project.org or project.id")

    return org, project_id


def query_project_items(org: str, project_number: int) -> list[dict]:
    """Query GitHub Projects v2 for items."""
    query = GRAPHQL_QUERY.strip()
    variables = json.dumps({'org': org, 'projectNumber': project_number})

    result = subprocess.run(
        ['gh', 'api', 'graphql',
         '-f', f'query={query}',
         '-f', f'variables={variables}'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        print(f"GraphQL query failed: {result.stderr}", file=sys.stderr)
        return []

    data = json.loads(result.stdout)
    try:
        items = data['data']['organization']['projectV2']['items']['nodes']
        return items
    except (KeyError, TypeError):
        print(f"Unexpected response structure: {result.stdout}", file=sys.stderr)
        return []


def filter_ready_issues(items: list[dict]) -> list[int]:
    """Filter items to issues with 'Plan Accepted' status and 'agentize:plan' label."""
    ready = []
    for item in items:
        content = item.get('content')
        if not content or 'number' not in content:
            continue

        # Check status
        status = item.get('fieldValueByName', {})
        if not status or status.get('name') != 'Plan Accepted':
            continue

        # Check label
        labels = content.get('labels', {}).get('nodes', [])
        label_names = [l['name'] for l in labels]
        if 'agentize:plan' not in label_names:
            continue

        ready.append(content['number'])

    return ready


def worktree_exists(issue_no: int) -> bool:
    """Check if a worktree exists for the given issue number."""
    result = subprocess.run(
        ['wt', 'resolve', str(issue_no)],
        capture_output=True, text=True
    )
    return result.returncode == 0


def spawn_worktree(issue_no: int) -> bool:
    """Spawn a new worktree for the given issue."""
    print(f"Spawning worktree for issue #{issue_no}...")
    result = subprocess.run(['wt', 'spawn', str(issue_no)])
    return result.returncode == 0


def run_server(period: int) -> None:
    """Main polling loop."""
    org, project_id = load_config()
    print(f"Starting server: org={org}, project={project_id}, period={period}s")

    # Setup signal handler for graceful shutdown
    running = [True]

    def signal_handler(signum, frame):
        print("\nShutting down...")
        running[0] = False

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    while running[0]:
        try:
            items = query_project_items(org, project_id)
            ready_issues = filter_ready_issues(items)

            for issue_no in ready_issues:
                if not worktree_exists(issue_no):
                    spawn_worktree(issue_no)
                else:
                    print(f"Issue #{issue_no}: worktree already exists, skipping")

            if running[0]:
                time.sleep(period)

        except Exception as e:
            print(f"Error during poll: {e}", file=sys.stderr)
            if running[0]:
                time.sleep(period)


def main() -> None:
    """Entry point."""
    parser = argparse.ArgumentParser(
        description='Poll GitHub Projects for Plan Accepted issues'
    )
    parser.add_argument(
        '--period', default='5m',
        help='Polling interval (e.g., 5m, 300s). Default: 5m'
    )
    args = parser.parse_args()

    try:
        period_seconds = parse_period(args.period)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    run_server(period_seconds)


if __name__ == '__main__':
    main()
