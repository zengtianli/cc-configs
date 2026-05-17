#!/usr/bin/env bash
# deploy-guard.sh — PreToolUse hook for Bash tool
# 目的：拦截绕过现成 deploy.sh / Makefile / /site ship 自己 SSH 编译的事故
# 参考：Session 10c7c364 案例
#
# 输入：tool input JSON（command 字段）
# 解析顺序：stdin JSON → $CLAUDE_TOOL_INPUT → $1
# 触发模式：
#   - ssh root@104.218.100.67 / ssh.*tianlizeng
#   - cd /var/www/
#   - npm run build / next build（且 cwd 在 ~/Dev/stations/ 下）
#   - rsync .* root@.*:/var/www/
# 触发后：
#   - cwd 有 deploy.sh / Makefile → exit 2 + stderr 警告
#   - 无 → exit 0
# 任何意外（JSON 解析失败 / 工具缺失）→ exit 0（不阻断）

set +e  # 不要因任何错退出
PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# ---------- 1. 读取 tool input ----------
TOOL_INPUT=""
if [[ ! -t 0 ]]; then
  # stdin 有内容
  TOOL_INPUT=$(cat 2>/dev/null || echo "")
fi
[[ -z "$TOOL_INPUT" && -n "$CLAUDE_TOOL_INPUT" ]] && TOOL_INPUT="$CLAUDE_TOOL_INPUT"
[[ -z "$TOOL_INPUT" && -n "$1" ]] && TOOL_INPUT="$1"
[[ -z "$TOOL_INPUT" ]] && exit 0

# ---------- 2. 解析 command 字段 ----------
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
# 终极 fallback：正则抠
if [[ -z "$CMD" ]]; then
  CMD=$(echo "$TOOL_INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[[ -z "$CMD" ]] && exit 0

# ---------- 3. 检测触发模式 ----------
TRIGGER=""
TRIGGER_REASON=""

# (a) SSH 进生产 VPS
if echo "$CMD" | grep -qE 'ssh[[:space:]]+(root@)?104\.218\.100\.67|ssh[[:space:]]+[^|]*tianlizeng'; then
  TRIGGER="ssh-prod"
  TRIGGER_REASON="SSH 直连生产 VPS"
fi

# (b) cd /var/www/
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'cd[[:space:]]+/var/www/'; then
  TRIGGER="cd-varwww"
  TRIGGER_REASON="cd /var/www/（应在 VPS 端由 deploy 工具操作）"
fi

# (c) npm run build / next build —— 仅当 cwd 在 ~/Dev/stations/ 下时触发
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE '(npm[[:space:]]+run[[:space:]]+build|next[[:space:]]+build|pnpm[[:space:]]+build|yarn[[:space:]]+build)'; then
  if [[ "$PROJECT_CWD" == "$HOME/Dev/stations/"* || "$PWD" == "$HOME/Dev/stations/"* ]]; then
    TRIGGER="local-build-stations"
    TRIGGER_REASON="在 ~/Dev/stations/ 下手动 build（应走 deploy.sh / /site ship）"
  fi
fi

# (d) rsync 推生产
if [[ -z "$TRIGGER" ]] && echo "$CMD" | grep -qE 'rsync[^|]*[[:space:]]+root@[^:]*:/var/www/'; then
  TRIGGER="rsync-prod"
  TRIGGER_REASON="rsync 直推生产 /var/www/"
fi

[[ -z "$TRIGGER" ]] && exit 0

# ---------- 4. 检查 cwd 有无现成 deploy 工具 ----------
# 优先用 PROJECT_CWD（CC 项目根），fallback 当前 PWD
CHECK_DIR="$PROJECT_CWD"
[[ ! -d "$CHECK_DIR" ]] && CHECK_DIR="$PWD"

HAS_DEPLOY=0
DEPLOY_HINT=""

if [[ -f "$CHECK_DIR/deploy.sh" ]]; then
  HAS_DEPLOY=1
  DEPLOY_HINT="bash $CHECK_DIR/deploy.sh"
elif [[ -f "$CHECK_DIR/Makefile" ]] && grep -qE '^(deploy|ship|release):' "$CHECK_DIR/Makefile" 2>/dev/null; then
  HAS_DEPLOY=1
  DEPLOY_HINT="cd $CHECK_DIR && make deploy/ship/release（看 Makefile target）"
elif [[ -f "$CHECK_DIR/paths.yaml" ]] || [[ -f "$CHECK_DIR/.claude/settings.json" ]]; then
  # 可能是 station 项目，建议 /site ship
  if [[ "$CHECK_DIR" == "$HOME/Dev/stations/"* ]] || ls "$CHECK_DIR"/{deploy,ship,release}* 2>/dev/null | grep -q .; then
    HAS_DEPLOY=1
    DEPLOY_HINT="/site ship <name>（或查项目 CLAUDE.md 找 deploy SOP）"
  fi
fi

# 5. 决策
if [[ $HAS_DEPLOY -eq 1 ]]; then
  echo "⚠ 检测到绕过现成 deploy.sh / Makefile / /site ship。" >&2
  echo "   触发：$TRIGGER_REASON" >&2
  echo "   命令：${CMD:0:200}" >&2
  echo "   建议：$DEPLOY_HINT" >&2
  echo "   若确需绕过，明确说理由 + 让用户批准。" >&2
  exit 2
fi

# 无现成工具 → 放行
exit 0
