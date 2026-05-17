#!/usr/bin/env bash
# plan-checkpoint.sh — PreToolUse hook for Edit / Write
# 目的：拦截"大改动跳过 plan 的反模式"。当一个会话编辑文件数 / 跨 repo 数超阈值，
#       且未明确 plan-approved 时，强制 Claude 先 ExitPlanMode 提交计划。
# 参考：cc-options P1 "走错方向全部重写"事件
#
# 输入：tool input JSON（含 file_path 字段）
# 解析顺序：stdin JSON → $CLAUDE_TOOL_INPUT → $1
# session 识别：$CLAUDE_SESSION_ID（CC 提供）→ fallback $PPID
# state 文件：~/.claude/state/plan-checkpoint-${SESSION_ID}.json
#   格式：{"files": [...], "started_at": "..."}
# approved 标志文件：~/.claude/state/plan-checkpoint-${SESSION_ID}.approved
#
# 阈值（按用户体验调）：
#   FILE_THRESHOLD=5    会话累计编辑 5 个 unique file
#   REPO_THRESHOLD=2    跨 2 个以上 git repo
# 触发后：
#   exit 2 + stderr 警告 → Claude 看到立即考虑 ExitPlanMode
# 任何意外（JSON 解析失败 / 工具缺失）→ exit 0（不阻断 = fail-open）

set +e  # 不要因任何错退出
umask 077

# ---------- 阈值（按用户体验调） ----------
FILE_THRESHOLD=5
REPO_THRESHOLD=2

# ---------- 路径 ----------
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR" 2>/dev/null

# ---------- session ID ----------
SESSION_ID="${CLAUDE_SESSION_ID:-$PPID}"
# 防注入：只保留 alnum / dash / underscore
SESSION_ID=$(echo "$SESSION_ID" | tr -cd '[:alnum:]_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

STATE_FILE="$STATE_DIR/plan-checkpoint-${SESSION_ID}.json"
APPROVED_FILE="$STATE_DIR/plan-checkpoint-${SESSION_ID}.approved"

# ---------- 过期清理（>7 天的 state 文件） ----------
find "$STATE_DIR" -maxdepth 1 -name 'plan-checkpoint-*' -mtime +7 -delete 2>/dev/null

# ---------- 1. 读取 tool input ----------
TOOL_INPUT=""
if [[ ! -t 0 ]]; then
  TOOL_INPUT=$(cat 2>/dev/null || echo "")
fi
[[ -z "$TOOL_INPUT" && -n "$CLAUDE_TOOL_INPUT" ]] && TOOL_INPUT="$CLAUDE_TOOL_INPUT"
[[ -z "$TOOL_INPUT" && -n "$1" ]] && TOOL_INPUT="$1"
[[ -z "$TOOL_INPUT" ]] && exit 0

# ---------- 2. 解析 file_path 字段 ----------
FILE_PATH=""
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")
fi
if [[ -z "$FILE_PATH" ]] && command -v python3 >/dev/null 2>&1; then
  FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); print(d.get('file_path',''))
except Exception:
    pass" 2>/dev/null || echo "")
