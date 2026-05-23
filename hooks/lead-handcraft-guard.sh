#!/usr/bin/env bash
# lead-handcraft-guard: PreToolUse on Write — warn when lead writes
# a very large single file (>100 lines) without prior fan-out evidence.
# Advisory only.
set -u
TOOL="${CLAUDE_TOOL_NAME:-}"
[ "$TOOL" != "Write" ] && exit 0
SID="${CLAUDE_SESSION_ID:-unknown}"
EVID="/tmp/lead-fanout-evidence-${SID}.txt"
# If evidence exists, lead has fanned out — fine.
[ -f "$EVID" ] && exit 0
# We don't see file content here in stub form; rely on flag presence.
# Real implementation would parse tool input JSON.
exit 0
