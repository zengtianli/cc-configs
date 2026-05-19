---
description: 会话收尾族 — recap 复盘 / retro 写 playbook / handoff 全流程交接 / distill 提炼到全局
---

# /wrap — 会话收尾统一入口

`/wrap <subcommand> [args]`

| 子命令 | 受众 | 产出 |
|---|---|---|
| `handoff` | 下次会话 | `handoffs/<slug>.md` + recap + harness 三合一（默认） |
| `recap` | CC 自己 | 更新 memory/skills/commands，session-retro MD |
| `retro` | 用户 | Playbook 式复盘（slash command 编排流程） |
| `distill` | 全局知识库 | 从项目提炼 commands / 踩坑 / playbook 骨架 |

未传子命令 → `handoff`（最完整）。

---

## § 跨子命令编排协议

四子命令的**唯一入口 / 参数透传 / 数据一致性**底层契约。新增子命令前先来这里加一行。

### 1. 共享产物的唯一写入责任

**每个产物只允许一个子命令写**（其他子命令读不写，避免重复 / 冲突 / 漂移）：

| 产物 | 唯一写入者 | 时机 | 其他子命令 |
|---|---|---|---|
| `~/Dev/stations/docs/knowledge/INDEX.md` | **retro** Step 4 | 建中央 symlink 后追加倒序行 | handoff/recap/distill 禁写 |
| `~/Dev/tools/cc-configs/skill-tracker.json` | **recap** Step 3.2 | 更新 last_used / use_count / correction_count | handoff/retro/distill 禁写 |
| `~/Dev/tools/cc-configs/skill-candidates.md` | **recap** Step 3.2 | 候选追加或 use_count++ | handoff/retro/distill 禁写 |
| `<root>/handoffs/<slug>.md` | **handoff** Step 3.1 | 建 / 覆盖更新 | recap/retro/distill 禁写 |
| `<主项目>/docs/retros/session-retro-{date}-{slug}.md` | **retro** Step 2 / **recap** Step 4 | recap 默认调 retro 内部逻辑（共享 Step 1 主项目判别） | handoff/distill 禁写 |
| `~/.claude/commands/*.md` | **distill** Phase 4 (`--apply` 模式) | 同名冲突列 diff 让用户决 | 其他子命令禁写 |

### 2. Priority marker 格式（待办标准化）

handoff Step 3.1 / recap Step 4 写入待办时，**统一用 priority marker** — `/start` 才能解析出优先级展示：

```markdown
- [ ] [P0] 必须本会话闭环（blocking）— 一句话决策
  - 详细背景 / 约束 / 验收
- [ ] [P1] 下 1-2 会话内做（critical path）
- [ ] [P2] nice-to-have（不阻塞）
- [ ] [defer-v0.3] 明确推延到 v0.3
- [ ] [external] 等用户操作 / 等第三方（如等 RM 回复 / 等买域名）
- [ ] 无 marker — 视同 P2
```

**判别**：
- `[P0]` = 用户怒怼级 / 数据错误 / 阻塞下一步
- `[P1]` = 应做但能 defer 一两轮
- `[defer-vX.Y]` = 用户**明确说**"留下次"才打（不允许 CC 主动 defer，参见全局 CLAUDE.md "完成度纪律"）
- `[external]` = 阻塞点不在 CC，等外部输入

### 3. handoff ↔ recap 内部调用合约

handoff Phase 1 内部调 recap，**参数透传 + step 复用**避免重跑：

| recap step | handoff Phase 1 行为 |
|---|---|
| Step 1 回顾对话 | ✅ 跑（必须） |
| Step 2 改进经验 | ✅ 跑（必须） |
| Step 3.1-3.4 Memory/Skills/Commands/CLAUDE.md | ✅ 跑（必须） |
| Step 3.5 paths audit | ⏭️ **跳过** — 复用 handoff Phase 3.0a 的结果（同会话同结果不重跑） |
| Step 4 session-retro 写入 | ✅ 跑（必须） — 主项目判别复用 handoff Phase 3.0 |

