---
description: 部署族 — (default) 当前目录 / changed 按 git diff 扇出 / fanout 并行多站编辑+部署
---

# /deploy — 部署统一入口

`/deploy [<subcommand>] [args]`

未传子命令 → 部署当前目录（通用单站，需 deploy.sh）。

| 子命令 | 干啥 |
|---|---|
| (none) | 部署当前目录的项目（通用，适配任意 deploy.sh） |
| `<name>` | 部署 ~/Dev/<name> （从 repo-map 解析路径）— 实际同上，仅以路径区分 |
| `changed` | 扫 git diff，自动找受影响的站，批量部 |
| `fanout` | 并行多站编辑+构建+部署+验证，汇总状态表 |

> 新静态站首次上线（含 CF DNS/Access）→ `/site ship <name>`
> 多 repo 重构 + audit gate + worktree 隔离 → `/refactor fanout`

---

## (default) — 通用部署（当前目录或指定项目）

### 流程

#### 0. Pre-flight（任一失败立即停止，零副作用）
- 确认 `deploy.sh` 存在
- `git status` — 有未 commit → 警告 + 等用户确认
- VPS 连通性：`ssh root@104.218.100.67 "echo ok"` 超时 5s 报错退出

#### 1–3. 构建 + 部署
1. 自动检测前置：有 `frontend/` 且未构建 → `cd frontend && npm run build`
2. 运行 `bash deploy.sh`

#### 4. 验证（不得用 exit code 0 代替）
- 线上地址 → `curl -sI` 检查实际 HTTP（200/302 算过）
- 服务名 → `ssh root@104.218.100.67 "systemctl is-active <service>"` 必须返回 `active`
- 任一未过 → 报错，打印排查路径，不声称"完成"

#### 5. 记录历史（silent fail，不阻塞 deploy 结论）

部署完成（成败均记），追加一条 deploy 历史到 `ops_history.db`：

```bash
python3 ~/Dev/personal-kb/bin/ops_history.py record-deploy \
  --target "<repo or station name>" \
  --status "<success|failure|skipped>" \
  --branch "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)" \
  --commit "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)" \
  --duration "<elapsed seconds, optional>" \
  --notes "<optional context>" 2>/dev/null || true
```

**规则**：
- `2>/dev/null || true` 兜底 — DB 写失败不影响 deploy 结论（exit 0 仍代表 deploy 成功，仅历史漏记）
- `--target` 用 repo 目录名 / station id（与 services.ts 子域 id 对齐为佳）
- `--status` 严格三选一：success / failure / skipped
- 历史消费者：`ops-console /ops-history` 页面 30 天 deploy 频次柱状图

### 参数

`$ARGUMENTS` 可选：
- `--no-verify` — 跳过验证
- `--dry-run` — 只显示会执行什么，不实际跑

### 验证逻辑

从 CLAUDE.md 提取：
- `线上地址` / `https://xxx.tianlizeng.cloud` → curl 目标
- `systemd 服务` / `端口` → systemctl 检查目标

CLAUDE.md 无相关信息 → 跳过验证，提示用户补充。

### 规则
- 凭证在 `~/.personal_env`
- 不硬编码任何 URL / 服务名
- deploy.sh 失败立即停止，不验证

---

## changed — 按 git diff 扇出批量部署

`/deploy changed [--since origin/main] [--fast] [--dry]`

薄皮 — 调 `~/Dev/tools/dev/scripts/deploy-changed.sh`。一键"我刚改的几站上线"，不用手工列站名。

### Pre-flight（`--dry` 隐含，非 `--dry` 时强制）

