---
description: 入场 — 一条命令了解项目 + 配脚手架。warmup（读状态）→ gap 分析 → 推荐脚手架 → 用户批准应用。/start 为 /wrap 的对称：start 进、wrap 出。
---

# /start — 立刻进入工作

进 `~/Dev/*` 或 `~/Dev/Work/*` 任何项目跑这一句，得到：**当前情报 + 缺啥脚手架 + 怎么补**。

```
/start                 # 默认：4 phase 全跑（warmup → gap → 推荐 → 用户批准应用）
/start --check         # 只跑 Phase 1+2（warmup + gap report，不推荐不应用）
/start --apply-all     # 批量应用全部推荐（auto-approve，仅推荐熟悉项目用）
```

`/start` 和 `/wrap` 是会话两端：
- **`/start`** 进来：读状态 → 缺啥补啥（脚手架）
- 中段：playbook 分派（META.md §5）
- **`/wrap`** 出去：复盘 → 检查 harness 增量 → handoff

---

## Phase 1 — Warmup（纯只读）

### 执行

```bash
python3 ~/Dev/devtools/lib/tools/warmup.py
python3 ~/Dev/devtools/lib/tools/paths.py audit --brief
```

第 2 条输出单行 `paths: 25 registered / 20 dead / 0 drift`，作为「输出段」第 3.5 项展示。

### 输出段

1. **项目** — CWD、git branch、脏/干净、未推 commit、最近一次 commit
2. **🔗 跨项目主题**（仅在 cwd 命中 `topic-index.yaml` 时显示） — 当前 topic + description + primary 入口 + 同 topic 兄弟项目清单。**避免"我在 X 目录但不知道 Y 目录有现成基建"**。
   - 数据源：`~/Dev/tools/configs/topic-index.yaml`（10 topics × directories 反向索引）
   - 实现：`warmup.py section_topics()` → `python3 ~/Dev/devtools/lib/tools/topic_index.py lookup <cwd>`
   - 维护：加新项目→找最匹配 topic 的 `directories:` 加一行；找不到→加新 topic
3. **CC 配置** — 是否有 `.claude/`、CLAUDE.md（+ H1）、`harness.yaml` 的全局 + 本项目 skills、合计加载数
4. **交接状态** — 多输入感知（与 `/wrap` 对称）：
   - **当前层 `handoffs/*.md` 全列**（每条 age + H1）；本层无 → 走 `~/Dev/wiki/handoffs/dev/` Dev-meta 层；legacy `HANDOFF*.md` 兜底
   - **单 handoff** → 提取前 6 条待办（priority marker 高亮：`**[P0]**` 加粗 / `~~[defer-vX.Y]~~` 灰化 / `⏳[external]` 等候）
   - **多 handoff 并行**（`>1` 份）→ 跨全部 handoff 汇总待办（每 slug ≤3 条，总 ≤12），按 slug 分组展示；priority marker 同上规则解析
   - **slug 推荐**（仅多 handoff 触发）→ warmup 调 `_suggest_slug(cwd, existing, git_branch)`：branch 匹配某 slug → 复用；否则推荐"基于 branch / cwd-name / 含日期"新 slug，避免串线
   - **其他活跃 handoff**（跨项目最近 3 份）→ 通知性展示（不解析待办，只看到上下文）
5. **📍 paths** — `paths.py audit --brief` 的单行输出原样展示；dead `1-50` 第 5 段追加 hint；dead `>50` 升级为「下一步」首项 + 建议 `paths.py scan-dead --strict`（与 `/wrap` Phase 3.0a 阶梯一致）

---

## Phase 2 — Gap 分析（诊断 + 对比 harness 预期）

### 2a. 项目类型判定

| 类型 | 判定依据 |
|---|---|
| `streamlit` | 有 `app.py` + `streamlit` in requirements |
| `tauri` | 有 `src-tauri/` |
| `cli` | 有 `if __name__` 入口 + argparse/click，无 web 框架 |
| `library` | 有 `setup.py` / `pyproject.toml`，无入口脚本 |
| `scripts` | 多个独立脚本，无统一入口 |
| `docs` | 纯 Markdown，无代码 |
| `monorepo` | 多个子项目（apps/packages 目录） |
| `webapp` | Flask/FastAPI/Express 等 web 框架 |
| `nextjs` | 有 `next.config.*` |

### 2b. 项目阶段判定

| 阶段 | 判定 | 配置预期 |
|---|---|---|
| **seed** | 无 CLAUDE.md，<5 个源文件 | 最小：CLAUDE.md |
| **growing** | 有 CLAUDE.md 但不完整，5-50 个源文件 | 补全 CLAUDE.md + README + .gitignore |
| **established** | 有 CLAUDE.md + README，>50 个源文件或有部署 | 完整配置 + hooks + 项目专用 rules |
| **mature** | 完整配置，多贡献者或复杂工作流 | 优化：skills 绑定、agent 定义、验证闭环 |

