---
name: engineering-mode
description: 精准、高效、工程学式的"方案 → 追踪 → 验证 → 归档"7 步循环协议。当长会话（>20 工具调用）/ 多步操作（≥3 步）/ 破坏性改动 / 跨系统协作（local + VPS + CF/GitHub）/ 用户说「工程学 / 精准高效 / 按这个模式 / engineering-mode」时必触发。
---

# 工程学执行协议

> 全局铁律见 `~/.claude/CLAUDE.md` 15 条；本 skill 只补**循环结构 + 反面示例**。不重复铁律。

## 适用情形

任一满足即进入：多步骤任务（≥3 步）/ 破坏性操作 / 跨系统（local + VPS + 第三方 API）/ 跨会话接力 / 单轮工具调用 > 20。

**不适用**：单次问答、一行修改、纯信息查询。

---

## 7 步循环

```
  [1] 理解 → [2] 方案 → [3] 任务化 → [4] Dry-run / 试点
                                         ↓
  [7] 归档 ← [6] 验证 ← [5] 执行并 incremental commit
```

### 1. 理解（最关键，最容易跳）
复述需求 → 标歧义词 → 模糊处 `AskUserQuestion`（≤ 2 个）→ 读相关文件不靠猜 → 产出"做什么、不做什么、怎么算完成"。

### 2. 方案（破坏性/跨系统必写）
至少含：Context / 步骤+验证 / 关键绝对路径 / 复用清单（先 `ls ~/.claude/{commands,skills}/`）/ **非目标**（挡过度发挥）/ 风险+回滚。

### 3. 任务化
拆可独立步骤；一次只一个 in_progress；完成立即 completed，不批量结账。

### 4. Dry-run / 试点
工具有 `--dry-run` 必跑；没有就改最小范围验证再扩量；只读体检（`/cf-audit` / `/health sites`）先跑。

### 5. 执行 + 增量 commit
原子步骤完成立即 commit + push（铁律 #4）。失败停下，不用 `--no-verify` / `git reset --hard` 当捷径。

### 6. 验证（端到端，铁律 #11）
Web → `curl -sI` + 浏览器；VPS → SSH + `systemctl status` + `journalctl`；CF → `/cf-audit`。失败展示**实际返回内容**给用户。

### 7. 归档
`/wrap handoff` 自动写 `HANDOFF.md`；新踩坑 → `/wrap distill` 入 memory / 新 skill；新工具 → 文档进 `~/Dev/tools/cc-configs/commands/`。

---

## 反面示例（真实坑）

- **"统一/合并" 没指现成的样子就动**：ops-console navbar 事故 — 用户说"统一"指共享同一份 navbar，我做成各站独立品牌。教训：让用户指 URL / 截图。
- **抽象滞后实现**：规划 `/next-scaffold` 还没跑通 pilot 就抽命令。教训：至少 2 个具体实例之后再抽模板。
- **build 绿 ≠ 跑得起来**：`pnpm build` 通过但 VPS 上 styled-jsx 找不到 500。教训：必须 `curl 生产地址 → 2xx`。
- **破坏性命令没回退**：rsync `--delete` 吞掉 data 目录。教训：`--dry-run` 先行。

---

## 触发时显式声明

进入本协议后首条回复必写："进入工程学模式，按 7 步协议走"，然后进 [1] 理解。
