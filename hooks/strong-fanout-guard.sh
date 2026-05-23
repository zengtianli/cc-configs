#!/usr/bin/env bash
# strong-fanout-guard: warn when lead agents fail to materialize fan-out evidence.
# PreToolUse hook — non-blocking. Looks for evidence files; if a lead session
# is 2+ minutes old and has no /tmp/lead-fanout-evidence-*.txt, emit a warning.
set -u
SESSION_ID="${CLAUDE_SESSION_ID:-${ANTHROPIC_SESSION_ID:-unknown}}"
[ "$SESSION_ID" = "unknown" ] && exit 0
EVID="/tmp/lead-fanout-evidence-${SESSION_ID}.txt"
START_MARK="/tmp/lead-start-${SESSION_ID}.mark"
[ ! -f "$START_MARK" ] && { date +%s > "$START_MARK"; exit 0; }
START=$(cat "$START_MARK" 2>/dev/null || date +%s)
NOW=$(date +%s)
AGE=$(( NOW - START ))
if [ $AGE -gt 120 ] && [ ! -f "$EVID" ]; then
  echo "⚠ strong-fanout-guard: lead session $SESSION_ID is ${AGE}s old with no fan-out evidence ($EVID). 铁律 #16/#26 要求 ≥ N 真并行 worker。" >&2
fi
exit 0
