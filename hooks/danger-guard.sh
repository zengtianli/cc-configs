#!/usr/bin/env bash
# danger-guard.sh — PreToolUse/Bash 统一危险命令守门
# 合并 destruct-guard (L1 硬拦 exit 2) + preflight-auto (L2 软提示 exit 0)
#
# L1 (不可恢复): git filter-repo/branch · gc --prune=now/--aggressive · reflog expire=now
#                git reset --hard <非HEAD> · git clean -fd/-fx · find -delete
#                rm -rf 数据路径(Work/{shared,projects,water-*}/*.gpkg/*.gdb/data/gis) · rm -rf >100MB
# L2 (可恢复): 其它 rm -rf · chmod -R · chown -R · git push --force/-f
# Bypass: CC_DESTRUCT_OK=1 前缀(跳L1) · --dry-run/--no-act/`-n `(全跳)

set +e

# ---- 读 input + parse command ----
IN=""; [[ ! -t 0 ]] && IN=$(cat 2>/dev/null)
[[ -z "$IN" && -n "$CLAUDE_TOOL_INPUT" ]] && IN="$CLAUDE_TOOL_INPUT"
[[ -z "$IN" && -n "$1" ]] && IN="$1"
[[ -z "$IN" ]] && exit 0

CMD=$(command -v jq >/dev/null && echo "$IN" | jq -r '.command // ""' 2>/dev/null)
[[ -z "$CMD" ]] && CMD=$(echo "$IN" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('command',''))
except: pass" 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# ---- Bypass ----
echo "$CMD" | grep -qE -- '--dry-run|[[:space:]]-n[[:space:]]|--no-act' && exit 0
echo "$CMD" | grep -qE '^[[:space:]]*CC_DESTRUCT_OK=1[[:space:]]' && exit 0

# ---- L1 检测 ----
L1=""; R=""; T=""
if echo "$CMD" | grep -qE 'git[[:space:]]+filter-(repo|branch)'; then
  L1="filter"; R="git filter-repo/branch (永久重写)"; T="整个 repo"
elif echo "$CMD" | grep -qE 'git[[:space:]]+gc[[:space:]]+.*(--prune=now|--aggressive)'; then
  L1="gc"; R="git gc --prune=now/--aggressive"; T=".git"
elif echo "$CMD" | grep -qE 'git[[:space:]]+reflog[[:space:]]+expire.*--expire=(now|0)'; then
  L1="reflog"; R="reflog expire (清防恢复)"; T=".git/logs"
elif echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+'; then
  RT=$(echo "$CMD" | sed -nE 's/.*git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+([^ &|;]+).*/\1/p')
  [[ -n "$RT" && "$RT" != "HEAD" ]] && { L1="reset"; R="git reset --hard $RT (丢 commit)"; T="HEAD+wt"; }
elif echo "$CMD" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[fdx]*[fdx]*[dx]'; then
  L1="clean"; R="git clean -fd/-fx"; T="working tree"
elif echo "$CMD" | grep -qE 'find[[:space:]].*-delete\b'; then
  L1="find-del"; R="find -delete (不入 Trash)"; T="find 匹配集"
fi

# rm -rf → L1 (数据路径 / 大目录) 或后续 L2
if [[ -z "$L1" ]] && echo "$CMD" | grep -qE 'rm[[:space:]]+(-[rRfF]+|--recursive|--force)[[:space:]]+'; then
  RT=$(echo "$CMD" | sed -nE 's/.*rm[[:space:]]+-[rRfF]+[[:space:]]+([^ &|;]+).*/\1/p' | head -1)
  RT="${RT//\~/$HOME}"
  if echo "$RT" | grep -qE '(/Work/(shared|projects|water-)|\.gpkg|\.gdb|/data/|/gis/|^~/Archives/scatter/gis)'; then
    L1="rm-data"; R="rm -rf 数据敏感路径"; T="$RT"
  elif [[ -d "$RT" ]]; then
    SZ=$(du -sk "$RT" 2>/dev/null | cut -f1)
    [[ -n "$SZ" && "$SZ" -gt 102400 ]] && { L1="rm-large"; R="rm -rf ${SZ}KB (>100MB)"; T="$RT"; }
  fi
