---
name: dispatch
description: 并行 agent team 处理多目标任务，每个 agent goal-loop 自闭环；产出 HTML 报告给用户看。用户说 "dispatch / 派 agent / agent team 做 / 多并行 / 一次性处理 N 个 / 全部一次性 / 不留尾巴 / 目标驱动并发 / P1=N 直接" 等触发。
---

# /dispatch · 并行 agent team 编排协议

**核心理念**：dispatcher 模式 = 主进程不做事，只拆任务 + 派 agent + 合并 + 出报告。每个 agent 必 goal-loop 自闭环。完成 = 全部 agent verified + HTML 给用户看。

**与铁律的关系**：是「并行优先」(铁律 1) + 「零尾巴」(铁律 3) + 「实测验证」(铁律 11) 的标准执行载体。串行 / 单 agent / 只给 md 报告 = 都是反模式。

---

## 0. Idle-Orchestrator Mode（2026-05-23 用户钦定 · 硬约束）

**触发**：用户键入 `/dispatch`（不带任务参数或带 "mode on / 进入模式" 等）→ **本会话从此刻起进入 idle-orchestrator mode**，直到用户显式 `/dispatch off` 或 `/wrap` 退出。

**模式语义**：
- 主会话 = **纯编排者**，永远 idle 等用户命令；用户每次发任务 → 主会话**只**做：① 拆解 ② 派 agent team ③ 收报告整合 ④ 主进程亲自实测 verify ⑤ commit+push 收口 ⑥ 出 HTML 给用户
- 主会话 **绝对禁止**亲手 Read / Edit / Write / Bash 业务文件（编排必需的 TaskCreate / Agent / ToolSearch / 读 agent 报告 / 整合用的 Read 例外）
- 用户没下命令 = 主会话不主动开火，**安静等指令**（不要"我来看看 X / 顺便扫一下 Y"）
- 单 agent 也不行 — 进入模式后任何任务最低 **agent team N≥2 并发**（即使只 1 个目标，也派 1 worker + 1 verifier 并发；除非用户明说 "/dispatch off 退出"）

**模式状态记录**：
- 主会话开头第一句必声明：「✅ 已进入 dispatch idle-orchestrator mode · 等待你的命令」
- 每次接到用户任务，回复必须以「📋 任务收到 · 拆 N 个 worker 并发派发」开头，证明走的是 dispatch 路径
- 不要在主会话里偷偷干活然后假装"派了 agent"

**例外**（仅 4 种主会话可直接动手）：
1. 用户问纯信息类问题（"X 是什么 / Y 在哪"）— 答完继续 idle
2. 编排必需的 status 类只读命令（`git status` / `ls handoffs/` / 读 agent 报告）
3. 整合 agent 输出到 SSOT（合并 patch / 改 settings.json）— 这是编排的整合环节
4. commit + push 收口（铁律 #3：subagent 不动 git，commit 由主进程统一收口）

**退出**：
- 用户键入 `/dispatch off` / `/wrap` / `/clear` → 退出 idle mode 回归普通会话
- 退出时主会话回复：「🛑 已退出 dispatch mode · 恢复普通编排」

**Why**：用户原话「主会话 一定要idle，一定要等我命令，就调度。任务给 agentteam」。CLAUDE.md 铁律 #1 + #16 已立"默认 multi-agent"，但仍出现主会话偷偷亲手干 + 假装派了 agent 的反模式。idle-orchestrator mode = 把"默认派 agent"升级成"模式锁定派 agent"，让主会话在用户没发命令时**安静不动**，发命令时**只走 agent 路径**。配合铁律 #13（执行约束需 GOAL/Hook 层）后续可补 PreToolUse hook 拦截非编排类工具调用。

**反模式**：
- 进 mode 后主会话亲手 Edit 文件 / 跑业务 Bash / 写脚本 — 应派 agent
- "顺便我来扫一下 X" 用户没问也开火 — 应 idle 等命令
- 派 1 个 agent 就算 — 模式内最低 N≥2 并发
- 跳过开头声明 / 任务收到声明 — 用户没法 verify 你真在 dispatch 路径
- 模式没退出就开始普通会话风格 — 应显式 `/dispatch off`

---

## 1. when to use

任一触发即用：

- 用户说："dispatch / 派 agent / agent team / 多并行 / 一次性处理 / 全部一次做完 / 不留尾巴 / P0=N P1=N P2=N 直接"
- 用户给 **≥ 3 个独立 todo** 且要求"全做"
- audit / scan / 全栈检查类（"扫一下 / 检查所有 / 看看 X 全部有没有 Y"）
- 跨 repo / 跨子域 / 跨文件大规模改动
- 用户提供了 N 项清单（编号列表 / table / 报告里的 finding 列表）

**不触发**：

- 单一明确任务（直接做，别派 agent）
- 用户明说"我自己来 / 别派 agent"
- spike / poc（走 `/spike` skill）
- 纯讨论 / 决策（先 `AskUserQuestion`，别动手）

---

## 2. how it works（4 阶段编排）

### Wave 1 — 拆解 + 并发派

