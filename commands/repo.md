---
description: Repo 维护族 — map 注册表 / pull 批量拉 / ship 提交推 / promote GH 元数据 / audit 完整性 / groom 全流程 / launch 新项目一条龙
---

# /repo — Repo 维护统一入口

`/repo <subcommand> [args]`

| 子命令 | 干啥 |
|---|---|
| `map` | 维护 GitHub ↔ local path 映射（scan/sync/show/check/add/regen） |
| `pull` | 批量 git pull --ff-only |
| `ship` | commit + push（多 repo 一键） |
| `promote` | 推广 GH repo — README 审计 / 元数据 / 截图 |
| `audit` | 完整性审计（基于 repo-standards.json） |
| `groom` | 全流程：pull → audit → fix(/promote) → review → ship |
| `launch` | 新项目一条龙：site add → groom → repo map → site ship → deploy |

---

## map — GitHub ↔ local path 映射

SSOT：`~/Dev/tools/configs/repo-map.json`

字段：local / github / vps（null=未部署）/ category（hydro/tools/infra/knowledge/personal/work）/ auto_push

**Consumers**（嵌入此映射的文件）：
1. `~/Dev/tools/dev/scripts/tools/git_smart_push.py` — 运行时读 JSON，过滤 `auto_push: true`
2. `~/Dev/CLAUDE.md` — repo map table 节。`sync` 更新
3. `/repo ship` — `all` 模式读 `repo-map.json` 解析路径

> webhook 自动部署链路已下线（commit 9d8dfb8，2026-04-28）；归档说明见 `stations/docs/knowledge/架构设计/webhook-deployment.md`。

### 子命令

#### `scan`（默认）
1. 扫 `~/Dev/*/`、`~/Dev/Work/*/`、`~/Documents/sync` 找 `.git`
2. 每个读 `git remote get-url origin` 拿 GitHub repo
3. 对比 `repo-map.json`：
   - ✓ Matched
   - ⚠️ New（disk 有但 registry 无）→ 提示加 + category/vps/auto_push
   - ✗ Missing（registry 有但 disk 无）→ 警告
4. 更新 `repo-map.json`

#### `sync`
1. 读 `repo-map.json`
2. 重生 consumer #2 嵌入映射：
   - `CLAUDE.md` repo map 节 — 全部按 category 分组
3. 显示 diff，apply，报告

#### `show`
按 category 分组的格式表格：

```
hydro (12)  ★=auto_push
  hydro-rainfall    ~/Dev/stations/web-stack/services/hydro-rainfall    zengtianli/hydro-rainfall    /opt/hydro/hydro-rainfall

work (2)
★ zdwp              ~/Dev/Work/zdwp             zengtianli/zdwp              /var/www/zdwp
```

#### `check`
验证一致性：
- `repo-map.json` vs 实际 `git remote`
- vs `webhook_receiver.py` REPO_PATHS
- vs `CLAUDE.md` repo map 节
报告 mismatch + file:line。

#### `add <name>`
1. 检查目录存在 + 有 git remote
2. 提示 category / vps / auto_push
3. 加进 `repo-map.json`
4. 建议跑 `sync` 传播

#### `regen`
完全重扫 `~/Dev/{stations,tools,labs,content,migrated}/*` + 根下工具基建，**消除手工漂移**，写入 `~/Dev/tools/configs/repo-map.json`。

```bash
/repo map regen           # 写入
/repo map regen --dry-run # 预览（stdout）
```

实际执行：
```bash
python3 ~/Dev/tools/dev/lib/tools/repo_map_gen.py            # 写入
python3 ~/Dev/tools/dev/lib/tools/repo_map_gen.py --stdout   # 预览
```

**和 scan 区别**：scan 增量对账（找新增/缺失），交互式确认每条；regen 全量重建（覆盖 JSON），用于"手工漂移已严重，统一对齐"场景。2026-04-22 调查 22 条陈旧 + 8 条缺失 → regen 一次清干净。

**何时用 regen**：大规模目录重构后 / 怀疑漂移 / `check` 大量不一致

**规则**：只登记含 `.git` 的本地 repo；路径统一 `~/Dev/...`；remote 从 `git config --get remote.origin.url`；分层 stations/tools/labs/content/migrated；根下白名单 ROOT_REPOS（devtools / doctools / mactools / clashx / dotfiles / ...）

