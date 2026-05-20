---
description: 设定/追踪 machine-checkable 北极星目标 — 写 GOAL.md (north star + 验收标准 + 不变量), 收尾逐条 verify。用户说 /goal 或 "设置 goal / 钉死目标 / 北极星" 触发
---

# /goal — machine-checkable 目标追踪

大任务开干前先 `/goal set` 钉死北极星 + 可验证验收标准; agentteam 干完 `/goal check` 逐条跑命令验, 不靠感觉判断"完成"。

## 用法

```
/goal set "<north star one-liner>"   → 在当前 jobs/<task>/GOAL.md 写: 北极星 + 验收标准表 + 不变量
/goal check                          → 逐条跑 GOAL.md 验收命令, 出 pass/fail 表
```

## /goal set 流程

1. 定位当前 `jobs/<task>/` (cwd 或最近 job); 无则在 cwd 建 `GOAL.md`。
2. 写入模板:
   - **北极星** one-liner — 一句话说清"做完长什么样"。
   - **验收标准表** — 每条必须给 machine-checkable 验证命令 (grep / test / curl / 文件存在):

     | # | 标准 | 验证命令 |
     |---|---|---|
     | G1 | <可验证的状态> | `grep -L 'marker' files` 为空 |

   - **收敛策略 / 不变量** — 硬约束 (删=mv .Trash, 不动 X, 等)。
3. 报告: 已钉死 N 条验收标准 + GOAL.md 路径。

## /goal check 流程

1. 读当前 `jobs/<task>/GOAL.md` 的验收标准表。
2. 逐条跑验证命令, 收集 exit code / 输出。
3. 出 pass/fail 表:

   | # | 标准 | 命令 | 结果 |
   |---|---|---|---|
   | G1 | ... | ... | ✓ PASS / ✗ FAIL |

4. 有 FAIL → 列出未达标项 + 一句修复建议; 全 PASS → 报告"北极星达成"。

## 模板参考

`~/Dev/jobs/wiki-knowledge-net/GOAL.md` — 含北极星 + G1–G7 验收标准 (每条带 grep/test 验证命令) + 收敛策略 + 不变量。

## 作用

把"完成"从主观感觉变成机器可验。配合 agentteam: set 钉死 → 并发干 → check 逐条验, 不留尾巴。
