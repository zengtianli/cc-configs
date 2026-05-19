---
description: 重构族 — dir 搬目录 + 零死链 / auto 自循环 patch+test+fix / fanout 多 repo 并行 audit gate / classify 项目分类 / migrate hydro 站迁 monorepo
---

# /refactor — 重构统一入口

`/refactor <subcommand> [args]`

| 子命令 | 干啥 |
|---|---|
| `dir` | 搬目录 + paths SSOT 维护 + 零死链验证（migration→mv→rewrite-dead→build-const→scan-dead） |
| `auto` | 自循环：定义验收脚本，CC 在 worktree 里 patch→test→fix 直到通过或超预算 |
| `fanout` | 并行多 repo 重构编排 — 每 repo 独立 worktree，audit 绿才 commit，supervisor 汇总 |
| `classify` | 扫描 ~/Dev 所有项目，产出技术栈 × 部署 × 活跃度 × 迁移目标的只读分类清单 |
| `migrate` | 把 hydro-* Streamlit 站迁成 monorepo apps/<name>-web 骨架 + FastAPI wrapper |

---

## dir — 搬目录 + 零死链

`/refactor dir <old> <new> [--dry] [--no-rewrite] [--reason "<text>"]`

搬目录到新位置，同时维护 `paths.yaml` SSOT + 批量重写老文档引用 + 零死链验证。

### 用法

```bash
/refactor dir ~/Dev/<old> ~/Dev/apps/<old> --reason "新 repo 归 labs 孵化"
/refactor dir ~/Dev/<old> ~/Dev/_archive/<old>-YYYY-MM --no-rewrite   # 归档场景跳 rewrite
/refactor dir ~/Dev/<old> ~/Dev/<new> --dry                           # 只预览
```

### 何时用
- 搬 `~/Dev/<xxx>` 目录到新位置（labs/ / stations/ / tools/ / content/ / _archive/）
- 触发词：搬目录 / 搬 repo / 归档项目 / refactor-dir / 把 X 挪到 Y
- **不是**：新建 stations 子项目（用 `/station-promote`）；CF 子域下线（用 `/site archive`）

### 执行（按顺序）

#### Step 1 · Preflight
- `<old>` 存在
- `<new>` 不存在
- `<old>` 是 git repo → `git status` 检查 clean（不阻断只警告）
- 失败即中止

#### Step 2 · 引用扫描（非阻塞预警）
Grep 扫 `<old>` 在以下位置出现次数（三种写法：`~/Dev/...` + `/Users/tianli/Dev/...` + 裸路径）：
- `~/Dev/tools/cc-configs/`
- `~/Dev/tools/configs/`
- `~/Dev/tools/dev/`
- `~/Dev/stations/docs/`
- `~/Dev/CLAUDE.md` / `HANDOFF.md` / `paths.yaml`

汇总作为 Step 5 rewrite-dead 影响面预估。

#### Step 3 · 追加 paths.yaml migration
`migrations:` 节追加（**双写 `~/` 和 `/Users/tianli/`**）：

```yaml
  # <--reason 内容>
  - {from: <old-home>, to: <new-home>}
  - {from: <old-absolute>, to: <new-absolute>}
```

顺序：放节末，除非 new 覆盖范围更小则靠前（避免父路径误伤子路径）。

#### Step 4 · 执行 mv

```bash
mkdir -p "$(dirname <new>)"
mv <old> <new>
```

#### Step 5 · rewrite-dead（若无 `--no-rewrite`）

```bash
python3 ~/Dev/tools/dev/lib/tools/paths.py rewrite-dead --dry-run   # 预览
# --dry 开启 → 中止
python3 ~/Dev/tools/dev/lib/tools/paths.py rewrite-dead             # 实跑
```

#### Step 6 · build-const 刷派生

```bash
python3 ~/Dev/tools/dev/lib/tools/paths.py build-const -w
```

#### Step 6.5 · rewrite-allow-missing

```bash
python3 ~/Dev/tools/dev/lib/tools/paths.py rewrite-allow-missing --apply
```

