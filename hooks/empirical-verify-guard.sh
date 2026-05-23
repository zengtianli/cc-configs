#!/usr/bin/env bash
# empirical-verify-guard: when main session about to emit a URL claim,
# check recent transcript for `curl -sI` or `dig` against that host.
# Non-blocking advisory.
set -u
TRANSCRIPT="${CLAUDE_TRANSCRIPT_PATH:-}"
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0
# look at last ~200 lines for URL mentions vs curl/dig calls
LAST=$(tail -n 400 "$TRANSCRIPT" 2>/dev/null || echo "")
URLS=$(echo "$LAST" | grep -oE 'https?://[a-zA-Z0-9._-]+' | sort -u | head -10)
[ -z "$URLS" ] && exit 0
for u in $URLS; do
  host=$(echo "$u" | sed -E 's|https?://([^/]+).*|\1|')
  if ! echo "$LAST" | grep -qE "curl -[sS]?I[^|]*${host}|dig [^|]*${host}"; then
    echo "ℹ empirical-verify-guard: URL ${u} mentioned without recent curl -sI/dig (铁律 #11)。" >&2
  fi
done
exit 0
