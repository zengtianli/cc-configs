#!/usr/bin/env bash
# CC dashboard auto-regen hook (PostToolUse Write|Edit|MultiEdit|Bash)
# 触发: 检测 tool_input 路径/命令含 CC config 区域 → 跑 cc_dashboard.py
# 异步 (不阻塞主流程), exit 0 (advisory)
#
# 安装位置: ~/.claude/hooks/dashboard-regen.sh (主进程负责 symlink/copy)
# settings.json 接入: PostToolUse[Write|Edit|MultiEdit] + PostToolUse[Bash] 末尾
set -u

INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

# 解析 path / command 字段, 命中 CC 区域 → HIT
DETECT=$(python3 -c '
import json, os
try:
    d = json.loads(os.environ.get("CLAUDE_TOOL_INPUT", ""))
    p = d.get("file_path", "") or d.get("path", "")
    c = d.get("command", "")
    cc_paths = [
        "/.claude/commands/",
        "/.claude/skills/",
        "/.claude/hooks/",
        "/.claude/agents/",
        "/.claude/projects/-Users-tianli-Dev/memory/",
        "/.claude/settings.json",
        "/tools/cc-configs/",
    ]
    hit = any(s in p for s in cc_paths) or any(s in c for s in cc_paths)
    print("HIT" if hit else "MISS")
except Exception:
    print("MISS")
' 2>/dev/null)

[ "$DETECT" != "HIT" ] && exit 0

# Debounce: 30s 内已跑过 → skip (state file mtime)
STATE_DIR="$HOME/.claude/state"
STATE_FILE="$STATE_DIR/cc_dashboard_last_regen"
LOG_FILE="$STATE_DIR/cc_dashboard.log"
mkdir -p "$STATE_DIR"

if [ -f "$STATE_FILE" ]; then
  NOW=$(date +%s)
  LAST=$(stat -f %m "$STATE_FILE" 2>/dev/null || echo 0)
  AGE=$(( NOW - LAST ))
  if [ "$AGE" -lt 30 ]; then
    exit 0
  fi
fi
touch "$STATE_FILE"

# 异步 regen, 不阻塞主流程; 日志固定位置便于 debug
REGEN="$HOME/Dev/tools/dev/lib/tools/report/cc_dashboard.py"
if [ ! -f "$REGEN" ]; then
  echo "[$(date +%FT%T)] generator missing: $REGEN" >> "$LOG_FILE"
  exit 0
fi

nohup python3 "$REGEN" >> "$LOG_FILE" 2>&1 &
disown 2>/dev/null || true
exit 0
