---
description: 子域生命周期族 — add 新建（含 --monorepo 站群 scaffolder）/ promote 挪进 stations 站群 / rename 改名 / archive 下线 / activate 复活 / ship 部署上线 / nginx-regen 重生 vhost。触发：加新站 / 新建工具站 / new station / 起一个 X 子域 / 加个 X-web / promote X / 把 X 加到 stations / 挪 X 进站群
---

# /site — 子域 / 站点统一入口

`/site <subcommand> [args]`

| 子命令 | 干啥 |
|---|---|
| `add` | 脚手架新建 ~/Dev/<name> 静态站项目（projects.yaml + generate.py + deploy.sh）|
| `add --monorepo` | **站群 scaffolder**（合自 ex-`/new-station` skill · 2026-05-19）— 一命令加新 station 进 web-stack monorepo，把 6 文件 8 步压成 1 命令 |
| `promote` | **挪 ~/Dev/<name> → ~/Dev/stations/<name>**（合自 ex-`/station-promote` cmd · 2026-05-19），扫硬编码路径 + 可选 --auto-fix sed |
| `rename` | 原子改名子域 — CF DNS/Origin/Access + nginx + services.ts + 14 天 301 |
| `archive` | 下线闲置子域 — 停服务/删 nginx/CF DNS+Origin+Access/移 /var/www 归档 |
| `activate` | 给闲置站点赋新用途 — 更新 projects.yaml status/notes 并记入 memory |
| `ship` | 一键部署新静态站到 <name>.tianli.cyou（rsync + Nginx + /cf + 验证） |
| `nginx-regen` | 从 services.ts 重新生成所有动态子域 nginx vhost（不推送 VPS） |

> v0.2 (2026-05-19)：合入 `add --monorepo`（ex-`new-station` skill）+ `promote`（ex-`station-promote` cmd）两个站群专属子命令

---

## add — 脚手架新建静态站项目

`/site add <name> [--template stack|changelog|docs|md-docs] [--source <repo-name>]`
`/site add <name> --monorepo --port <8510-8599> --group <id> --mode <subdomain|apex_subpath> --label "<中文>" --label-en "<EN>" --description "<一句话>" [--access cf-access|none] [--backend none|fastapi] [--dry-run]`

生成可直接 `bash deploy.sh` + `/site ship <name>` 的项目骨架，或（`--monorepo`）一命令把新 station 加进 web-stack 站群 monorepo。

### 模式判别

| 触发 | 模式 | 落地路径 |
|---|---|---|
| 无 `--monorepo` | 独立静态站 | `~/Dev/<name>/` (后续可用 `/site promote` 挪进站群) |
| `--monorepo` | **站群 scaffolder** | `stations/web-stack/apps/<name>-web/` (+ services/<name>/ 可选) |

### 流程（默认 · 独立静态站）

#### 1. 参数解析
- `<name>` 必填，项目目录名（也是默认子域名）
- `--template` 可选：默认 `stack`
  - `stack` — yaml → HTML 卡片站（参考 ~/Dev/stations/stack）
  - `changelog` — yaml → 时间线（参考 cc-evolution）
  - `docs` — 文档站
  - `md-docs` — 跨仓读 markdown + frontmatter → HTML（参考已归档 stations/assets template）
- `--source <repo>` 仅 `md-docs` 需要：指定源 Markdown 仓，generate.py 读 `~/Dev/<source>/docs/*.md`，仅渲染带 frontmatter `public: true` 的文章

#### 2. 目录检查
确认 `~/Dev/<name>/` 不存在（已存在则报错退出）

#### 3. 创建骨架

```
~/Dev/<name>/
├── CLAUDE.md
├── README.md
├── deploy.sh           # 从 ~/Dev/_archive/2026-04-19-cc-evolution/deploy.sh 拷贝，替换域名
├── generate.py         # 从 stack/generate.py 拷贝或简化版
├── projects.yaml       # 占位（或对应模板）
└── site/
    └── index.html      # 首次 generate 产物
```

模板来源：`~/Dev/_archive/2026-04-19-cc-evolution/`（静态 HTML 生成器范式）/ `~/Dev/stations/stack/`（项目说明书范式）/ `~/Dev/tools/dev/lib/templates/nginx-static.conf`

