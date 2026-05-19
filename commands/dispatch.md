---
description: 并行 agent team 处理多目标任务，每个 agent goal-loop 自闭环；产出 HTML 报告给用户看
---

# /dispatch — 多 agent 并发 goal-loop

trigger: 见 `~/.claude/skills/dispatch/SKILL.md`

显式入口给用户手键 `/dispatch` 时使用。自动场景见 skill description trigger 关键词（"dispatch / 派 agent / agent team 做 / 多并行 / P1=N 直接"）。

## 调用

```
/dispatch <任务描述>
```

等同于让 Claude 调用 dispatch skill。N agent 并发 → 主进程合并 → background commit → HTML 完工报告。

详细 4 阶段模板 / subagent prompt / 主进程合并避 race 见 SKILL.md。
