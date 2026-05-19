---
description: 会话结束时生成单文件富 HTML 汇报（dark 风 + vault nav + KPI + 可点击），保存到 ~/Dev/wiki/handoffs/dev/ 并打开浏览器
---

# /debrief — 会话收尾 HTML 汇报

trigger: 见 `~/.claude/skills/debrief/SKILL.md`

显式入口给用户手键 `/debrief` 时使用。自动场景见 skill description trigger 关键词（"汇报 / debrief / 会话总结 / 做个 html"）。

## 调用

```
/debrief [topic]
```

等同于让 Claude 调用 debrief skill。输出到 `~/Dev/wiki/handoffs/dev/<date>-<slug>.html`，自动 open 浏览器。

详细 6+1 层强制流水线 / KPI 规范 / vault nav 注入逻辑见 SKILL.md。
