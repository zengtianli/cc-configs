---
description: 健康检查族 — sites 边缘 HTTP / services 全景 12 服务矩阵 / nav navbar 链接 / vps systemd / project 单 repo git+文件卫生 / dotfiles symlink+SSOT 漂移
---

# /health — 健康检查统一入口

`/health <subcommand> [args]`

| 子命令 | 干啥 | 输出 |
|---|---|---|
| `sites` | 扫 services.ts 所有子域 HTTP/Access/Navbar 状态 | 诊断矩阵 |
| `services` | 合并 menus-audit + services_vs_live → 12 服务 × N 维 | markdown 表 / JSON |
| `nav` | navbar.yaml 每链接存活 + 每子域 favicon/og:image/apple-touch-icon | markdown 报告 |
| `vps` | VPS 服务/端口/磁盘/内存/Docker | 文本 |
| `project` | 当前目录 / 多 repo 的 git 状态 + 文件卫生 | 表格 |
| `dotfiles` | _dotfiles symlink 健康 / 孤儿副本 / SSOT 反向覆盖 / ~ 顶层 orphan | 表格行 |

未传子命令 → `project`（最常用）。

> 单组件审计：`/menus-audit`（菜单 17 类）/ `/cf-audit`（CF 对账）

---

## sites — 边缘 HTTP / Access / Navbar

`/health sites [--filter PREFIX1,PREFIX2] [--no-traffic] [--json]`

一键健康探针 — 验证 `~/Dev/stations/website/lib/services.ts` 里所有子域可达性、CF Access 一致性、navbar 部署。

### 参数
- `--filter` — 逗号分隔子域前缀（如 `dashboard,cc,auggie`）
- `--no-traffic` — 跳过 7 天流量聚合
- `--json` — 机器可读（供 `/site rename` 等消费）

### 执行

```bash
python3 ~/Dev/tools/dev/lib/tools/sites_health.py "$@"
```

### 输出解读

| 符号 | 含义 |
|---|---|
| ✅ 200 | 站点公开可达 |
| 🔒 302 | CF Access 守门（正常） |
| ❌ {code} | 4xx/5xx 或 timeout |
| 🌐 | edge 看是公开访问 |
| 🔒 | CF Access 302 → cloudflareaccess.com |
| ⚠ | services.ts 声明 accessType 与实际不符 |
| ✓ | edge curl 抓到 `class="tlz-nav"` |
| ✓(local) | edge 探测不到（Access 阻挡），SSH→origin 抓到 navbar |
| ✗ | 抓了 HTML 但无 navbar — 真缺失 |
| ? | SPA（Streamlit）或无 port 的 Access 站，HTTP 探测不出，需人肉浏览器 |

### 限制
1. **Streamlit 全 SPA**：初始 HTML 不含 navbar（JS mount 后注入），永远给 `?`
2. **7d Hits 暂不可用**：VPS nginx 默认 combined log_format 不含 `$host`；开启需改 `/etc/nginx/nginx.conf` log_format 加 `$host`
3. `auggie` / `panel` / `sub` 等 API 站返回 405/400 属正常（GET `/` 不支持），不代表服务死

### 记录快照（silent fail，不阻塞结论）

每次跑完 `/health <scope>` 后追加一条快照到 `ops_history.db`：

```bash
python3 ~/Dev/personal-kb/bin/ops_history.py record-health \
  --scope "<sites|services|nav|vps|project>" \
  --passed <N> --failed <N> --total <N> \
  --details '<JSON, optional>' 2>/dev/null || true
```

**规则**：
- 适用 `sites` / `services` / `nav` / `vps` / `project` 五个 subscope；写入 `scope` 字段透传
- `--details` 可选 — 塞被检查项数组 / 失败列表 JSON，便于回溯
- 兜底 `|| true` — DB 失败不影响 health 结论
- 消费者：`ops-console /ops-history` 趋势图（未来）

### 规则
- 凭证无需（curl + ssh）
- 并发 8 路 curl + 6 路 SSH，27 站约 15-30 秒
- 支持子集：`/health sites --filter hydro` 只扫 hydro-*

---

## services — 全景 12 服务矩阵

