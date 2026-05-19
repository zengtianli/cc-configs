---
description: 刷新 auggie dashboard — GitHub repo 列表 / workspace 注册表 / health 健康
---

# /auggie — 刷新 auggie dashboard

`$ARGUMENTS` 子命令：
- `dash`（默认）— 拉 GitHub repo 列表，刷新 ops-console 的 auggie scan 卡片
- `sync` — 重 build workspace 注册表 + retry-failed warmup + scp health.json，刷新 `/auggie/workspaces` 表
- `all` — 串跑 `dash` + `sync`

未传子命令 → 跑 `dash`。

---

## dash — GitHub repo 列表（3 步）

1. **拉 GitHub 最新清单**
   ```bash
   python3 ~/Dev/apps/ai-tools/auggie-dashboard/lib/scanner.py \
       ~/Dev/apps/ai-tools/auggie-dashboard/data/scan.json
   ```
   产出当前所有 repo（公开 + 私有）的 7 字段 JSON。

2. **同步到 ops-console 消费者**
   ```bash
   cp ~/Dev/apps/ai-tools/auggie-dashboard/data/scan.json \
      ~/Dev/stations/ops-console/data/auggie-scan.json
   ```

3. **scp 到 VPS**
   ```bash
   scp ~/Dev/stations/ops-console/data/auggie-scan.json \
       root@104.218.100.67:/opt/ops-console/data/auggie-scan.json
   ```
   不 rebuild Next.js，页面 `revalidate: 60` 60s 内自动拿到新数据。

### 验证 dash
```bash
curl -s --noproxy '*' https://dashboard.tianlizeng.cloud/api/auggie \
  | python3 -c "import json, sys; d=json.load(sys.stdin); print(len(d['repos']))"
```

---

## sync — workspace 注册表 + health 数据（4 步）

刷新 `dashboard.tianlizeng.cloud/auggie/workspaces` 表（41 行 + 健康徽章）。

1. **rebuild auggie-workspaces.json**
   ```bash
   python3 ~/Dev/tools/dev/lib/tools/auggie_workspaces.py build
   python3 ~/Dev/tools/dev/lib/tools/auggie_workspaces.py audit  # 必须 0 退出
   ```

2. **retry-failed warmup**（仅重跑 status != 'ok' 的，保留已 ok）
   ```bash
   python3 ~/Dev/tools/dev/lib/tools/auggie_warmup.py run --retry-failed
   ```
   产出 `~/Dev/tools/configs/auggie-health.json`。预计耗时几分钟（视失败数量）。

3. **scp 到 VPS**
   ```bash
   scp ~/Dev/tools/configs/auggie-workspaces.json \
       ~/Dev/tools/configs/auggie-health.json \
       root@104.218.100.67:/opt/ops-console/data/
   ```

4. **验证 live**
   ```bash
   curl -fsSL "https://dashboard.tianlizeng.cloud/auggie/workspaces" \
     -o /dev/null -w "HTTP %{http_code}\n"
   # 预期 200
   ```

### sync 何时跑
- 改 `auggie-workspaces.yaml`（增删 workspace / 改 indexable）后必须跑
- warmup 失败重试（如 augment 后端节流恢复后）
- 周期性维护（建议每周 1 次）

---

## all — dash + sync 串跑

```bash
# 等价
/auggie dash
/auggie sync
```

完整一次刷新 dashboard 两个 auggie 页面。

---

## 数据 schema 快查

### scan.json（dash 数据）— 7 字段
```json
{
  "name": "dotfiles",
  "visibility": "private",
  "language": "Shell",
  "pushed_at": "2026-04-20T12:31:39Z",
  "description": "dotfiles for macOS",
  "html_url": "https://github.com/zengtianli/dotfiles",
  "archived": false
}
```

### auggie-workspaces.json（sync 数据）
SSOT 源 `~/Dev/tools/configs/auggie-workspaces.yaml`，41 entries · 22 indexable。字段见 yaml 顶部 banner。

### auggie-health.json（sync 数据）
warmup 产出。每个 indexable workspace 1 record：`status / duration_s / avg_relevance / warmup_at / error`。

