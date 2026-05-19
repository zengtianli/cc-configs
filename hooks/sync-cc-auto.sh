#!/usr/bin/env bash
# sync-cc-auto.sh — SessionStart hook
# 目的：进入 ~/Dev/* 项目时快速检测 CC 配置文档与 repo 实际状态漂移，stderr 单行提示。
# 调用底层 cc_audit.py（若存在 + 快速模式），否则降级为本地 grep 检测。
# 硬限制：5s timeout，silent on no-drift / non-Dev cwd。

set +e

CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# 1. 范围闸：必须 ~/Dev/* 且在 git repo 内
case "$CWD" in
  "$HOME/Dev"/*) : ;;
  *) exit 0 ;;
esac

# 找 git root（最近 .git 上溯，限 4 层）
GIT_ROOT=""
DIR="$CWD"
for _ in 1 2 3 4 5; do
  if [[ -d "$DIR/.git" ]]; then GIT_ROOT="$DIR"; break; fi
  DIR=$(dirname "$DIR")
  [[ "$DIR" == "/" || "$DIR" == "$HOME" ]] && break
done
[[ -z "$GIT_ROOT" ]] && exit 0

# 2. 优先调 cc_audit.py 快查（5s 内）
AUDIT="$HOME/Dev/tools/cc-configs/tools/cc-audit/cc_audit.py"
DRIFT=0
if [[ -f "$AUDIT" ]]; then
  # --json 只读快查；解析 findings 数量
  OUT=$(timeout 4 python3 "$AUDIT" --cwd "$GIT_ROOT" --json 2>/dev/null)
  if [[ -n "$OUT" ]]; then
    N=$(echo "$OUT" | python3 -c "import sys,json
try:
    d=json.loads(sys.stdin.read())
    findings=d.get('findings') if isinstance(d,dict) else d
    print(len(findings) if isinstance(findings,list) else 0)
except Exception:
    print(0)" 2>/dev/null || echo 0)
    [[ "$N" -gt 0 ]] && DRIFT=1
  fi
else
  # 3. 降级：仅检测 CLAUDE.md / MEMORY.md 引用死链
  if [[ -f "$GIT_ROOT/CLAUDE.md" ]]; then
    # 找 ./xxx.md 引用 → 不存在即漂移
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      [[ ! -e "$GIT_ROOT/$ref" ]] && DRIFT=1 && break
    done < <(grep -oE '\(\./[^)]+\.md\)' "$GIT_ROOT/CLAUDE.md" 2>/dev/null | sed 's|(\./||;s|)||' | head -10)
  fi
fi

[[ "$DRIFT" -eq 1 ]] && echo "drift detected, run /sync-cc" >&2

exit 0
