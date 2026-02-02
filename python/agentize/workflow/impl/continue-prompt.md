Primary goal: implement issue #{{issue_no}} described in {{issue_file}}.
Each iteration:
- read the issue file for the context, and read the current repo file state to determine what to do next to achieve the goal.
- it is ok to fail some test cases temporarily at the end of an iteration, as long as they are properly reported for further development.
- create the commit report file for the current iteration in .tmp/commit-report-iter-<iter>.txt with the full commit message for this iteration.
- update {{finalize_file}} with PR title (first line) and body (full file); include "Issue {{issue_no}} resolved" only when done.
- before claiming completion, ensure you have the goal described in the issue file fully implemented, and all tests are passing.
- once completed the implementation, create a {{finalize_file}} file with the PR title and body, including "closes #{{issue_no}}" at the end of the body.

{{iteration_section}}{{previous_output_section}}{{previous_commit_report_section}}
