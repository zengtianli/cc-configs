#!/usr/bin/env bash
# wiki auto-rebuild hook (PostToolUse Write|Edit|MultiEdit)
# 触发: 改动文件命中 ~/Dev/wiki/ 下 .html 或 .md → 异步重建知识网
# 跑 wiki_build.py (扫全 wiki → 注 nav + 重算 backlinks + 生成 index)
# 异步 (不阻塞主流程), advisory, exit 0
#
# 安装位置: ~/.claude/hooks/wiki-rebuild.sh (主进程负责 symlink/copy)
# settings.json 接入: PostToolUse[Write|Edit|MultiEdit] 末尾, async:true, timeout 10
#
# ── 防循环方案 (关键) ───────────────────────────────────────────────
# 问题: wiki_build.py 注入 nav/backlinks 会改 wiki HTML → 又触发本 hook
#       → 再 rebuild → 死循环 / 风暴。
# 防护双层:
#   1. DEBOUNCE 30s (state file mtime): 任意 wiki 改动只要落在上次重建后
#      30s 窗口内 → skip。wiki_build.py 自己注入产生的全部 writes 都落在
#      这个窗口内 (重建瞬间完成) → 被吞掉, 不会反弹触发新一轮。
#   2. 重建前先 touch state file: 即"宣告本轮重建已开始", 注入写回时
#      AGE<30 → 全部 skip。下一次真实人为改动 (>30s 后) 才会再触发。
# 即便 wiki_build.py 注入是幂等的 (marker 检测 nav 已存在则跳过), debounce
# 仍是防风暴的硬保险。
set -u

INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

# 解析 file_path, 命中 ~/Dev/wiki/ 下 .html 或 .md → HIT
DETECT=$(python3 -c '
import json, os
try:
    d = json.loads(os.environ.get("CLAUDE_TOOL_INPUT", ""))
    p = d.get("file_path", "") or d.get("path", "")
    home = os.path.expanduser("~")
    wiki = home + "/Dev/wiki/"
    hit = p.startswith(wiki) and (p.endswith(".html") or p.endswith(".md"))
    print("HIT" if hit else "MISS")
except Exception:
    print("MISS")
' 2>/dev/null)

[ "$DETECT" != "HIT" ] && exit 0

# Debounce: 30s 内已重建 → skip (吞掉 wiki_build.py 注入产生的写回)
STATE_DIR="$HOME/.claude/state"
STATE_FILE="$STATE_DIR/wiki_build_last_rebuild"
LOG_FILE="$STATE_DIR/wiki_build.log"
mkdir -p "$STATE_DIR"

if [ -f "$STATE_FILE" ]; then
  NOW=$(date +%s)
  LAST=$(stat -f %m "$STATE_FILE" 2>/dev/null || echo 0)
  AGE=$(( NOW - LAST ))
  if [ "$AGE" -lt 30 ]; then
    exit 0
  fi
fi
# 先 touch: 宣告本轮重建开始, 注入写回落在 debounce 窗口内被吞
touch "$STATE_FILE"

REGEN="$HOME/Dev/tools/dev/lib/tools/wiki_build.py"
if [ ! -f "$REGEN" ]; then
  echo "[$(date +%FT%T)] generator missing: $REGEN" >> "$LOG_FILE"
  exit 0
fi

# 异步重建, 不阻塞主流程; 日志固定位置便于 debug
nohup python3 "$REGEN" >> "$LOG_FILE" 2>&1 &
disown 2>/dev/null || true
exit 0