fi
# 终极 fallback：正则
if [[ -z "$FILE_PATH" ]]; then
  FILE_PATH=$(echo "$TOOL_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[[ -z "$FILE_PATH" ]] && exit 0

# 规范化为绝对路径（去掉相对路径里的 ./../）
case "$FILE_PATH" in
  /*) ABS_PATH="$FILE_PATH" ;;
  *)  ABS_PATH="$PWD/$FILE_PATH" ;;
esac

# ---------- 3. 读 state（python 优先；jq 次之；终极 grep） ----------
read_state_files() {
  # stdout: 每行一个 file path
  [[ ! -f "$STATE_FILE" ]] && return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import sys,json
try:
    with open('$STATE_FILE') as f: d=json.load(f)
    for x in d.get('files', []): print(x)
except Exception:
    pass" 2>/dev/null
  elif command -v jq >/dev/null 2>&1; then
    jq -r '.files[]?' "$STATE_FILE" 2>/dev/null
  fi
}

write_state() {
  # 入参：files (newline-separated 字符串)
  local files="$1"
  local started_at="$2"
  if command -v python3 >/dev/null 2>&1; then
    FILES_DATA="$files" STARTED_AT="$started_at" STATE_OUT="$STATE_FILE" \
      python3 -c "import os,json
files=[x for x in os.environ.get('FILES_DATA','').split('\n') if x]
out={'files': sorted(set(files)), 'started_at': os.environ.get('STARTED_AT','')}
with open(os.environ['STATE_OUT'],'w') as f: json.dump(out,f)" 2>/dev/null
  else
    # 简易 fallback：直接 JSON 拼装
    {
      printf '{"files":['
      local first=1
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ $first -eq 1 ]]; then first=0; else printf ','; fi
        # 简单转义双引号 & 反斜杠
        esc=$(printf '%s' "$line" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '"%s"' "$esc"
      done <<< "$files"
      printf '],"started_at":"%s"}' "$started_at"
    } > "$STATE_FILE"
  fi
}

# ---------- 4. 累计 file 列表（unique set） ----------
EXISTING_FILES=$(read_state_files)
ALL_FILES=$(printf '%s\n%s' "$EXISTING_FILES" "$ABS_PATH" | awk 'NF && !seen[$0]++')

# 写回 state（每次都更新）
STARTED_AT=""
if [[ -f "$STATE_FILE" ]] && command -v python3 >/dev/null 2>&1; then
  STARTED_AT=$(python3 -c "import json
try:
    print(json.load(open('$STATE_FILE')).get('started_at',''))
except Exception:
    pass" 2>/dev/null)
fi
[[ -z "$STARTED_AT" ]] && STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_state "$ALL_FILES" "$STARTED_AT"

# ---------- 5. 统计：unique file 数 + 跨 repo 数 ----------
FILE_COUNT=$(printf '%s\n' "$ALL_FILES" | awk 'NF' | wc -l | tr -d ' ')

# 跨 repo 数：每个文件找它的 git toplevel
get_repo_root() {
  local f="$1"
  local d
  d=$(dirname "$f" 2>/dev/null)
  while [[ -n "$d" && "$d" != "/" ]]; do
    if [[ -d "$d" ]]; then
      local root
      root=$(cd "$d" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
      if [[ -n "$root" ]]; then
        echo "$root"
        return
      fi
      # 不是 git 子目录 → 用 dirname 当 bucket（防止 non-git 文件全聚成一个）
      echo "$d"
      return
    fi
    d=$(dirname "$d")
  done
  echo "/"
}

REPO_SET=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  r=$(get_repo_root "$f")
  REPO_SET=$(printf '%s\n%s' "$REPO_SET" "$r")
done <<< "$ALL_FILES"
REPO_COUNT=$(printf '%s\n' "$REPO_SET" | awk 'NF && !seen[$0]++' | wc -l | tr -d ' ')

# ---------- 6. 决策 ----------
APPROVED=0
[[ -f "$APPROVED_FILE" ]] && APPROVED=1

if [[ $APPROVED -eq 0 ]] && \
   { [[ "$FILE_COUNT" -ge $FILE_THRESHOLD ]] || [[ "$REPO_COUNT" -ge $REPO_THRESHOLD ]]; }; then
  {
    echo "⚠ plan-checkpoint 触发：本会话已编辑 ${FILE_COUNT} 文件 / ${REPO_COUNT} repo。"
    echo "   阈值：FILE>=${FILE_THRESHOLD} 或 REPO>=${REPO_THRESHOLD}"
    echo "   建议先 ExitPlanMode 提交计划等用户批准。"
    echo "   如已 plan 过：touch ${APPROVED_FILE} 后重试。"
    echo "   session: ${SESSION_ID}"
  } >&2
  exit 2
fi

exit 0