把 `allow_missing:` 段命中本次 migration 的 path 前缀整体平移到新路径。避免老前缀失效后"隐性死链"显形。

#### Step 6.6 · rebuild-symlinks

```bash
python3 ~/Dev/tools/dev/lib/tools/paths.py rebuild-symlinks --apply --backup
```

扫 ~/Dev 所有 symlink，对 `target` 命中 migration 但 dangling 的，按新 target 重建。`--backup` 写 `<link>\t<old>\t<new>` 到 `~/Dev/_archive/symlink-rewrites/<ts>.tsv`。

回滚：
```bash
while IFS=$'\t' read l o n; do ln -sfn "$o" "$l"; done < ~/Dev/_archive/symlink-rewrites/<ts>.tsv
```

#### Step 6.7 · scan-symlinks 验证（**硬阻塞**）

```bash
python3 ~/Dev/tools/dev/lib/tools/paths.py scan-symlinks --strict
```

- exit 0 = 0 个 migration-hit dangling，继续
- exit 1 = 还有未修，**禁止继续**（重跑 6.6；orphan / allow_missing dangling 不阻塞）

#### Step 7 · scan-dead 验证（**硬阻塞**）

```bash
python3 ~/Dev/tools/dev/lib/tools/paths.py scan-dead --strict
```

- exit 0 = 零新死链，继续
- 非 0 = 硬阻塞
  - **必须打印详情**：逐条列哪些文件 / 哪几行引用不存在路径（原样输出 stdout）
  - **必须给修复建议**：
    - 本次 mv 产生的新死链 → 修引用（Edit 原文件），或退到 Step 5 重跑
    - 历史债（mv 前就存在）→ Edit 修复，或父前缀加到 paths.yaml `allow_missing:` 节
    - 修完后**重跑 `/refactor dir <old> <new>`** 走完整流程，不要单独补跑 Step 7
  - **不自动回滚 mv**（新死链可能是历史债显露，回滚反而掩盖问题）；流程中止由用户决策

#### Step 8 · Summary

列：搬迁 `<old> → <new>` / 新加 migration 条数 / rewrite-dead 影响文件数 / paths_const.py 是否刷新 / 接下来建议 commit 的 repo

### 失败回滚

| 步 | 回滚 |
|---|---|
| 1 Preflight | 无改动 |
| 3 Edit paths.yaml | 工具原子报错 |
| 4 mv 失败 | Edit 删回 Step 3 加的 migration |
| 5 rewrite-dead | `mv <new> <old>` 反向 + 删 migration |
| 6.5 | git 撤 paths.yaml 改动 + 同 5 |
| 6.6 | 用 backup tsv 反向重建 + 同 5 |
| 6.7 仍 dangling | 重跑 6.6；仍失败查 backup tsv 手动恢复 |
| 7 新死链 | **不回滚** — 打详情让用户判断 |

### 不做
- 不动 GitHub remote
- 不自动 commit
- 不动 systemd / nginx / CF
- 不递归重命名 `<old>` 子目录
- 不合并目录（`<new>` 必须不存在）
- 不修 orphan symlink

### 依赖
- `~/Dev/paths.yaml`（SSOT 手写）
- `~/Dev/tools/dev/lib/tools/paths.py`（CLI）
- `~/Dev/tools/dev/lib/paths_const.py`（派生）

### 参考 playbook
完整 SOP + 踩坑：`~/Dev/tools/configs/playbooks/paths.md`

---

## auto — 自循环重构

`/refactor auto --goal "<目标>" --verify <脚本路径> --max-iter <N>`

大型重构变"过夜任务"。你定义目标 + 验收标准，CC 自循环执行，只在完成或超预算时叫你。

### 验收脚本约定

输出 JSON 到 stdout，exit 0 表示可继续：

```json
{"passing": false, "failures": ["hydro-annual build failed: missing tsconfig", "navbar missing in stack"]}
```

或：`{"passing": true, "failures": []}`

CC 解析 `failures`，**每轮只修第一条**，重新跑脚本，直到 `passing: true` 或 `max-iter`。

### 执行流程

