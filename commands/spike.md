---
description: 抛弃式 spike / poc / toy 实验协议。显式豁免「每个项目必配 CLAUDE.md + .claude/ 脚手架」铁律 — 因为 spike 本质就是用完即弃
---

# /spike — 抛弃式实验

trigger: 见 `~/.claude/skills/spike/SKILL.md`

显式入口给用户手键 `/spike` 时使用。自动场景见 skill description trigger 关键词（"试一下 / 试试 X 行不行 / 看 Y 可不可行 / 快速验证 / 玩具版 / spike / poc / 抛弃式实验"）。

## 调用

```
/spike <实验主题>
```

等同于让 Claude 调用 spike skill。落地到 `~/Dev/_archive/spikes/<slug>/`，< 50 行单文件 + 跑完归档 + 用户决定是否提级。

详细豁免范围 / 提级条件见 SKILL.md。