`/health services [--json]`

聚合 `menus.py audit()`（17 类 SSOT 漂移）+ `services_vs_live.py`（live /api/metadata）→ 矩阵，定位单服务问题到单一命令。

### 执行

```bash
python3 ~/Dev/tools/dev/scripts/tools/services_health.py "$@"
```

### 输出列

| 列 | 含义 | 来源 |
|---|---|---|
| service_id | 子域 id | entities/subdomains.yaml |
| public_port | 前端/nginx 端口 | subdomains.yaml |
| api_port | FastAPI 内部端口 (+100 convention) | derived |
| live_version | 实时 /api/metadata 版本 | services_vs_live |
| http | /api/metadata HTTP 状态码 | services_vs_live |
| ms | /api/metadata 响应毫秒 | services_vs_live |
| menus | 该服务相关的 menus.audit 漂移数 | menus.audit() |
| live-drift | port/id/version 漂移项 | services_vs_live |

### 相关
- `/menus-audit` — 单跑 SSOT 17 类漂移（不 probe live）
- `/health sites` — 边缘 HTTP + CF Access + navbar（公网视角）
- `/cf-audit` — DNS + nginx + Origin Rules + Access 声明对账
- services_vs_live.py — 纯 live probe（单跑也行）

### 规则
- 只读，无副作用
- 17 类 + live + http 全绿 → exit 0
- 任一红 → exit 1（可 CI gate）
- Live probe 需 127.0.0.1:$api_port 本地可达（VPS 自动满足；本机 dev 需先起 uvicorn）

---

## nav — navbar 链接 + 每域 assets

`/health nav [--links-only] [--assets-only] [--fail-on-warn]`

每次改了 navbar.yaml / subdomains.yaml 后跑一次；会话收尾前跑一次。只读，无副作用。

### 执行

```bash
python3 ~/Dev/tools/dev/lib/tools/nav_health.py $ARGUMENTS
```

### 检查维度

#### Leaf URLs（navbar.yaml 全部展开）
- `OK`  HTTP 200 + body > 500B + `<title>` 非 "loading"
- `AUTH` HTTP 302 + 标 `access: cf-access`（预期）
- `WARN` 重定向但没标 access / title 是 loading / body 太薄
- `DEAD` 连不上 / 4xx / 5xx

#### Per-host assets（每子域）
- `og:image` — 从根页面 HTML 抓 `<meta property="og:image">`，再 probe 目标
- `favicon.ico` — 直接 probe
- `apple-touch-icon.png` — 直接 probe

### 什么时候跑
- 改 `entities/subdomains.yaml` / `navbar.yaml` / `relations/*.yaml` 后
- `/site archive` / `/site rename` / `/site add` 之后
- 会话收尾前（`/wrap handoff` 之前）
- 定期（cron / launchd）

### 不做
- 不修任何文件
- 不尝试登录 CF Access（302 = auth-gated 健康）
- 不做深度 UI 检查
- 修复由你自己决定

### 常见问题

| 症状 | 可能原因 | 修复 |
|---|---|---|
| GitHub URL 404 | repo private 或不存在 | catalog.yaml 删 URL 或换 private 标记 |
| og:image 缺失（Next.js） | layout.tsx 没设 metadata.openGraph.images | 加 `openGraph: { images: [...] }` |
| favicon.ico 404（Next.js） | `app/icon.png` / `public/favicon.ico` 没放 | 放 512×512 PNG 到 `app/icon.png` |
| `302 missing` on CF-Access | 资产被 Access 拦 | 允许匿名 `/favicon.ico`、`/_next/static/*` |

---

## vps — VPS 服务/端口/磁盘/内存/Docker

`/health vps [<service>]`

```bash
ssh root@104.218.100.67 "echo '=== Services ===' && systemctl list-units --type=service --state=running --no-pager | grep -E 'nginx|oauth|marzban' && echo && echo '=== Ports ===' && ss -tlnp | grep -E '8443|9100|8000|7891|443' && echo && echo '=== Disk ===' && df -h / && echo && echo '=== Memory ===' && free -h && echo && echo '=== Docker ===' && docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null"
```

