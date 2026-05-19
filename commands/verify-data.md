---
description: 数据 deliverable 写入前的三角对账（本地 DB + ≥2 独立网源），消灭"Wuxing 错配 Jiaxing / xlsx 没对公报 / 作者顺序错"那类因 cross-check 缺失被退回的事件
---

# /verify-data — 数据三角对账

trigger: 见 `~/.claude/skills/verify-data/SKILL.md`

显式入口给用户手键 `/verify-data` 时使用。自动场景见 skill description trigger 关键词（"/verify-data X / 校核 X / 三角对账 X / X 对不对"），或在写 deliverable（报告 / xlsx / 简历 / 论文 / 法律意见）前需要落入具体声明时。

## 调用

```
/verify-data <claim or dataset>
```

等同于让 Claude 调用 verify-data skill。本地 DB 查 + ≥2 独立网源核对，分歧 → 标注置信度 + 信源。

详细对账流程 / 信源选择 / 输出格式见 SKILL.md。
