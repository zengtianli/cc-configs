---
description: 把本次会话的成果按标准富 HTML 范式（vault-citizen）渲染一页给用户。用户说"/html / html 汇报 / 成果按 html 给我 / 出个 html / 这个用 html 给我"触发。
---

# /html — 成果按标准样式 HTML 汇报

把**本次会话的成果**（结论 / 对账 / 方案 / 报告 / 清单 / 决策）按标准富 HTML 范式渲染一页给用户。

**与姊妹命令的区别**：
- `/debrief` — 会话总结（goals + commits + pending，含 git log）
- `/html-fig` — 作图（SVG/PNG/PDF 多导出 + 样式预览）
- `/html` — **成果交付物**本身做成 HTML（本命令）

## 标准样式（硬约束 · 全部继承现有 vault-citizen 范式）

样式细节 SSOT = `~/Dev/tools/cc-configs/skills/debrief/SKILL.md §3.3-3.4`，直接套用。核心约束：

- **单文件 · CSS inline · 零 CDN · 零外链 JS**
- GitHub dark theme：`bg #0d1117` / `card #161b22` / `border #30363d` / `text #e6edf3` / `link #58a6ff` / `done #3fb950` / `pending #d29922`
- **顶部 vault nav bar**（sticky）：`📁 父目录 › 当前页 › 右上同级链接`
- **KPI row ≥ 4 卡**，每卡 `<a href="#anchor">` 包裹 → 点击跳具体 section；数字下面**自解释一行**（不是"任务数"，是"已完成 7/10 — 点击看清单"）
- **drill-down 到具体 N 项**：每个 KPI / finding 必能点进去看到 N 行清单，不许停在数字层
- body 内 `[[wikilink]]` 渲染为 `<a href="name.html">`
- 涉及架构 / 脚本 / 模块 / 拓扑 → **必嵌 `/module-map` 引擎派生的图**（铁律 #5：手画方框 = 反模式）

## 输出位置

| 场景 | 路径 |
|---|---|
| 会话级成果 | `~/Dev/wiki/handoffs/dev/<slug>-YYYY-MM-DD.html` |
| 项目级成果 | `<project>/handoffs/<slug>.html` |
| 临时 jobs | `~/Archives/dev-jobs/jobs/$JOB/<slug>.html` |

落盘后立刻 `open <path>` 浏览器打开 + 一行回报告路径（user 可点击）。

## 反模式

- 给 markdown 代替 HTML — 违反 [[user-facing-output-is-html]]
- KPI 没 href / 不能 drill-down — 违反 [[html-kpi-must-clickable-and-explain]]
- 无 vault nav 裸 HTML — 违反 [[html-vault-citizen]]
- 多文件依赖 / CDN 引入 / 外链 JS — vault 自含原则
- 架构图手画方框示意图 — 必走 catalog→`catalog_module_map.py` 派生
- 把"成果"渲成长篇 prose — HTML 是结构化网格，不是 markdown 转 HTML

## 关联

- [[html-vault-citizen]] · [[html-kpi-must-clickable-and-explain]] · [[user-facing-output-is-html]]
- `/debrief` · `/html-fig` · `/share`（推 tianli.cyou/share/ 给链接）
- `/module-map`（架构图唯一来源）
