---
name: dispatch
description: 并行 agent team 处理多目标任务，每个 agent goal-loop 自闭环；产出 HTML 报告给用户看。用户说 "dispatch / 派 agent / agent team 做 / 多并行 / 一次性处理 N 个 / 全部一次性 / 不留尾巴 / 目标驱动并发 / P1=N 直接" 等触发。
---

# /dispatch · 并行 agent team 编排协议

**核心理念**：dispatcher 模式 = 主进程不做事，只拆任务 + 派 agent + 合并 + 出报告。每个 agent 必 goal-loop 自闭环。完成 = 全部 agent verified + HTML 给用户看。

**与铁律的关系**：是「并行优先」(铁律 1) + 「零尾巴」(铁律 3) + 「实测验证」(铁律 11) 的标准执行载体。串行 / 单 agent / 只给 md 报告 = 都是反模式。

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
