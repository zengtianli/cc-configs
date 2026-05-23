---
name: sessions
description: 一条命令出 session 现状 + ROI 全景 HTML（包装 cc_sessions.py index + regen_dev_roi.py，输出规范 /debrief 风 HTML，含 vault nav + KPI clickable + per-project 表）。用户说「列会话 / session 现状 / 会话 ROI / sessions / /sessions / 看下 session / 清理候选」时触发
triggers: 列会话 / session 现状 / 会话 ROI / sessions / 看下 session / 清理候选 / cc session 全景
---

# /sessions — Session 现状 + ROI 一站式 HTML

## 核心用途

一站式查看 `~/.claude/projects/**/*.jsonl` 现状（数量、cwd、stale 程度、ROI），自动产规范富 HTML 给用户看。**不要手工写 session 清单**，走本 skill。

## 执行 3 步

1. **刷索引**：`uv run python3 ~/Dev/tools/dev/scripts/tools/cc_sessions.py index`
   → 写 runtime 索引 session_index.json 到 ~/.claude/projects/（全 jsonl 扫一遍）
2. **生成 HTML**：`uv run python3 ~/Dev/tools/dev/scripts/tools/regen_dev_roi.py`
   → 重生 `~/Dev/wiki/handoffs/dev/dev-sessions-roi.html`
3. **打开**：`open ~/Dev/wiki/handoffs/dev/dev-sessions-roi.html`

## 不重复执行的判定

若 `dev-sessions-roi.html` mtime < 5 分钟 **且** 无新 jsonl session 加入（`find ~/.claude/projects -name '*.jsonl' -newer dev-sessions-roi.html | head -1` 空）→ 跳过步骤 1+2，直接 `open`。

## HTML 必含（验收点）

per [[user-facing-output-is-html]] [[html-must-be-vault-citizen]] [[every-number-card-must-be-clickable]]：

- **vault nav 顶栏** + 侧边 aside 入口（_index / handoffs / topics）
- **KPI 卡 clickable**：session 总数、stale > 30d、top ROI、清理候选数 — 每个数字 `<a href>` 指向锚点
- **per-project 表**：cwd 路径 + session count + last_ts + topic（完整 36 位 UUID 可粘贴 `claude -r <uuid>`）
- **Top ROI 段**：按 turns × signal_density desc
- **Stale 清理候选**：stale_days desc，列出可归档
- **底部 backlinks** + footer 时间戳

## 验收

- audit dead link = 0
- `<aside>` + `<nav>` 标签存在
- 0 个裸 `[[wikilink]]`（必解析为 `<a>`）
- KPI 数字全 clickable（每个 KPI card 内含 `<a class="kpi">` 或 nested-in-anchor）

## 相关脚本 / skill 互补

| 入口 | 用途 | 与本 skill 关系 |
|---|---|---|
| `cc_sessions.py export <uuid>` | 单会话导 markdown | 互补，不冲突 |
| `cc_sessions.py index` | 刷 session_index.json | **本 skill 步骤 1** |
| `regen_dev_roi.py` | 数据 + HTML 渲染引擎 | **本 skill 步骤 2** |
| `/debrief` | 单会话 wrap-up HTML | 不同语境（debrief = 收尾 1 个，sessions = 俯瞰 N 个） |
| `/wrap recap` | 会话复盘 md | 不同语境 |

## 反模式

- 直接手写 session 清单 HTML（绕过 regen_dev_roi.py，破坏 SSOT）
- 只跑 `cc_sessions.py` 不出 HTML（用户要看 HTML，不要看 jsonl 字段）
- 列会话只给 8 位短码（违反 [[session-listing-format]] — 必须完整 36 位 UUID + cwd + topic）
- 跑 regen 不验 dead link / 不验 vault citizen（HTML 退化）

## 触发短语

`/sessions`、`列会话`、`session 现状`、`会话 ROI`、`看下 session`、`清理候选`、`cc session 全景`