### Map 规则
- `repo-map.json` 永远是 SoT
- `web` repo: GitHub `web`，本地 `website`
- `git_smart_push.py` 运行时读 JSON，无需 sync（动态）
- `webhook_receiver.py` 静态（VPS 上跑），必须 sync + push
- 不删除 entry 不问

---

## pull — 批量 git pull --ff-only

### 范围（同 ship 参数规范）
- 无参数 → 当前目录（必须 git repo）
- `.` → 当前目录
- `<name> [name2 ...]` → `repo-map.json` 查 `local` 路径
- `all` → 所有 `"ignored": false` 的 repo

### 流程
对每 repo：
1. 解析 `local` 路径，确认存在
2. `git fetch --all --prune`
3. `git pull --ff-only`
4. ff-only 失败（diverged）→ ⚠ 不强制

### 输出
```
✓ dockit          pulled (2 commits)
✓ hydro-rainfall  already up to date
⚠ vps             diverged — manual resolve needed
— oauth-proxy     no remote tracking branch
✗ hydro-qgis      directory not found
```

### 规则
- 永远不 force pull / auto-rebase
- 跳过 `local` 不存在（报 ✗）
- 跳过 `"ignored": true`

---

## ship — commit + push（多 repo）

### 行为

1. **Determine scope** from `$ARGUMENTS`:
   - 无参数 → CWD（必须 git repo）
   - `.` → CWD
   - `all` → 读 `repo-map.json`，ship 所有有 uncommitted changes 的 repo
   - `<name> [name2 ...]` → 在 repo-map.json 查 local path

2. **For each project with changes**:
   - `git status --short` 看变更
   - `git diff --stat` 摘要
   - `git add -A`
   - 从 diff 生成简洁 commit message（1-2 句，conventional commits）
   - commit + push 一步
   - 报告：✓ project → commit hash 或 ✗ project → error

3. **Output summary table**:
   ```
   ✓ dockit        a7ff7b1  docs: fix Python version badge
   ✓ cc-configs    e96c3c4  docs: unify README format
   ✗ hydro-annual  (nothing to commit)
   ```

### 规则
- 总是追加 `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`
- 永不 commit `.env` / `credentials*` / `*secret*` / `*.pem` / `*.key`
- `all` 模式发现 5+ 项目有 changes → 先列出，确认后再继续
- `git push` 不 force
- push 失败（behind remote）→ 报错，不 force / auto-rebase

---

## promote — GitHub 元数据推广

审计 README，更新 metadata（description/topics/homepage），确保截图存在。

### 范围
- 无参数 → CWD
- `<name> [name2 ...]` → 指定项目（按目录名）
- `all` → ~/Dev 所有 git repo
- `--check` → dry run

### Per-project 流程

#### 1. README audit
`python3 ~/Dev/tools/dev/repo_manager.py audit <name>`

发现问题列出，**不自动改 README**（README 改动单独走）。

#### 2. GitHub metadata

```bash
gh repo view zengtianli/<name> --json description,repositoryTopics,homepageUrl
```

**Description** — 空则从 README 第一段语言选择器后的一行描述提取：
```bash
gh repo edit zengtianli/<name> --description "<extracted>"
```

**Topics** — 空或 < 3 → 推荐 + 添加：

| Pattern | Topics |
|---|---|
| `hydro-apps` | tauri, desktop-app, hydrology, water-resources, rust, typescript, monorepo |
| `hydro-*` | hydrology, water-resources, python, streamlit |
| `cc-*` | claude-code, cli, developer-tools, python |
| `dockit*` | document-processing, python, streamlit |
| `edict` | ai-agents, multi-agent, python, openclaw |
| `cclog` | claude-code, cli, developer-tools, python, session-management |
| `downloads-*` | file-management, automation, python, cli |
| `vps-*` | vps, nginx, cloudflare, proxy |

扫 README 关键词建议附加 topics。**总是确认后再加**。

```bash
gh repo edit zengtianli/<name> --add-topic topic1 --add-topic topic2
```

