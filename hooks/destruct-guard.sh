#!/usr/bin/env bash
# destruct-guard.sh — PreToolUse hook for Bash tool
# 目的：拦截 git history rewrite / 强力清理类不可恢复破坏性操作，强制先备份到 ~/.Trash/
# 触发事故：2026-05-19 git filter-repo 永久丢 1.85 GB GPKG
#
# 触发模式（高 blast radius · 不可恢复）：
#   - git filter-repo / git filter-branch
#   - git gc --prune=now / --aggressive
#   - git reflog expire --expire=now
#   - git reset --hard <非 HEAD>（reset 到具体 SHA / HEAD~N / 其它分支）
#   - git clean -fd / -fx
#   - rm -rf 目标 > 100MB 或在 ~/Dev/Work/ 数据目录内
#
# 触发后：exit 2 + stderr 给出 trash 包装命令；user 见 stderr 重新发指令
# 显式 bypass：命令前缀 `CC_DESTRUCT_OK=1` （知情情况下放行）
#
# 任何意外（JSON 解析失败 / 工具缺失）→ exit 0（不阻断）

set +e
PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# ---------- 1. 读取 tool input ----------
TOOL_INPUT=""
if [[ ! -t 0 ]]; then
  TOOL_INPUT=$(cat 2>/dev/null || echo "")
fi
[[ -z "$TOOL_INPUT" && -n "$CLAUDE_TOOL_INPUT" ]] && TOOL_INPUT="$CLAUDE_TOOL_INPUT"
[[ -z "$TOOL_INPUT" && -n "$1" ]] && TOOL_INPUT="$1"
[[ -z "$TOOL_INPUT" ]] && exit 0

