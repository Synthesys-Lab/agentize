Primary goal: implement issue #{{issue_no}} described in {{issue_file}}.
Each iteration:
- read the issue file for the context, and read the current repo file state to determine what to do next to achieve the goal.
- it is ok to fail some test cases temporarily at the end of an iteration, as long as they are properly reported for further development.
- create the commit report file for the current iteration in .tmp/commit-report-iter-<iter>.txt with the full commit message for this iteration.
- update {{finalize_file}} with PR title (first line) and body (full file); include "Issue {{issue_no}} resolved" only when done.

PR Title Format:
The first line of {{finalize_file}} will be used as the PR title and MUST follow this exact format:
  [tag][#{{issue_no}}] Brief description

Examples:
  [feat][#42] Add user authentication
  [bugfix][#15] Fix memory leak in worker
  [agent.skill][#3] Add code review skill

Available tags are defined in docs/git-msg-tags.md. Choose the most specific tag for your changes.
- before claiming completion, ensure you have the goal described in the issue file fully implemented, and all tests are passing.
- once completed the implementation, create a {{finalize_file}} file with the PR title and body, including "closes #{{issue_no}}" at the end of the body.

If a CI failure context section is provided, use it to prioritize fixes and
include relevant test updates or diagnostics in your response.

{{iteration_section}}{{previous_output_section}}{{previous_commit_report_section}}{{ci_failure_section}}
