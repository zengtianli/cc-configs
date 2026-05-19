---
description: 检测 + 修复当前项目「实际状态」与「CC 配置文档」(CLAUDE.md / HANDOFF.md / MEMORY.md / README.md / paths / harness.yaml) 的漂移
---

# /sync-cc — CC 配置漂移修复

跨项目可用。任何 cwd 都能跑，自动适配（~/Dev 内项目额外加 paths + harness 检测）。

`/menus-audit` 管站群 yaml SSOT 的漂移，`/repo audit` 管 repo 完整性，`/sync-cc` 填补**项目 CC 配置文档** 与 **repo 实际状态** 漂移检测的空缺。

## 用法

```bash
/sync-cc                       # 默认: 全维度 check + 逐项问修
/sync-cc --check               # 只报告，不动文件（dry-run）
/sync-cc --apply               # 全部自动修（不问，仅推荐熟悉项目）
/sync-cc --only CLAUDE.md      # 只查 CLAUDE.md 维度
/sync-cc --only CLAUDE.md HANDOFF.md   # 多维度
/sync-cc --json                # 结构化输出（给脚本用）
```

## 检测维度（6 类）

底层执行 `python3 ~/Dev/tools/cc-configs/tools/cc-audit/cc_audit.py --cwd <cwd> --json`，读它的 findings。

| 维度 | 检测内容 | 典型 finding |
|---|---|---|
| `claude_md` | `CLAUDE.md` 的「文档结构」/「项目结构」节列的目录 vs `ls` 实际 + git log 提到的新增 | 实际有 `yanyuan/`，CLAUDE.md 没列 |
| `handoff_md` | `HANDOFF.md` 的 `- [ ]` 待办 vs git log --since=mtime 是否提到关键词 | 待办「修 carry 数学模型」已 commit，可能已 done |
| `memory_md` | `~/.claude/projects/*/memory/MEMORY.md` 引用的 `.md` 链接 → `test -f` | 引用了 `feedback_X.md`，文件已删 |
| `readme_md` | `README.md` / `README_CN.md` 内部链接 → `test -f` | 链接到 `docs/old.md`，文件已 mv |
| `paths` | 调 `paths.py audit --brief` | `paths: 56 / 41 dead / 0 drift` → 死链偏多 |
| `harness` | `~/Dev/tools/cc-configs/harness.yaml` 是否注册当前项目 + 注册 path 是否存在 | cwd 在 `~/Dev/X` 但未注册 |

外部项目（cwd 不在 `~/Dev/`）：自动跳过 `paths` + `harness` 维度。

## 流程（默认 / 修复模式）

### Phase 1 · check
```bash
python3 ~/Dev/tools/cc-configs/tools/cc-audit/cc_audit.py --cwd $(pwd) --json
```

读 JSON `findings`，按维度分组打印简表（terminal 友好）：

```
🔍 /sync-cc · {project_name}

✗ claude_md (2 warn / 1 error)
   - 实际有 yanyuan/，CLAUDE.md「文档结构」节没列  [warn]
   - CLAUDE.md 提到 docs/old.md，但目录已删     [error]

✗ handoff_md (1 info)
   - 「修 carry 数学模型」可能已 done — commit 47077d0 提到该关键词

✓ memory_md
✓ readme_md
✗ paths (1 warn) — 41 dead / 56 registered
✓ harness — international-assets 已注册

总计：3 warn / 1 error / 1 info → 修复? [Y/n/逐项]
```

### Phase 2 · 修复（用户答 Y 或 逐项）

每个 finding 由 CC 决定怎么修：

| 维度 | 自动修方案 |
|---|---|
| `claude_md` 实际有但未列 | 让 CC 写一段补丁 → 显示 diff → 用户批准 → Edit |
| `claude_md` 列了但实际没了 | 让 CC 删行 → 显示 diff → 用户批准 → Edit |
| `handoff_md` 待办可能 done | 显示 commit 链接 + ✓/×/skip 让用户选；✓ 则改 `- [x]` |
| `memory_md` 死链 | 列死链 → 用户决定删行 / 改路径 / 保留（标 outdated） |
| `readme_md` 死链 | 同上 |
| `paths` dead links | 提示跑 `paths.py scan-dead --strict` —— 不在本 command 内修 |
| `harness` 未注册 | 询问是否 `harness-sync init <path>` —— 不在本 command 内修 |

### Phase 3 · 二次验证

修完再跑一次 `cc_audit.py --cwd $(pwd) --brief`，确认 finding 数下降。

### Phase 4 · 输出汇总

```
✅ /sync-cc 完成

修了：
  - CLAUDE.md +12 行（补 yanyuan/ 章节）
  - HANDOFF.md ✓ 1 项已 done
  - MEMORY.md 删 1 条死链
  
跳过：
  - paths 41 dead — 单独跑 paths.py scan-dead

剩余 0 warn / 0 error → 干净
```

如还有 finding，列出 + 标记 `defer` 原因（如「需用户决策无法自动改」）。

## --check 模式

只跑 Phase 1，到 Phase 2 之前停。仅打印报告，零写入。CI / pre-commit 用这个。退出码：

- `0` — 全绿
- `1` — 有 warn / error

## --apply 模式

跳过 Phase 2 的逐项确认，能自动修的全部修（claude_md drift / handoff_md ✓ / 死链删行）。不能自动修的（如 harness 未注册）仍跳过。

⚠️ 仅在熟悉项目用。新项目用默认模式。

## --only 模式

```bash
/sync-cc --only claude_md handoff_md
```

只跑指定维度。dimension 名字见上表第一列。

## --json 模式

调底层脚本 `--json` flag 直接 stdout JSON，不交互。给 CI / 上游脚本用。schema：

```json
{
  "summary": {"total": 5, "warn": 3, "error": 1, "info": 1},
  "findings": [
    {
      "dimension": "claude_md",
      "severity": "warn",
      "title": "实际有 yanyuan/，CLAUDE.md 未列",
      "detail": "...",
      "suggestion": "在「文档结构」节追加 yanyuan/ 行",
      "auto_fixable": false
    }
  ]
}
```

## 跨项目示例

```bash
cd ~/Dev/content/investment
/sync-cc                   # 6 维度全跑

cd ~/Dev/Work/shared/bids
/sync-cc                   # paths/harness 跳过（不在 ~/Dev/）

cd ~/zls
/sync-cc --only claude_md  # 只查 CLAUDE.md
```

## 规则

- 默认 dry-run，破坏前必显示 diff + 用户批准
- `--apply` 不影响外部状态（不 git commit / push，只改文件）
- 修完不自动 commit — 用户自己决定（接 `/repo ship` 或 `/wrap handoff`）
- 不重造轮子：`paths` 调 `paths.py`，`menus_audit` 不重跑（重叠由 `/menus-audit` 负责）

## 相关

- `/menus-audit` — 站群 yaml SSOT 漂移
- `/repo audit` — repo 完整性
- `/wrap handoff` — 收尾时自动跑 `/sync-cc --check` 作为 gate（待集成）
- `/start` Phase 2 gap 分析 — 入场时跑轻量版（待集成）

## 实施

- 检测脚本：`~/Dev/tools/cc-configs/tools/cc-audit/cc_audit.py`
- Python stdlib only，无 pip 依赖
- 脚本只检测，不修复 — 修复由本 command MD 编排 CC 做
