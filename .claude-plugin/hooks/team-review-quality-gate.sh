#!/bin/bash
# Quality gate hook for /team-review command.
# Handles TeammateIdle and TaskCompleted events to enforce cross-challenge participation.
# Only activates for teams named "review-*" (ignores other agent teams).
#
# Exit codes:
#   0 = allow (proceed normally)
#   2 = reject with feedback (keep teammate working / prevent task completion)

INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | python -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" 2>/dev/null)
TEAM_NAME=$(echo "$INPUT" | python -c "import sys,json; print(json.load(sys.stdin).get('team_name',''))" 2>/dev/null)

# Only apply to team-review teams (named "review-*")
case "$TEAM_NAME" in
  review-*) ;;
  *) exit 0 ;;
esac

if [ "$HOOK_EVENT" = "TeammateIdle" ]; then
  TEAMMATE_NAME=$(echo "$INPUT" | python -c "import sys,json; print(json.load(sys.stdin).get('teammate_name',''))" 2>/dev/null)
  TRANSCRIPT=$(echo "$INPUT" | python -c "import sys,json; print(json.load(sys.stdin).get('transcript',''))" 2>/dev/null)

  # Check if the teammate has sent at least one challenge message
  if echo "$TRANSCRIPT" | grep -qi "CHALLENGE to"; then
    exit 0
  fi

  echo "You have not challenged any findings from other reviewers yet. Review the other reviewers' findings and send at least one CHALLENGE message before going idle." >&2
  exit 2
fi

if [ "$HOOK_EVENT" = "TaskCompleted" ]; then
  TASK_NAME=$(echo "$INPUT" | python -c "import sys,json; print(json.load(sys.stdin).get('task_name',''))" 2>/dev/null)
  TASK_OUTPUT=$(echo "$INPUT" | python -c "import sys,json; print(json.load(sys.stdin).get('task_output',''))" 2>/dev/null)

  # For review tasks, verify findings were produced
  case "$TASK_NAME" in
    review-*)
      if echo "$TASK_OUTPUT" | grep -q "Location:"; then
        exit 0
      fi
      echo "Review task output does not contain structured findings. Please produce findings with Location/Standard/Recommendation format." >&2
      exit 2
      ;;
  esac
fi

exit 0