#### 4. 初始化内容
- 拷贝对应 template 的 generate.py 和 deploy.sh
- 在 deploy.sh 里把域名替换成 `<name>.tianli.cyou`
- 生成最小可用 projects.yaml
- 写 CLAUDE.md（参考 ~/Dev/stations/stack/CLAUDE.md 格式）

#### 5. 第一次生成
运行 `python3 generate.py` 验证能出 site/index.html

#### 6. 提示下一步
> 下一步：编辑 `~/Dev/<name>/projects.yaml`，然后 `/site ship <name>` 一键上线。

### 规则
- 所有模板路径动态查找
- 失败时清理已创建的 `~/Dev/<name>/`
- 不触碰 git init

### md-docs 模板（跨仓 Markdown → HTML）

**场景**：把某 private repo 部分 markdown 发布成公开静态站。

**源仓约定**：`~/Dev/<source>/docs/*.md`，仅 frontmatter `public: true` 渲染（防 PII）；可选字段：`title` / `group` / `abstract` / `order`

**脚手架产物**（在 stack template 基础上替换 generate.py）：
```
~/Dev/<name>/
├── CLAUDE.md            # 说明源仓 + 分组 key + 加新文章流程
├── deploy.sh            # rsync 到 VPS:/var/www/<name>
├── generate.py          # 从历史 stations/assets/generate.py 模板拷贝改 DOCS_DIR / GROUPS / SITE_HEADER
├── site-navbar.html     # 从 ~/Dev/tools/dev/lib/templates/site-navbar.html 拷贝
├── site-header.html     # 本站专属
├── site-content.css     # 从 ~/Dev/tools/dev/lib/templates/ 拷贝
└── site/                # generate.py 产物（index + per-article 独立页）
```

参考：md-docs 模板范式 (2026-04-19 stations/assets 首次落地，已归档)

首次 generate 前：源仓 .md 加 frontmatter（最少 public/title/group/abstract/order）。

依赖：`uv pip install --system --break-system-packages markdown pyyaml`

### 参考
- 下一步：`/site ship <name>` — 一键部署
- 再下一步：`/repo launch` — 新项目一条龙
- Playbook：`~/Dev/tools/configs/playbooks/web-scaffold.md`

---

## add --monorepo — 站群 scaffolder（合自 ex-`/new-station` skill · 2026-05-19）

**触发词**：`加新站` / `加一个新站` / `起一个 X-web` / `new station` / `scaffold a station` / `起个 X 子域` / `上一个 X 工具` / `加一个工具站到站群`

把"加新 station 改 6 文件 / 8 步"折叠成一条 `new_station.py` 调用。配合现有 menus.py SSOT 链路，自动跑 4 个 regenerator + audit gate，不通过自动回滚。

### 不触发（→ 走 `web-scaffold` playbook 或 `/site add`）

- 静态站（非 Next.js / 非 web-stack 内）→ `/site add <name>`
- 外部 apps/ workspace 不进站群 monorepo

### 工具

```bash
python3 ~/Dev/tools/dev/lib/tools/new_station.py \
  --id <kebab-case>            # e.g. eco-flow, wpl-tracker
  --port <8510-8599>           # backend port; devPort 自动 = port - 5410, apiPort = port + 100
  --group <group_id>           # main | hydro-tools | applications | infra (见 entities/groups.yaml)
  --mode <subdomain|apex_subpath>  # 独立 X.tianli.cyou / 还是 tianli.cyou/X 子路径
  --label "<中文名>"
  --label-en "<English name>"
  --description "<一句话描述>"
  [--access cf-access|none]    # 默认 none (公开)
  [--backend none|fastapi]     # 默认 none (纯前端)
  [--service-dir <override>]   # 默认 = --id
  [--dry-run]                  # 不写文件，只打印
```

### 流程

