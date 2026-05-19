#!/usr/bin/env bash
# ship-guard-v2 — PostToolUse/Bash hook · 强化完成 ritual 强制提示
#
# 触发: 任何 Bash 工具调用结束后；本脚本自筛 git commit
# 输入: $CLAUDE_TOOL_INPUT (JSON, 含 .command, .cwd)
# 输出: stderr 强显眼 box (CC 主进程会读到) · exit 始终 0 (不阻塞)
# 状态: ~/.claude/state/ship_guard_last_deploy.<cwd_hash> mtime = 最近 deploy 时间
# 维护: tianli · 2026-05-19
set -u
INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

parsed=$(python3 -c '
import json,sys,os
try:
    d=json.loads(os.environ.get("CLAUDE_TOOL_INPUT",""))
    cmd=(d.get("command","") or "").replace("\n"," ")
    cwd=d.get("cwd","") or os.getcwd()
    print(cmd + "\x1f" + cwd)
except Exception:
    sys.exit(2)
' 2>/dev/null) || exit 0

CMD="${parsed%%$'\x1f'*}"
CWD="${parsed##*$'\x1f'}"

# 必须真是 git commit (排除 commit-tree / --dry-run / --amend)
echo "$CMD" | grep -qE '(^|[^-a-z])git[[:space:]]+commit([[:space:]]|$)' || exit 0
echo "$CMD" | grep -qE 'commit-tree|--dry-run|--amend' && exit 0

station_root="$HOME/Dev/stations"
in_station=0
case "$CWD" in "$station_root"/*) in_station=1 ;; esac

# deploy 痕迹: state file mtime < 30 min
hash=$(printf '%s' "$CWD" | shasum | awk '{print $1}' | cut -c1-12)
state_file="$HOME/.claude/state/ship_guard_last_deploy.$hash"
fresh_deploy=0
if [ -f "$state_file" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$state_file" 2>/dev/null || echo 0) ))
  [ "$age" -lt 1800 ] && fresh_deploy=1
fi

if [ "$in_station" = 1 ] && [ "$fresh_deploy" = 0 ]; then
  station=$(echo "$CWD" | sed -E "s|$station_root/([^/]+).*|\1|")
  {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  SHIP-GUARD: commit ≠ done                                 ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  Station:  $station"
    echo "║  完成 = commit + push + deploy + 验证 live URL"
    echo "║  下一步:   /ship $station"
    echo "║  或:       cd $CWD && /deploy"
    echo "╚════════════════════════════════════════════════════════════╝"
  } >&2
elif [ "$in_station" = 1 ] && [ "$fresh_deploy" = 1 ]; then
  : # 30 分钟内已 deploy, 安静
else
  echo "[ship-guard] commit done · 非 station 项目, 按需 push/deploy" >&2
fi
exit 0