---

## 页面位置
- `dashboard.tianlizeng.cloud/auggie` — GitHub repo 列表（dash）
- `dashboard.tianlizeng.cloud/auggie/workspaces` — workspace 注册表 + 健康（sync）

---

## ws-add — 注册新 workspace 到 SSOT（替代旧 /auggie-workspace-add）

`/auggie ws-add <id> <abs-path-or-~-path> [extra options]`

### 何时用
- 新 clone 一个 repo 到 ~/Dev 想被 auggie 索引
- 移动 / 重命名了某个已有 workspace 的路径
- 升降级 indexable（数据型 repo 标 `indexable: false`）

### 参数

| 参数 | 必填 | 说明 |
|---|---|---|
| `<id>` | ✅ | 稳定 slug，CC dispatch 用（建议跟 GitHub repo 名一致） |
| `<path>` | ✅ | `~/Dev/...` 或绝对路径 |
| `--github=<owner/repo>` |  | 不传则探测 `git -C <path> remote get-url origin` |
| `--type=code\|docs\|data\|meta` |  | 默认 `code` |
| `--status=active\|archive\|data\|deprecated` |  | 默认 `active` |
| `--indexable=true\|false` |  | 默认 `true`；data/archive 默认 `false` |
| `--notes=<text>` |  | 可选注解 |

### 流程

1. **参数检查**：path 展开后必须存在；`<id>` 在现有 yaml 不能重复（先 grep `~/Dev/tools/configs/auggie-workspaces.yaml`）
2. **自动探测**（未传时）：github / visibility / type
3. **体积闸门**：`du -sh <path>` > 500 MB → 强制提示标 `type=data, indexable=false, github=null`
4. **写 yaml**：在 `auggie-workspaces.yaml` 合适分组（tools/labs/content/Work/migrated）末尾追加，缩进对齐
5. **重生成 + 校验**：
   ```bash
   python3 ~/Dev/tools/dev/lib/tools/auggie_workspaces.py build
   python3 ~/Dev/tools/dev/lib/tools/auggie_workspaces.py audit
   ```
6. **验证 dispatch**：`auggie_workspaces.py resolve <id>` 应输出绝对路径
7. **提示**：是否 `cd ~/Dev/tools/configs && git commit`（pre-commit hook 自动跑 audit gate）

### 反模式 / 守门
- 不允许把整个 `~/Dev` 加进来（已存在 `dev-meta` 条目，indexable=false）
- 不允许把 `_archive/*` 子目录加进来
- `path` 必须是 git repo（`.git/` 存在），否则 auggie 索引意义不大

---

## map — 大型项目二进制文件地图（替代旧 /auggie-map）

`/auggie map <target> [--depth N] [--dry-run]`

为大型项目生成 `_files.md`，让 Auggie 能索引那些不推 GitHub 的二进制文件。

### 参数
- `<target>`（必填）：项目根目录，如 `~/Dev/Work/zdwp`、`~/Dev/Work/reports`
- `--depth N`（默认 3）：扫描深度
- `--dry-run`：只生成不提交

### 流程

1. **验证前置**：目标是 git 仓库；`.gitignore` 含 `!_files.md`（白名单），缺则提示加
2. **运行扫描**：
   ```bash
   python3 ~/Dev/_archive/scripts-archive/scripts/file/scan_binary_manifest.py \
     --target <target> --depth <N> --clean
   ```
3. **生成项目级汇总** `_PROJECT_MAP.md`：目录结构（tree depth 2）+ 文件统计表 + 各目录 `_files.md` 清单
4. **提交并推送**（除非 `--dry-run`）：
   - `git add` 所有 `_files.md` + `_PROJECT_MAP.md`
   - 提交：`chore: update auggie file map`
   - `git push`
5. **报告**：生成多少 `_files.md` / 涵盖多少二进制文件 / 是否已推

### 注意

- 只扫二进制（docx/pdf/xlsx/shp/zip/tif 等），文本本身已被 git 跟踪
- `_files.md` 已在 zdwp `.gitignore` 白名单
- `_PROJECT_MAP.md` 需确认也在白名单