fi

# mv home 顶层目录 → L1 (铁律 #19: 必走 /refactor dir, 不许裸 mv)
# 检测: source 是 $HOME/<非隐藏顶层> 且为目录, dest 不在 ~/.Trash; CC_DESTRUCT_OK=1 已在前面 bypass
if [[ -z "$L1" ]] && echo "$CMD" | grep -qE '(^|[[:space:]&|;])mv[[:space:]]'; then
  HIT=$(echo "$CMD" | HOME="$HOME" python3 -c '
import sys, shlex, os, re
HOME = os.environ["HOME"]
cmd = sys.stdin.read()
for piece in re.split(r"&&|\|\||[;&|]|\n", cmd):
    piece = piece.strip()
    if not re.match(r"^mv(\s|$)", piece): continue
    try: args = shlex.split(piece)
    except Exception: continue
    posargs = [a for a in args[1:] if not a.startswith("-")]
    if len(posargs) < 2: continue
    dest = posargs[-1]
    dest_exp = os.path.expanduser(dest.replace("$HOME", HOME))
    if "/.Trash" in dest_exp: continue   # 入 Trash 是回收,放过
    for s in posargs[:-1]:
        s_exp = os.path.expanduser(s.replace("$HOME", HOME))
        if not s_exp.startswith(HOME + "/"): continue
        rel = s_exp[len(HOME)+1:].rstrip("/")
        if "/" in rel or rel.startswith(".") or not rel: continue   # 非顶层/隐藏跳过
        if not os.path.isdir(s_exp): continue                       # 仅拦目录
        print(f"{s} → {dest}"); sys.exit(0)
' 2>/dev/null)
  if [[ -n "$HIT" ]]; then
    L1="mv-home-top"; R="裸 mv home 顶层目录 (铁律 #19, 必走 /refactor dir)"; T="$HIT"
  fi
fi

if [[ -n "$L1" ]]; then
  if [[ "$L1" == "mv-home-top" ]]; then
    cat >&2 <<EOF

⛔ danger-guard L1 拦截 — 裸 mv home 顶层目录 (铁律 #19)
  触发: $R
  对象: $T
  命令: ${CMD:0:300}

  目录迁移 = SSOT 原子事务,禁裸 mv。正确流程:
    1) /refactor dir <old> <new>   ← 原子事务: paths.yaml migration + mv + rewrite-dead + rebuild-symlinks + audit
    2) 已走 SSOT 显式绕过:           CC_DESTRUCT_OK=1 <原命令>
  Trash 回收除外: mv ... ~/.Trash/... 自动放过
EOF
    exit 2
  fi
  BK="cc-pre-destruct-$(date +%s)-${L1}"
  cat >&2 <<EOF

⛔ danger-guard L1 拦截 (不可恢复)
  触发: $R
  对象: $T
  命令: ${CMD:0:300}

  必须先 Trash 备份:
    mkdir -p ~/.Trash/$BK && cp -Rc <target> ~/.Trash/$BK/
  备份后跑: CC_DESTRUCT_OK=1 <原命令>
EOF
  exit 2
fi

# ---- L2 软提示 ----
if echo "$CMD" | grep -qE '(\brm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f|\bgit[[:space:]]+push[[:space:]]+(--force|-f)|\bchmod[[:space:]]+-R|\bchown[[:space:]]+-R)'; then
  cat >&2 <<EOF
⚠ danger-guard L2 提示 (可恢复但危险)
  命令: $(echo "$CMD" | head -c 120)
  建议先跑 /preflight 列爆炸半径 (不阻塞)
EOF
fi

exit 0