#### Step 0 — 初始化
- `git worktree add /tmp/refactor-<timestamp> -b refactor/<goal-slug>`
- 在 worktree 改动，不污染主分支
- 跑一次脚本建 baseline

#### Step 1 — 自循环（最多 max-iter 次）

```
loop:
  1. 读当前 failures[0]
  2. 分析根因（不熟代码先调 mcp__auggie__codebase-retrieval(workspace=<repo>,
     request="<failures[0] 涉及的功能/模块语义描述>") 拿跨文件上下文），实施最小修复
  3. 跑脚本
  4. 如 passing: true → 跳出 → 报告成功
  5. 如 failures 没减少（卡住）→ 换策略，记录尝试
  6. 迭代 +1，未超 max-iter → 继续
```

CC **不向用户提问**，只在以下情况打断：
- 需要删除文件（需确认）
- 需要改 settings.json / CLAUDE.md（需确认）

#### Step 2 — 完成或超预算

**通过**：
- `git commit -m "autonomous-refactor: <goal>"`
- 输出摘要：迭代次数 / 修复路径 / diff 统计
- 询问是否 merge 回主

**超预算**：
- 输出已尝试策略清单和当前 failures
- 标注"卡在哪一步"
- worktree 保留供人工接力

### 验收脚本模板

```bash
#!/bin/bash
set -e
failures=()

cd ~/Dev/stations/web-stack
pnpm build 2>/dev/null || failures+=("web-stack pnpm build failed")

for site in hydro-annual hydro-capacity; do
  code=$(curl -sI -o /dev/null -w "%{http_code}" "https://$site.tianlizeng.cloud" 2>/dev/null)
  [[ "$code" == "200" || "$code" == "302" ]] || failures+=("$site HTTP $code")
done

if [ ${#failures[@]} -eq 0 ]; then
  echo '{"passing": true, "failures": []}'
else
  python3 -c "import json,sys; print(json.dumps({'passing': False, 'failures': sys.argv[1:]}))" "${failures[@]}"
fi
```

### 和 fanout 的区别

| 命令 | 适合 |
|---|---|
| `/deploy fanout` | **已知改什么**，让各站并行执行 |
| `/refactor fanout` | 已知改什么 + 重构（含 audit gate + worktree） |
| `/refactor auto` | **知道目标，不确定路径**，让 CC 自己摸索 |

### 规则
- worktree 在 `/tmp/refactor-<timestamp>/`
- 每迭代前 git commit（方便回滚）
- 不自动 push/merge
- 验收脚本本身报错（不是 JSON）→ 暂停通知用户

---

## fanout — 并行多 repo 重构

`/refactor fanout "<规格>" --repos <r1>,<r2>,... [--deploy] [--dry-run]`

跨 repo 批量重构。和 `/deploy fanout` 区别：本命令为**重构改动**设计，必须每 repo 在独立 worktree 跑完整 audit 后才允许 commit，绝不绕开质量闸。

### 用法

```bash
/refactor fanout "<规格>" --repos <r1>,<r2> [--deploy]
/refactor fanout "<规格>" --all [--deploy]
/refactor fanout "<规格>" --repos <r1>,<r2> --dry-run
```

- `<规格>` — 自然语言，如「把 api.py 的 df_to_json_safe 调用换成 v2」
- `--all` — 从 services.ts 读全部站
- `--deploy` — audit 绿的 repo 自动触发 `/deploy`（默认只 commit + push）
- `--dry-run` — 每 repo 只 patch + audit，不 commit

### 和现有命令区别

| 命令 | 适合 | audit gate | worktree |
|---|---|---|---|
| `/deploy` | 当前目录单站 | ✗ | ✗ |
| `/deploy changed` | git diff 扇出 | ✗ | ✗ |
| `/site ship` | 新站首次上线 | ✗ | ✗ |
| `/deploy fanout` | 已知改哪些站，并行 edit+deploy | ✗ | ✗ |
| **`/refactor fanout`** | **重构 + 严格 audit + worktree** | ✓ | ✓ |

### 适用场景
- 共享库 API 升级，改 N 个调用方
- 依赖版本批量升级 + 测试回归
- Lint 规则收紧
- 统一代码风格 / 引入新 helper 替换旧
- 架构级 rename / 移文件路径

