---
name: ship
description: 单站点 commit + push + deploy + 健康检查一条龙组合 skill。串联 /repo ship → /deploy → /health project → live URL → /wrap retro --quick，确保「完成 = 上线 + 验 200」零尾巴。用户说 "/ship X" / "ship X" / "把 X 发上去" / "X 上线" / "把 X 部上去" 时触发。**硬约束**：必须在 station repo 目录下跑（cwd 是 ~/Dev/stations/<name> 或 ~/Dev/<station>），~/Dev 根 / 非部署项目 → 立即拒绝。
---

# /ship — 一条命令把改动发上线

**核心理念**：全局铁律「"完成" = commit + push + deploy + 验证 live URL」（`~/.claude/CLAUDE.md` §执行铁律 2）。手动串 4 条 slash 容易漏一环（push 完忘 deploy / deploy 完不验 / 验完不 retro）。本 skill 把它焊死成一个原子操作 — **要么全过，要么明确报失败卡在哪步，不允许声明完成**。

**与 /repo ship 的关系**：`/repo ship` 只管 commit + push。`/ship` 是**站点级**编排，包它在内 + deploy + 验证 + retro。**单 repo 用 /ship，跨多 repo 批量推用 /repo ship**。

---

## 触发场景

用户说以下任一：
- `/ship` / `/ship <name>` （显式 slash）
- "ship X" / "把 X 发上去" / "X 上线" / "把 X 部上去"
- "提交并部署" / "推上线" / "上一下 / 发一下"

**不触发**（必走单独命令）：
- "只 commit 不 deploy" → `/repo ship`
- "只 deploy 不 commit"（已 push 过）→ `/deploy`
- 跨多 repo 批量 commit + push（无 deploy）→ `/repo ship all` / `/repo ship a b c`
- 多站并行 fanout deploy → `/deploy fanout`
- 新站首次上线（含 CF DNS / Access 创建）→ `/site ship <name>`

---

## 硬约束

### 必须在部署项目目录下跑

**前置 1**：cwd 必须满足下列任一：
- `~/Dev/stations/<name>/` 或 `~/Dev/stations/<name>/apps/<sub>/`（station monorepo 子目录）
- `~/Dev/<name>/` 且该目录含 `deploy.sh` 或 CLAUDE.md 声明的部署信息
- `~/Dev/stations/web-stack/apps/<name>-web/` 类前端子项目

**前置 2**：cwd 是 `~/Dev` 根 / 非 git repo / 无 deploy target → **立即拒绝**：
```
✗ /ship 拒绝：当前目录 <cwd> 不是部署项目。
  - 需要 commit + push 多 repo → 用 /repo ship
  - 需要进入某 station → cd ~/Dev/stations/<name> 后重跑
```
**不**尝试猜测目标，**不**列出选项让用户选，**直接报错退**。用户带显式参数 `/ship <name>` → 先 `cd ~/Dev/stations/<name>` 再继续。

### 失败 = 立即停 + 明确报第 N 步

任一步失败立即 abort，**不**继续后续步，**不**声明完成。stderr 必须明确包含：
```
✗ /ship 失败：卡在第 <N> 步「<step name>」
  原因：<具体错误>
  排查：<下一步建议或日志路径>
  已完成步骤：<1..N-1 列表>
  未完成步骤：<N+1..5 列表>
```

**绝对禁止**：
- ❌ 把"deploy.sh 跑成功"等同于"已上线"（必须 curl -sI 200/302 才算）
- ❌ 失败后跳过卡住的步直接进下一步
- ❌ 任一步失败仍输出"✓ 已完成"汇总

---

## 编排步骤（5 步）

> **执行前**：先 `git status` 看 cwd 是否有改动；无改动且无传 `--redeploy` → 跳过 Step 1（仅 deploy + 验证 + retro）。

### Step 1 · `/repo ship <name>` — commit + push

- 自动从 cwd 解析 station 名 → 调 `/repo ship` 子流程
- `/repo ship` 内部：`git status --short` → `git diff --stat` → `git add -A` → 生成 conventional commit message → commit + push 一步
- **跳过条件**：`git status --porcelain` 为空（无 uncommitted changes）→ 打印「Step 1 skipped: nothing to commit」继续
- **失败**：push 失败（behind remote / 网络 / 权限）→ 立即按硬约束 abort，**不**强 push、**不**自动 rebase

### Step 2 · `/deploy` — 触发 deploy.sh