**独立 `/wrap recap`**（不经 handoff）：Step 3.5 必跑（无上游可复用）。

### 4. multi-slug 共存协调

同项目 `handoffs/` 已有 N 份并行时，handoff 子命令默认改哪个？**判别矩阵**：

| 当前会话与已有 slug 关系 | 决策 | 操作 |
|---|---|---|
| 任务描述匹配某 slug（AskUserQuestion 确认） | **同任务多轮** | 复用该 slug，文件覆盖；顶部 banner 加"共 N 轮 → vN.x" |
| 是某 slug 的明显续接（"PR1 完成 → PR2"） | **同任务续接** | 复用该 slug，banner 推版本号 |
| 与所有 slug 都无关（新需求 / 新 PR） | **新任务** | 建新 slug，并存互不覆盖 |
| 用户说"上轮闭环了，新的来了" | **闭旧建新** | `/wrap handoff --close <旧 slug>` 后建新 slug |
| 模糊不定 | **建新更安全** | AskUserQuestion 让用户拍板，倾向新 slug |

`/start` 入场时调 warmup 跨 handoff 汇总待办，按 priority marker 高亮 — 看到全景再决策。

---

## handoff — 会话收尾与交接（推荐默认）

一步完成复盘、配置升级、交接文件生成。

### 参数
- 无参数 → 完整流程（recap + harness + `handoffs/<slug>.md`）
- `--slug <name>` → 显式 slug（推荐）。没传则 AskUserQuestion 让用户起或用 `<git-branch>` 兜底
- `quick` → 跳过 recap 和 harness，只生成 `handoffs/<slug>.md`
- `--close <slug>` → 闭环：把 `handoffs/<slug>.md` 移到 `handoffs/_archive/$(date +%F)-<slug>.md`，不写新文件

### Phase 1: 复盘（内部调 recap 流程）

执行 `/wrap recap` 的全部步骤：回顾对话 / 提取主题/进程/成果/踩坑 / 分析做对做错 / 更新 CC 侧记录（Memory/Skills/Commands/CLAUDE.md）/ 生成 session-retro（默认「主项目 docs/retros/ + 中央 symlink」双向链接，见 retro 节「输出位置规则」）

### Phase 2: 配置升级检查（/harness）

基于本轮收获检查项目 CC 配置是否需要升级：Skills / Commands / CLAUDE.md / Hooks。需要更新的直接执行。

### Phase 3: 生成 HANDOFF.md

#### Step 3.0a · Paths 健康体检（阶梯式严格度）

```bash
python3 ~/Dev/devtools/lib/tools/paths.py audit --brief
```

按 dead 数量分级处理（不阻塞 commit，但写入 handoff）：

| dead 数 | 处理 |
|---|---|
| `0` | 不写入 handoff |
| `1-50` | 把 `audit --brief` 输出原样记入 handoff「踩过的坑」节 |
| `> 50` | **升级**：记入 handoff「待完成」节首项 + 必须建议下次跑 `paths.py scan-dead --strict` 定位 + 给出"路径死链偏多"flag |

#### Step 3.0 · 判主项目（确定 `<root>` 目录）

启发式：
1. 盘点本轮所有 Edit/Write 文件绝对路径
2. 按 `~/Dev/{stations,labs,content,tools,devtools,migrated}/<top>` 归组
3. 唯一桶 ≥70% 改动 → `<root>` = 该 repo 根；跨 3+ repo 且根级文件占主 → `<root>` = `~/Dev`；模糊用 AskUserQuestion 让用户选

#### Step 3.0b · slug 确定（option E · 2026-05-02 立）

写到 `<root>/handoffs/<slug>.md`，**禁用**裸 `<root>/HANDOFF.md`（旧 SSOT 已废）。多并行任务靠不同 slug 隔离，互不覆盖。

