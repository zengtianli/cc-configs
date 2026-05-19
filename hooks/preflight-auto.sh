#!/usr/bin/env bash
# preflight-auto.sh — PreToolUse/Bash advisory hook
# 目的：检测破坏性命令时给 stderr 提示「建议先跑 /preflight」，不阻塞。
# 与 destruct-guard.sh 的关系：destruct-guard 拦不可恢复（exit 2，git filter-repo 类）；
# 本 hook 覆盖更宽（rm -rf / chmod -R / push --force 等），仅提示不阻塞（exit 0）。
#
# Bypass：命令含 --dry-run 跳过

set +e

# 读 tool input（沿用 destruct-guard 兼容多源模式）
TOOL_INPUT=""
[[ ! -t 0 ]] && TOOL_INPUT=$(cat 2>/dev/null || echo "")
[[ -z "$TOOL_INPUT" && -n "$CLAUDE_TOOL_INPUT" ]] && TOOL_INPUT="$CLAUDE_TOOL_INPUT"
[[ -z "$TOOL_INPUT" ]] && exit 0

# 解析 command
CMD=""
if command -v jq >/dev/null 2>&1; then
  CMD=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null || echo "")
fi
if [[ -z "$CMD" ]] && command -v python3 >/dev/null 2>&1; then
  CMD=$(echo "$TOOL_INPUT" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); print(d.get('command',''))
except Exception:
    pass" 2>/dev/null || echo "")
fi
[[ -z "$CMD" ]] && exit 0

# Bypass: dry-run
echo "$CMD" | grep -qE -- '--dry-run|-n[[:space:]]|--no-act' && exit 0

# 触发模式（高 blast radius · 提示性）
PATTERNS='(\brm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f|\bgit[[:space:]]+filter-repo|\bgit[[:space:]]+reset[[:space:]]+--hard|\bgit[[:space:]]+push[[:space:]]+(--force|-f)|\bchmod[[:space:]]+-R|\bchown[[:space:]]+-R|\bfind[[:space:]]+.*-delete\b)'

if echo "$CMD" | grep -qE "$PATTERNS"; then
  # 截断命令到 120 字符做显示
  DISP=$(echo "$CMD" | head -c 120)
  cat >&2 <<EOF
⚠ preflight-auto: 检测到破坏性命令
命令: $DISP
建议先跑 /preflight 列爆炸半径再决定
(本提示不阻塞执行，但请确认)
EOF
fi

exit 0