- 默认无参数 → 部署当前目录（`/deploy` default 模式自动识别 cwd 是哪个 station）
- 显式覆盖：`/ship <name>` → 隐含 `/deploy <name>`（从 repo-map 解析路径）
- 内部走 `/deploy` 标准 0-5 阶段：pre-flight（VPS 连通 + deploy.sh 存在）→ frontend 构建 → 跑 deploy.sh → 验证（curl + systemctl）→ 记录到 ops_history.db
- **失败**：deploy.sh exit 非 0 / VPS 连不上 / systemctl is-active 非 active → abort

### Step 3 · `/health project <name>` — curl 200 检查

- 调 `/health project <name>` 实测线上 URL（`curl -sI` 看 HTTP 200/301/302）
- **不**复述 deploy.sh 报告或 services.ts 字面量 — 实测才算（铁律 §11 实测验证）
- 看到 `198.18.x` 段 IP（Shadowrocket fake-IP）→ 报警「DNS 可能未生效，再等 30s 重试」
- **失败**：HTTP 5xx / 超时 / DNS 不存在 → abort

### Step 4 · 打印 live URL

```
✓ Live: https://<sub>.tianlizeng.cloud (HTTP <code>)
```

URL 从 cwd 项目 CLAUDE.md「线上地址」节 / `~/Dev/stations/website/lib/services.ts` 推断。两源都无 → Step 3 阶段就该报错。

### Step 5 · `/wrap retro --quick` — 一句话 retro（可选）

- 默认开启，写一行 retro 到 memory（不动产物文件）
- **关闭**：用户传 `--no-retro` / `/ship <name> --no-retro` → 整步跳过
- 失败不阻塞 ship 结论（silent fail）— 这步是观测，不是关键路径

---

## 参数

- 无参数 → 部署当前目录（必须满足硬约束「前置 1」）
- `<name>` → 显式指定 station（自动 `cd ~/Dev/stations/<name>` 后跑）
- `--no-retro` → 跳过 Step 5
- `--redeploy` → 跳过 Step 1（即使有未 commit 改动也不 commit），直接 deploy + 验证
- `--dry-run` → 打印每步会执行什么，不实际跑

---

## 反模式

- ❌ 在 `~/Dev` 根 / 非 git repo / 无 deploy.sh 项目下跑 `/ship`（直接拒绝，不猜测）
- ❌ Step 2 deploy.sh exit 0 就声明完成（必须 Step 3 curl 200 才算）
- ❌ 失败后跳过卡住的步直接进下一步
- ❌ Step 3 看 `198.18.x` IP 就说"已上线"（这是 Shadowrocket fake-IP，DNS 不存在的征兆）
- ❌ 跨多 repo 批量上线用 /ship（应该用 `/repo ship a b c` + `/deploy fanout`）
- ❌ 新站首次上线用 /ship（应该用 `/site ship <name>`，含 CF DNS / Access 创建）

---

## 输出格式

成功：
```
─── /ship <name> ───
Step 1 ✓ commit + push  abc1234  chore: <message>
Step 2 ✓ deploy.sh      (12.3s)
Step 3 ✓ curl HTTP 200  https://<sub>.tianlizeng.cloud
Step 4 ✓ Live URL
Step 5 ✓ retro          (one-liner to memory)

完成：4/5 步（retro 可选）
```

失败示例（卡在 Step 3）：
```
─── /ship <name> ───
Step 1 ✓ commit + push  abc1234
Step 2 ✓ deploy.sh
Step 3 ✗ curl HTTP 502 Bad Gateway
  原因：upstream nginx 配置错误 / systemd service 未起来
  排查：ssh root@104.218.100.67 "journalctl -u <service> -n 50"
  已完成：1, 2
  未完成：3, 4, 5

✗ /ship 失败，未声明完成。
```

---

## 何时用 /ship vs 其他命令

| 场景 | 用 |
|---|---|
| **单站 commit + 上线 + 验证**（本 skill 主场景） | `/ship` |
| **只 commit + push，不部署** | `/repo ship` |
| **已 push 过，只重跑 deploy** | `/deploy` 或 `/ship --redeploy` |
| **跨多 repo 批量 commit + push** | `/repo ship a b c` |
| **多站并行 deploy** | `/deploy fanout` |
| **新站首次上线**（CF DNS / Access 创建） | `/site ship <name>` |
| **只看健康，不 ship** | `/health project <name>` |

---

## 参考

- 全局铁律「完成定义」：`~/.claude/CLAUDE.md` §执行铁律 2「完成 = commit + push + deploy + 验证 live URL」
- 实测验证铁律：`~/.claude/CLAUDE.md` §执行铁律 11「不复述别人状态」
- 底层积木：`/repo ship` `/deploy` `/health project` `/wrap retro`
- services.ts SSOT：`~/Dev/stations/website/lib/services.ts`
- ops 历史 DB：`~/Dev/tools/kb/bin/ops_history.py`