**slug 来源（优先级）**：
1. `--slug <name>` 显式参数 → 直接用
2. 缺失 → AskUserQuestion 让用户给（带候选：当前 git branch / 上轮 slug / `main`）
3. 用户没回 → 用 git branch；branch = `main`/`master` → 用 `main` 兜底

**slug 命名**：kebab-case + 任务关键词（`nav-merge` / `ops-console-hammerspoon` / `28-doms-audit`）。**禁带日期 / 版本号** — 日期看 mtime，多轮同 slug 覆盖更新。

**多轮 / 多版本**：保持同 slug，文件覆盖；**不**开 `<slug>-v0.1.md` `<slug>-v0.2.md`。要保留历史 → 先关闭旧 slug（`/wrap handoff --close <旧 slug>`，mv 进 `_archive/`）再开新 slug。

#### Step 3.0c · 准备目录

```bash
mkdir -p <root>/handoffs/_archive
```

#### Step 3.1 · 写入 `<root>/handoffs/<slug>.md`

格式：

```markdown
# Handoff · {项目名} · {slug}

> {YYYY-MM-DD} · {一句话当前状态}

## 当前进展
{已完成工作，按逻辑分组}

## 待完成
- [ ] [P0] {具体任务} — {一句话决策 / 上下文}
  - {详细背景 / 约束 / 验收方式}
- [ ] [P1] ...
- [ ] [defer-v0.x] ...   # 用户明确说"留下次"才打

# marker 格式见顶部「§ 跨子命令编排协议」第 2 节

## 关键文件
| 文件 | 说明 |
|---|---|
| {完整绝对路径} | {一句话} |

## 踩过的坑
{本轮问题与解决方案}

## 下个会话启动
{建议第一条指令}
```

可选多轮 banner（顶部追加）：`> 共 N 轮 → v1.0 · 本轮闭环：xxx`

### Phase 4: 输出汇总

```
--- Handoff 完成 ---
复盘（物理）：<主项目>/docs/retros/session-retro-{date}.md
复盘（中央 symlink）：~/Dev/stations/docs/knowledge/session-retro-{date}.md
记忆：更新 {N} 条 / 新增 {N} 条
配置：{更新了什么 / 无需更新}
交接：{<root>/handoffs/<slug>.md 的绝对路径}
本项目并行 handoff：{N} 份（含本次）— 见 `ls <root>/handoffs/`
待办：{N} 项未完成
下个会话启动：{建议指令}
```

无主项目（`--central` 或跨多 repo）→ 复盘行只显示中央路径。

### 规则
- `handoffs/<slug>.md` 的受众是下一个 CC 会话，写得像技术文档不是散文
- 关键文件用完整绝对路径
- 待完成项用 `- [ ] [P0/P1/P2/defer-v0.x/external] xxx` 标准格式（见「§ 跨子命令编排协议」第 2 节）— /start 才能解析高亮
- 踩过的坑写根因和解法
- `quick` 模式跳过 Phase 1+2
- 关闭旧 handoff：`/wrap handoff --close <旧 slug>` 或手工 `mv <root>/handoffs/<旧 slug>.md <root>/handoffs/_archive/$(date +%F)-<旧 slug>.md`
- 落地：单 station 改动 → `<station>/handoffs/<slug>.md`；跨站群 / ~/Dev meta 级 → `~/Dev/wiki/handoffs/dev/<slug>.md`
- 没有 INDEX.md / 没有 symlink — `ls handoffs/` 就是 query

---

## recap — 复盘本轮对话

通读对话，更新 CC 侧记录，生成 session retro 文件。

### Step 1: 回顾本轮对话
提取：主题 / 目的 / 进程 / 最终成果 / 踩坑经历

### Step 2: 改进与经验
分析：做对了什么 / 做错了什么 / 工程模式 / 沟通层面

### Step 3: CC 侧记录

