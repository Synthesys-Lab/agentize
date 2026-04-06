Primary goal: implement issue #{{issue_no}} described in {{issue_file}}.
Each iteration:
- read the issue file for the context, and read the current repo file state to determine what to do next to achieve the goal.
- it is ok to fail some test cases temporarily at the end of an iteration, as long as they are properly reported for further development.
- create the commit report file for the current iteration in .tmp/commit-report-iter-<iter>.txt with the full commit message for this iteration.

Available tags are defined in docs/git-msg-tags.md. Choose the most specific tag for your changes.
- before claiming completion, ensure you have the goal described in the issue file fully implemented, and all tests are passing.

If a CI failure context section is provided, use it to prioritize fixes and
include relevant test updates or diagnostics in your response.

COMPLETION SIGNAL (MANDATORY):
When implementation is done, you MUST create {{finalize_file}} with this exact structure:
Line 1: PR title in format [tag][#{{issue_no}}] Brief description
Line 2+: PR body describing the changes
Last line: "Issue {{issue_no}} resolved" and "closes #{{issue_no}}"

Run this command to create the file:
```
cat > {{finalize_file}} << 'FINALIZE_EOF'
[tag][#{{issue_no}}] Brief description of changes
Summary of what was implemented.
Issue {{issue_no}} resolved
closes #{{issue_no}}
FINALIZE_EOF
```
The orchestrator checks {{finalize_file}} for "Issue {{issue_no}} resolved" after every iteration. If the file does not exist or does not contain this string, another iteration will run. You MUST create this file in the SAME iteration where you finish the implementation.

{{iteration_section}}{{previous_output_section}}{{previous_commit_report_section}}{{ci_failure_section}}
