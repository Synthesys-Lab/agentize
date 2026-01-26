#!/usr/bin/env python3
"""Polling server for GitHub Projects automation.

Polls GitHub Projects v2 for issues with "Plan Accepted" status and
`agentize:plan` label, then spawns worktrees for implementation.
"""

import os
import signal
import sys
import time

# Re-export all public functions from submodules for backward compatibility
# (tests import from agentize.server.__main__)
from agentize.server.log import _log
from agentize.server.notify import (
    parse_period,
    send_telegram_message,
    notify_server_start,
    _extract_repo_slug,
    _format_worker_assignment_message,
    _format_worker_completion_message,
    TELEGRAM_API_TIMEOUT_SEC,
)
from agentize.server.session import (
    _resolve_session_dir,
    _load_issue_index,
    _load_session_state,
    _get_session_state_for_issue,
    _remove_issue_index,
    set_pr_number_for_issue,
)
from agentize.server.github import (
    load_config,
    get_repo_owner_name,
    lookup_project_graphql_id,
    discover_candidate_issues,
    query_issue_project_status,
    query_project_items,
    filter_ready_issues,
    filter_ready_refinements,
    discover_candidate_prs,
    filter_conflicting_prs,
    resolve_issue_from_pr,
    discover_candidate_feat_requests,
    query_feat_request_items,
    filter_ready_feat_requests,
    has_unresolved_review_threads,
    filter_ready_review_prs,
    ISSUE_STATUS_QUERY,
    _project_id_cache,
)
from agentize.server.workers import (
    worktree_exists,
    spawn_worktree,
    spawn_refinement,
    spawn_feat_request,
    spawn_review_resolution,
    rebase_worktree,
    init_worker_status_files,
    read_worker_status,
    write_worker_status,
    get_free_worker,
    check_worker_liveness,
    cleanup_dead_workers,
    _check_issue_has_label,
    _cleanup_refinement,
    _cleanup_feat_request,
    _cleanup_review_resolution,
    DEFAULT_WORKERS_DIR,
)
from agentize.server.runtime_config import load_runtime_config, resolve_precedence


def _resolve_tg_credentials() -> tuple[str, str]:
    """Resolve Telegram credentials from YAML only.

    Returns:
        Tuple of (token, chat_id), both as strings (empty if not configured)
    """
    # Load YAML config
    config, _ = load_runtime_config()
    telegram = config.get("telegram", {}) if isinstance(config.get("telegram"), dict) else {}

    cfg_token = telegram.get("token") or ""
    cfg_chat_id = telegram.get("chat_id")

    # Handle chat_id being an int in YAML
    if isinstance(cfg_chat_id, int):
        cfg_chat_id = str(cfg_chat_id)
    cfg_chat_id = cfg_chat_id or ""

    return cfg_token, cfg_chat_id