逐项检查更新：

1. **Memory**（`~/.claude/projects/*/memory/`）— 新 feedback / project / user / reference？检查现有需更新或删除？

2. **Skills**（`~/Dev/tools/cc-configs/skills/`）— 现有 skill 需更新？需新建？

   **Skill 候选池**（`~/Dev/tools/cc-configs/skill-candidates.md`）— 识别**重复出现的工作模式**未被 skill/command 覆盖：
   - 多步操作被手动执行 2+ 次？
   - 固定判断逻辑被反复描述？
   - 特定领域知识被反复注入？

   新候选追加记录：候选名称 / 发现时间 / 出现次数 / 状态 (active|done|dismissed) / 模式描述 / 涉及项目 / 潜在 skill 类型。已存在则更新出现次数。次数 ≥ 3 提示用户正式创建。

   **Skill/Command 使用追踪**（`~/Dev/tools/cc-configs/skill-tracker.json`）— 更新 last_used / use_count / correction_count（用户纠正时）。correction_count >= 3 提示重写。

3. **Commands** — 现有需更新？需新建？

4. **CLAUDE.md** — 当前项目新约束或路径变化需记录？

### Step 3.5: Paths 健康体检（**复用上游 / 独立运行才跑**）

**handoff 内部调用**（默认路径）：handoff Phase 3.0a 已跑过 `paths.py audit --brief`，本步**复用结果**，不重跑（详见「§ 跨子命令编排协议」第 3 节）。

**独立 `/wrap recap`**（不经 handoff）：本步必跑：

```bash
python3 ~/Dev/devtools/lib/tools/paths.py audit --brief
```

按 dead 数量分级（与 handoff Phase 3.0a 一致）：

| dead 数 | 处理 |
|---|---|
| `0` | 不写入 retro |
| `1-50` | 记入 retro「未完成项」节 |
| `> 50` | **升级**：记入「未完成项」首项 + 建议跑 `paths.py scan-dead --strict` |

### Step 4: 用户侧记录

生成 session retro MD。**默认走「主项目目录 + 中央 symlink」双向链接模式**（见 retro 节「输出位置规则」），即：
- 物理：`<主项目>/docs/retros/session-retro-{YYYYMMDD}.md`（同日多 session 加 `-2.md` 后缀）
- 中央 symlink：`~/Dev/stations/docs/knowledge/session-retro-{YYYYMMDD}.md` → 物理
- 中央索引：`~/Dev/stations/docs/knowledge/INDEX.md` 追加一行

无主项目（跨多 repo）→ 直接落中央，不建 symlink。

格式：1.做对了什么 / 2.走了哪些弯路（和为什么）/ 3.工程模式 / 4.沟通反思 / 5.成果清单（路径表）/ 6.未完成项

### Step 5: 输出汇总

```
📋 本轮复盘完成
主题：...
成果：N 个文件
记忆：更新 N / 新增 N
技能候选：N 个新增 / N 个达阈值
追踪：N 个 skill/command 更新
待办：N 项
文件（物理）：<主项目>/docs/retros/session-retro-{date}.md
文件（中央 symlink）：~/Dev/stations/docs/knowledge/session-retro-{date}.md
中央索引：~/Dev/stations/docs/knowledge/INDEX.md（已追加一行）
```

无主项目时仅显示中央路径。

### 规则
- 诚实，不粉饰错误
- 踩坑写根因，不只描述现象
- 用户原话反馈如实记录
- Memory 更新具体，不写空泛"用户喜欢 X"
- 没踩坑可简写第 2 节；没新工程模式可跳过第 3 节
- retro 用中文

---

## retro — Playbook 式复盘（受众：用户）

**Playbook，不是工具调用清单**。产出"这类任务的标准 slash command 编排流程"，让用户下次能抄。

通常由 handoff Phase 1 内部链路生成；也可手工 `/wrap retro` 单跑（已有 retro，做后期补充提炼）。