**Homepage** — 空且有 live demo：
- Streamlit: `https://<name>.tianlizeng.cloud`
- 先验证 URL 可达再设
```bash
gh repo edit zengtianli/<name> --homepage "https://<name>.tianlizeng.cloud"
```

#### 3. Screenshot
检查 `~/Dev/<name>/docs/screenshots/demo.png`。缺则 `repo_manager.py screenshot`：
- Streamlit + URL → `screenshot streamlit <name> <url>`
- CLI tool → `screenshot cli <name> "<command>"`
- Tauri desktop（hydro-apps）→ `screenshot tauri hydro-apps`（osascript 取窗口 + screencapture -R）
- 不支持的项目 → 标注待手工

#### 4. Summary

```
✅ dockit          — all good
🔧 cc-configs     — added 5 topics, set homepage
⚠️  oauth-proxy    — skipped (internal)
```

### 规则
- 永不覆盖 README 内容（只 audit）
- 添加 topics 前总是确认
- 永不 force-push / 重写 history
- 无项目排除（用户用 GH public/private 控制）
- `gh` CLI 跑全部 GitHub API 操作
- 改完用 `/repo ship` commit + push

---

## audit — 完整性审计

基于 `repo-standards.json` 检查文件和 GitHub metadata。

### 范围（同 pull）
- 无参数 → CWD
- `<name> [name2 ...]`
- `all`
- `--category <cat>` — hydro/tools/infra/knowledge/personal/work

### 并行策略
多目标 → 每目标独立 subagent（Agent tool）并行审计；单目标直接执行。

### 检查项

#### 文件存在性
- LICENSE（MIT，copyright = tianli）
- .gitignore（含 `repo-standards.json → common.gitignore_baseline` 全部）
- README.md
- README_CN.md（如 `category.bilingual = true`）
- CLAUDE.md

#### README 质量（按 `readme_template`）
- **app**: language selector / badges / separator / screenshot / feature table / install / quick start
- **infra**: title / badges / what-it-does / setup / usage
- **content**: title / badges / contents overview
- **minimal**: title / overview

#### GitHub metadata
```bash
gh repo view zengtianli/<name> --json description,repositoryTopics,homepageUrl
```
- description 非空
- topics >= 3
- homepage 已设（如有 VPS 部署或 Streamlit）

### 参考
- `~/Dev/tools/configs/repo-standards.json`
- `python3 ~/Dev/tools/dev/repo_manager.py audit`

### 输出

```
✅ dockit           — all clear
🔧 hydro-rainfall  — missing LICENSE, missing README_CN.md
🔧 learn           — missing CLAUDE.md, missing LICENSE, 0 topics
⚠️  essays          — missing LICENSE, no description
```

汇总：`N repos checked, X all clear, Y need fixes`

---

## groom — Repo 维护全流程

编排：`/repo pull` → `/repo audit` → fix(`/repo promote`) → review → `/repo ship`

### 范围
- 无参数 → 全部 non-ignored repos（`repo-map.json`）
- `<name> [name2 ...]`
- `--check` → 只 Phase 1-2，不修
- `--skip-pull` → 跳 Phase 1
- `--category <cat>`

### 数据源
- `repo-map.json` — 注册表
- `repo-standards.json` — 完整性标准
- 金标准 README：`~/Dev/stations/dockit/README.md` / `README_CN.md`

跳过 local 不存在（warn）或 `"ignored": true`。

### Phase 1: Pull
调 `/repo pull <targets>`

### Phase 2: Audit
调 `/repo audit <targets>`。`--check` 到此停。

### Phase 3: Fix

按 fix type 分组，**生成 fixes 但暂不应用**。

#### Auto-fixable（批量确认）

1. **LICENSE** — MIT，copyright=tianli，year=current
2. **.gitignore gaps** — 追加 baseline 缺失项，不删现有
3. **GitHub metadata** — 调 `/repo promote <name>`：description / topics / homepage

#### User-review fixes（逐个确认）

4. **CLAUDE.md generation**
   先用 auggie 拿"项目脑图"：`mcp__auggie__codebase-retrieval(workspace=<repo>, request="项目核心模块、入口、关键数据流、对外接口")`，再读关键文件细化。
   生成：标题 + 一行描述 / Quick Reference 表（关键文件、URL、deploy 路径）/ 常用命令（dev/test/build/deploy）/ 项目结构（tree -L 2）。中文（匹配现有约定）。