1. **验参**：id kebab-case 不冲突 / port 8510-8599 唯一 / group ∈ groups.yaml / mode 合法
2. **写 SSOT**：append `entities/subdomains.yaml` + `relations/subdomain-group.yaml` + `navbar.yaml` 菜单项
3. **渲染前端**：`tools/configs/templates/station-app/` → `stations/web-stack/apps/<id>-web/`
4. **(可选) 渲染后端**：`--backend fastapi` → `stations/web-stack/services/<id>/`
5. **跑 4 regenerator**：
   - `menus.py build-services-ts -w`
   - `menus.py build-website-navbar -w`
   - `menus.py build-react-mega-navbar -w`
   - `menus.py audit` ← exit 0 才算成功
6. **任何步失败 → 自动回滚**（yaml 还原 + 新文件/目录删）

### 用法示例

**1. 纯前端工具站（独立子域 + CF Access）**

```bash
/site add wpl-tracker --monorepo --port 8525 --group applications --mode subdomain \
  --label "WPL 跟踪器" --label-en "WPL Tracker" \
  --description "WPL 余额/利息日跟踪面板" \
  --access cf-access --backend none
```

**2. apex_subpath 子路径站（公开）**

```bash
/site add cost-calc --monorepo --port 8526 --group applications --mode apex_subpath \
  --label "成本计算器" --label-en "Cost Calculator" \
  --description "项目成本快算工具"
```

URL = `https://tianli.cyou/cost-calc`

**3. 带 FastAPI 后端**

```bash
/site add eco-flow --monorepo --port 8527 --group hydro-tools --mode apex_subpath \
  --label "生态流量评估" --label-en "Eco-Flow Assessment" \
  --description "河流生态流量评估与保障率计算" \
  --backend fastapi
```

会同时生成 `services/eco-flow/api.py` + `services/eco-flow/pyproject.toml`。

### 验收（done 标准）

- [ ] `menus.py audit` 退出 0（含 17 类 strict + paths-drift）
- [ ] `cd stations/web-stack/apps/<id>-web && pnpm install && pnpm dev` 起得来
- [ ] 浏览器 http://localhost:<devPort> 看到骨架页（含 `{{label}}` 标题）

如 audit 失败：scaffolder 已自动回滚 yaml。手工检查 `git status -- stations/web-stack/apps/<id>-web/` 残留可删。

### 兜底（scaffolder 异常时）

如 scaffolder 本身 bug，回退到手工 8 步 SOP：见 `~/Dev/tools/configs/playbooks/station-add-via-scaffold.md` § 兜底。

---

## promote — 把 ~/Dev/<name> 挪进 stations 站群（合自 ex-`/station-promote` cmd · 2026-05-19）

**触发词**：`挪 X 进站群` / `promote X` / `把 X 加到 stations` / `把 X promote 进 stations` / `归位 X 到生产站群`

将 `~/Dev/<name>` promote 到 `~/Dev/stations/<name>`（生产站群目录），自动扫硬编码路径引用，可选 sed 批量替换。

### 用法

```bash
/site promote <name>                  # 只挪 + 扫引用
/site promote <name> --auto-fix       # 挪 + 批量 sed 替换硬编码
/site promote <name> --dry            # 不动，只打印计划
/site promote <name> --no-smoke       # 跳过 api-smoke 烟测（静态站适用）
```

### 何时用

- 某个 `~/Dev/<xxx>/` 的项目已稳定上线，要归位到站群目录
- 与 `add --monorepo` 的关系：`add --monorepo` 是**直接**起在 monorepo；`promote` 是**事后**把独立 repo 挪进去

### 执行

```bash
bash ~/Dev/tools/dev/scripts/station-promote.sh "$@"
```

### 流程（脚本内部做的事）

1. 前置检查：`~/Dev/<name>` 存在 / `~/Dev/stations/<name>` 不存在 / git clean
2. `mv ~/Dev/<name> ~/Dev/stations/<name>`
3. 扫 `cc-configs/` `devtools/` `configs/` `memory/` 里的 `~/Dev/<name>` 硬编码引用
4. 若 `--auto-fix`：sed 批量替换 3 种写法（`~/Dev/` / `$HOME/Dev/` / `/Users/tianli/Dev/`）
5. 重建 raycast symlinks 指向新位置
6. `/api-smoke <name>` 烟测（若是 API 类站）
7. 打印摘要 + 提示接下来哪些 repo 要 commit