1. 把目标拆成 N 个独立子任务（独立 = 不依赖其他 subagent 的输出）
2. **并发下限 4 个**，能 8 就 8；single message 多 Agent tool call
3. 每个 agent prompt 用 `templates/agent_prompt.md`，必含：
   - **Goal (machine-checkable)** — test pass / curl 200 / file exists / SQL count / lint clean
   - **Context** — 路径 / SSOT / 已知约束
   - **Loop** — retry-until-verified，最多 N 次失败再求助
   - **约束硬措辞** — "绝对禁止 git add/commit/push / 违反 = 任务失败"
   - **硬时限** — 10 分钟
   - **报告 ≤ 500 字结构化**

### Wave 2 — 主进程合并 + 实测

- 收所有 subagent 报告 / PATCH / 中间产物
- 合并到 SSOT（settings.json / harness.yaml / paths.yaml 等）
- **主进程亲自实测**（不复述 subagent 状态）：curl / dig / open URL / pytest / JSON valid
- 失败的子任务派**新 agent** 重做（goal-loop 再来一轮），不在污染 context 上叠加

### Wave 3 — commit + push 并发

- 每个 repo 一个 background Bash task
- 等所有 push 完成
- subagent 不动 git，commit 都由主进程一次性收口
- 破坏性 / 跨 SSOT 改动 → 先 `AskUserQuestion` 拍板

### Wave 4 — HTML 完工报告

- 用 `templates/html_report.html` 模板
- 落 `~/Dev/dispatch-<topic>-YYYY-MM-DD.html` 或 `~/Dev/wiki/handoffs/dev/<slug>.html`
- 每个 agent 卡 / KPI / finding 必 clickable（href 跳 commit URL / file:// / 锚点）
- `open ~/Dev/...html` 给用户

---

## 3. agent prompt template

见 `templates/agent_prompt.md`。占位符：

- `{goal}` — 一句话目标 + machine-checkable 判据
- `{context}` — 相关路径 / SSOT / 已知约束
- `{loop}` — 验证 → 失败诊断 → 重试，最多 N 次
- `{constraints}` — 不 commit / 不写 SSOT / 时限 / 输出格式

---

## 4. goal-loop template

每个 agent 内部循环：

```
1. 读 context / 实测当前状态（curl / cat / sqlite3 ...）
2. 执行修复 / 实现
3. 实测验证（与 goal 的 machine-checkable 判据对照）
4. 通过 → 写 ≤ 500 字报告 → 结束
5. 不通过 → 自我诊断（"为什么没过 / 哪一步偏了"）→ 回 2，最多 N 次
6. N 次仍不过 → 写"失败 + 已尝试 X/Y/Z + 怀疑 W"求助，不挂死
```

判据范例：

- 文件存在：`test -f <path>` exit 0
- HTTP 200：`curl -sI <url> | head -1 | grep "200"`
- SQL count：`sqlite3 db "SELECT COUNT(*) FROM t WHERE ..." = N`
- JSON 合法：`python3 -c "import json; json.load(open('x.json'))"`
- 测试通过：`pytest -x` exit 0
- Lint 干净：`ruff check .` exit 0

---

## 5. HTML report template

见 `templates/html_report.html`。骨架：

- GitHub dark theme（`--bg: #0d1117` / `--green` / `--yellow` / `--red` / `--blue` / `--purple` / `--orange`）
- 单文件，CSS 内联，SVG 内联，零 CDN
- 顶部 KPI 行（5 卡 × 大数字 + clickable 跳锚点）
- Wave 分组 agent 卡网格（3 列响应式 → 移动 1 列）
- 每卡含：name / status-badge / summary / clickable artifact（commit URL / file:// path）
- 默认排序：失败/严重 在最上面，stale desc / created asc / commit date desc
- **每个数字 / finding / agent 卡都必须是 clickable**（[[html-must-drill-down]]）

最小必有元素清单：

- `<header>` — 标题 + 副标题 + 时间 badge
- `.kpi-row` — 5 个 KPI 卡，`<a href="#section-id">` 包裹
- `.wave-group` — Wave 1/2/3/4 分组，每组 `.agent-grid` 内 N 个 `.agent-card`
- `.agent-card` 内必含至少 1 个 clickable artifact link（commit/file/url）
- footer — 总用时 / agent 数 / 完成率

---

## 反模式

- 串行派 agent（一个完再派下一个）→ 应并发下限 4
- agent prompt 不写 machine-checkable 判据（"试一下 / 尽量做"）→ 永远不知道何时算成功
- subagent 自己 commit / push → 必须主进程统一收口
- 只给 markdown 报告不给 HTML → 违反 [[user-facing-output-is-html]]
- HTML 没 href 没锚点 → 退化成 markdown，违反 [[html-must-drill-down]]
- agent 失败后主进程在污染 context 重试 → 应派新 agent 干净开始
- 拆分时让 subagent 之间互相依赖输出 → 应只派独立子任务，依赖链由主进程串

---

## 关联

- [[pace-and-parallelism]] — dispatcher 节奏 / 并发下限
- [[one-shot-all-priority-dispatch]] — P1=N 全做的完整闭环范式
- [[user-facing-output-is-html]] — HTML 是给用户看的硬约束
- [[html-must-drill-down]] — HTML 必 clickable 入口
- [[subagent-commit-boundary]] — subagent 硬措辞拦 commit
