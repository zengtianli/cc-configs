---
name: structure
description: ZDWP 目录结构规范、文件归属规则、命名规范、自动整理。当需要整理文件、判断文件归属、创建新项目时触发。
---

# ZDWP 目录结构与整理规范

## 目录架构

```
zdwp/
├── projects/               # 业务项目（10 个）
├── archives/               # 已完成项目
├── workspace/              # 收文暂存（inbox/drafts）
├── docs/                   # 使用指南
├── scripts/                # 工具脚本
└── .claude/                # skills + agents + commands
```

共享资源已独立：`~/Dev/Work/shared/resources/`（GIS、参考资料、基础数据）

## 项目标准结构

```
projects/{project-name}/
├── _project.yaml           # 项目元数据
├── _index.md               # 数据目录卡片（供 auggie 索引）
├── docs/                   # 文档
├── data/                   # 数据
├── code/                   # 代码/脚本（或 symlink 到 ~/Dev/）
├── deliverables/           # 交付成果
└── references/             # 参考资料
```

县市子项目：`projects/{project-name}/{city}-{county}/`

## 文件归属规则

| 文件特征 | 应放位置 |
|---------|---------|
| 全省/多县市共享 GIS | `~/Dev/Work/shared/resources/gis/` |
| 规范、政策、模板 | `~/Dev/Work/shared/resources/references/` |
| 脚本、工具、代码 | `~/Dev/` 下对应仓库 |
| 历史版本 | `archives/` |
| 归属不明的新文件 | `workspace/inbox/` |

### 项目关键词映射

| 关键词 | zdwp 项目 | 独立项目 |
|-------|-----------|---------|
| 再生水 | `projects/reclaim/` | — |
| 水库调度 | `projects/dispatch/` | — |
| 供水管网 | `projects/supply-net/` | — |
| 可用水量 | `projects/avail-water/` | — |
| 分质供水、千岛湖 | `projects/qual-supply/` | — |
| 纳污能力 | `projects/poll-cap/` | — |
| 农业水价 | `projects/agri-price/` | — |
| 用水权、水权 | `projects/rights/` | — |
| 漏损 | `projects/leak/` | — |
| 钱塘江监测 | `projects/qiantang-monitoring/` | — |
| 生态流量 | — | `~/Dev/Work/projects/eco-flow/` |
| 风险图、洪水 | — | `~/Dev/Work/projects/risk-map/` |
| 浙东、引水 | — | `~/Dev/Work/projects/zdys/` |
| 水源地 | — | `~/Dev/Work/projects/water-src/` |
| 岸线 | — | `~/Dev/Work/projects/shoreline/` |
| 建模竞赛 | — | `~/Dev/Work/projects/modeling/` |

### 按地区归类

景宁/缙云/青田... → lishui-xxx/
婺城/金东/兰溪... → jinhua-xxx/
温岭/仙居... → taizhou-xxx/

完整映射：`references/region-mapping.yaml`

### 按文件类型

| 类型 | 子目录 |
|-----|-------|
| .shp/.gdb/.geojson | data/ |
| .xlsx/.xls | data/ |
| .docx/.doc/.pdf | docs/ |
| .py/.sh/.js | 提示用户放 ~/Dev/ |
| .png/.jpg/.tif | references/ |

## 命名规范

文件：`[日期]_[业务]_[内容]_[版本].[后缀]`
示例：`2024-03-04_风险图_成果报告_v1.docx`

## 自动整理

当用户说"整理文件"时：

1. **先试运行**：`python3 .claude/skills/zdwp-structure/scripts/auto-organize.py --dry-run`
2. **显示结果**：展示将要移动的文件列表
3. **确认后执行**：`python3 .claude/skills/zdwp-structure/scripts/auto-organize.py`

## 创建新项目

1. 在 `projects/` 下创建目录（英文短名）
2. 创建 `_project.yaml`（参考 references/template-meta.yaml）
3. 创建 `_index.md`（数据目录卡片）
4. 创建标准子目录（按需）