### 依赖

- `~/Dev/tools/dev/lib/station_path.sh` / `.py` — 路径发现函数（脚本/工具均用它）
- 核心脚本 `api-smoke.sh` / `menus.py` / `deploy-changed.sh` / `web-stack deploy.sh` 已接入 station_path，`mv` 后**零代码改动**就能正常工作
- `--auto-fix` 只针对文档级引用（cc-configs/commands/*.md 描述路径）

### 不做

- 不改 nginx / systemd / VPS 侧（VPS 路径与本地路径无耦合）
- 不改 GitHub remote
- 不 archive 源 repo
- 不回滚（要回滚：`mv ~/Dev/stations/<name> ~/Dev/<name>`，sed 改过的文件 `git checkout --`）

---

## rename — 原子改名子域

`/site rename <old> <new> [--301-days N] [--yes] [--dry-run]`

一致改名一个子域，所有注册表 + CF + nginx 同步更新，老域名 N 天 301 到新域名，到期后用 `/site archive <old>` 收尾。

### 参数
- `<old>` / `<new>` — 子域名（不带 `.tianli.cyou`）
- `--301-days` — 老域 301 保留天数（默认 14）
- `--yes` — 跳过交互确认
- `--dry-run` — 打印计划但不执行

### 执行

```bash
source ~/.personal_env
python3 ~/Dev/tools/dev/lib/tools/site_rename.py "$@"
```

### 动作顺序

1. **Pre-flight**（任一失败 → 0 副作用）
   - `<old>` 在 services.ts 中存在
   - `<new>` 不在 services.ts / CF DNS
   - `services.ts` + `projects.yaml` git 工作区 clean
2. **CF DNS**：`dns add <new>` → VPS_IP，proxied；老记录保留
3. **CF Origin Rule**（如老域有 `port`）：在现有 Rule expression 加 `<new>`
4. **CF Access**（如老域是 `cf-access`）：新建 app，沿用现有邮箱
5. **VPS nginx**：
   - `cp sites-available/<old> → <new>`，`sed` 改 `server_name` 和 `root`
   - 静态站：`ln -sfn /var/www/<old> /var/www/<new>`（共享目录，不拷贝）
   - 老 vhost 备份 `.prerename.bak` 后改写为 `return 301 https://<new>$request_uri`
   - `nginx -t && systemctl reload`
6. **services.ts**：精确 sed — 只改那条 entry 的 subdomain 字段
7. **projects.yaml**：全局 `<old-host>` → `<new-host>` 替换
8. **scheduled-archives.json**：登记 `<old>` 的预期归档日

### 验证

```bash
/health sites --filter <new>          # 新域应 200 / 302
curl -sI https://<old>.tianli.cyou # 应 301 → new
```

### 回滚（每步可单步回）
- `cf_api.py dns delete <new>` / `access delete <new>`
- `cf_api.py origin-rules remove <new>`
- VPS：从 `.prerename.bak` 恢复老 vhost；`rm /etc/nginx/sites-enabled/<new>`；reload
- `git checkout --` services.ts / projects.yaml

### 规则
- 不覆盖老 CF Access app（301 期间老域名也需走 Access）
- `/var/www/<new>` 用软链而非 mv（流量 0 中断）
- 到期 teardown 靠 `/site archive <old>`，不自动

---

## archive — 下线闲置子域

`/site archive <name> [--keep-data] [--yes] [--dry-run]`

对一个闲置子域做"整体下线"。services.ts 条目移除，`/var/www/<name>` 日期后缀移到 `_archived/`，可通过 git + `_archived/` 快速恢复。

### 参数
- `<name>` — 子域名
- `--keep-data` — 不动 `/var/www/<name>`
- `--yes` / `--dry-run`

### 执行

```bash
source ~/.personal_env
python3 ~/Dev/tools/dev/lib/tools/site_archive.py "$@"
```

### 动作顺序

1. **Pre-flight** — 扫 services.ts / nginx / systemd / `/var/www`，打印动作清单
2. **systemd** — `stop && disable` 对应 unit
3. **nginx** — `rm sites-enabled/{host}`，`nginx -t && reload`
4. **CF Access** — 删 Access app（若声明 cf-access）
5. **CF DNS** — 删 A 记录
6. **CF Origin Rule** — 从 expression 剔除 hostname
7. **services.ts** — 删 entry
8. **projects.yaml** — `status: archived`
9. **`/var/www/<name>`** — `mv` 到 `/var/www/_archived/<name>-YYYYMMDD/`

### 恢复
- `services.ts` / `projects.yaml`：`git checkout` 回旧版
- `/var/www`：从 `_archived/<name>-DATE/` 移回来
- CF DNS / Origin / Access：用 `/cf` 重建

### 规则
- 交互确认默认 ON；只有 `--yes` 或 `--dry-run` 跳过
- 失败某步后续继续（各步幂等可重跑）
- 不依赖 7d 流量数据（由 `/health sites` 判断）

---

## activate — 给闲置站点赋新用途

`/site activate <name> --purpose "新的用途描述"`

只动 projects.yaml 和 memory；激活后实际部署交给 `/site ship`。

### 执行

```bash
name="$1"; shift
purpose=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --purpose) purpose="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done
[[ -z "$purpose" ]] && { echo "Usage: /site activate <name> --purpose \"...\"" >&2; exit 1; }

yaml="$HOME/Dev/stations/stack/projects.yaml"
today=$(date +%F)

# 更新 projects.yaml（用 Python，缩进对齐 8 空格）
if grep -q "- name: $name" "$yaml"; then
  python3 - <<PY
import re
from pathlib import Path
p = Path("$yaml")
text = p.read_text()
pattern = re.compile(r'(- name:\s*$name\s*\n(?:\s+[^\n]*\n)*?)', re.MULTILINE)
def repl(m):
    block = m.group(1)
    block = re.sub(r'^\s+status:.*\n', '', block, flags=re.MULTILINE)
    block = re.sub(r'^\s+notes:.*\n', '', block, flags=re.MULTILINE)
    indent = '        '
    return block + f"{indent}status: active\n{indent}notes: Reactivated $today — $purpose\n"
new = pattern.sub(repl, text, count=1)
p.write_text(new)
print("✓ projects.yaml updated")
PY
else
  echo "⚠ projects.yaml: $name not found — run /site add first"
fi

# 追加 memory 日志
memfile="$HOME/.claude/projects/-Users-tianli-Dev/memory/site_activations.md"
if [[ ! -f "$memfile" ]]; then
  cat > "$memfile" <<EOF
---
name: Site Activations Log
description: 子域重新激活记录，每行一个 activation
type: project
---

EOF
  idx="$HOME/.claude/projects/-Users-tianli-Dev/memory/MEMORY.md"
  grep -q "site_activations.md" "$idx" || \
    echo "- [Site Activations Log](site_activations.md) — 子域激活时间线" >> "$idx"
fi
echo "$today  $name  $purpose" >> "$memfile"
echo "✓ memory logged: $today $name"
echo
echo "Next: nginx/CF Access 需改 → /site ship $name"
```

### 规则
- 只动 projects.yaml + memory，不碰 CF / nginx / services.ts
- memory 文件 `site_activations.md` 首次触发自动创建 + 登记到索引

---

## ship — 一键部署新静态站（**首次上线专用**）

`/site ship <name> [--source DIR] [--no-access]`

编排 rsync + Nginx + `/cf dns/origin/access` + 验证。

**何时用 `/site ship` vs `/deploy`**：

| 场景 | 用 |
|---|---|
| 首次上线一个新子域（CF DNS/Access/nginx vhost 都还不存在） | `/site ship <name>` |
| 已上线站点改完代码再发一次 | `/deploy` 或 `/deploy <name>`（跑现成 deploy.sh） |
| 改了几个 repo 不确定影响哪几站 | `/deploy changed` |
| 跨多站同步同一变更 | `/deploy fanout` |

`ship` 含 CF/nginx/Access 这些**首次性创建动作**，已存在自动跳过（幂等），但**不要拿来当日常 deploy** —— 一是慢（多次幂等检查），二是语义混淆。

### 参数
- `<name>` — 子域名（也是 `/var/www/<name>` 目录名）
- `--source DIR` — 本地源目录（默认：当前目录下的 `site/`）
- `--no-access` — 公开站点，不加 CF Access 保护

### 执行步骤（按顺序，任一失败立即停止）

#### 0. Pre-flight（并行扫，任一阻断 → 暂停等确认）
- `$SOURCE/index.html` 存在？
- CF DNS / Access 是否已有同名记录？
- VPS `/var/www/<name>` 是否存在（rsync 会覆盖）？
- VPS nginx `sites-enabled/<hostname>` 是否存在？
- VPS 连通性：`ssh root@104.218.100.67 "echo ok"`

#### 1. 本地预检
- `HOSTNAME=<name>.tianli.cyou`
- `REMOTE=/var/www/<name>`

#### 2. 幂等检查（先查再建）
```bash
python3 ~/Dev/tools/dev/lib/tools/cf_api.py dns list --filter $HOSTNAME
python3 ~/Dev/tools/dev/lib/tools/cf_api.py access list | grep $HOSTNAME
ssh root@104.218.100.67 "ls /etc/nginx/sites-enabled/$HOSTNAME 2>/dev/null"
```
已存在跳过，不重建。

#### 3. rsync 内容
```bash
ssh root@104.218.100.67 "mkdir -p $REMOTE"
rsync -avz --delete $SOURCE/ root@104.218.100.67:$REMOTE/
```

#### 4. Nginx 配置
模板 `~/Dev/tools/dev/lib/templates/nginx-static.conf`，替换 `{{HOSTNAME}}` `{{NAME}}`，写到 `/etc/nginx/sites-available/<hostname>`，软链 `sites-enabled/`，`nginx -t && systemctl reload nginx`

#### 5. CF DNS + Origin Rule
```bash
/cf dns add <name>
/cf origin add <hostname> 8443
```

#### 6. CF Access（默认开启）
```bash
/cf access add <hostname>
```
邮箱从现有 policy 沿用。`--no-access` 跳过。

#### 7. 验证
等 5 秒后 `curl -sI https://$HOSTNAME`：
- **302** → cloudflareaccess.com = Access 守门 ✓
- **200** = 站点直达（`--no-access` 模式）✓
- 其他 = 报错 + 提示排查路径

#### 8. 登记（提示用户手工加）
> 记得在 `~/Dev/stations/website/lib/services.ts` 加一条（accessType: cf-access 除非 --no-access）

### 规则
- 凭证在 `~/.personal_env`，工具自动读
- 不硬编码 VPS IP / 端口 / 邮箱
- 每步失败立即停止
- 所有"创建类"先 `list` 再 `add`（幂等）

### 参考
- 模板：`~/Dev/tools/dev/lib/templates/nginx-static.conf`
- 实战：2026-04-17 stack.tianli.cyou 首次部署

---

## nginx-regen — 重生 nginx vhost（不推 VPS）

`/site nginx-regen [<name>]`

扫 `~/Dev/stations/website/lib/services.ts` 所有带 `port` 的子域（hydro-* / audiobook / cclog / dockit / cc-options / dashboard），渲染 nginx vhost 到 `~/Dev/tools/configs/nginx/out/<name>.conf`。

**不推 VPS** — 只生成本地文件。审阅 diff 后自行 rsync。

### 执行

```bash
python3 ~/Dev/tools/dev/lib/tools/services_to_nginx.py [name]
```

### 端口约定

| 端口类型 | 公式 | 示例（hydro-capacity port 8511） |
|---|---|---|
| legacy (Streamlit) | services.ts 的 `port` | 8511 |
| api (FastAPI) | legacy + 100 | 8611 |
| web (Next.js) | legacy − 5400 | 3111 |
| 例外 | audiobook api = 9200 | — |

### 后续

```bash
diff -r ~/Dev/tools/configs/nginx/out/ <(ssh root@104.218.100.67 'cat /etc/nginx/sites-enabled/*.conf')
rsync -avz ~/Dev/tools/configs/nginx/out/ root@104.218.100.67:/etc/nginx/sites-enabled/
ssh root@104.218.100.67 'nginx -t && systemctl reload nginx'
```