5. **README.md generation/repair**
   - 缺：从 category `readme_template` 生成
   - 在但不合：仅修结构问题
   - 先英文

6. **README_CN.md translation**
   `bilingual = true` 且缺失/过时：翻译 README.md，结构镜像，保留代码块/URL/技术术语。

### Phase 4: Review

#### Batch-approvable
```
LICENSE additions (N repos) → Approve all? [Y/n]
.gitignore fixes (N repos) → Approve all? [Y/n]
GitHub metadata (N repos) → table → Approve all? [Y/n]
```

#### Individual review
```
CLAUDE.md (N repos) → each: Approve? [Y/n/edit]
README updates (N repos) → each
README_CN.md translations (N repos) → each
```

### Phase 5: Ship
调 `/repo ship <targets>`（仅推有 approved changes）。Commit messages: conventional（chore/docs/fix）

最终 summary：

```
✓ hydro-rainfall  a7f3b1c  chore: add LICENSE, fix .gitignore
✓ learn           e96c3c4  docs: add CLAUDE.md, generate README
✗ vps             (push failed — behind remote)
— dockit          (no changes needed)
```

### 规则
- repo-map.json 是 repo 列表唯一 SoT
- repo-standards.json 是完整性标准唯一 SoT
- 永不 force-push / 重写 history
- 永不 commit .env / credentials / secrets / *.pem / *.key
- pull diverged → audit 但不 fix
- CLAUDE.md 中文 / README.md 英文 / README_CN.md 中文
- /tidy 和 README 改动总是 individual review
- LICENSE 和 .gitignore 可 batch-approve

---

## launch — 新项目一条龙

`/repo launch <name> [--kind static|app] [--no-github] [--no-deploy] [--vps-path PATH]`

把已有积木串成一条：本地骨架 → GitHub repo → webhook 注册 → 子域名绑定 → 部署验证。

### 参数
- `<name>` — 项目/子域/目录
- `--kind static`（默认）→ 用 `/site ship`
- `--kind app` → 用 `/deploy`（需本地 deploy.sh）
- `--no-github` — 跳过 GH repo 创建/推广
- `--no-deploy` — 仅初始化骨架
- `--vps-path PATH` — 默认 `/var/www/<name>`

### 编排顺序

每步失败立即停止；已完成的步骤幂等。

#### Phase 1: 本地骨架（如 ~/Dev/<name>/ 不存在）
调 `/site add <name>`

#### Phase 2: Repo 质量 + GitHub（除非 --no-github）
```
/repo groom <name>   # pull → audit → promote → ship
```
内部已含 promote 推广和 ship commit+push。

#### Phase 3: Webhook 注册（除非 --no-github）
```
/repo map add <name> --vps <vps-path>
```
把 `<name> → <vps-path>` 加到 webhook receiver REPO_PATHS。

#### Phase 4: 部署（除非 --no-deploy）
```
if --kind static:   /site ship <name>
elif --kind app:    cd ~/Dev/<name> && /deploy
```

#### Phase 5: stack 登记
> 已上线：https://<name>.tianlizeng.cloud
> 建议把条目加到 `~/Dev/stations/website/lib/services.ts`

### 规则
- **不重新发明**：所有真实动作委托给已有命令
- **幂等**：每阶段先检查是否已完成，跳过
- **可中断恢复**：失败后人工修，再跑会从下一未完成步骤继续

### 典型流程

```bash
/repo launch mynewsite
# ↓ 自动串起：
# /site add mynewsite       — 建目录 + yaml/py/sh
# 用户编辑 projects.yaml
# /repo launch mynewsite    — 再跑一次，从 Phase 2 继续
# /repo groom mynewsite     — repo 质量
# /repo map add mynewsite
# /site ship mynewsite      — DNS + Access + 部署
```

### 参考
- 2026-04-17 stack 上线流程暴露的缺口 → 本命令把当时的 15 手工步编排成 1 条
- 底层积木：`/site add` `/site ship` `/repo groom` `/repo promote` `/repo ship` `/repo map` `/cf` `/deploy`
