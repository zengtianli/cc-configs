#!/usr/bin/env bash
# Stop hook: 每轮 LLM 回答结束 → 若 cwd 是 ~/Dev 内 git repo 且 dirty → auto_commit.py --no-confirm --push
#
# 设计：
#   - 全 ~/Dev 默认 ON（exclude list ~/.claude/auto-commit-exclude.txt 排外）
#   - 失败静默 exit 0，绝不阻塞 Stop
#   - 每 repo 一把 flock，防并发 race
#   - 日志: ~/.claude/state/auto-commit.log
#   - escape: ~/.claude/state/no-autocommit.marker (全局)
#            或 ~/.claude/state/no-autocommit-<session>.marker (当轮)
#
# 用户原话 2026-05-18: "全 ~/Dev 默认 ON, ok 其他按照你的意思"

set +e  # 绝不 fail

LOG="$HOME/.claude/state/auto-commit.log"
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR" 2>/dev/null

ts() { date '+%F %T'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

cwd="$(pwd)"

# 0. 全局 kill switch
[ -f "$STATE_DIR/no-autocommit.marker" ] && exit 0

# 1. cwd 必须在 ~/Dev 内
case "$cwd" in
  "$HOME/Dev"|"$HOME/Dev/"*) ;;
  *) exit 0 ;;
esac

# 2. 必须是 git repo
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# 3. 找到 repo root（hook fire 时 cwd 可能是子目录）
repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$repo_root" ] && exit 0

# 4. exclude list 检查
EXCLUDE_FILE="$HOME/.claude/auto-commit-exclude.txt"
if [ -f "$EXCLUDE_FILE" ]; then
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
    # 展开 ~ 和环境变量
    pattern="${pattern/#\~/$HOME}"
    case "$repo_root" in
      $pattern|$pattern/*)
        log "SKIP excluded: $repo_root (matched $pattern)"
        exit 0
        ;;
    esac
  done < "$EXCLUDE_FILE"
fi

# 5. dirty check
[ -z "$(git -C "$repo_root" status --porcelain 2>/dev/null)" ] && exit 0

# 6. plan mode (best effort env var detection)
[ "$CLAUDE_PLAN_MODE" = "1" ] && { log "SKIP plan mode: $repo_root"; exit 0; }

# 7. 解析 session id（Stop hook stdin 是 JSON）
SESSION_ID=""
if [ -t 0 ]; then
  :
else
  SESSION_ID=$(cat 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null || true)
fi
[ -n "$SESSION_ID" ] && [ -f "$STATE_DIR/no-autocommit-$SESSION_ID.marker" ] && exit 0

# 8. 检测远程 → 决定是否 --push
PUSH_FLAG="--push"
if ! git -C "$repo_root" remote get-url origin >/dev/null 2>&1; then
  PUSH_FLAG=""
  log "INFO local-only (no origin): $repo_root (will commit, skip push)"
fi

# 9. per-repo mkdir 原子锁防并发（macOS 无 flock）
lock_key=$(echo "$repo_root" | shasum | cut -c1-12)
LOCK_DIR="$STATE_DIR/auto-commit-${lock_key}.lock.d"
# 清理 stale lock（>120s 即僵死）
if [ -d "$LOCK_DIR" ]; then
  if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    log "WARN stale lock removed: $LOCK_DIR"
    rmdir "$LOCK_DIR" 2>/dev/null
  fi
fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "SKIP locked (concurrent run): $repo_root"
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# 10. 先 git add -A 把 untracked 也纳入（用户原话"无脑 commit push"），
#     commit-guard 会自动剔除派生产物 / >10MB 大文件 / .env 等敏感
cd "$repo_root" || exit 0
git add -A >> "$LOG" 2>&1

# 11. fire auto_commit.py
log "FIRE $repo_root (push=${PUSH_FLAG:-NO})"
timeout 90 python3 "$HOME/Dev/tools/dev/lib/tools/auto_commit.py" \
  --no-confirm $PUSH_FLAG --model claude-sonnet-4-6 \
  >> "$LOG" 2>&1
rc=$?
log "DONE $repo_root rc=$rc"

exit 0
