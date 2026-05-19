---
name: debrief
description: 会话结束时生成单文件富 HTML 汇报（dark 风 + vault nav + KPI + 可点击），保存到 ~/Dev/wiki/handoffs/dev/ 并打开浏览器。用户说"汇报 / debrief / 会话总结 / 做个 html / /debrief"触发。
triggers: /debrief / 汇报 / 会话总结 / html 汇报 / 做个 html / session report / 收尾汇报
---

# /debrief · 会话 HTML 汇报

**核心理念**：每次会话结束，用一页富 HTML 说清楚"做了什么 / 推了哪些 commit / 留了什么"，替代纯文字回复。

---

## 1. 触发时机

- 用户说 `/debrief` 或"汇报 / html 汇报 / 会话总结"
- 用户说"做完了 / 全部完成 / 收尾"时，如果本次改动超过 2 个文件或 1 个 commit

---

## 2. 数据收集（先做，再写 HTML）

执行以下命令收集实时数据：

```bash
# 本次会话涉及的 repo，各自 git log --oneline -5
# 新建/修改的关键文件列表
# 当前 session UUID（如有 $CLAUDE_SESSION_ID）
date +%Y-%m-%dT%H:%M
```

整理成结构化数据：
- **goals**：本次用户目标（从对话上下文提取，1-5 条）
- **completed**：已完成（✅），含 commit hash + repo
- **pending**：未完成或留到下次（⏳），注明原因
- **commits**：`[repo] hash message` 格式列表
- **new_files**：新建的脚本/文件路径
- **decisions**：本次做的关键技术决策

---

## 3. HTML 生成规范

### 3.1 文件命名 & 输出位置

```
~/Dev/wiki/handoffs/dev/debrief-YYYY-MM-DD-<slug>.html
```

`slug` = 本次主题 2-3 词 kebab-case（如 `auggie-fix`、`raycast-scripts`）

### 3.2 必须包含的 6 个元素

1. **Session UUID badge** — 头部 `<span class="session-badge">session: <UUID></span>`（无 UUID 则写 current）
2. **KPI row（≥4 格）** — 每格 clickable：
   - ✅ 目标完成数 / 总数
   - 📦 commits 数
   - 🚀 push 了哪些 repo（数量）
   - ⏳ pending 数（0 也显示）
3. **Goals section** — 每条目标 + ✅/⏳ 状态
4. **Commits section** — 每条 commit 含 `[repo] hash msg`，hash clickable（`https://github.com/zengtianli/<repo>/commit/<hash>`）
5. **Pending / Next section** — 下次要做什么，或"无待办 🎉"
6. **Footer** — 生成时间 + `claude -r <UUID>` 续接命令（如有）

### 3.3 样式约束（与 vault HTML 一致）

```css
/* 必须 inline，不依赖外部 CSS */
body { background: #0d1117; color: #e6edf3; font-family: -apple-system, monospace; }
.kpi-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 12px; }
.kpi-card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 16px; text-align: center; text-decoration: none; color: inherit; }
.kpi-card:hover { border-color: #58a6ff; }
.kpi-num { font-size: 2em; font-weight: 700; }
section { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; margin: 16px 0; }
h2 { color: #58a6ff; }
.badge { background: #21262d; border: 1px solid #30363d; border-radius: 4px; padding: 2px 8px; font-size: 0.8em; font-family: monospace; }
.done { color: #3fb950; }
.pending { color: #d29922; }
```

### 3.4 vault nav bar（固定头）

```html
<nav style="background:#161b22;border-bottom:1px solid #30363d;padding:8px 16px;position:sticky;top:0;z-index:100;display:flex;gap:12px;align-items:center;">
  <a href="file:///Users/tianli/Dev/wiki/handoffs/dev/" style="color:#58a6ff;text-decoration:none;">📁 handoffs</a>
  <span style="color:#6e7681">›</span>
  <span style="color:#e6edf3">debrief-YYYY-MM-DD</span>
  <span style="flex:1"></span>
  <a href="file:///Users/tianli/Dev/wiki/handoffs/dev/dev-sessions-roi.html" style="color:#8b949e;font-size:0.85em;text-decoration:none;">ROI 报告</a>
</nav>
```

---

## 4. 执行步骤

1. 收集数据（git log / 对话上下文）
2. 用 Write 工具直接生成 HTML（不调外部脚本，一次性写出）
3. `open <html-path>` 打开浏览器
4. 如果本次有 commit 未 push → 提示用户（不自动 push）
5. 报告文件路径（一行，user 可点击）

---

## 5. 反模式

- 生成 markdown 代替 HTML — 违反 [[user-facing-output-is-html]]
- KPI 卡片没有 href — 违反 [[every-number-card-must-be-clickable]]
- commit hash 不带 GitHub 链接 — 用户没法点进去看 diff
- 把 debrief 存到 `~/Dev/wiki/handoffs/dev/`（老路径）— 正确位置是 `~/Dev/wiki/handoffs/dev/`
- pending 为空时省略 section — 必须写"无待办 🎉"，让用户确认清单已空

---

## 关联

- [[user-facing-output-is-html]] — 用户看的必须是 HTML
- [[every-number-card-must-be-clickable]] — KPI 数字必须 clickable
- [[html-must-be-vault-citizen]] — 含 vault nav bar
- [[/wrap]] — markdown handoff 姊妹命令（给下次 CC 看）
- [[/render-handoff]] — 把 .md 链接转 HTML
