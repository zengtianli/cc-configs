---
description: 智能 commit · Opus 4.7 看 diff 写 conventional commit msg · 含安全 guard
---

# /commit — 智能 commit

`/commit [--push]`

跑 `python3 ~/Dev/devtools/lib/tools/auto_commit.py "$@"`。

cwd 必须在 git repo 内。脚本会：
1. 扫敏感文件（.env / .key / credentials → 立即拒绝）
2. git status 展示 + 选 staging 范围（默认 git add -u + untracked 询问）
3. git diff --cached → Opus 4.7 → conventional commit msg
4. 用户确认 / 编辑（`$EDITOR`）/ 拒绝
5. commit (+ optional push)

CLI flags：
- `--push` commit 后 push（默认不 push）
- `--no-confirm` 不交互，直接用 LLM msg commit（CI / Raycast 用）
- `--dry` 只生成 msg 不 commit（看质量）
- `--model claude-opus-4-7` 默认；可换 sonnet/haiku
- `--scope <files>` 限定 staging 哪些文件
- `--allow-derived` 关闭派生 guard（极少用，详见 [[commit-guard]] skill）

## commit-guard（默认 ON · 2026-05-18）

`auto_commit.py` 默认走 [[commit-guard]]：扫 staging 识别派生产物 / 缓存 / 备份 / 作废副本 / 系统元数据 / >10MB 大文件，**自动 unstage** 并 warn。规则源 `~/Dev/tools/cc-configs/skills/commit-guard/SKILL.md`。

需要保留派生入仓 → `--allow-derived`。

适用：任意 ~/Dev 内 git repo。

## 多 repo 递归 commit（默认并行）

参数含「全部 / 递归 / 所有 / N 个」或显式 `--recursive` → **必须并行**（铁律 [[agentteam-parallel-default]]）。

模板：
```bash
REPOS=()
while IFS= read -r gitdir; do
  repo=$(dirname "$gitdir")
  [[ "$repo" == *"/.claude/worktrees/"* ]] && continue
  st=$(cd "$repo" 2>/dev/null && git status --porcelain 2>/dev/null)
  [ -n "$st" ] && REPOS+=("$repo")
done < <(find ~/Dev -name ".git" -not -path "*/node_modules/*" -not -path "*/_archive/*" 2>/dev/null)

printf '%s\n' "${REPOS[@]}" | xargs -P 8 -I{} bash -c '
  cd "$1" && git add -A && python3 ~/Dev/devtools/lib/tools/auto_commit.py --no-confirm --push 2>&1 | tail -3
' _ {}
```

并发 P=8（LLM rate limit 安全区）。**禁止逐个串行跑**——24 repo 串行 = 6+ min，并行 = 45s。

不适用：
- 涉及 SSOT 多 repo cascade → 用 `/refactor dir`
- 站点部署 → 用 `/ship`

退出码：
- 0 成功 / dry / 用户取消
- 1 非 git repo
- 2 llm_client 导入失败
- 3 命中敏感文件
- 4 staging 为空
- 5 LLM 调用失败
- 6 git commit 失败
- 7 git push 失败
