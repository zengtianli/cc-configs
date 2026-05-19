---
description: 单站点 commit + push + deploy + 健康检查一条龙组合 skill。/repo ship → /deploy → /health project → live URL → /wrap retro --quick
---

# /ship — 单站发布一条龙

trigger: 见 `~/.claude/skills/ship/SKILL.md`

显式入口给用户手键 `/ship` 时使用。自动场景见 skill description trigger 关键词（"/ship X / ship X / 把 X 发上去 / X 上线 / 把 X 部上去"）。

## 调用

```
/ship <station-name>
```

等同于让 Claude 调用 ship skill。串联 commit → push → deploy → health → live URL → retro。

硬约束：必须在 station repo 目录下跑（cwd 是 `~/Dev/stations/<name>` 或 `~/Dev/<station>`），~/Dev 根 / 非部署项目立即拒绝。

详细流程见 SKILL.md。