### 执行流程

#### Step 0 — Pre-flight

- 解析 `--repos` / `--all` → 目标清单
- 每 repo 检查：
  - 存在 `.git`
  - 工作区干净（`git status --porcelain` 空）
  - 有 `origin` 远端
  - 有可执行的 audit 入口（`/repo audit` `/menus-audit` `/api-smoke` 视类型）
- 任一失败 → 报告清单，不继续

#### Step 1 — Fan-out（一个 message 起 N 个 Agent）

每目标 repo 并行启 Task Agent，每个拿到：
- repo 路径（独立 git worktree 挂到 `~/Dev/.worktrees/fanout-<timestamp>/<repo>`）
- 完整 `<规格>`（逐字传递不复述）
- Audit 入口（`/repo audit` / `/menus-audit` / `/api-smoke` / typecheck / build / 单元测试）
- 硬规则：**audit 不绿禁止 commit**；失败时把诊断写到 `<worktree>/FANOUT_FAIL.md`

单 Agent 内部：

```
1. cd worktree
2. （陌生 repo）mcp__auggie__codebase-retrieval(workspace=<repo>,
   request="<规格涉及的模块/接口/调用链>") 召回上下文
3. 按规格 Edit
4. 跑 audit：
   - hydro-*-web → pnpm typecheck && build
   - web-stack services → /api-smoke <name> --compute
   - 静态站 → /menus-audit 对应维度
   - 任何 repo → /repo audit
5. 绿 → git add -A && git commit -m "<规格>"
   不绿 → 写 FANOUT_FAIL.md，不 commit
6. 返回 { repo, passed, diff_summary, audit_output, fail_reason? }
```

并行性硬规则：
- 同一 message 必须 fan-out 全部 Agent（不允许串行）
- Agent 独立 worktree，不写同一目录

#### Step 2 — Supervisor 汇总

所有 Agent 返回后：

- **状态矩阵**：`| repo | passed | files | loc +/- | audit | next |`
- **diff 汇总**：每 repo 3-5 行关键改动摘要
- **分组**：A 绿（候选 push）/ B 红（保留 worktree，列 fail_reason）/ C 零改动（跳过）
- **决策点**：AskUserQuestion「A 组 N 个 audit 绿，是否 push？是否 `--deploy`？」

#### Step 3 — Push + 可选 Deploy

用户批准：
- A 组每 repo：`git push`，worktree merge 回主分支或保留作 PR
- `--deploy` 且有 deploy 入口 → 主工作区（不是 worktree）触发 `/deploy <name>`
- B 组 worktree 保留，报告末尾给 `cd <path>` 提示
- C 组 worktree 自动清理

#### Step 4 — 验收

- A 组实际 deploy 的 → `/health sites` 或对应 verify
- 最终报告：`N push / M deploy / K audit 红待人工 / X 零改动`
- 更新任务列表 / HANDOFF（大改动）

### 硬规则
- **audit 不绿禁 commit**，绝不 `--no-verify`
- **worktree 隔离**
- **全局 fan-out**（不允许串行起 Agent）
- **破坏性确认门**：Step 2 后必 AskUserQuestion
- **失败留痕**：失败 repo 的 worktree + FANOUT_FAIL.md 必须保留到用户确认

### 常见失败

| 失败 | 处理 |
|---|---|
| worktree 创建失败（'already checked out'） | `git worktree prune` 或换 `--worktree-dir` |
| audit 命令找不到 | Step 0 时跳过 |
| 规格模糊导致 Agent 各改各的 | Plan mode 重审；先 `--dry-run` 在 2 repo 验证 |
| push 被 protected branch 拒绝 | 报告标出，让人工开 PR |
| deploy 阶段某站失败 | 留 A 组已 push 不回滚；单独修失败站 |

---

## classify — 项目分类清单

`/refactor classify [--target <path>] [--format md|json|table] [--filter <regex>] [--include-archived]`

扫描 ~/Dev 所有项目，产出技术栈 × 部署 × 活跃度 × 迁移目标的**只读分类清单**。

