#!/usr/bin/env bash
# PostToolUse hook on Write|Edit
# 当 Claude 写文件到子 ws memory(`~/.claude/projects/-Users-tianli-*/memory/user_*.md` 或
# `reference_*.md`,但**排除 home ws** `-Users-tianli/`)时,跑 wheel_audit.py --strict 拦截轮子。
#
# 行为:
# - 不 block(只 stderr warning,让 LLM context 看到)
# - wheel_audit.py 不存在 → 静默 exit 0(容错另一个 agent 还没写完)
# - 任何错误吞掉,绝不破坏正常 write flow

set +e
umask 077

WHEEL_AUDIT_PY="${HOME}/Dev/tools/dev/lib/tools/report/wheel_audit.py"

# 1. 抠 file_path —— 优先从 stdin/$CLAUDE_TOOL_INPUT JSON 取,fallback $CLAUDE_TOOL_INPUT_FILE_PATH
FILE=""
TOOL_INPUT=""
# 用 read 带 timeout 避免无 stdin 时挂死(测试场景);生产 Claude 框架会立即喂 JSON
if [[ ! -t 0 ]]; then
  # -t 1: 1 秒超时;-d '': 读到 EOF
  IFS= read -r -t 1 -d '' TOOL_INPUT 2>/dev/null || true
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

# fallback: env var (tests / 其他框架版本)
[[ -z "$FILE" && -n "$CLAUDE_TOOL_INPUT_FILE_PATH" ]] && FILE="$CLAUDE_TOOL_INPUT_FILE_PATH"

# 无路径信息 → 静默退出
[[ -z "$FILE" ]] && exit 0

# 2. 路径匹配:子 ws memory + user_/reference_ 前缀,**排除 home ws** `-Users-tianli/`
#    匹配: ~/.claude/projects/-Users-tianli-<子目录>/memory/{user_,reference_}*.md
#    不匹配: ~/.claude/projects/-Users-tianli/memory/... (home ws)
case "$FILE" in
  */.claude/projects/-Users-tianli-*/memory/user_*.md|*/.claude/projects/-Users-tianli-*/memory/reference_*.md)
    : # match,继续
    ;;
  *)
    exit 0
    ;;
esac

# 3. wheel_audit.py 容错(另一 agent 在并发写,可能还没到)
if [[ ! -f "$WHEEL_AUDIT_PY" ]]; then
  exit 0
fi

# 4. 跑 wheel_audit.py --strict --summary --root <projects-root>,非 0 → stderr warning(不 block)
#    wheel_audit 接 --root 扫整个 projects/ 找 user_*/reference_* 类轮子(非 per-file),所以
#    我们给它 ~/.claude/projects 这个根,让它对照 home 白名单扫所有子 ws。--summary 出 markdown
#    给 LLM context 直读,--strict 让 exit code 区分是否检出。
PROJECTS_ROOT="${HOME}/.claude/projects"
out=$(python3 "$WHEEL_AUDIT_PY" --strict --summary --root "$PROJECTS_ROOT" 2>&1)
rc=$?

if [[ $rc -ne 0 ]]; then
  cat >&2 <<EOF
[wheel-audit] 警告：刚写入 $FILE 后扫到造轮子(铁律 #18 子公司不造轮子)。
$out
建议：查 ~/Dev/tools/dev/lib/tools/report/hq_capabilities.yaml 看 home 是否已有该能力,有则改走 use_via 绝对路径消费,而不是子 ws 重写。
(本警告仅提醒,write 已落盘;hook 不 block 流程)
EOF
fi

exit 0