`$ARGUMENTS` 指定 service 名（如 `oauth-proxy` `nginx`）→ 额外 `journalctl -u <service> --no-pager -n 20`。

---

## project — 当前 repo 文件卫生 + Git 状态

`/health project [<name>...] [all]`

### 范围
- 无参数 → 当前目录
- `<name>` → repo-map.json 查路径
- `all` → 所有 non-ignored repo

### 检查项

#### 1. Git 状态
- uncommitted changes（`git status --short`）
- behind remote（`git fetch --dry-run`）
- untracked 大文件 >10MB
- 敏感文件被 track（`.env` / `*.pem` / `*.key` / `credentials*`）

#### 2. 文件卫生
- 垃圾：`~$*` / `.DS_Store` / `Thumbs.db` / `__pycache__/` / `.~lock.*`
- docx 解包残留：含 `word/` / `_rels/` / `[Content_Types].xml` 的目录
- 版本冗余：`deliverables/` / `docs/` 下同一文档多版本

#### 3. ~/Dev/Work/ 额外
- 在 `~/Dev/Work/zdwp/` 下 → 跑 `python3 ~/Dev/tools/dev/scripts/tools/zdwp_health.py`
- 大目录（>1GB）提醒

### 输出

```
✅ doctools        — clean
⚠️  hydro-rainfall — 3 uncommitted files, 2 __pycache__/
⚠️  zdwp           — 5 version chains, 12 garbage files
✗  oauth-proxy    — .env tracked by git!
```

末尾汇总：`N checked, X clean, Y need attention`

### 清理

输出后有可清理项 → 问用户：`是否调用 /tidy 清理？[Y/n]`

`$ARGUMENTS` 含 `--fix` → 自动调 `/tidy`，不二次确认。

### 调用的原子命令
- `/tidy` — 目录深度整理

---

## dotfiles — _dotfiles SSOT 漂移 + ~ 顶层卫生

`/health dotfiles [--strict] [--json]`

跑 `dotfile_audit.py` 4 维度检查：

1. **symlink 健康** — `_dotfiles/link.sh` 声明的每一对必须是 symlink 且指向 `_dotfiles/` 内（FAIL 阻 commit）
2. **孤儿副本** — `~/.config/<name>(copy|bak|old|stale|backup)` 残留（WARN）
3. **SSOT 反向覆盖** — `_dotfiles/` 顶层 entry 没被 `link.sh` 引用（WARN）
4. **~ 顶层 orphan dotfile** — `~/.X` 目录/文件 ≥60 天未动且 PATH 无对应 binary 且不在白名单（WARN）

### 执行

```bash
python3 ~/Dev/tools/dev/lib/tools/dotfile_audit.py check $ARGUMENTS
```

`--json` → 机读，被 health 矩阵聚合时使用：解析 `summary.{fail,warn,pass}` 输出统一 ✓/⚠/✗ 行。

### 输出统一行（聚合时）

```
✓ dotfiles  — 0 FAIL / 0 WARN / 19 PASS
⚠ dotfiles  — 0 FAIL / 7 WARN / 19 PASS  (剩余 7 项 ~ 顶层 orphan, 跑 dotfile_audit check 看清单)
✗ dotfiles  — 2 FAIL / 5 WARN / 17 PASS  (symlink 坏: 跑 dotfile_audit check 看明细)
```

### 退出码

- 0 — 全绿（FAIL=0；非 strict 时 WARN 不算红）
- 1 — 有 FAIL；或 `--strict` + 有 WARN

### 什么时候跑

- 改 `_dotfiles/link.sh` 后 → 已被 pre-commit 自动 gate（`pre-commit-multi.sh` chain 第 3 环），手跑用于预检
- 周期性会话收尾 → `~ 顶层 orphan` 提醒归档（`/wrap` 前自检）
- 装/卸 CLI 工具后 → 看是否产生新孤儿 dotdir

### 相关
- pre-commit hook: `~/Dev/tools/dev/scripts/hooks/pre-commit-dotfiles.sh`
- 白名单 SSOT: `~/Dev/tools/dev/lib/tools/dotfile_audit.py` `HOME_DOTFILE_ALLOW`
