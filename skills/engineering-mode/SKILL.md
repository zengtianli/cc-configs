---
name: engineering-mode
description: 精准、高效、工程学式的交流与执行协议。长会话、多步操作、破坏性改动、跨系统协作时必触发。
---

# 工程学交流与执行协议

**核心理念**：磨刀不误砍柴工。用结构化的"方案 → 追踪 → 验证 → 归档"循环替代"想到哪做到哪"。降低沟通熵，提升结果可追溯性。

## 适用情形

只要当前会话满足下面任一项，就进入本协议：
- 多步骤任务（≥3 步）
- 有破坏性操作（删文件、改生产配置、推生产分支）
- 跨系统协作（本机 + VPS + 第三方 API）
- 本次或下次会话可能要接力继续

不适用：单次问答、一行代码修改、纯信息查询。

---

## 交流协议（用户视角）

### 口径

- **别替用户决策**：遇到"统一 / 合并 / 对齐 / 差不多"等语义模糊的词，先确认用户心里的具体画面再动。可以画 ASCII/HTML 草图或列 2–3 种候选让用户选。
- **先回答再动手**：用户问"你理解我意思吗 / 你明白吗"时，**必须**先用自己的话复述理解 + 暴露可能的分歧，等用户确认再执行。
- **坏消息快报**：dry-run 失败、API 400、build 绿了但访问 500——立刻告诉用户，不拖到本轮最后。
- **承认错误不找借口**：做错了直接说"我错了 + 根因 + 修法"三段。上一次 ops-console navbar 事故就是反面。

### 格式

- 回复长度跟任务复杂度匹配。单步操作 → 一句话；多步方案 → 编号列表 + 表格。
- 代码/路径用反引号；文件用绝对路径 `/Users/tianli/Dev/...`。
- 禁止 emoji 装饰（除非用户要）。状态符号 ✓ / ✗ / ⚠ 可以用。

---

## 执行协议（7 步循环）

```
  [1] 理解 → [2] 方案 → [3] 任务化 → [4] Dry-run / 试点
                                         ↓
  [7] 归档 ← [6] 验证 ← [5] 执行并 incremental commit
```

### 1. 理解（最关键，最容易跳）

- 复述用户需求，标出每个可能有歧义的词
- 模糊处用 `AskUserQuestion` 或直接文字询问
- 读相关代码/文件（不要猜），用 `Explore` agent 批量并行
- 产出：**明确的"做什么、不做什么、怎么算完成"**

### 2. 方案

**任何破坏性或跨系统操作**：进入 plan mode（或至少在对话里写一份方案），至少含：
- Context（为什么做）
- 步骤（序号 + 每步验证方式）
- 关键文件（绝对路径）
- 复用（已有 slash command / skill / 脚本）
- 非目标（**必须写**，挡过度发挥）
- 风险 + 回滚

**原则**：复用 > 新写。每写一行新代码前，先 `grep` / `ls ~/.claude/commands/` 看是否已有工具可套。

### 3. 任务化

- 用 `TaskCreate` 把方案拆成可独立完成的步骤
- **一次只 in_progress 一个**；完成立即标 completed，不批量结账

### 4. Dry-run / 试点

- 有 `--dry-run` 的工具必跑一遍
- 没有的自己造一个：先改一个最小范围，验证无误再扩量
- 有 `/cf-audit` / `/sites-health` 这种只读体检，先跑

### 5. 执行 + 增量 commit

- 原子步骤做完就 `git commit` + `git push`，别凑一大坨
- commit message 说"为什么"而不是"改了什么"
- 失败停下，**不** 把 `--no-verify` / `git reset --hard` 当捷径

### 6. 验证（端到端，不只跑测试）

- Web 改动 → `curl` + 浏览器；涉及 edge → 等 CF 传播再 curl
- VPS 改动 → SSH 看 `systemctl status` + `journalctl -u <svc> -n 20`
- CF 改动 → `/cf-audit` 对账
- 失败时，**展示实际返回内容**给用户，别只说"失败了"

### 7. 归档（跨会话接力的关键）

**本轮结束时必须产出**：
- `HANDOFF.md` — 本轮做了啥、下轮从哪开始、已知遗留问题、到期提醒（用 `/reminder` 建 Apple 提醒）
  位置：项目根 + symlink 到 `~/Dev/HANDOFF.md`（`/wrap handoff` 命令自动做）
- 关键新踩坑 → `/wrap distill` 提炼到 memory 或新 skill
- 本轮新建的可复用工具 → 写 `.md` 命令文档 + 放入 `~/Dev/tools/cc-configs/commands/`

---

## `/clear` 会话卫生（硬性约束）

**背景**：Context rot 是长会话第一大隐患——前面的错误判断会污染后续推理（CC 业界共识 2026）。

**铁律**：
- **切任务必清**：当前任务关闭 → 立即 `/clear` 开新会话，handoff 文件接续状态
- **纠错 2 次未通过强制清场**：同一个 bug / 同一个修改尝试 2 次 LLM 仍未对，**第 3 次必 `/clear`** + 用文件总结"已知错误尝试"再开新 prompt，**不允许**在污染的 context 上继续叠加
- **会话已超 200 轮 / context 占用超 70%**：主动 `/clear` 并写一份 mini-handoff 续接

