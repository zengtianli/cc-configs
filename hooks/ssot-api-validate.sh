#!/usr/bin/env bash
# ssot-api-validate.sh — PreToolUse hook (Bash tool 类 git commit)
#
# G1 修复:文档驱动写理想 API 代码兑现一半。
# 当用户跑 `git commit` 且 staged diff 含 SSOT 文档时, 自动 grep 文档里教的
# import 子句 + python3 -c 真验证, 失败 exit 2 阻断 commit + 提示用户。
#
# 监控目标:
#   - paths.yaml / paths_const.py
#   - SSOT-INDEX.md
#   - 全局 CLAUDE.md (_dotfiles/claude/CLAUDE.md)
#   - hq_capabilities.yaml (检测器立的 use_via)
#
# Claude Code PreToolUse hook 协议:
#   stdin = JSON {tool_input:{command:"..."}, ...}
#   exit 0 = 放行 / exit 2 = 阻断 (stderr 显示给 Claude)
#
# 设计取舍:
#   - 只阻 git commit; 其他 Bash 命令直接放行
#   - 用 git diff --cached --name-only 取 staged 文件;非 git 仓库放行
#   - 抽 import 用宽松 regex; 单个 import 验证失败=整个 hook fail
set -euo pipefail

INPUT="$(cat 2>/dev/null || true)"
CMD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("tool_input",{}).get("command",""))
except Exception:
    print("")
' 2>/dev/null)"

# 不是 git commit → 放行
case "$CMD" in
    *"git commit"*) ;;
    *) exit 0 ;;
esac

# 不在 git 仓库 → 放行
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

# 列 staged 文件
STAGED="$(git diff --cached --name-only 2>/dev/null || true)"
[ -z "$STAGED" ] && exit 0

# 触发条件:staged 含 SSOT 文档之一
SSOT_PATTERN='(paths\.yaml|paths_const\.py|SSOT-INDEX\.md|_dotfiles/claude/CLAUDE\.md|hq_capabilities\.yaml)'
HIT="$(printf '%s\n' "$STAGED" | grep -E "$SSOT_PATTERN" || true)"

# CC harness 触发条件:staged 含 cc-configs skills/commands/hooks/agents/settings.json 或 projects/*/memory
CC_HARNESS_PATTERN='(cc-configs/(skills|commands|hooks|agents)/|settings\.json|projects/.+/memory/)'
CC_HIT="$(printf '%s\n' "$STAGED" | grep -E "$CC_HARNESS_PATTERN" || true)"

# 两类都没命中 → 放行
[ -z "$HIT" ] && [ -z "$CC_HIT" ] && exit 0

REPO_ROOT="$(git rev-parse --show-toplevel)"
DEV_ROOT="$HOME/Dev"
export PYTHONPATH="$DEV_ROOT:$DEV_ROOT/tools/dev/scripts:$DEV_ROOT/tools/dev:$DEV_ROOT/tools/dev/lib:${PYTHONPATH:-}"

FAILED=0
FAIL_MSGS=()

# CC harness 守门:staged 含 cc-configs harness 类文件 → 跑 cc_harness_consistency --strict
# dead 增长 = 阻断(类比 G1 文档驱动的 import 验证)
if [ -n "$CC_HIT" ]; then
    CC_HARNESS_PY="$DEV_ROOT/tools/dev/lib/tools/report/cc_harness_consistency.py"
    if [ -f "$CC_HARNESS_PY" ]; then
        if ! python3 "$CC_HARNESS_PY" --strict >/tmp/cc-harness-precommit.log 2>&1; then
            dead_summary="$(tail -5 /tmp/cc-harness-precommit.log | sed 's/^/      /')"
            FAIL_MSGS+=("CC harness 7 层有 dead 引用 (cc_harness_consistency --strict 非零):")
            FAIL_MSGS+=("$dead_summary")
            FAIL_MSGS+=("  详见 /tmp/cc-harness-precommit.log;修法: 跑 --fix-dry-run 看建议或清理 dead 引用")
            FAILED=1
        fi
    fi
fi

# 对每个命中的 SSOT 文档抽 import 子句, 真验证
for f in $HIT; do
    full="$REPO_ROOT/$f"
    [ -f "$full" ] || continue
    # 抽取 `from X import Y` / `import X` (限单行,跳注释)
    imports=$(grep -hE "^[^#]*(from [A-Za-z_][A-Za-z0-9_\.]* import [A-Za-z_]|^import [A-Za-z_])" "$full" 2>/dev/null \
        | grep -oE "(from [A-Za-z_][A-Za-z0-9_\.]* import [A-Za-z_][A-Za-z0-9_\,\s]*|import [A-Za-z_][A-Za-z0-9_\.]*)" \
        | sort -u || true)
    [ -z "$imports" ] && continue

    while IFS= read -r stmt; do
        [ -z "$stmt" ] && continue
        # 跳过明显文档里 anti-pattern 的反例(本身就是说"不要这么写")
        case "$stmt" in
            *"import anthropic"*|*"from anthropic"*) continue ;;
            *"import openai"*|*"from openai"*) continue ;;
        esac
        if ! python3 -c "$stmt" 2>/dev/null; then
            err="$(python3 -c "$stmt" 2>&1 | tail -1 || true)"
            FAIL_MSGS+=("$f → 文档里教的 \`$stmt\` 真跑失败: $err")
            FAILED=1
        fi
    done <<< "$imports"
done

if [ "$FAILED" -eq 1 ]; then
    {
        echo "❌ SSOT-API 验证失败(G1 守门 · 文档教的 import 真跑不过):"
        for m in "${FAIL_MSGS[@]}"; do echo "  · $m"; done
        echo ""
        echo "修法: 要么 SSOT 文档改成真能跑的 API, 要么把 API 兑现到代码里。"
        echo "豁免: 真要 force-commit, --no-verify (不建议)。"
    } >&2
    exit 2
fi

exit 0
