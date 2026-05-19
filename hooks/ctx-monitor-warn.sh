#!/usr/bin/env bash
# ctx-monitor-warn.sh — Stop hook
# 目的：每轮 LLM 回答结束时估算当前会话 token 用量，>70% (~140K) → stderr 提示 /wrap 或 /compact
# 不冲突: 已有 Stop hook = session_stop_notify + auto-commit-on-stop, 本 hook append 在后.

set +e

# 1. 找 transcript（环境变量优先 → 默认路径推断）
TP="${CLAUDE_TRANSCRIPT_PATH:-}"

if [[ -z "$TP" || ! -f "$TP" ]]; then
  # 降级：按 cwd encode 找最新 jsonl
  CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
  ENC=$(echo "$CWD" | sed 's|/|-|g')
  PROJDIR="$HOME/.claude/projects/$ENC"
  [[ -d "$PROJDIR" ]] && TP=$(ls -t "$PROJDIR"/*.jsonl 2>/dev/null | head -1)
fi

[[ -z "$TP" || ! -f "$TP" ]] && exit 0

# 2. 估算：文件 bytes / 4 ≈ tokens（粗估，jsonl 含 JSON overhead，4 char ≈ 1 token 上限）
BYTES=$(wc -c < "$TP" 2>/dev/null | tr -d ' ')
[[ -z "$BYTES" || "$BYTES" -eq 0 ]] && exit 0

# 阈值：200K context window × 70% = 140K tokens ≈ 560K bytes（保守 4 char/token）
# 实际 jsonl 含元数据膨胀，真 token 更少 → 用 700K bytes 作阈值（贴近 70% 真值）
THRESHOLD=${CLAUDE_CTX_WARN_BYTES:-700000}

if [[ "$BYTES" -gt "$THRESHOLD" ]]; then
  KB=$((BYTES / 1024))
  echo "ctx > 70% (transcript ${KB}KB), 建议 /wrap 或 /compact" >&2
fi

exit 0