**与"完成度纪律 · 零尾巴"铁律的关系**：
- `/clear` 不等于放弃 — handoff 文件接续目标，新会话继续完成
- "零尾巴" 要求**目标完成**，不要求**单一会话完成**

**反模式**：
- ❌ 同一 bug 反复尝试 5+ 次 LLM 答非所问，仍不 /clear
- ❌ /clear 后没写 handoff，新会话失去上下文
- ❌ 拒绝 /clear 因为"重要的判断在前面"——重要判断应该已经写成文件（handoff / 决策日志），不应该只活在会话历史里

_Karpathy + CC 业界对比报告 2026-05-13 立_

---

## 工具箱（按场景对应的 slash command / skill）

| 场景 | 用这个 |
|---|---|
| 长方案 + 需用户确认 | `plan-first` skill + plan mode |
| 多步追踪 | TaskCreate / TaskUpdate / TaskList |
| 破坏性 VPS/CF 改动 | `/cf`, `/cf-audit`, `/health sites`, `/site rename`, `/site archive` |
| 新站首次上线（含 CF DNS/Access/nginx 创建） | `/site ship <name>` |
| 已上线站点的迭代部署（跑现成 deploy.sh） | `/deploy` 或 `/deploy <name>` |
| 健康 + 清理 | `/health {sites,services,nav,vps,project}`, `/tidy` |
| repo 维护链 | `/repo groom`（`/repo pull → /repo audit → /repo promote → /repo ship`）|
| 提炼知识 | `/wrap distill`（改 memory + 写新 skill）|
| 复盘 | `/wrap recap` |
| 会话收尾 | `/wrap handoff` |
| 查历史会话 | `cclog` MCP, `/cmd-stats` |
| 新建 Next.js 站 | `/site add` + `/refactor migrate` |

**原则**：用之前先 `ls ~/.claude/commands/ ~/.claude/skills/`；看 skill 列表（对话开头的 system-reminder 会列全）。

---

## 归档载体（"MD + 域名" 双备份原则）

用户需求：任何一次工作都要有 **本地 MD** 留存 + **域名** 可远程查。

| 内容 | 本地 | 域名 |
|---|---|---|
| HANDOFF | `~/Dev/<project>/HANDOFF.md` + symlink `~/Dev/HANDOFF.md` | `journal.tianlizeng.cloud`（TODO 建） |
| Recap | `/recap` 输出 md + 存入 memory | 同上 |
| Plans | `~/.claude/plans/<slug>.md` | 同上 |
| Commands/Skills 说明书 | `~/Dev/tools/cc-configs/commands/*.md` | `cmds.tianlizeng.cloud` |
| 架构地图 | `~/Dev/stations/stack/projects.yaml` | `stack.tianlizeng.cloud` |
| CC 演化日志 | `~/Dev/_archive/2026-04-19-cc-evolution/changes.yaml` | `changelog.tianlizeng.cloud` |
| 会话历史 | `~/.claude/sessions/` | `cc-pulse` MCP（替代 cclog · 2026-05-03） |

**新建任何重要产出**，下意识问：放哪本地？哪个子域能查？两边都没有 → 先补。

---

## 反面示例（本会话踩过的真实坑）

### ❌ "UI 统一" 理解歪了
用户说"风格统一"，我理解为"各站各做一条长得像的 navbar"，做出 ops-console 独立品牌 + `返回主站` 链接。正确解法是"所有站顶着同一份 site-navbar.html"。
**教训**：遇到"统一 / 合并"先让用户指一个**现成的样子**（URL / 截图），别自己编。

### ❌ 先建命令再用
上一轮规划过 `/next-scaffold`，但没跑通 pilot 就要抽命令。后来发现应该先手搓 ops-console，跑通后再把可复用骨架抽成命令。
**教训**：抽象滞后实现。至少 2 个具体实例之后再抽模板。

### ❌ 只验证 build 绿，不验证生产 200
ops-console 首次部署 `pnpm build` 通过，但 VPS 上 styled-jsx 找不到，HTTP 500。
**教训**：build 绿 ≠ 跑得起来。上 VPS 后必须 `curl 生产地址 → 2xx`。

### ❌ 自动化没有回退路径
rsync `--delete` 把刚 mkdir 的 data 目录吞掉。
**教训**：破坏性命令（`--delete`、`rm -rf`、`git reset`）后必须有验证步骤；有疑问就 `--dry-run`。

---

## 触发条件（skill auto-activation）

以下任一满足即加载本 skill：
- 用户说"工程学 / 精准高效 / 按这个模式"
- 对话涉及 3+ 个系统（local + VPS + CF / GitHub / Gmail）
- 当前 CWD 在 `~/Dev` 或 `~/Dev/Work` 下的项目
- 单轮对话超过 20 次工具调用
- 正在跑破坏性操作且未写方案

触发后：
1. 在回复开头或首次方案里，**显式** 告诉用户"进入工程学模式，按 7 步协议走"
2. 套 `plan-first` 组合拳
3. 会话末尾必定 `/wrap handoff`
