---
description: 一站式 session 现状 + ROI 规范 HTML
---

调用 /sessions skill。

数据：`~/.claude/projects/**/*.jsonl`
输出：`~/Dev/wiki/handoffs/dev/dev-sessions-roi.html`
执行：`uv run python3 ~/Dev/tools/dev/scripts/tools/cc_sessions.py index && uv run python3 ~/Dev/tools/dev/scripts/tools/regen_dev_roi.py && open ~/Dev/wiki/handoffs/dev/dev-sessions-roi.html`