### 2c. 输出诊断

```
📋 Phase 2 · Gap Analysis

项目：hydro-rainfall (streamlit, growing → established)
路径：~/Dev/stations/web-stack/services/hydro-rainfall
源文件：37 个 Python, 2 个 YAML
部署：VPS (hydro-rainfall.tianlizeng.cloud)

现有配置：CLAUDE.md ✓  README.md ✓  README_CN.md ✗  .gitignore ✓  LICENSE ✗  hooks ✗
harness.yaml 注册：未注册（如需要）

Gaps（按 established 阶段预期）：
- README_CN.md 缺
- LICENSE 缺
- 推荐 hooks（streamlit 项目可加端口冲突检查）
```

**陌生项目深探（可选 · auggie 优先）**：判定为 `growing`/`established`/`mature` 且 CC 对此项目陌生（无 cwd 历史 / 上轮 HANDOFF 缺 / Phase 3 要生成 CLAUDE.md）→ 用 auggie 拿一份"项目脑图"，避免后续问"X 在哪 / 数据怎么走"再单独召回。

```
mcp__auggie__codebase-retrieval(
  workspace=<project root>,
  request="项目核心模块、入口、主要数据流、对外接口"
)
```

跳过条件：`seed` 阶段 / 项目在 `~/Dev/tools/configs/auggie-workspaces.yaml` 标 `indexable: false`（数据型 / archive） / 用户已说"快速看一眼"。

`--check` 到此停。

---

## Phase 3 — 推荐脚手架（scaffold.py 驱动）

### 入口

```bash
# 探测 type / stage / gaps
python3 ~/Dev/devtools/lib/tools/scaffold.py detect [path]

# 预览某项产物（不写文件）
python3 ~/Dev/devtools/lib/tools/scaffold.py preview [path] --kind <claude-md|readme-en|readme-cn|gitignore|dot-claude> [--stage <s>] [--type <t>]

# 应用单项（默认 dry-run，加 --yes 实写）
python3 ~/Dev/devtools/lib/tools/scaffold.py apply [path] --kind <k> [--yes]

# 应用所有 gaps（推荐主入口）
python3 ~/Dev/devtools/lib/tools/scaffold.py apply [path] --all [--yes]
```

### 模板路径

| 类型 | 模板根 |
|---|---|
| CLAUDE.md（4 stage） | `~/Dev/tools/cc-configs/templates/project-claude-md/{seed,growing,established,mature}.md.j2` |
| README（4 type variant） | `~/Dev/tools/cc-configs/templates/readme/{app-en,app-cn,content-en,minimal-en}.md.j2` |
| `.claude/` 骨架 | `~/Dev/tools/cc-configs/templates/project-dot-claude/` |
| `.gitignore` baseline | `~/Dev/tools/cc-configs/templates/gitignore-baseline/{python,node,docs,go}.txt` |

scaffold.py 会按 `detect` 输出的 `type + stage` 自动选模板 variant + 替换占位符（`{{project_name}}` / `{{description}}` / `{{type}}` / `{{stage}}` / `{{tree_2}}` / `{{commands}}` / `{{stack}}` / `{{deploy}}`）。

### 阶段对应表

按 stage 给具体补什么 + 内容预览：

### seed → 最小可用

| 配置 | 内容 |
|---|---|
| **CLAUDE.md** | 项目概述、Quick Reference 表、常用命令、项目结构（tree depth 2） |

### growing → 补全基础

包含 seed 全部，加：

| 配置 | 内容 |
|---|---|
| **README.md** | 按 `/repo audit` 的 readme_template 规则生成（app/infra/content/minimal） |
| **README_CN.md** | README.md 的中文翻译 |
| **.gitignore** | 按语言补全 baseline 条目（复用 `repo-standards.json → common.gitignore_baseline`） |
| **LICENSE** | MIT（copyright holder = tianli） |

### established → 工程化

包含 growing 全部，加：

