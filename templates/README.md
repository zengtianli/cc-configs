# Templates — 项目脚手架模板族

`scaffold.py` 渲染入口，按 type+stage 给项目自动生成 CLAUDE.md / README / .gitignore / .claude/。

## 目录

```
templates/
├── project-claude-md/        4 stage 阶梯（中文）
│   ├── seed.md.j2            最小：项目名 + Quick Reference + 命令
│   ├── growing.md.j2         + 项目结构 + 数据源
│   ├── established.md.j2     + 技术栈 + 注意事项 + 部署
│   └── mature.md.j2          + done-conditions + skill 绑定 + agent 建议
├── readme/                   README 风格变体
│   ├── app-en.md.j2          应用类英文（徽章 + 截图 + 安装 + 快速上手）
│   ├── app-cn.md.j2          应用类中文（镜像）
│   ├── content-en.md.j2      内容/写作类（无徽章，重导航）
│   └── minimal-en.md.j2      极简（H1 + 描述 + 1 个命令）
├── project-dot-claude/       项目级 .claude/ 骨架
│   ├── settings.json.j2      空 `{}`
│   ├── commands/.keep        slash command 占位
│   └── skills/.keep          skill 占位
├── gitignore-baseline/       按语言分的 .gitignore 起点
│   ├── python.txt
│   ├── node.txt
│   ├── docs.txt
│   └── go.txt
└── README.md                 本文件
```

## 占位符（mini-templating）

`scaffold.py` 用 stdlib re，仅支持 2 类语法：

| 语法 | 效果 |
|---|---|
| `{{var}}` | 变量替换 |
| `{{#if var}}...{{/if}}` | 条件块（var 真值则保留，否则删除整块） |

可用变量：

| 变量 | 含义 |
|---|---|
| `project_name` | 仓库目录名 |
| `description` | 一句话描述（默认占位） |
| `type` | streamlit/tauri/cli/library/scripts/docs/monorepo/webapp/nextjs |
| `stage` | seed/growing/established/mature |
| `entry` | 主入口（如 `app.py`、`scripts/`） |
| `tree_2` | tree depth 2 输出 |
| `commands` | 常用命令 |
| `stack` | 技术栈说明 |
| `deploy` | 部署 URL/方式（条件块用） |
| `notes` | 数据源/备注 |
| `install_cmd` | 安装命令（README 用） |
| `screenshot_path` | 截图路径（README 用） |

## 用法（CLI）

```bash
# 探测当前项目状态（输出 JSON）
python3 ~/Dev/tools/dev/lib/tools/scaffold.py detect

# 预览要生成的内容（不写文件）
python3 ~/Dev/tools/dev/lib/tools/scaffold.py preview --kind claude-md --stage growing
python3 ~/Dev/tools/dev/lib/tools/scaffold.py preview --kind readme-en

# 应用（默认 dry-run，加 --yes 才真写）
python3 ~/Dev/tools/dev/lib/tools/scaffold.py apply --kind claude-md --yes

# 应用所有 gaps 推荐
python3 ~/Dev/tools/dev/lib/tools/scaffold.py apply --all --yes
```

`/start` Phase 3-4 调这个 CLI。

## 维护

**加新模板**：

1. 放到对应子目录，文件名 `<name>.md.j2` 或 `<name>.txt`
2. 改 `scaffold.py` 的 `KIND_MAP` 加入新 kind
3. 占位符尽量复用上面表格里的，新增的更新 README

**改占位符**：

1. 改模板里的 `{{var}}`
2. 在 `scaffold.py` `detect()` / `build_vars()` 加对应字段
3. 跑 `scaffold.py preview` 验证

## 不做

- 不引入 Jinja2 / PyYAML 依赖（stdlib only）
- 不在模板里硬编码项目特定路径
- 不重复维护 readme_template — 这里就是 SoT