def run_server(
    period: int,
    num_workers: int = 5
) -> None:
    """Main polling loop.

    Args:
        period: Polling interval in seconds
        num_workers: Maximum concurrent workers (0 = unlimited)

    Telegram credentials are loaded from .agentize.local.yaml only.
    """
    org, project_id, remote_url = load_config()
    print(f"Starting server: org={org}, project={project_id}, period={period}s, workers={num_workers}")

    # Extract repo slug for issue links (computed once)
    repo_slug = _extract_repo_slug(remote_url) if remote_url else None

    # Resolve Telegram credentials (YAML only)
    token, chat_id = _resolve_tg_credentials()

    # Resolve session directory for completion notifications
    session_dir = _resolve_session_dir()

    # Initialize worker status files (if num_workers > 0)
    if num_workers > 0:
        init_worker_status_files(num_workers)
        cleanup_dead_workers(
            num_workers,
            tg_token=token,
            tg_chat_id=chat_id,
            repo_slug=repo_slug,
            session_dir=session_dir
        )

    # Send startup notification if Telegram is configured
    if token and chat_id:
        notify_server_start(token, chat_id, org, project_id, period)
    else:
        print("Telegram notification skipped (no credentials configured)")

    # Setup signal handler for graceful shutdown
    running = [True]

    def signal_handler(signum, frame):
        print("\nShutting down...")
        running[0] = False

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    while running[0]:
        try:
            # Clean up dead workers before polling
            if num_workers > 0:
                cleanup_dead_workers(
                    num_workers,
                    tg_token=token,
                    tg_chat_id=chat_id,
                    repo_slug=repo_slug,
                    session_dir=session_dir
                )

            items = query_project_items(org, project_id)
            ready_issues = filter_ready_issues(items)

            # Build issue titles map (without changing filter_ready_issues return type)
            issue_titles: dict[int, str] = {}
            for item in items:
                content = item.get('content')
                if content and 'number' in content:
                    issue_titles[content['number']] = content.get('title', '')

            for issue_no in ready_issues:
                if worktree_exists(issue_no):
                    print(f"Issue #{issue_no}: worktree already exists, skipping")
                    continue

                # Check worker availability (if bounded)
                if num_workers > 0:
                    worker_id = get_free_worker(num_workers)
                    if worker_id is None:
                        print(f"All {num_workers} workers busy, waiting for next poll")
                        break

                    # Mark worker as busy before spawning
                    write_worker_status(worker_id, 'BUSY', issue_no, None)
                    success, pid = spawn_worktree(issue_no)
                    if success:
                        write_worker_status(worker_id, 'BUSY', issue_no, pid)
                        print(f"issue #{issue_no} is assigned to worker {worker_id}")

                        # Send Telegram notification if configured
                        if token and chat_id:
                            issue_title = issue_titles.get(issue_no, '')
                            issue_url = f"https://github.com/{repo_slug}/issues/{issue_no}" if repo_slug else None
                            msg = _format_worker_assignment_message(issue_no, issue_title, worker_id, issue_url)
                            send_telegram_message(token, chat_id, msg)
                    else:
                        write_worker_status(worker_id, 'FREE', None, None)
                        _log(f"Failed to spawn worktree for issue #{issue_no}", level="ERROR")
                else:
                    # Unlimited workers mode
                    success, _ = spawn_worktree(issue_no)
                    if not success:
                        _log(f"Failed to spawn worktree for issue #{issue_no}", level="ERROR")

            # Process refinement candidates
            ready_refinements = filter_ready_refinements(items)
            for issue_no in ready_refinements:
                # Check worker availability (if bounded)
                if num_workers > 0:
                    worker_id = get_free_worker(num_workers)
                    if worker_id is None:
                        print(f"All {num_workers} workers busy, waiting for next poll")
                        break

                    # Mark worker as busy before spawning
                    write_worker_status(worker_id, 'BUSY', issue_no, None)
                    success, pid = spawn_refinement(issue_no)
                    if success:
                        write_worker_status(worker_id, 'BUSY', issue_no, pid)
                        print(f"issue #{issue_no} refinement assigned to worker {worker_id}")

                        # Send Telegram notification if configured
                        if token and chat_id:
                            issue_title = issue_titles.get(issue_no, '')
                            issue_url = f"https://github.com/{repo_slug}/issues/{issue_no}" if repo_slug else None
                            msg = f"🔄 Refinement started: <a href=\"{issue_url}\">#{issue_no}</a> {issue_title}" if issue_url else f"🔄 Refinement started: #{issue_no} {issue_title}"
                            send_telegram_message(token, chat_id, msg)
                    else:
                        write_worker_status(worker_id, 'FREE', None, None)
                        _log(f"Failed to spawn refinement for issue #{issue_no}", level="ERROR")
                else:
                    # Unlimited workers mode
                    success, _ = spawn_refinement(issue_no)
                    if not success:
                        _log(f"Failed to spawn refinement for issue #{issue_no}", level="ERROR")

            # Process feat-request candidates
            feat_request_items = query_feat_request_items(org, project_id)
            ready_feat_requests = filter_ready_feat_requests(feat_request_items)
            for issue_no in ready_feat_requests:
                # Check worker availability (if bounded)
                if num_workers > 0:
                    worker_id = get_free_worker(num_workers)
                    if worker_id is None:
                        print(f"All {num_workers} workers busy, waiting for next poll")
                        break

                    # Mark worker as busy before spawning
                    write_worker_status(worker_id, 'BUSY', issue_no, None)
                    success, pid = spawn_feat_request(issue_no)
                    if success:
                        write_worker_status(worker_id, 'BUSY', issue_no, pid)
                        print(f"issue #{issue_no} dev-req planning assigned to worker {worker_id}")

                        # Send Telegram notification if configured
                        if token and chat_id:
                            issue_url = f"https://github.com/{repo_slug}/issues/{issue_no}" if repo_slug else None
                            msg = f"📝 Dev-req planning started: <a href=\"{issue_url}\">#{issue_no}</a>" if issue_url else f"📝 Dev-req planning started: #{issue_no}"
                            send_telegram_message(token, chat_id, msg)
                    else:
                        write_worker_status(worker_id, 'FREE', None, None)
                        _log(f"Failed to spawn dev-req planning for issue #{issue_no}", level="ERROR")
                else:
                    # Unlimited workers mode
                    success, _ = spawn_feat_request(issue_no)
                    if not success:
                        _log(f"Failed to spawn dev-req planning for issue #{issue_no}", level="ERROR")

            # Process conflicting PRs
            try:
                owner, repo = get_repo_owner_name()
                pr_project_id = lookup_project_graphql_id(org, project_id)
                candidate_prs = discover_candidate_prs(owner, repo)
                conflicting_pr_numbers = filter_conflicting_prs(candidate_prs, owner, repo, pr_project_id)

                for pr_no in conflicting_pr_numbers:
                    # Resolve issue number for worker tracking
                    pr_metadata = next((p for p in candidate_prs if p.get('number') == pr_no), None)
                    if not pr_metadata:
                        continue

                    issue_no = resolve_issue_from_pr(pr_metadata)
                    if not issue_no:
                        _log(f"PR #{pr_no}: could not resolve issue number, skipping", level="WARNING")
                        continue

                    # Check if worktree already exists
                    if not worktree_exists(issue_no):
                        _log(f"PR #{pr_no} (issue #{issue_no}): worktree does not exist, skipping rebase", level="WARNING")
                        continue

                    # Worker assignment and rebase (follows existing pattern)
                    if num_workers > 0:
                        worker_id = get_free_worker(num_workers)
                        if worker_id is None:
                            print(f"All {num_workers} workers busy, waiting for next poll")
                            break

                        write_worker_status(worker_id, 'BUSY', issue_no, None)
                        success, pid = rebase_worktree(pr_no, issue_no)
                        if success:
                            write_worker_status(worker_id, 'BUSY', issue_no, pid)
                            print(f"PR #{pr_no} (issue #{issue_no}) rebase assigned to worker {worker_id}")

                            if token and chat_id:
                                pr_url = f"https://github.com/{repo_slug}/pull/{pr_no}" if repo_slug else None
                                msg = f"🔄 PR rebase started: <a href=\"{pr_url}\">#{pr_no}</a> (issue #{issue_no})" if pr_url else f"🔄 PR rebase started: #{pr_no} (issue #{issue_no})"
                                send_telegram_message(token, chat_id, msg)
                        else:
                            write_worker_status(worker_id, 'FREE', None, None)
                            _log(f"Failed to rebase PR #{pr_no}", level="ERROR")
                    else:
                        # Unlimited workers mode
                        success, _ = rebase_worktree(pr_no, issue_no)
                        if not success:
                            _log(f"Failed to rebase PR #{pr_no}", level="ERROR")
            except RuntimeError as e:
                _log(f"Failed to process conflicting PRs: {e}", level="ERROR")

            # Process review resolution candidates
            try:
                owner, repo = get_repo_owner_name()
                review_project_id = lookup_project_graphql_id(org, project_id)
                review_prs = discover_candidate_prs(owner, repo)
                ready_review_prs = filter_ready_review_prs(review_prs, owner, repo, review_project_id)

                for pr_no, issue_no in ready_review_prs:
                    # Check if worktree exists
                    if not worktree_exists(issue_no):
                        _log(f"PR #{pr_no} (issue #{issue_no}): worktree does not exist, skipping review resolution", level="WARNING")
                        continue

                    # Worker assignment and spawn (follows existing pattern)
                    if num_workers > 0:
                        worker_id = get_free_worker(num_workers)
                        if worker_id is None:
                            print(f"All {num_workers} workers busy, waiting for next poll")
                            break

                        write_worker_status(worker_id, 'BUSY', issue_no, None)
                        success, pid = spawn_review_resolution(pr_no, issue_no)
                        if success:
                            write_worker_status(worker_id, 'BUSY', issue_no, pid)
                            print(f"PR #{pr_no} (issue #{issue_no}) review resolution assigned to worker {worker_id}")

                            if token and chat_id:
                                pr_url = f"https://github.com/{repo_slug}/pull/{pr_no}" if repo_slug else None
                                msg = f"📝 Review resolution started: <a href=\"{pr_url}\">#{pr_no}</a> (issue #{issue_no})" if pr_url else f"📝 Review resolution started: #{pr_no} (issue #{issue_no})"
                                send_telegram_message(token, chat_id, msg)
                        else:
                            write_worker_status(worker_id, 'FREE', None, None)
                            _log(f"Failed to spawn review resolution for PR #{pr_no}", level="ERROR")
                    else:
                        # Unlimited workers mode
                        success, _ = spawn_review_resolution(pr_no, issue_no)
                        if not success:
                            _log(f"Failed to spawn review resolution for PR #{pr_no}", level="ERROR")
            except RuntimeError as e:
                _log(f"Failed to process review resolution: {e}", level="ERROR")

            if running[0]:
                time.sleep(period)

        except Exception as e:
            _log(f"Error during poll: {e}", level="ERROR")
            if running[0]:
                time.sleep(period)


def main() -> None:
    """Entry point.

    Configuration is YAML-only: server.period and server.num_workers
    are read from .agentize.local.yaml. CLI flags are no longer accepted.
    """
    # Reject any CLI arguments - configuration is YAML-only
    if len(sys.argv) > 1:
        print("Error: python -m agentize.server no longer accepts CLI flags.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Configure server.period and server.num_workers in .agentize.local.yaml:", file=sys.stderr)
        print("", file=sys.stderr)
        print("  server:", file=sys.stderr)
        print("    period: 5m", file=sys.stderr)
        print("    num_workers: 5", file=sys.stderr)
        sys.exit(1)

    # Load YAML config for server parameters
    config, _ = load_runtime_config()
    server_config = config.get("server", {}) if isinstance(config.get("server"), dict) else {}

    # Apply precedence: YAML > default (no CLI)
    period = resolve_precedence(None, None, server_config.get("period"), "5m")
    num_workers = resolve_precedence(None, None, server_config.get("num_workers"), 5)

    try:
        period_seconds = parse_period(period)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    run_server(period_seconds, num_workers)


if __name__ == '__main__':
    main()
