#!/usr/bin/env python3
"""Polling server for GitHub Projects automation.

Polls GitHub Projects v2 for issues with "Plan Accepted" status and
`agentize:plan` label, then spawns worktrees for implementation.
"""

import argparse
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
    ISSUE_STATUS_QUERY,
    _project_id_cache,
)
from agentize.server.workers import (
    worktree_exists,
    spawn_worktree,
    spawn_refinement,
    spawn_feat_request,
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
    DEFAULT_WORKERS_DIR,
)


def run_server(
    period: int,
    tg_token: str | None = None,
    tg_chat_id: str | None = None,
    num_workers: int = 5
) -> None:
    """Main polling loop.

    Args:
        period: Polling interval in seconds
        tg_token: Telegram Bot API token (optional, falls back to TG_API_TOKEN env)
        tg_chat_id: Telegram chat ID (optional, falls back to TG_CHAT_ID env)
        num_workers: Maximum concurrent workers (0 = unlimited)
    """
    org, project_id, remote_url = load_config()
    print(f"Starting server: org={org}, project={project_id}, period={period}s, workers={num_workers}")

    # Extract repo slug for issue links (computed once)
    repo_slug = _extract_repo_slug(remote_url) if remote_url else None

    # Resolve Telegram credentials (CLI args take precedence over env vars)
    token = tg_token or os.getenv('TG_API_TOKEN', '')
    chat_id = tg_chat_id or os.getenv('TG_CHAT_ID', '')

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
                        print(f"issue #{issue_no} feat-request planning assigned to worker {worker_id}")

                        # Send Telegram notification if configured
                        if token and chat_id:
                            issue_url = f"https://github.com/{repo_slug}/issues/{issue_no}" if repo_slug else None
                            msg = f"📝 Feat-request planning started: <a href=\"{issue_url}\">#{issue_no}</a>" if issue_url else f"📝 Feat-request planning started: #{issue_no}"
                            send_telegram_message(token, chat_id, msg)
                    else:
                        write_worker_status(worker_id, 'FREE', None, None)
                        _log(f"Failed to spawn feat-request planning for issue #{issue_no}", level="ERROR")
                else:
                    # Unlimited workers mode
                    success, _ = spawn_feat_request(issue_no)
                    if not success:
                        _log(f"Failed to spawn feat-request planning for issue #{issue_no}", level="ERROR")

            if running[0]:
                time.sleep(period)

        except Exception as e:
            _log(f"Error during poll: {e}", level="ERROR")
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
    parser.add_argument(
        '--tg-token',
        help='Telegram Bot API token (or set TG_API_TOKEN env var)'
    )
    parser.add_argument(
        '--tg-chat-id',
        help='Telegram chat ID (or set TG_CHAT_ID env var)'
    )
    parser.add_argument(
        '--num-workers', type=int, default=5,
        help='Maximum concurrent workers (0 = unlimited). Default: 5'
    )
    args = parser.parse_args()

    try:
        period_seconds = parse_period(args.period)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    run_server(period_seconds, args.tg_token, args.tg_chat_id, args.num_workers)


if __name__ == '__main__':
    main()