# ---------- 2. 解析 command ----------
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
if [[ -z "$CMD" ]]; then
  CMD=$(echo "$TOOL_INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[[ -z "$CMD" ]] && exit 0

# ---------- 3. Bypass token ----------
if echo "$CMD" | grep -qE '^[[:space:]]*CC_DESTRUCT_OK=1[[:space:]]'; then
  exit 0
fi

# ---------- 4. 检测触发模式 ----------
TRIGGER=""
TRIGGER_REASON=""
TARGET_HINT=""

# (a) git filter-repo / filter-branch
if echo "$CMD" | grep -qE 'git[[:space:]]+filter-(repo|branch)'; then
  TRIGGER="filter-rewrite"
  TRIGGER_REASON="git filter-repo / filter-branch (永久重写 history + 删 working tree + expire reflog)"
  TARGET_HINT="整个 repo（含 working tree 内的目标 path）"
fi

# (b) git gc --prune=now / --aggressive
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'git[[:space:]]+gc[[:space:]]+.*(--prune=now|--aggressive)'; then
  TRIGGER="gc-prune"
  TRIGGER_REASON="git gc --prune=now / --aggressive (立即清 dangling blob，不可恢复)"
  TARGET_HINT="整个 .git 目录的 dangling objects"
fi

# (c) git reflog expire
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'git[[:space:]]+reflog[[:space:]]+expire.*--expire=(now|0)'; then
  TRIGGER="reflog-expire"
  TRIGGER_REASON="git reflog expire --expire=now (清 reflog 防恢复)"
  TARGET_HINT="整个 .git/logs"
fi

# (d) git reset --hard <非 HEAD>
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+'; then
  RESET_TARGET=$(echo "$CMD" | sed -nE 's/.*git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+([^ &|;]+).*/\1/p')
  # 只 reset 到 HEAD 是安全的（仅清 working tree 修改），其它是危险的（丢 commit）
  if [[ -n "$RESET_TARGET" && "$RESET_TARGET" != "HEAD" ]]; then
    TRIGGER="reset-hard-ref"
    TRIGGER_REASON="git reset --hard $RESET_TARGET (丢弃当前 → 目标之间的 commit，不可恢复)"
    TARGET_HINT=".git/HEAD + working tree"
  fi
fi

# (e) git clean -fd / -fx (含 -d 或 -x 才危险，单纯 -f 不动 .gitignored)
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[fdx]*[fdx]*[dx]'; then
  TRIGGER="git-clean-deep"
  TRIGGER_REASON="git clean -fd/-fx (删未追踪 + ignored 文件，不进 Trash)"
  TARGET_HINT="working tree 内全部 untracked / ignored"
fi

# (f) rm -rf 大目标（~/Dev/Work/ 数据 / ~/Dev/Work/shared/ / 任何 .gpkg .gdb .shp 字面 / 任何 git repo 内 data/）
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'rm[[:space:]]+(-[rRfF]+|--recursive|--force)[[:space:]]+'; then
  RM_TARGET=$(echo "$CMD" | sed -nE 's/.*rm[[:space:]]+-[rRfF]+[[:space:]]+([^ &|;]+).*/\1/p' | head -1)
  RM_TARGET="${RM_TARGET//\~/$HOME}"
  # 危险路径模式
  if echo "$RM_TARGET" | grep -qE '(/Work/(shared|projects|water-)|/\.gpkg|/\.gdb|/data/|/gis/|^~/gis)'; then
    TRIGGER="rm-rf-data"
    TRIGGER_REASON="rm -rf 命中数据敏感路径"
    TARGET_HINT="$RM_TARGET"
  fi
  # 大目录（实测 size）
  if [[ -z "$TRIGGER" && -d "$RM_TARGET" ]]; then
    SIZE_KB=$(du -sk "$RM_TARGET" 2>/dev/null | cut -f1)
    if [[ -n "$SIZE_KB" && "$SIZE_KB" -gt 102400 ]]; then  # >100 MB
      TRIGGER="rm-rf-large"
      TRIGGER_REASON="rm -rf 目标 ${SIZE_KB} KB (>100 MB)"
      TARGET_HINT="$RM_TARGET"
    fi
  fi
fi

# (g) find ... -delete
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'find[[:space:]].*-delete\b'; then
  TRIGGER="find-delete"
  TRIGGER_REASON="find -delete (批量 unlink，不进 Trash)"
  TARGET_HINT="find 命令的 -path/-name 匹配集"
fi

[[ -z "$TRIGGER" ]] && exit 0

# ---------- 5. 输出阻断信息 ----------
TS=$(date +%s)
BACKUP_NAME="cc-pre-destruct-${TS}-${TRIGGER}"

cat >&2 <<EOF

⛔ destruct-guard 拦截：高危不可恢复操作

  触发：$TRIGGER_REASON
  对象：$TARGET_HINT
  命令：${CMD:0:300}

  ── 必须先做 Trash 备份 ──

  推荐流程（cwd 选合适的目标）：
  1) 备份目标到 ~/.Trash/$BACKUP_NAME/
     mkdir -p ~/.Trash/$BACKUP_NAME
     cp -Rc <target> ~/.Trash/$BACKUP_NAME/        # APFS clonefile 零拷贝瞬时完成
     # 或：cp -R <target> ~/.Trash/$BACKUP_NAME/   # 普通拷贝

  2) 验证备份完整：
     ls -la ~/.Trash/$BACKUP_NAME/

  3) 备份后跑原命令前缀 CC_DESTRUCT_OK=1 放行：
     CC_DESTRUCT_OK=1 <原命令>

  对 git filter-repo 类的特殊提醒：
  - 同 repo 内 \`git tag backup-*\` 不算备份（filter-repo 一并 rewrite）
  - cp 必须到 ~/.Trash/ 或 ~ 外部，不能在 repo 内
  - 跑完立即 \`ls\` 验 working tree（filter-repo 默认会删 working tree 文件）

  规则来源：[[trash-everything-protocol]] · [[filter-repo-working-tree-loss]]
EOF

exit 2
