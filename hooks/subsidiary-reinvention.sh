#!/usr/bin/env bash
# subsidiary-reinvention.sh — SessionStart hook
# 跑子公司反造轮子巡检(subsidiary_audit.py),发现"重复总部能力"才报警注入 context。
# 子公司 = ~/ 顶层带 GOAL.md/check_goal.sh 的目录(Work/Apps/Archives/zdys + 未来自动纳入)。
# 快(~1s),非破坏只读;干净时静默(不刷屏),有造轮子时给精简总账。
# Why: 用户「很担心子公司自己造轮子不用总部」→ 从"能查"升级为"自动查·不查不放过"。
set +e

AUDIT="$HOME/Dev/tools/dev/lib/tools/report/subsidiary_audit.py"
[ -f "$AUDIT" ] || exit 0

out=$(python3 "$AUDIT" 2>/dev/null)
rc=$?

if [ "$rc" -eq 3 ]; then
  echo "⚠ 子公司反造轮子巡检：发现重复总部能力的脚本（应改调 ~/Dev 共享服务，别自造轮子）"
  echo "$out" | grep -E '⚠ 造轮子|\[deploy_family\]|\[paths_ssot\]|\[llm_client\]|\[cf_api\]|总账' | head -20
  echo "  详查 python3 $AUDIT · 修复=改调总部 / distill 上提总部+更新 SSOT-INDEX"
fi
exit 0
