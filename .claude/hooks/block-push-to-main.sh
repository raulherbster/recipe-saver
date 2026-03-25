#!/usr/bin/env bash
# Blocks any `git push` that would land commits on main.
# Catches both explicit ("git push origin main") and implicit
# ("git push" / "git push origin" while the current branch is main).

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)

# Only care about git push commands.
echo "$CMD" | grep -qE 'git\s+push' || exit 0

BLOCK='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Direct push to main is blocked. Create a feature branch and open a PR instead."}}'

# Case 1: explicit branch name `main` anywhere in the command.
if echo "$CMD" | grep -qE '\bmain\b'; then
  echo "$BLOCK"
  exit 0
fi

# Case 2: bare `git push` with no explicit destination branch
# (i.e. "git push" or "git push origin" or "git push -u origin").
# Strip "git push" and all flags; if ≤1 positional arg remains it's bare.
POSITIONAL_COUNT=$(echo "$CMD" | sed 's/git[[:space:]]*push//' | tr -s '[:space:]' '\n' | grep -v '^-' | grep -v '^$' | wc -l | tr -d '[:space:]')
if [ "$POSITIONAL_COUNT" -le 1 ]; then
  BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  if [ "$BRANCH" = "main" ]; then
    echo "$BLOCK"
    exit 0
  fi
fi

exit 0
