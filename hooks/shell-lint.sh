#!/usr/bin/env bash
# shell-lint.sh — PreToolUse hook for Bash tool
# 目的：拦截单文件 cat/head/tail/grep/echo>file，推 Read/Grep/Write 工具
# 参考：全局 CLAUDE.md "Read > cat/head/tail"；30d 统计 Bash=6115 vs Edit=1802
#
# 输入：tool input JSON（command 字段），stdin / $CLAUDE_TOOL_INPUT / $1
# 行为：拦中 → stderr 提示具体替换建议；始终 exit 0（不阻塞）
# 性能目标：< 500ms（纯 bash regex + python3 一次性 parse）

set +e
TOOL_INPUT=""
[[ ! -t 0 ]] && TOOL_INPUT=$(cat 2>/dev/null || echo "")
[[ -z "$TOOL_INPUT" && -n "$CLAUDE_TOOL_INPUT" ]] && TOOL_INPUT="$CLAUDE_TOOL_INPUT"
[[ -z "$TOOL_INPUT" && -n "$1" ]] && TOOL_INPUT="$1"
[[ -z "$TOOL_INPUT" ]] && exit 0

CMD=$(python3 -c "import sys,json
try:
    d=json.loads(sys.stdin.read()); print(d.get('command',''))
except Exception: pass" <<<"$TOOL_INPUT" 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# ---------- 全局豁免（任一命中放行整条 cmd）----------
# 管道 / 命令替换 / heredoc / 远程 ssh / find -exec
[[ "$CMD" == *"|"* ]] && exit 0
[[ "$CMD" == *'$('* || "$CMD" == *'`'* ]] && exit 0
[[ "$CMD" == *"<<"* ]] && exit 0
[[ "$CMD" =~ ^[[:space:]]*ssh[[:space:]] ]] && exit 0
[[ "$CMD" == *"-exec"* ]] && exit 0
# 组合（&& / ;）只检查首段
FIRST=$(echo "$CMD" | sed -E 's/[[:space:]]*(&&|;).*//')

warn() {
  echo "" >&2
  echo "⚠ shell-lint: 检测到 \`$1\`" >&2
  echo "建议: $2" >&2
  echo "原因: 全局 CLAUDE.md \"Read > cat/head/tail\" + Grep/Write 工具优先（避免污染 context）" >&2
  echo "" >&2
}

# ---------- cat <file> ----------
# 单 arg 文件，无 flag（豁免 cat -n / cat -A 等需要 flag 的场景由用户决定）
if [[ "$FIRST" =~ ^[[:space:]]*cat[[:space:]]+([^[:space:]]+)[[:space:]]*$ ]]; then
  ARG="${BASH_REMATCH[1]}"
  [[ "$ARG" != -* ]] && warn "cat $ARG" "Read(file_path=\"$ARG\")"
fi

# ---------- head / tail <file> ----------
# head /path or head -n N /path（单文件）
if [[ "$FIRST" =~ ^[[:space:]]*(head|tail)([[:space:]]+-[nc][[:space:]]*[0-9]+)?[[:space:]]+([^[:space:]-][^[:space:]]*)[[:space:]]*$ ]]; then
  TOOL="${BASH_REMATCH[1]}"
  FILE="${BASH_REMATCH[3]}"
  warn "$TOOL ... $FILE" "Read(file_path=\"$FILE\", offset/limit=N) — 比 $TOOL 更省 context"
fi

# ---------- grep PATTERN <file> ----------
# 非递归（无 -r/-R），最后一 arg 是文件
if [[ "$FIRST" =~ ^[[:space:]]*grep[[:space:]] ]] && [[ "$FIRST" != *" -r"* ]] && [[ "$FIRST" != *" -R"* ]] && [[ "$FIRST" != *"--recursive"* ]]; then
  # 数 token：grep PAT FILE 至少 3 token；多文件（>3）放行
  TOKENS=$(echo "$FIRST" | awk '{print NF}')
  if [[ "$TOKENS" == "3" ]]; then
    LAST=$(echo "$FIRST" | awk '{print $NF}')
    PAT=$(echo "$FIRST" | awk '{print $2}')
    [[ -f "$LAST" || "$LAST" == /* || "$LAST" == ./* || "$LAST" == ../* || "$LAST" == ~* ]] && \
      warn "grep $PAT $LAST" "Grep(pattern=\"$PAT\", path=\"$LAST\") — 结构化输出、可 head_limit"
  fi
fi

# ---------- echo ... > <file>（非 >>）----------
if [[ "$FIRST" =~ ^[[:space:]]*echo[[:space:]] ]] && [[ "$FIRST" == *">"* ]] && [[ "$FIRST" != *">>"* ]]; then
  FILE=$(echo "$FIRST" | sed -E 's/.*[^>]>[[:space:]]*([^[:space:]]+).*/\1/')
  warn "echo ... > $FILE" "Write(file_path=\"$FILE\", content=...) — 避免 quoting/转义问题"
fi

exit 0