| 配置 | 内容 |
|---|---|
| **CLAUDE.md 升级** | 添加开发注意事项、技术栈、数据源说明 |
| **hooks** | 根据项目类型推荐 PostToolUse hooks |
| **rules/** | 项目专用规则（如有 Word 文档处理 → 写作规范 rule） |

推荐 hooks 策略：

| 项目类型 | 推荐 hooks |
|---|---|
| streamlit / webapp | Bash 后自动检查端口冲突 |
| cli / library | Edit 后检查 import 完整性 |
| scripts | Bash 后检查退出码 |
| 有测试的项目 | Edit 后提示运行相关测试 |

### mature → 优化闭环

包含 established 全部，加：

| 配置 | 内容 |
|---|---|
| **skills 绑定** | 检查 `~/Dev/tools/cc-configs/skills/` 是否有适用的 skill，建议绑定 |
| **agent 定义** | 复杂多步工作流 → 专用 agent |
| **验证命令** | CLAUDE.md 添加 done-conditions 和验证命令 |

---

## Phase 4 — 用户批准 + 应用

逐项展示生成结果，等待批准：

```
[1/4] CLAUDE.md (新建)
{preview first 20 lines}
→ 审批? [Y/n/edit]

[2/4] README.md (新建)
{preview first 20 lines}
→ 审批? [Y/n/edit]

[3/4] README_CN.md (新建)
→ 审批? [Y/n/edit]

[4/4] .gitignore (补全 3 条)
+ __pycache__/
+ .env
+ *.pyc
→ 审批? [Y/n/edit]
```

`--apply-all` 跳过批准，全部应用（仅推荐熟悉项目）。

### 应用规则

1. **已存在且达标** → 跳过，标记 ✓
2. **已存在但不完整** → 显示 diff 预览，等待批准
3. **不存在** → 生成完整内容，等待批准

---

## CLAUDE.md / README 生成规范

> 模板已落地到 `~/Dev/tools/cc-configs/templates/`，scaffold.py 自动按 type+stage 选变体 + 替换占位符。下文为模板设计原则参考。

### CLAUDE.md（中文）

读项目代码后生成，参考已有项目格式：

```markdown
# {项目名}

{一句话描述}

## Quick Reference

| 项目 | 路径/值 |
|---|---|
| 入口 | `{main entry}` |
| 部署 | {deploy info if any} |
| 测试 | `{test command}` |

## 常用命令

\```bash
{最常用的命令}
\```

## 项目结构

\```
{tree output, depth 2}
\```

## 开发注意事项

- {从代码中提取的关键约束}
```

### README.md（英文）

复用 `/repo audit` 的 readme_template 体系。金标准参考：`~/Dev/stations/dockit/README.md`。

必须包含：
- 语言切换：`**English** | [中文](README_CN.md)`
- for-the-badge 徽章
- 分隔线 + 截图占位
- 功能表格
- 安装 / 快速上手

### README_CN.md（中文）

镜像 README.md 结构，翻译为中文。代码块、URL、技术术语不变。

---

## Phase 5 — 收尾汇总

```
🏗️ /start 完成

项目：hydro-rainfall (streamlit, established)
现状：
  ✅ CLAUDE.md / README / .gitignore — 已达标
  🆕 README_CN.md / LICENSE — 已新建
  🔧 .gitignore +3 条 — 已补
  💤 hooks — 跳过（用户拒）

建议：
  → engineering-mode 已加载，破坏性操作记得 Plan mode
  → handoffs/<slug>.md 1 天前，可读取上次进度（多份并行则提示 slug 数）
  → 下一步按 META.md §5 trigger words 匹配 playbook

提交? [Y/n]
```

确认 → 调用 `/repo ship` 提交。

---

## 什么时候跑

- **首选**：进入新/陌生项目目录的第一个命令
- 久未动的项目重新开工前
- 不确定当前 CC 配置加载了啥时
- 想知道 harness.yaml 把哪些 skills 分给这个项目时
- 新项目刚 mkdir 完想配脚手架

## 不做

- 不修改任何 git 状态（不 commit / push 在 /start 内做，建议提交是 Phase 5 末尾邀约）
- 不自动跑 `/wrap handoff`；只提示是否该跑
- 不展示 HANDOFF 全文（太长）；只给年龄、标题、摘要
- 不覆盖已有内容 — 只补全或升级
- 不生成用不到的配置（seed 阶段不推 hooks，没部署不推 deploy 相关）

## 规则

- CLAUDE.md 用中文，README.md 用英文，README_CN.md 用中文
- 每个配置项都要批准，不批量强推（除非 `--apply-all`）
- 复用已有命令的逻辑：.gitignore baseline 来自 `repo-standards.json`，README 模板来自 `/repo audit` 体系
- 阶段判定要保守 — 宁可低估，让用户决定是否升级
- `--check` 模式纯只读，不写任何文件
- 凭证在 `~/.personal_env`，不问用户要

## 相关

- `/wrap`（对称收尾） — recap + harness check + handoff
- `/preflight`（干活中） — 破坏性操作前侦察（不属入场）
- META.md §5 — 入场后按 trigger words 匹配 domain playbook
