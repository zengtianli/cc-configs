---
name: build-report
description: 给用户出 HTML 完工报告 / wrap report / dispatch 汇报的强制 6 层 checklist 流水线。任一触发即走完 8 步（含 audit 自循环），dead=0 + aside + wikilinks 解析率 ≥80% 才能 open 给用户。用户说「生成报告 / 出 HTML / 写报告 / 产出 HTML / 汇报 HTML / build-report / 完工报告 / dispatch 完工汇报 / wrap report / 写个 HTML 给我看」触发。
triggers: 生成报告 / 出 HTML / 写报告 / 产出 HTML / 汇报 HTML / build-report / 完工报告 / dispatch 完工汇报 / wrap report / 写个 HTML 给我看 / 做个汇报
---

# /build-report · user-facing HTML 报告 6 层强制流水线

**Why**：用户原话 2026-05-19 "你刚刚的 html 都没有按照 html 报告要求！！" — 每次新生 HTML 漏 L1-L6 其中一两条。规则散落 6 条 memory，没机器强制 = 形同虚设。本 skill 把 6 层物化为一个不可绕开的流水线 + audit 自循环。

## 1. 6 层规则 SSOT

| L | rule | 检查项 | 关联 memory |
|---|---|---|---|
| L1 | 是 HTML 不是 MD | 完工产物 `.html`，不是 `.md` | [[user-facing-output-is-html]] |
| L2 | KPI/finding/agent 卡 clickable | KPI 数字 `<a class="kpi-*" href>` 包裹 | [[html-must-drill-down]] |
| L3 | .md href 必须有同名 .html | 跑 `/render-handoff` 渲所有引用的 .md | [[md-links-must-render-html]] |
| L4 | vault nav + aside + backlinks | `<aside>` 存在 + 顶 nav + 底 backlinks | [[html-must-be-vault-citizen]] |
| L5 | HTML 自含双链 不靠 SSG | `inject_vault_nav.py` 注入，不依赖 Quartz | [[html-native-bidirectional-links]] |
| L6 | 每个数字（含 td 内）clickable | KPI + table 内数字 + 候选卡子数字全 `<a href>` | [[every-number-card-must-be-clickable]] |

## 2. 触发后必走 8 步（不允许跳）

1. **数据收集** — CC 已有材料 / agent team 已返回 / 实测 curl 结果汇总
2. **第一稿 HTML** — 写 `~/Dev/wiki/handoffs/dev/<slug>.html`，必含：
   - GitHub dark 风（参 `~/Dev/wiki/handoffs/dev/_archive/2026-05-19-wrap-status.html`）
   - vault nav top bar（占位也行，Step 4 注入真链）
   - KPI 数字 `<a class="kpi-value" href="...">N</a>`
   - **表格里的数字也 clickable**：`<td><a href="...">8</a></td>` 而不是 `<td>8</td>`
   - aside 抽屉（左/右侧 `<aside>` 元素）
   - 底部 backlinks 节占位
3. **第一次 audit**：
   ```bash
   python3 ~/Dev/tools/dev/lib/hooks/kpi_clickability.py --file ~/Dev/wiki/handoffs/dev/<slug>.html --strict
   ```
   要求 `dead==0`。dead!=0 → 自循环修，直到 0 为止；**不准"差不多了交活"**
4. **跑 vault-inject**：
   ```bash
   python3 ~/Dev/tools/dev/lib/tools/inject_vault_nav.py ~/Dev/wiki/handoffs/dev/<slug>.html
   ```
   注入真 vault nav + aside 邻居 + backlinks + 解析 body 里 `[[wikilink]]` → `<a href>`
5. **第二次 audit**（验收三件套）：
   - `dead == 0`
   - `<aside` 存在
   - 残留裸 `[[xxx]]` ≤ 5 个（wikilink 解析率 ≥ 80%）
6. **任一项 fail 必自循环修**，不让用户看半成品
7. `open ~/Dev/wiki/handoffs/dev/<slug>.html` 给用户浏览
8. （可选）报告引用了 .md → 跑 `/render-handoff` 把 .md 渲成同目录 .html

## 3. 反模式（用户骂过的样子）

- `<td>8</td>` 死数字 — 应 `<td><a href="...">8</a></td>` 或加 `title=` self-explain
- 没 `<aside>` 抽屉 — 不是 vault citizen
- body 残留 `[[xxx]]` 未解析 — 用户直接看到 wikilink 原文
- 用 markdown 给用户看完工报告（L1 fail，应该用 HTML）
- KPI label 没释义（hover tooltip 或顶部 details.kpi-legend）— [[every-kpi-must-self-explain]] 配套
- skip Step 5 第二次 audit 就 open — 大概率漏 L4 aside / L5 wikilink

## 4. 范本与工具

| 用途 | 路径 |
|---|---|
| 合规范本（这次 F2 生的） | `~/Dev/wiki/handoffs/dev/2026-05-19-final-cleanup.html` |
| 样式参考（dark + KPI + go-box） | `~/Dev/wiki/handoffs/dev/_archive/2026-05-19-wrap-status.html` |
| audit hook（dead KPI + aside + wikilinks + td 装饰） | `~/Dev/tools/dev/lib/hooks/kpi_clickability.py` |
| audit 核心函数 | `inject_vault_nav.audit_kpi_clickability(text: str) -> dict` |
| vault 注入器 | `~/Dev/tools/dev/lib/tools/inject_vault_nav.py <html>` |
| vault 索引（需新增 wiki entry 后重建） | `~/Dev/tools/dev/lib/tools/vault_index.py` |
| backlinks map | `~/Dev/tools/dev/lib/tools/backlinks_map.py` |

## 5. 与其他 skill 衔接

- **`/dispatch`** — agent team 跑完直接调本 skill 出 HTML，不再自己手写
- **`/wrap recap` / `/wrap handoff`** — 收尾汇报全走本 skill 出 HTML
- **`/render-handoff`** — Step 8 调用，处理 .md href
- **`/vault-inject`** — Step 4 已经调用，无需重复
- **`commit-guard`** — commit HTML 时 pre-commit hook 会跑 `kpi_clickability.py` 再次拦 dead KPI

## 6. 报告产物位置约定

- 永久 handoff → `~/Dev/wiki/handoffs/dev/<slug>.html`
- 临时 dispatch job → `~/Dev/jobs/$JOB/report.html`
- 归档老报告 → `~/Dev/wiki/handoffs/dev/_archive/YYYY-MM-DD-<slug>.html`
- **禁止根级 `.html`**（见 [[html-output-location]]）
