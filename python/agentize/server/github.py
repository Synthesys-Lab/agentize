"""GitHub issue/PR discovery and GraphQL helpers for the server module."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

from agentize.server.log import _log


# Cache for project GraphQL ID (org/project_number -> GraphQL ID)
_project_id_cache: dict[tuple[str, int], str] = {}


def load_config() -> tuple[str, int, str | None]:
    """Load project config from .agentize.yaml.

    Returns:
        Tuple of (org, project_id, remote_url) where remote_url may be None.
    """
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
    remote_url = None
    with open(yaml_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('org:'):
                org = line.split(':', 1)[1].strip()
            elif line.startswith('id:'):
                project_id = int(line.split(':', 1)[1].strip())
            elif line.startswith('remote_url:'):
                remote_url = line.split(':', 1)[1].strip()
                # Handle URLs with : in them (e.g., https://...)
                if remote_url.startswith('https') or remote_url.startswith('git@'):
                    # Re-read the full value after 'remote_url:'
                    remote_url = line.split('remote_url:', 1)[1].strip()

    if not org or not project_id:
        raise ValueError(".agentize.yaml missing project.org or project.id")

    # Fallback to git remote if remote_url not configured
    if remote_url is None:
        result = subprocess.run(
            ['git', 'remote', 'get-url', 'origin'],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            url = result.stdout.strip()
            if url:
                remote_url = url
                _log("remote_url not in .agentize.yaml, using git remote origin")

    return org, project_id, remote_url


def get_repo_owner_name() -> tuple[str, str]:
    """Resolve repository owner and name from git remote origin."""
    result = subprocess.run(
        ['git', 'remote', 'get-url', 'origin'],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to get git remote: {result.stderr}")

    url = result.stdout.strip()
    # Handle SSH format: git@github.com:owner/repo.git
    if url.startswith('git@'):
        path = url.split(':')[1]
    # Handle HTTPS format: https://github.com/owner/repo.git
    elif 'github.com' in url:
        path = url.split('github.com/')[1]
    else:
        raise RuntimeError(f"Unrecognized git remote format: {url}")

    # Remove .git suffix and trailing slash properly
    if path.endswith('/'):
        path = path[:-1]
    if path.endswith('.git'):
        path = path[:-4]
    parts = path.split('/')
    if len(parts) >= 2:
        return parts[0], parts[1]
    raise RuntimeError(f"Cannot parse owner/repo from: {url}")


def lookup_project_graphql_id(org: str, project_number: int) -> str:
    """Convert owner (organization or user) and project number into ProjectV2 GraphQL ID.

    Uses repositoryOwner query which works for both organizations and personal user accounts.
    Result is cached to avoid repeated lookups.
    """
    cache_key = (org, project_number)
    if cache_key in _project_id_cache:
        return _project_id_cache[cache_key]

    # Use repositoryOwner query which works for both organizations and users
    query = '''
query($owner: String!, $projectNumber: Int!) {
  repositoryOwner(login: $owner) {
    ... on Organization {
      projectV2(number: $projectNumber) {
        id
      }
    }
    ... on User {
      projectV2(number: $projectNumber) {
        id
      }
    }
  }
}
'''
    result = subprocess.run(
        ['gh', 'api', 'graphql',
         '-f', f'query={query.strip()}',
         '-f', f'owner={org}',
         '-F', f'projectNumber={project_number}'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to lookup project ID: {result.stderr}", level="ERROR")
        return ''

    try:
        data = json.loads(result.stdout)
        # Use repositoryOwner path which works for both Organization and User
        project_id = data['data']['repositoryOwner']['projectV2']['id']
        _project_id_cache[cache_key] = project_id
        return project_id
    except (KeyError, TypeError, json.JSONDecodeError) as e:
        _log(f"Failed to parse project ID response: {e}", level="ERROR")
        return ''


def discover_candidate_issues(owner: str, repo: str) -> list[int]:
    """Discover open issues with agentize:plan label using gh issue list."""
    result = subprocess.run(
        ['gh', 'issue', 'list',
         '-R', f'{owner}/{repo}',
         '--label', 'agentize:plan',
         '--state', 'open',
         '--json', 'number',
         '--jq', '.[].number'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to list issues: {result.stderr}", level="ERROR")
        return []

    issues = []
    for line in result.stdout.strip().split('\n'):
        line = line.strip()
        if line:
            # Handle both tab-separated format and plain number format
            try:
                issue_no = int(line.split('\t')[0])
                issues.append(issue_no)
            except (ValueError, IndexError):
                continue
    return issues


# GraphQL query to get an issue's project status
ISSUE_STATUS_QUERY = '''
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      projectItems(first: 20) {
        nodes {
          project { id }
          fieldValues(first: 50) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2SingleSelectField { name } }
                name
              }
            }
          }
        }
      }
    }
  }
}
'''


def query_issue_project_status(owner: str, repo: str, issue_no: int, project_id: str) -> str:
    """Fetch an issue's Status field value for the configured project.

    Returns the status string (e.g., "Plan Accepted") or empty string if not found.
    """
    result = subprocess.run(
        ['gh', 'api', 'graphql',
         '-f', f'query={ISSUE_STATUS_QUERY.strip()}',
         '-f', f'owner={owner}',
         '-f', f'repo={repo}',
         '-F', f'number={issue_no}'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to query issue #{issue_no} status: {result.stderr}", level="ERROR")
        if os.getenv('HANDSOFF_DEBUG'):
            _log(f"Variables: owner={owner}, repo={repo}, number={issue_no}", level="ERROR")
        return ''

    try:
        data = json.loads(result.stdout)
        project_items = data['data']['repository']['issue']['projectItems']['nodes']

        # Find the project item matching our project ID
        for item in project_items:
            if item.get('project', {}).get('id') != project_id:
                continue

            # Find the Status field value
            for field_value in item.get('fieldValues', {}).get('nodes', []):
                field_name = field_value.get('field', {}).get('name', '')
                if field_name == 'Status':
                    return field_value.get('name', '')

        return ''
    except (KeyError, TypeError, json.JSONDecodeError) as e:
        _log(f"Failed to parse issue status response: {e}", level="ERROR")
        return ''


def query_project_items(org: str, project_number: int) -> list[dict]:
    """Query GitHub Projects v2 for items using label-first discovery.

    Uses gh issue list to discover candidates with agentize:plan label,
    then performs per-issue GraphQL queries to check project status.
    """
    # Get repo owner/name for gh issue list
    try:
        owner, repo = get_repo_owner_name()
    except RuntimeError as e:
        _log(f"Failed to get repo info: {e}", level="ERROR")
        return []

    # Lookup project GraphQL ID for status matching
    project_id = lookup_project_graphql_id(org, project_number)
    if not project_id:
        _log("Failed to lookup project GraphQL ID", level="ERROR")
        return []

    # Discover candidates via label-first query
    candidate_issues = discover_candidate_issues(owner, repo)
    if not candidate_issues:
        if os.getenv('HANDSOFF_DEBUG'):
            _log("No candidate issues found with agentize:plan label")
        return []

    if os.getenv('HANDSOFF_DEBUG'):
        _log(f"Found {len(candidate_issues)} candidate issues: {candidate_issues}")

    # Build items list with per-issue status lookups
    items = []
    for issue_no in candidate_issues:
        status = query_issue_project_status(owner, repo, issue_no, project_id)

        # Build item in the same format expected by filter_ready_issues
        item = {
            'content': {
                'number': issue_no,
                'labels': {'nodes': [{'name': 'agentize:plan'}]}  # Already filtered by label
            },
            'fieldValueByName': {'name': status} if status else None
        }
        items.append(item)

    return items


def filter_ready_issues(items: list[dict]) -> list[int]:
    """Filter items to issues with 'Plan Accepted' status and 'agentize:plan' label."""
    debug = os.getenv('HANDSOFF_DEBUG')
    ready = []
    skip_status = 0
    skip_label = 0

    for item in items:
        content = item.get('content')
        if not content or 'number' not in content:
            continue

        issue_no = content['number']
        status_field = item.get('fieldValueByName') or {}
        status_name = status_field.get('name', '')
        labels = content.get('labels', {}).get('nodes', [])
        label_names = [l['name'] for l in labels]

        # Check status
        if status_name != 'Plan Accepted':
            if debug:
                print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: SKIP, reason: status != Plan Accepted", file=sys.stderr)
            skip_status += 1
            continue

        # Check label
        if 'agentize:plan' not in label_names:
            if debug:
                print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: SKIP, reason: missing agentize:plan label", file=sys.stderr)
            skip_label += 1
            continue

        if debug:
            print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: READY, reason: matches criteria", file=sys.stderr)
        ready.append(issue_no)

    if debug:
        total_skip = skip_status + skip_label
        _log(f"Summary: {len(ready)} ready, {total_skip} skipped ({skip_status} wrong status, {skip_label} missing label)")

    return ready


def filter_ready_refinements(items: list[dict]) -> list[int]:
    """Filter items to issues eligible for refinement.

    Requirements:
    - Status = 'Proposed'
    - Labels include both 'agentize:plan' and 'agentize:refine'
    """
    debug = os.getenv('HANDSOFF_DEBUG')
    ready = []
    skip_status = 0
    skip_plan_label = 0
    skip_refine_label = 0

    for item in items:
        content = item.get('content')
        if not content or 'number' not in content:
            continue

        issue_no = content['number']
        status_field = item.get('fieldValueByName') or {}
        status_name = status_field.get('name', '')
        labels = content.get('labels', {}).get('nodes', [])
        label_names = [l['name'] for l in labels]

        # Check status
        if status_name != 'Proposed':
            if debug:
                print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: SKIP, reason: status != Proposed", file=sys.stderr)
            skip_status += 1
            continue

        # Check agentize:plan label
        if 'agentize:plan' not in label_names:
            if debug:
                print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: SKIP, reason: missing agentize:plan label", file=sys.stderr)
            skip_plan_label += 1
            continue

        # Check agentize:refine label
        if 'agentize:refine' not in label_names:
            if debug:
                print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: SKIP, reason: missing agentize:refine label", file=sys.stderr)
            skip_refine_label += 1
            continue

        if debug:
            print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: READY, reason: matches criteria", file=sys.stderr)
        ready.append(issue_no)

    if debug:
        total_skip = skip_status + skip_plan_label + skip_refine_label
        _log(f"Summary: {len(ready)} ready, {total_skip} skipped ({skip_status} wrong status, {skip_plan_label} missing agentize:plan, {skip_refine_label} missing agentize:refine)")

    return ready


def discover_candidate_prs(owner: str, repo: str) -> list[dict]:
    """Discover open PRs with agentize:pr label.

    Returns:
        List of PR metadata dicts with number, headRefName, mergeable fields.
    """
    result = subprocess.run(
        ['gh', 'pr', 'list',
         '-R', f'{owner}/{repo}',
         '--label', 'agentize:pr',
         '--state', 'open',
         '--json', 'number,headRefName,mergeable,body,closingIssuesReferences'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to list PRs: {result.stderr}", level="ERROR")
        return []

    try:
        prs = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        _log(f"Failed to parse PR list response: {e}", level="ERROR")
        return []

    if not prs:
        if os.getenv('HANDSOFF_DEBUG'):
            _log("No candidate PRs found with agentize:pr label")
        return []

    if os.getenv('HANDSOFF_DEBUG'):
        pr_numbers = [pr.get('number') for pr in prs]
        _log(f"Found {len(prs)} candidate PRs: {pr_numbers}")

    return prs


def filter_conflicting_prs(prs: list[dict], owner: str, repo: str, project_id: str) -> list[int]:
    """Filter PRs to those with merge conflicts and not already being rebased.

    Returns PR numbers where:
    - mergeable == "CONFLICTING"
    - Resolved issue does not have Status == "Rebasing"

    Skips PRs with:
    - mergeable == "UNKNOWN" (retry on next poll)
    - Status == "Rebasing" (already being processed)
    - Cannot resolve issue number (still queued - best effort)
    """
    debug = os.getenv('HANDSOFF_DEBUG')
    conflicting = []
    skip_healthy = 0
    skip_unknown = 0
    skip_rebasing = 0

    for pr in prs:
        pr_no = pr.get('number')
        mergeable = pr.get('mergeable', '')

        if mergeable == 'UNKNOWN':
            if debug:
                print(f"  - PR #{pr_no}: {{ mergeable: {mergeable} }}, decision: SKIP, reason: retry next poll", file=sys.stderr)
            skip_unknown += 1
            continue

        if mergeable != 'CONFLICTING':
            if debug:
                print(f"  - PR #{pr_no}: {{ mergeable: {mergeable} }}, decision: SKIP, reason: healthy", file=sys.stderr)
            skip_healthy += 1
            continue

        # PR is CONFLICTING - check if already being rebased via status
        issue_no = resolve_issue_from_pr(pr)
        if issue_no is not None:
            status = query_issue_project_status(owner, repo, issue_no, project_id)
            if status == 'Rebasing':
                if debug:
                    print(f"  - PR #{pr_no}: {{ mergeable: {mergeable}, status: {status} }}, decision: SKIP, reason: already being rebased", file=sys.stderr)
                skip_rebasing += 1
                continue
            status_str = f", status: {status}" if status else ""
        else:
            status_str = ""

        if debug:
            print(f"  - PR #{pr_no}: {{ mergeable: {mergeable}{status_str} }}, decision: QUEUE, reason: needs rebase", file=sys.stderr)
        conflicting.append(pr_no)

    if debug:
        total_skip = skip_healthy + skip_unknown + skip_rebasing
        _log(f"Summary: {len(conflicting)} queued, {total_skip} skipped ({skip_healthy} healthy, {skip_unknown} unknown, {skip_rebasing} rebasing)")

    return conflicting


def resolve_issue_from_pr(pr: dict) -> int | None:
    """Resolve issue number from PR metadata.

    Fallback order:
    1. Branch name pattern: issue-<N>
    2. closingIssuesReferences
    3. PR body #<N> pattern
    """
    # Fallback 1: Branch name
    head_ref = pr.get('headRefName', '')
    match = re.match(r'issue-(\d+)', head_ref)
    if match:
        return int(match.group(1))

    # Fallback 2: closingIssuesReferences
    closing_refs = pr.get('closingIssuesReferences', [])
    if closing_refs and len(closing_refs) > 0:
        first_ref = closing_refs[0]
        if isinstance(first_ref, dict) and 'number' in first_ref:
            return first_ref['number']

    # Fallback 3: PR body #N pattern
    body = pr.get('body', '')
    if body:
        body_match = re.search(r'#(\d+)', body)
        if body_match:
            return int(body_match.group(1))

    return None


def discover_candidate_feat_requests(owner: str, repo: str) -> list[int]:
    """Discover open issues with agentize:dev-req label using gh issue list."""
    result = subprocess.run(
        ['gh', 'issue', 'list',
         '-R', f'{owner}/{repo}',
         '--label', 'agentize:dev-req',
         '--state', 'open',
         '--json', 'number',
         '--jq', '.[].number'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to list dev-req issues: {result.stderr}", level="ERROR")
        return []

    issues = []
    for line in result.stdout.strip().split('\n'):
        line = line.strip()
        if line:
            try:
                issue_no = int(line.split('\t')[0])
                issues.append(issue_no)
            except (ValueError, IndexError):
                continue
    return issues


def query_feat_request_items(org: str, project_number: int) -> list[dict]:
    """Query GitHub for feat-request items using label-first discovery.

    Uses gh issue list to discover candidates with agentize:dev-req label,
    then performs per-issue lookups for status and full label list.
    """
    try:
        owner, repo = get_repo_owner_name()
    except RuntimeError as e:
        _log(f"Failed to get repo info: {e}", level="ERROR")
        return []

    # Lookup project GraphQL ID for status matching
    project_id = lookup_project_graphql_id(org, project_number)
    if not project_id:
        _log("Failed to lookup project GraphQL ID", level="ERROR")
        return []

    # Discover candidates via dev-req label query
    candidate_issues = discover_candidate_feat_requests(owner, repo)
    if not candidate_issues:
        if os.getenv('HANDSOFF_DEBUG'):
            _log("No candidate issues found with agentize:dev-req label")
        return []

    if os.getenv('HANDSOFF_DEBUG'):
        _log(f"Found {len(candidate_issues)} feat-request candidates: {candidate_issues}")

    # Build items list with per-issue status and label lookups
    items = []
    for issue_no in candidate_issues:
        status = query_issue_project_status(owner, repo, issue_no, project_id)
        labels = _query_issue_labels(owner, repo, issue_no)

        item = {
            'content': {
                'number': issue_no,
                'labels': {'nodes': [{'name': label} for label in labels]}
            },
            'fieldValueByName': {'name': status} if status else None
        }
        items.append(item)

    return items


def _query_issue_labels(owner: str, repo: str, issue_no: int) -> list[str]:
    """Query an issue's labels via gh issue view."""
    result = subprocess.run(
        ['gh', 'issue', 'view', str(issue_no),
         '-R', f'{owner}/{repo}',
         '--json', 'labels',
         '--jq', '.labels[].name'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        return []

    return [label.strip() for label in result.stdout.strip().split('\n') if label.strip()]


def filter_ready_feat_requests(items: list[dict]) -> list[int]:
    """Filter items to issues eligible for feat-request planning.

    Requirements:
    - Has 'agentize:dev-req' label
    - Does NOT have 'agentize:plan' label (not already planned)
    - Status is NOT 'Done' or 'In Progress' (terminal statuses)
    """
    debug = os.getenv('HANDSOFF_DEBUG')
    ready = []
    skip_has_plan = 0
    skip_terminal = 0

    terminal_statuses = {'Done', 'In Progress'}

    for item in items:
        content = item.get('content')
        if not content or 'number' not in content:
            continue

        issue_no = content['number']
        status_field = item.get('fieldValueByName') or {}
        status_name = status_field.get('name', '')
        labels = content.get('labels', {}).get('nodes', [])
        label_names = [l['name'] for l in labels]

        # Must have agentize:dev-req label (already filtered by discovery)
        if 'agentize:dev-req' not in label_names:
            continue

        # Check for agentize:plan label (already planned)
        if 'agentize:plan' in label_names:
            if debug:
                print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: SKIP, reason: already has agentize:plan", file=sys.stderr)
            skip_has_plan += 1
            continue

        # Check for terminal status
        if status_name in terminal_statuses:
            if debug:
                print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: SKIP, reason: terminal status", file=sys.stderr)
            skip_terminal += 1
            continue

        if debug:
            print(f"  - Issue #{issue_no}: {{ labels: {label_names}, status: {status_name} }}, decision: READY, reason: matches criteria", file=sys.stderr)
        ready.append(issue_no)

    if debug:
        total_skip = skip_has_plan + skip_terminal
        _log(f"Summary: {len(ready)} ready, {total_skip} skipped ({skip_has_plan} already planned, {skip_terminal} terminal status)")

    return ready