不动目录，不改文件。与 `/tidy`（破坏性）互不干扰。

### 调用

```bash
python3 ~/Dev/tools/dev/lib/tools/classify.py $ARGUMENTS
```

### 输出列

| 列 | 含义 |
|---|---|
| Project | 目录名 |
| Stack | nextjs / streamlit / fastapi / python-cli / node / static / config / docs / monorepo / unknown |
| Deployed | 子域（从 services.ts 读）或 `—` |
| 30d Commits | 近 30 天 git 提交数 |
| Migration Target | `apps/<name>-web` / `already-nextjs` / `to-monorepo` / `keep-as-is` / `archive-candidate` / `fastapi-only` / `n/a` |
| Notes | 备注 |

### 典型用法

```
/refactor classify
/refactor classify --format table
/refactor classify --format json --filter hydro
/refactor classify --include-archived
```

### 判断规则（按优先级）
1. `next.config.*` → `nextjs`
2. `pnpm-workspace.yaml` / `turbo.json` → `monorepo`
3. `pyproject.toml` / `requirements.txt` 含 `streamlit` → `streamlit`
4. 同上含 `fastapi` 且无 streamlit → `fastapi`
5. 仅 `pyproject.toml` / `requirements.txt` → `python-cli`
6. `package.json`（非 next）→ `node`
7. `.claude/commands/` → `config`
8. `deploy.sh` / `generate.py` → `static`
9. 目录下 >50% 是 `.md` → `docs`
10. 其他 → `unknown`

### 迁移目标映射

| Stack | 目标 |
|---|---|
| streamlit | `apps/<name>-web` — pilot pattern，Python 保留 + FastAPI wrapper |
| nextjs | `already-nextjs` |
| fastapi | `fastapi-only` |
| python-cli / config / docs / node / monorepo | `keep-as-is` |
| static + deployed | `keep-as-is` |
| 无 git + 未部署 + 30 天静默 | `archive-candidate` |

### 不做
- 不搬目录（要搬走 `/tidy` 或手工）
- 不修改 `.git` / remote
- 不碰 `~/Dev/_archive/`（除非 `--include-archived`）

---

## migrate — hydro 站迁 monorepo

`/refactor migrate <repo> [--dry-run] [--force]`

把 hydro-* Streamlit 站迁成 `~/Dev/stations/web-stack/apps/<name>-web/` Next.js 骨架 + `~/Dev/<name>/api.py` FastAPI wrapper。**不碰原 app.py 和 src/**。

### 调用

```bash
python3 ~/Dev/tools/dev/lib/tools/stack_migrate_hydro.py $ARGUMENTS
```

### 产物
- `~/Dev/stations/web-stack/apps/<repo>-web/` — 完整 Next.js 骨架（package.json / next.config.mjs / tsconfig / tailwind / app/layout.tsx / app/page.tsx 用 `XlsxComputeForm` 模板）
- `~/Dev/<repo>/api.py` — FastAPI wrapper（`/api/health` + `/api/meta` + `/api/compute` 501 占位）
- `~/Dev/<repo>/pyproject.toml` — 已加 `fastapi` + `uvicorn`

### 后续手工
1. `cd ~/Dev/<repo> && uv add python-multipart`
2. `cd ~/Dev/<repo> && uv sync`
3. 把 `api.py::/api/compute` 的 501 占位替换成真实计算（参考 `~/Dev/stations/web-stack/services/hydro-reservoir/api.py::_run_reservoir()`）
4. `cd ~/Dev/stations/web-stack && pnpm install`
5. 本地联调：`cd ~/Dev/<repo> && uv run uvicorn api:app --port <api_port>` + `cd ~/Dev/stations/web-stack && pnpm --filter <repo>-web dev`

### 端口规则

脚本自动读 services.ts：
- `streamlit_port` — 原 Streamlit 端口
- `api_port` = streamlit_port + 100
- `web_port` = streamlit_port - 5400

### 相关
- `/refactor classify` — 全项目分类，判断哪些该迁
- `~/.claude/projects/-Users-tianli-Dev/memory/reference_stations_arch.md` — monorepo 速查
