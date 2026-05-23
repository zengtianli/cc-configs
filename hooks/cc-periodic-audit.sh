#!/usr/bin/env bash
# cc-periodic-audit.sh — SessionStart hook (24h cache)
#
# G5 修复:无周期巡检 → 立 audit 立后无 cron 拉动, 静默腐化。
# 每 24h 跑 4 类 audit, 摘要上屏给主会话, 让任何漂移立刻可见。
#
# Cache: /tmp/cc-periodic-audit-YYYYMMDD.done flag(按日)
# 跑慢/失败均软失败(echo 警告,不阻 SessionStart)
set +e

DEV="$HOME/Dev"
STAMP="/tmp/cc-periodic-audit-$(date +%Y%m%d).done"
[ -f "$STAMP" ] && exit 0

echo "🔍 cc-periodic-audit (24h 周期) — $(date '+%Y-%m-%d %H:%M')"

# A. paths.yaml 自检(顶层关键目录存在性 + 死链/dangling symlink)
PATHS_PY="$DEV/tools/dev/lib/tools/ssot/paths.py"
if [ -x "$PATHS_PY" ] || [ -f "$PATHS_PY" ]; then
    out="$(python3 "$PATHS_PY" audit --brief 2>&1 | head -8 || true)"
    if echo "$out" | grep -qE "(FAIL|missing|dangling|⚠)"; then
        echo "  ⚠ paths.audit 漂移:"
        echo "$out" | sed 's/^/      /'
    else
        echo "  ✅ paths.audit clean"
    fi
fi

# B. hq_capabilities use_via 真验证
HQ_TEST="$DEV/tools/dev/lib/tools/report/hq_capabilities_test.py"
if [ -f "$HQ_TEST" ]; then
    out="$(python3 "$HQ_TEST" 2>&1 | tail -2 || true)"
    if echo "$out" | grep -q "FAIL [1-9]"; then
        echo "  ⚠ hq_capabilities use_via 有失败:"
        echo "$out" | sed 's/^/      /'
    else
        echo "  ✅ hq_capabilities use_via PASS"
    fi
fi

# C. catalog 缺失扫(一级 workspace 目录每包应有 catalog.yaml)
CATALOG_MAP="$DEV/tools/dev/lib/tools/report/catalog_module_map.py"
if [ -f "$CATALOG_MAP" ]; then
    missing="$(python3 -c "
import os,sys
root=os.path.expanduser('~/Dev')
miss=0
for d in sorted(os.listdir(root)):
    p=os.path.join(root,d)
    if not os.path.isdir(p): continue
    if d.startswith('.') or d.startswith('_'): continue
    if d in ('node_modules','.venv'): continue
    # 各 subdir 内若 README 提示是包 workspace, 检查 catalog.yaml
    for sub in sorted(os.listdir(p)) if os.path.isdir(p) else []:
        sp=os.path.join(p,sub)
        if not os.path.isdir(sp): continue
        if sub.startswith('.') or sub.startswith('_'): continue
        # 启发: 有 pyproject.toml/package.json 视为包
        if (os.path.exists(os.path.join(sp,'pyproject.toml'))
            or os.path.exists(os.path.join(sp,'package.json'))):
            if not os.path.exists(os.path.join(sp,'catalog.yaml')):
                miss+=1
print(miss)
" 2>/dev/null || echo "?")"
    if [ "$missing" != "0" ] && [ -n "$missing" ] && [ "$missing" != "?" ]; then
        echo "  ⚠ catalog 缺失 $missing 个包(跑 /module-map 补)"
    else
        echo "  ✅ catalog 覆盖完整"
    fi
fi

# D. SSOT-INDEX.md 自一致性（走 ssot_banner_audit + paths.py audit 兜底）
SSOT_CHK="$DEV/tools/dev/lib/tools/ssot/ssot_banner_audit.py"
if [ -f "$SSOT_CHK" ]; then
    out="$(python3 "$SSOT_CHK" 2>&1 | tail -3 || true)"
    if echo "$out" | grep -qE "(dead|FAIL|⚠)"; then
        echo "  ⚠ SSOT-INDEX 漂移:"
        echo "$out" | sed 's/^/      /'
    else
        echo "  ✅ SSOT-INDEX 自一致"
    fi
fi

# E. Claude harness 7 层健康巡检（铁律 #25 · skills/commands/hooks/agents/goals/memory/settings）
CC_HARNESS="$DEV/tools/dev/lib/tools/report/cc_harness_consistency.py"
if [ -f "$CC_HARNESS" ]; then
    # 用退出码判定(0=clean / 3=有 dead);避免 grep "dead" 命中"0 项 dead"误报
    if python3 "$CC_HARNESS" --strict >/tmp/cc-harness-audit.log 2>&1; then
        echo "  ✅ cc-harness 7 层 clean (skills/commands/hooks/agents/goals/memory/settings)"
    else
        echo "  ⚠ cc-harness 7 层有 dead:"
        tail -5 /tmp/cc-harness-audit.log | sed 's/^/      /'
    fi
fi

touch "$STAMP" 2>/dev/null
exit 0
