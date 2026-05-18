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

适用：任意 ~/Dev 内 git repo。

不适用：
- 涉及 SSOT 多 repo cascade → 用 `/refactor dir`
- 站点部署 → 用 `/ship`
- 跨 repo 批量 push → 用 `python3 ~/Dev/devtools/scripts/tools/git_smart_push.py`

退出码：
- 0 成功 / dry / 用户取消
- 1 非 git repo
- 2 llm_client 导入失败
- 3 命中敏感文件
- 4 staging 为空
- 5 LLM 调用失败
- 6 git commit 失败
- 7 git push 失败