执行前先打印：
- 哪些 repo 有变更（`git diff --name-only`）
- 推断的目标站点列表
- 是否涉及共享模块（devtools/lib / packages/*）→ 标"全量部署"警告

输出后**暂停等确认**。`--dry` 跳过暂停直接退出。

### 执行

```bash
bash ~/Dev/tools/dev/scripts/deploy-changed.sh $ARGUMENTS
```

### 脚本行为

扫三个来源 `git diff --name-only <since> HEAD`：

- `~/Dev/tools/dev/lib/` — 共享 Python 模块，变了 → **所有**已迁站点
- `~/Dev/stations/web-stack/` — `apps/<name>-web/*` 变了 → 对应站；`packages/*` 变了 → 所有站
- `~/Dev/hydro-*`、`~/Dev/stations/audiobook` — 该 repo 任意变动 → 对应站

去重合并调 `~/Dev/stations/web-stack/infra/deploy/deploy-batch.sh <sites...>`。

零变更 → "nothing changed" 退 0（不算错）。

### 何时跑
- 改完一两站准备上线，记不清改了哪些 repo
- CI / hook 自动选站
- 迭代连续改数次，只想 push 最后一版合集

### 不做
- 不自动 commit / push（你自己先 commit）
- 不跨 branch 对比（默认 HEAD~1；跨分支用 `--since origin/main`）
- 不部署 Streamlit legacy 站（只看 web-stack/apps/*-web 存在的站）

### 相关
- `~/Dev/stations/web-stack/infra/deploy/deploy.sh` — 单站底层
- `~/Dev/stations/web-stack/infra/deploy/deploy-batch.sh` — 多站并行
- `~/Dev/stations/web-stack/infra/deploy/sync-global.sh` — 共享 devtools/lib 同步
- `/api-smoke` — 部署前本地 smoke

---

## fanout — 并行多站部署编排

`/deploy fanout "<变更规格>" --repos <r1>,<r2>,... | --all [--dry-run]`

跨站 SSOT 同步或批量变更时使用。比 `/deploy changed` 更主动：你指定变更规格，编排器为每站并行 edit → build → deploy → verify。

### 参数
- `<变更规格>` — 自然语言描述，如「把 navbar 版本号 2.1 改到 2.2」
- `--repos` — 逗号分隔 repo 路径（相对 ~/Dev/）或绝对路径
- `--all` — 从 `~/Dev/stations/website/lib/services.ts` 读全部站
- `--dry-run` — 只打印每站 diff，不部

### 适用场景

| 场景 | 示例 |
|---|---|
| navbar/menus SSOT 改完，推送所有消费者 | `--all` |
| 指定几站同步同改动 | `--repos hydro-annual,hydro-capacity,hydro-runoff` |
| 验证跨站影响范围（不部） | `--dry-run` |

### 和现有命令的区别

| 命令 | 适合 |
|---|---|
| `/deploy` | 当前目录单站，有 deploy.sh |
| `/deploy changed` | git diff 自动检测受影响站，批量 |
| `/site ship` | 新站首次上线（含 CF DNS/Access 创建） |
| **`/deploy fanout`** | 已知改哪些站，并行 edit+deploy+verify |
| `/refactor fanout` | 重构（含 audit gate + worktree 隔离） |

### 执行流程

#### Step 0 — Pre-flight
- 解析 `--repos` 或 `--all`，列出目标
- 验证每个 repo 路径存在
- 打印操作清单，暂停等确认（`--dry-run` 跳过）

#### Step 1 — 并行 fanout
为每目标 repo **同时**起 subagent（`run_in_background: true`），每个接收：
- repo 绝对路径
- 变更规格
- 该站验证 URL（从 services.ts 推断）

每 subagent 执行：
1. 应用变更到该 repo
2. 有 `deploy.sh` → `bash deploy.sh`；web-stack app → `pnpm build`
3. `curl -sI <验证URL>` 检查 HTTP
4. 返回结构化结果：`{repo, status, commit_sha, deployed_url, http_status, issues}`

#### Step 2 — 汇总
编排层收集，输出表：

```
## Fanout Deploy Results

| Repo              | Status  | Commit     | Live URL                      | HTTP |
|-------------------|---------|------------|-------------------------------|------|
| hydro-annual      | ✅ done | abc1234    | hydro-annual.tianlizeng.cloud | 302  |
| hydro-capacity    | ❌ fail | —          | —                             | err  |
| stations/web-stack| ✅ done | def5678    | stack.tianlizeng.cloud        | 302  |
```

失败列出 `issues`，提示排查路径。

### 规则
- 每 subagent 独立运行，互不阻塞 — 一站失败不影响其他
- `--dry-run` 输出每站 diff，不部不 commit
- 变更规格有歧义 → subagent 先问编排层再问用户
- 凭证在 `~/.personal_env`，subagent 自动继承

### 参考
- services.ts: `~/Dev/stations/website/lib/services.ts`
- 底层：`~/Dev/stations/web-stack/infra/deploy/deploy-batch.sh`
- 单站验证：`/health sites --filter <name>`
