---
description: 并行 agent team 处理多目标任务，每个 agent goal-loop 自闭环；产出 HTML 报告给用户看。带 mode 参数 = 进入 idle-orchestrator 模式，主会话锁定为纯编排者
---

# /dispatch — 多 agent 并发 goal-loop

trigger: 见 `~/.claude/skills/dispatch/SKILL.md`

## 调用

```
/dispatch                  # 进入 idle-orchestrator mode — 主会话锁定纯编排
/dispatch <任务描述>       # 一次性派一波 agent team 做完
/dispatch off              # 退出 idle-orchestrator mode 回普通会话
```

## Idle-Orchestrator Mode（不带任务参数时进入 · 硬约束）

- 主会话从此 **永远 idle 等命令**，每次接到任务才派 agent team
- 主会话**禁止亲手干活**（Read/Edit/Write/Bash 业务文件全派 agent，主进程只整合 + verify + commit）
- 开头必声明：「✅ 已进入 dispatch idle-orchestrator mode · 等待你的命令」
- 每个任务必以「📋 任务收到 · 拆 N 个 worker 并发派发」开头
- 用户键 `/dispatch off` / `/wrap` / `/clear` 退出

详见 SKILL.md §0 Idle-Orchestrator Mode（4 例外 + 反模式清单）。

## 普通模式（带任务）

```
/dispatch 一次性处理 N 个目标 / 不留尾巴 ...
```

N agent 并发 → 主进程合并 → background commit → HTML 完工报告。详细 4 阶段模板 / subagent prompt / 主进程合并避 race 见 SKILL.md。