### 参数
- 无参数 → 默认主项目 + 中央 symlink 双链（启发式判主项目同 handoff Phase 3.0）
- `--central` → 仅写中央 `~/Dev/stations/docs/knowledge/session-retro-{YYYYMMDD}-{topic-slug}.md`（跨多 repo / meta 级用）
- `--stdout` → 只输出不落盘
- `--path <path>` → 显式指定物理文件位置
- 短描述（如 `r7 mega`）→ 作 topic-slug

### 输出位置（默认行为）

1. **判主项目**（启发式）：盘点本轮 Edit/Write 路径 → 唯一桶 ≥70% → 主项目；跨 3+ repo 自动走 `--central`；模糊 AskUserQuestion
2. **物理文件**：`<主项目>/docs/retros/session-retro-{YYYYMMDD}-{topic-slug}.md`（topic-slug 与文件名一致即可，无需"文学化"）
3. **中央 symlink**：`~/Dev/stations/docs/knowledge/session-retro-{YYYYMMDD}-{topic-slug}.md` → 物理文件（用 `~/Dev/tools/cc-configs/tools/retro-symlink/retro_symlink.py link <物理文件>` 一句话搞定，自动算相对路径 + 更新 INDEX.md）
4. **INDEX.md** 追加倒序行（**仅 retro 写**，见「§ 跨子命令编排协议」第 1 节）

### 硬约束 · Playbook 格式

写完前问自己：
- 用户下次遇到类似任务，**抄这份 MD 哪几行就能指挥 CC**？
- 我本该用 skill 却走了 bash 的地方在哪？用户看完能纠正我吗？
- 这套流程能抽象成多少条 `/command` 编排？

答得出 = 好 playbook；答不出 = 工具调用流水账，作废重写。

必有节（顺序固定）：
1. **核心编排**（ASCII 流程图，slash command 串联，`/start` → 主体 → `/wrap handoff` 收口）
2. **每 Phase 节**：用什么 `/command` / 触发时机 / 本次怎么做（漏用 skill 老实说"走了 bash"）/ 正确姿势 / 下次记得
3. **通用 Playbook**：抽象成可复用模板
4. **本次漏了什么 skill**：诚实标出"本该用 /xxx 但走了 bash"，让用户能纠正

**反例 vs 正解**：
- ❌「Write × 3 / Edit × 5 / Bash × 12」工具流水账
- ✅「Phase 2 PR1 SSOT 改造，验证 /menus-audit（本次走了 bash，下次记得用 skill）」

### 常见可 skill 化动作映射

| 动作 | skill |
|---|---|
| 进项目看状态 | `/start` |
| 验证 yaml/配置 | `/menus-audit` `/cf audit` `/repo audit` |
| 同步 SSOT | `/refresh-site --kind {all,navbar,header,content}` |
| 部署 | `/deploy <name>`（已上线迭代） / `/site ship <name>`（首次上线 + CF/nginx 创建） |
| commit + push | `/repo ship <repo1> <repo2>` |
| 健康检查 | `/health {sites,vps,project}` |
| 整理目录 | `/tidy <path>` |
| 收尾 | `/wrap handoff` |

详细识别流程：通读会话 → 提取每个关键动作 → 查 available-skills 对照 → 找到=标"本该用 /xxx" / 找不到=保留工程工作。

## distill — 从项目提炼到全局（受众：全局知识库）

从当前项目提炼**可复用 commands / 踩坑 / playbook 骨架**到全局。适用任意 `~/Dev/` 或 `~/Dev/Work/` 项目。

通常单独跑 `/wrap distill`（不走 handoff 内部链）；高频 distill 是新工作模式从项目下沉到全局的方式。

### 参数
- 无参数 → 分析当前目录，输出提炼报告（不落盘）
- `--apply` → 真正执行（cp commands / 更新 CLAUDE.md / 写 playbook）
- `--dry-run` → 报告但不写
- `--skip-playbook` → 跳过 Phase 6

