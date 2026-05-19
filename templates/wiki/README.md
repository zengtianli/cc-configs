# wiki/ — 项目 Wiki 化模板族

把项目文档按 **Wikipedia 风格**组织：1 个 Main Page (`WIKI.md`) + N 个独立子条目 (`docs/wiki/*.md`) + 标准 markdown link（**不用 Obsidian 双方括号风格**）。

参考实现：`~/Dev/_archive/2026-05-18-anthropic-hygiene/` (WIKI.md + docs/wiki/ 共 8 条目)。

## 文件清单

| 文件 | 用途 | 输出位置 |
|---|---|---|
| `main-page.md.j2` | 项目 Wiki 主入口 | `<project>/WIKI.md` |
| `sub-entry.md.j2` | 单个子条目 | `<project>/docs/wiki/<slug>.md` |

## 模板占位符

### main-page.md.j2

| 变量 | 含义 | 示例 |
|---|---|---|
| `project_name` | 项目名（从目录名自动） | `anthropic-account-hygiene` |
| `summary_30s` | § 0 30 秒看懂 | "你是 X，问题是 Y，方案是 Z" |
| `current_status` | § 1 当前阶段 / 状态 | "Phase 4 观察期 (5/3 → 5/10)" |
| `subentries_block` | § 2 核心条目导航（已渲染的 markdown 列表，每行 `-` 开头 wikilink） | 调用方预渲染 |
| `workflow_table` | § 3 工作流表格（markdown table） | `| 场景 | 跑什么 |\n|---\|---\|\n...` |
| `file_map_table` | § 4 文档地图 | 同上 |
| `glossary` | § 5 术语速查（术语 + 跳转 link 列表） | 调用方预渲染 |
| `has_references` (条件) | 是否有 docs/references/ | true / false（控制提示语） |

### sub-entry.md.j2

| 变量 | 含义 |
|---|---|
| `entry_title` | 条目标题（如 "1024proxy"） |
| `one_line_summary` | 一句话摘要 |
| `core_facts` | 核心事实（markdown 段落 / 表格 / 列表） |
| `has_config` (条件) | 是否有配置/步骤段 |
| `config_or_steps` | 配置内容（仅 has_config=true 时渲染） |
| `related_block` | 相关条目列表（已渲染 markdown） |

## 模板引擎说明

scaffold.py 的 mini-template 只支持：
- `{{var}}` — 变量替换
- `{{#if X}}...{{/if}}` — 条件块（X 真则保留）

**不支持** `{{#each}}` 循环。所以 list 类内容（subentries / related）由调用方**预渲染成 markdown 字符串**传入，模板直接拼接。

## 用法

```bash
# 渲染 main page 到 stdout
python3 ~/Dev/tools/dev/lib/tools/scaffold.py preview <project> --kind wiki-mainpage

# 渲染单条目
python3 ~/Dev/tools/dev/lib/tools/scaffold.py preview <project> --kind wiki-entry

# 一键初始化 docs/wiki/ + WIKI.md 骨架
python3 ~/Dev/tools/dev/lib/tools/scaffold.py wiki-init <project> [--topic proxy-and-vpn]
```

`wiki-init` 创建空骨架（用户自己填内容），不破坏已有文件（如已存在则跳过 + 警告）。

## 与 Obsidian 集成

项目内为真，Obsidian vault 用 symlink 引用：

```bash
python3 ~/Dev/tools/dev/lib/tools/obsidian_sync.py link <project>
# → ~/Obsidian/dev-vault/topics/<topic-id>/<project-name>/  (symlink)
```

CC 工作流不变（项目内文件是真的）；Obsidian 只是查看器。
