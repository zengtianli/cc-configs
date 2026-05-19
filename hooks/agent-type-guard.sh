#!/usr/bin/env bash
# agent-type-guard.sh · PreToolUse hook for Agent tool
# 当 subagent_type=general-purpose 但 prompt 关键词暗示专项 agent → stderr 提示
# 始终 exit 0 不阻塞; JSON parse fail silent exit 0
set -u

# 1) 读输入 (CC hook 经 stdin; 兜底 $CLAUDE_TOOL_INPUT)
INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

# 2) parse JSON 拿 subagent_type + prompt (tab 分隔单行输出)
PARSED=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
    ti = d.get("tool_input", d)
    sub = ti.get("subagent_type", "") or d.get("subagent_type", "")
    pr  = ti.get("prompt", "") or d.get("prompt", "")
    print(sub + "\t" + pr.replace("\n", " ").replace("\t", " "))
except Exception:
    pass
' 2>/dev/null) || exit 0
[ -z "$PARSED" ] && exit 0

SUB="${PARSED%%	*}"
PROMPT="${PARSED#*	}"

# 3) 仅 general-purpose
[ "$SUB" = "general-purpose" ] || exit 0
[ -z "$PROMPT" ] && exit 0

# 4) 白名单: 要改文件 → 必须 general-purpose
if grep -qiE '(写入|创建文件|修改|编辑|重写|edit |write |create file|patch |refactor |实现|落地|commit|push)' <<< "$PROMPT"; then
  exit 0
fi

# 5) 关键词分类 (grep -qE 单次扫描 ~5ms; 比 python regex 启动省 ~30ms)
SUGGEST="" REASON=""
if grep -qiE '(找一?下|搜索|搜一?下|grep|locate|where is|查找|扫一?下|扫描|盘点|盘一?下|列出.*文件|找.*在哪)' <<< "$PROMPT"; then
  SUGGEST="Explore"
  REASON="read-only 找代码/文件/位置 → Explore 更精准且 token 省"
elif grep -qiE '(设计方案|出方案|规划|重构思路|architecture|架构|拆分方法|strategy|策略设计|plan |方案设计|路线图)' <<< "$PROMPT"; then
  SUGGEST="Plan"
  REASON="设计/规划/架构类 → Plan agent 内置 plan-mode 框架"
elif grep -qiE '(Claude API|Anthropic SDK|anthropic\.Messages|prompt cache|tool use 设计|claude-?code-?guide|messages\.create)' <<< "$PROMPT"; then
  SUGGEST="claude-code-guide"
  REASON="Claude API/SDK 专项 → claude-code-guide 有领域知识"
fi
[ -z "$SUGGEST" ] && exit 0

# 6) stderr 提示 (不阻塞)
SNIPPET=$(printf '%.120s' "$PROMPT")
cat >&2 <<EOF

[agent-type-guard] subagent_type=general-purpose 可能不是最佳选择
  → 建议改用: subagent_type="$SUGGEST"
  → 理由: $REASON
  → prompt 摘要: ${SNIPPET}...
  (本提示不阻塞执行, 可忽略)
EOF
exit 0