### 流程速览

1. **盘点本项目产出**：`.claude/commands/*.md` / `scripts/*.py` / handoff 踩坑节 / 草稿
2. **对比全局现有**：每个 local command 是否已在 `~/.claude/commands/` 存在；domain CLAUDE.md 踩坑是否已记
3. **生成提炼报告**：表格（类别 / 项目 / 状态 🆕/✅ / 建议）
4. **Slash 生态审计**（写到 `~/Dev/stations/docs/knowledge/slash-audit-{YYYYMMDD}.md`）：扫所有 `commands/*.md` description，按 4 类问题 — ① 重叠 / ② 职责错位 / ③ 空隙 / ④ 冗余 — 列建议
5. **执行提炼**（`--apply`）：泛化（移除项目特有引用）→ `cp` 到 `~/.claude/commands/`（**唯一写入入口**，见「§ 跨子命令编排协议」第 1 节）→ 同名冲突列 diff 让用户决 → 更新 domain CLAUDE.md 踩坑节
6. **Phase 6 · Playbook 归档**（按 cwd 前缀匹配 domain）：

| cwd 前缀 | domain | playbook 文件 |
|---|---|---|
| `~/Dev/Work/bids/` | `bids` | `~/Dev/Work/_playbooks/bids/` |
| `~/Dev/Work/eco-flow/` | `eco-flow` | `~/Dev/Work/_playbooks/eco-flow/` |
| `~/Dev/Work/zdwp/projects/reclaim/` | `reclaim` | `~/Dev/Work/_playbooks/reclaim/` |
| `~/Dev/Work/zdwp/projects/*/` | `zdwp-<子项目>` | `~/Dev/Work/_playbooks/zdwp-*/` |
| `~/Dev/<name>/`（站群） | `stations` | `~/Dev/tools/configs/playbooks/stations.md` |
| `~/Dev/<name>/`（新站） | `web-scaffold` | `~/Dev/tools/configs/playbooks/web-scaffold.md` |
| `~/Dev/hydro-*/` | `hydro` | `~/Dev/tools/configs/playbooks/hydro.md` |
| `~/Dev/personal-kb/` | `personal-kb` | `~/Dev/tools/configs/playbooks/personal-kb.md` |
| `~/Dev/tools/cc-configs/` 或 slash 整顿 | `cc-meta` | `~/Dev/tools/configs/playbooks/META.md` §5 |
| 其他 | 询问用户 | — |

- **首次（无 playbook）**：建文件按 META.md §3 8 节骨架填
- **已有 playbook**：末尾 `## 后续会话追加 <YYYY-MM-DD>` 小节
7. **验证**：`test -f` + grep INDEX.md 确认归档；输出 playbook 路径

### 关键约束
1. 泛化而非照搬（移除项目特有名 / 文件名 / 章节号）
2. **不覆盖**已有全局 command — 同名不同内容列 diff 让用户决
3. 踩坑不重复（先 grep domain CLAUDE.md）
4. Playbook 时间轴 + 命令清单简洁颗粒度

## 参考

- Playbook 总入口：`~/Dev/tools/configs/playbooks/META.md`
- 中央 retro 索引：`~/Dev/stations/docs/knowledge/INDEX.md`（symlink 集合 + 时间线）
- retro symlink 工具：`~/Dev/tools/cc-configs/tools/retro-symlink/retro_symlink.py`（link 单文件 / migrate 批量回迁）
- 旧示例（单一中央）：`~/Dev/stations/docs/knowledge/session-retro-20260419-r7-mega.md`
- 新示例（物理 + symlink）：`~/Dev/stations/wpl-calc/docs/retros/session-retro-20260501-wpl-calc-v08.md` ← `~/Dev/stations/docs/knowledge/session-retro-20260501-wpl-calc-v08.md`
