#!/usr/bin/env bash
# PostToolUse syntax-check hook
# Usage: syntax-check.sh <file_path>
# Dispatches by extension, exits non-zero on syntax error with stderr message.

set +e
umask 077

FILE="${1:-}"

# 如果没传 $1，尝试从 stdin / $CLAUDE_TOOL_INPUT 抠 file_path（hook 框架传 tool_input JSON）
if [[ -z "$FILE" ]]; then
  TOOL_INPUT=""
  if [[ ! -t 0 ]]; then
    TOOL_INPUT=$(cat 2>/dev/null || echo "")
  fi
  [[ -z "$TOOL_INPUT" && -n "$CLAUDE_TOOL_INPUT" ]] && TOOL_INPUT="$CLAUDE_TOOL_INPUT"

  if [[ -n "$TOOL_INPUT" ]]; then
    if command -v jq >/dev/null 2>&1; then
      FILE=$(echo "$TOOL_INPUT" | jq -r '.file_path // .tool_input.file_path // ""' 2>/dev/null || echo "")
    fi
    if [[ -z "$FILE" ]] && command -v python3 >/dev/null 2>&1; then
      FILE=$(echo "$TOOL_INPUT" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('file_path') or d.get('tool_input',{}).get('file_path',''))
except Exception:
    pass" 2>/dev/null || echo "")
    fi
  fi
fi

if [[ -z "$FILE" ]]; then
  # 无 file_path 信息（非 Edit/Write tool 或框架未传），silently skip
  exit 0
fi

if [[ ! -f "$FILE" ]]; then
  # File doesn't exist (deleted or path mismatch); skip
  exit 0
fi

# Extract lowercase extension (bash-portable)
ext="${FILE##*.}"
ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')

# Helper: emit error and exit non-zero
emit_err() {
  local first_line
  first_line=$(echo "$2" | head -n 1)
  echo "语法错误：$1 $first_line" >&2
  exit 1
}

case "$ext" in
  py)
    if ! out=$(python3 -m py_compile "$FILE" 2>&1); then
      emit_err "$FILE" "$out"
    fi
    ;;

  yaml|yml)
    if ! command -v yamllint >/dev/null 2>&1; then
      echo "yamllint 未装跳过" >&2
      exit 0
    fi
    if ! out=$(yamllint -d relaxed "$FILE" 2>&1); then
      emit_err "$FILE" "$out"
    fi
    ;;

  json)
    if ! out=$(jq empty "$FILE" </dev/null 2>&1); then
      emit_err "$FILE" "$out"
    fi
    ;;

  sh|bash)
    if ! command -v shellcheck >/dev/null 2>&1; then
      echo "shellcheck 未装跳过" >&2
      exit 0
    fi
    if ! out=$(shellcheck -S error "$FILE" 2>&1); then
      emit_err "$FILE" "$out"
    fi
    ;;

  ts|tsx)
    # tsc too slow; defer to pre-commit
    exit 0
    ;;

  *)
    exit 0
    ;;
esac

exit 0
