---
name: govern
description: 一句纠正 → 永久写进正确的 CC 配置层（CLAUDE.md / memory / skill / settings.json hook）。任何项目里 CC 犯错，打这个命令彻底锁死它以后的行为。
---

# /govern — 把纠正永久固化进 CC config

用户因为 CC **犯了错**或想**规范某种行为**而调用。`$ARGUMENTS` = 用户的纠正/规则（可能很短，如"别再这样了 / 以后都要 X"）。

**目标**：把这条纠正写进**正确的配置层**，让 CC 以后（本项目 + 视情况其它项目）不再犯。不是临时答应，是改文件。

## 步骤

### 1. 还原"错在哪"
若 `$ARGUMENTS` 含糊（"别再犯了"），**回看本会话**：CC 刚做错了什么具体动作？提炼成一句可判定的规则 + 一句 Why（带用户原话/踩坑）。不确定就先 `AskUserQuestion` 复述确认，**别猜**。

### 2. 判定落点（路由表，可多选）

| 纠正性质 | 落点 | 判别信号 |
|---|---|---|
| **自动行为**：每次/每当/X之后必须/X之前要、确定性强制动作 | `settings.json` **hook** → 用 `/update-config` skill | "whenever / each time / 自动 / 每次都" + 动作。**关键**：harness 执行，LLM 记忆保证不了 |
| 权限 / env var / 模型 / 状态栏 | `settings.json` | "允许 X 命令 / 设 X=Y / 默认用 X 模型" |
| 跨项目铁律 | `~/.claude/CLAUDE.md`（追加到「执行铁律」节） | "以后所有项目 / 不管哪个项目 / 永远" |
| 本项目事实/教训/偏好 | 项目 `<cwd>/.claude/`… 的 memory dir + `MEMORY.md`（路径见全局 CLAUDE.md §14） | 只跟当前 repo 有关 |
| 某领域操作流程/规范 | 对应 `skill/SKILL.md`（加「已锁参数」或反模式节） | "做 X 这类事的时候要…" |

判不准 → `AskUserQuestion` 给推荐项让用户拍板，**别同时往所有层乱塞**。

### 3. 写入
- **hook / settings.json** → 调用 `/update-config` skill（它专门改 settings.json，会校验 hook 语法）。**绝不**手写 hook 进未确认的 settings。
- **CLAUDE.md / SKILL.md** → 直接 Edit，追加一条，含 **Why（具体踩坑/用户原话）+ How to apply（下次怎么判断）**。
- **memory** → 新建 `feedback_<topic>.md`（type: feedback，含 Why + How to apply + `[[]]` 互链）+ 更新 `MEMORY.md` 一行指针。先查重，已有就改不新建。

### 4. 破坏性确认
改 `~/.claude/CLAUDE.md` / 加 hook / 改 settings.json 属可影响全局的改动 → 写前用 `AskUserQuestion` 复述「我要往 <层> 写 <这句>，确认？」。改项目内 memory/skill 可直接写。

### 5. 汇报
一张表：`层 | 文件路径 | 写入的规则原句`。让用户一眼看到"锁在哪了"。

## 反模式（本命令自己要避免）
- ❌ 把"自动行为"塞进 memory/CLAUDE.md —— 记忆≠执行，必须 hook。
- ❌ 一条纠正同时写 5 个地方 —— 选最准的 1~2 层。
- ❌ `$ARGUMENTS` 含糊就凭感觉编规则 —— 先还原错在哪，必要时确认。
- ❌ 改全局 CLAUDE.md / settings.json 不确认就动手。
