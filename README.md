# cc-configs

**中文** | [English](README_EN.md)

Claude Code 配置中心 — 斜杠命令 + 自动触发技能 + Agent 定义 + 规则 + CLI 工具（审计 + 上下文监控），全部用代码管理在一个 repo 里，symlink 到 `~/.claude/`。

[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/Python-3.8+-yellow?style=for-the-badge)](https://python.org)

---

![cc-configs 演示](docs/screenshots/demo.png)

---

## 这是什么？

| 层 | 内容 | 位置 |
|----|------|------|
| **Commands** | 30 个活跃命令 + 4 个已归档 | `commands/` |
| **Skills** | 14 个自动触发的上下文注入 | `skills/` |
| **Agents** | 2 个专用 Agent 定义 | `agents/` |
| **Rules** | 命令规则文件 | `rules/` |
| **Harness 工具** | 六维度配置质量扫描 | `tools/harness/` |
| **Context 工具** | Token 监控、快照、健康检查 | `tools/context/` |
| **Stats 工具** | 命令使用频率统计 | `tools/cmd_stats.py` |

`install.sh` 将 `commands/`、`skills/`、`agents/` symlink 到 `~/.claude/`，Claude Code 在所有项目中自动加载。

## 安装

```bash
git clone https://github.com/zengtianli/cc-configs.git ~/Dev/tools/cc-configs
cd ~/Dev/tools/cc-configs
bash install.sh
```

创建的 symlink：

```
~/.claude/commands     → ~/Dev/tools/cc-configs/commands
~/.claude/skills       → ~/Dev/tools/cc-configs/skills
~/.claude/agents       → ~/Dev/tools/cc-configs/agents
```

更新只需 `git pull`，symlink 保持同步。

---

## Commands 命令手册

在 Claude Code 中输入 `/命令名 [参数]` 调用。每个 command 封装了一套可重复的工作流。

### 交付与部署

| 命令 | 用法 | 说明 |
|------|------|------|
| `/ship` | `/ship`、`/ship all` | 提交 + 推送一个或多个 repo。自动生成 conventional commit 消息。 |
| `/deploy` | `/deploy` | 部署当前项目到 VPS。检测 `deploy.sh`，需要时先 build 前端。 |
| `/pull` | `/pull`、`/pull all` | 批量 `git pull --ff-only`，支持单个或多个 repo。 |
| `/dashboard` | `/dashboard`、`/dashboard --scan-only` | 用 LLM 分析 Claude Code 会话，然后部署 dashboard 应用。 |
| `/scan` | `/scan` | 扫描 Claude Code 会话，LLM 分析任务状态，生成 `tasks.json`。 |

### Repo 管理

| 命令 | 用法 | 说明 |
|------|------|------|
| `/groom` | `/groom`、`/groom --check` | 完整 repo 维护流水线：pull → audit → fix → review → push。 |
| `/audit` | `/audit`、`/audit hydro-risk` | 基于 `repo-standards.json` 审计 repo 完整性。 |
| `/promote` | `/promote`、`/promote all --check` | GitHub metadata 审计：description、topics、homepage、截图。 |
| `/repo-map` | `/repo-map scan`、`/repo-map show` | 管理 GitHub ↔ 本地路径注册表（`repo-map.json`）。 |

### 文档处理

| 命令 | 用法 | 说明 |
|------|------|------|
| `/md2word` | `/md2word path/to/file.md` | MD/DOCX → Word 流水线：套模板 → 文本修复 → 图名居中。 |
| `/review` | `/review path/to/report.docx` | 审阅 Word 文档。默认格式检查，`--deep` 4 维度 LLM 审阅，`--all` 两轮全做。 |

### 迁移与构建

| 命令 | 用法 | 说明 |
|------|------|------|
| `/migrate` | `/migrate capacity` | 将 Python/Streamlit 应用移植到 Tauri 桌面应用（Rust + React）。 |

### 脚手架

| 命令 | 用法 | 说明 |
|------|------|------|
| `/harness` | `/harness`、`/harness ~/Dev/new-project` | 检测项目类型和成熟度，生成或升级 Claude Code 配置。 |

### 会话与工作流

| 命令 | 用法 | 说明 |
|------|------|------|
| `/recap` | `/recap` | 会话复盘：回顾对话、提取经验、更新 memory。 |
| `/handoff` | `/handoff` | 会话收尾：复盘 + 配置升级 + 交接文件一步完成。 |
| `/context` | `/context monitor`、`/context health` | 监控会话健康——token 消耗、工具调用分布、上下文膨胀检测。 |
| `/tidy` | `/tidy`、`/tidy ~/Dev/Work/docs` | 深度清理目录：发现垃圾文件、版本链、散乱文件。 |
| `/health` | `/health` | 文件卫生 + Git 状态检查。可调用 `/tidy` 清理。 |
| `/cmd-stats` | `/cmd-stats`、`/cmd-stats --days 7` | 统计 slash command 使用频率，基于会话 transcript 数据。 |

### 已归档命令

4 个命令在 `commands/archive/`（零调用或已被替代）。仍可通过 `archive:name` 前缀访问：

`dissect-report` · `gen-report` · `prep-ecoflow-calc` · `prep-engineering`

---

## Skills 技能手册

Skills 是自动触发的上下文注入。Claude Code 检测到匹配场景时自动加载技能知识，无需手动调用。

### 全局技能（所有项目生效）

| 技能 | 触发场景 | 提供的知识 |
|------|---------|-----------|
| **context** | 在 ZDWP 水利公司项目中工作 | 集团架构、县市列表、数据字段规范、交付标准 |
| **structure** | 整理文件、创建新项目 | 目录命名规则、文件分类规则、自动整理逻辑 |
| **plan-first** | 批量操作、破坏性动作 | 强制"先写方案再操作"——展示表格，等待审批 |
| **quarto** | 将 DOCX 转换为 Quarto 项目 | Quarto 编译工作流、模板结构、图表处理 |
| **frontend** | 做 UI 开发时 | 信息密度、紧凑布局、可操作数据、Streamlit 约定 |

### 项目专用技能

| 技能 | 绑定项目 | 提供的知识 |
|------|---------|-----------|
| **risk-map** | ~/Dev/Work/projects/risk-map | 洪水风险图数据处理、QGIS 空间工作流、Excel 模板填充 |
| **eco-flow** | ~/Dev/Work/projects/eco-flow | 生态流量计算（Tennant 法）、水库筛选、保障方案 |
| **zdys** | ~/Dev/Work/projects/zdys | 浙东引水运行态势、调度模型、灌溉需水计算 |
| **water-src** | ~/Dev/Work/projects/water-src | 饮用水水源地安全保障评估方法 |
| **water-quality** | （独立） | 千岛湖引水分质供水管理 |
| **resources** | risk-map, eco-flow, zdys, water-src | 共享资源：水库 DB、GIS 底图、行政边界、水资源年报 |

### 工具技能

| 技能 | 触发场景 | 提供的知识 |
|------|---------|-----------|
| **harness** | 检查/同步技能配置 | 技能分发注册表、跨项目同步逻辑 |
| **repo-manage** | 管理 GitHub repo | 审计/截图/推广 SOP |
| **restart** | 终端重启后恢复会话 | 会话恢复指令 |

---

## Agents 手册

| Agent | 用途 |
|-------|------|
| **bid-chapter-writer** | 按公司模板编写标书章节 |
| **project-content-checker** | 按需求清单审计项目交付物完整性 |

---

## CLI 工具

### Harness — 配置审计

```bash
python3 tools/harness/harness.py /path/to/project        # 完整审计
python3 tools/harness/harness.py /path/to/project --json  # JSON 输出
python3 tools/harness/harness.py /path/to/project --security-only
```

| 维度 | 检查内容 |
|------|---------|
| **D1 Context** | CLAUDE.md 质量、Token 预算、重复规则、嵌套文件、凭证 |
| **D2 Hooks** | PostToolUse 覆盖、schema 验证、输出截断、错误上报 |
| **D3 Agents** | Skill 数量、重叠、描述质量、frontmatter、disable-model-invocation |
| **D4 验证** | 完成条件、build/test 命令、CI 集成 |
| **D5 会话** | Compact Instructions、HANDOFF.md、上下文预算文档 |
| **D6 结构** | 孤立文件、引用链、命名规范、gitignore |

### Context — 会话监控

```bash
python3 tools/context/context.py monitor    # token 消耗
python3 tools/context/context.py health     # 健康检查
python3 tools/context/context.py snapshot save
```

### Command Stats — 命令统计

```bash
python3 tools/cmd_stats.py                  # 全量统计
python3 tools/cmd_stats.py --days 7         # 最近 7 天
python3 tools/cmd_stats.py --registered     # 只看注册命令
```

## 测试

```bash
python3 -m pytest tools/harness/tests/ -v
python3 -m pytest tools/context/tests/ -v
```

## 许可证

MIT
