---
name: commit-guard
description: commit/push 前自动识别"不该入 git"的派生产物 / 缓存 / 备份 / 大文件 / 系统元数据，默认 auto-unstage。集成在 auto_commit.py 里，--allow-derived 关闭。
---

# commit-guard — commit/push 前自动 guard

## 触发

任何 `python3 ~/Dev/tools/dev/lib/tools/auto_commit.py` 调用（含 `/commit` 和递归批 commit 模板）**自动**跑 guard。无需用户显式调用。

## 拦截的文件类型

### Hard reject（已有 · sensitive scan）

ec=3 立即退出：
- `.env*` · `.personal_env` · `.pem` · `.key` · `.p12` · `credentials.json` · `*.token` · `id_rsa` · `id_ed25519` · `.cer/.crt/.pfx` · `secrets.{json,yaml,toml}`

### Auto-unstage + warn（commit-guard 新增 · 2026-05-18）

默认从 staging 移除，commit 继续走。`--allow-derived` 关闭。

| 类别 | 模式 | label |
|---|---|---|
| Python cache | `__pycache__/` · `*.pyc` · `*.pyo` | `py-cache` |
| Node deps | `node_modules/` | `node-modules` |
| venv | `.venv/` · `venv/` | `venv` |
| build out | `.next/` · `.nuxt/` · `dist/` · `build/` · `target/` · `out/` | `build-out` |
| 派生输出 | `*-output*.{csv,json,xlsx,tsv,txt}` · `*_output*.*` · `output_*.*` | `derived-output` |
| 备份 | `*.bak` · `*.tmp` · `*.swp` · `*.swo` · `*~` | `backup` / `editor-*` |
| 日志 | `log.txt` · `*.log` | `log` |
| 用户约定 (中文) | `*作废*` · `*副本*` · ` - 副本.*` · `备份.` | `obsolete-marker` / `copy-marker` |
| 系统元数据 | `.DS_Store` · `Thumbs.db` · `desktop.ini` | `macos-meta` / `windows-meta` |
| 大文件 | >10MB blob in staging | `large-file-XMB` |

## 用法

```bash
# 标准（默认 guard ON）
python3 ~/Dev/tools/dev/lib/tools/auto_commit.py --no-confirm --push

# 强制保留派生产物（极少用，仅在需要 commit 模板输出时）
python3 ~/Dev/tools/dev/lib/tools/auto_commit.py --no-confirm --push --allow-derived
```

## 来源

用户 2026-05-18 投诉："还有些 就是不必要 commit push 你应该知道，总体的规范 没有吗"。此前批量 commit `labs/hydro-apps` 入了 17 个派生 csv/bak/log/作废文件、7.2M sample input。事后 untrack + .gitignore 才补救。

这条规则把识别从「Claude 凭经验/语义」搬到「机器强制 pattern match」。规则层 → 执行层，参考 [[rules-vs-execution-layer-framing]]。

## 关联

- 实现：`~/Dev/tools/dev/lib/tools/auto_commit.py` 中 `DERIVED_PATTERNS` + `derived_guard()` + `scan_derived()`
- 命令：`/commit` 默认走这条管道
- memory: [[commit-guard-derived-files]] 教训 + 触发场景
- 反模式：commit 前不扫 untracked 类别，先 add -A 再发现派生入仓

## 限制 / 不覆盖的

- **不**改 `.gitignore`（破坏性，留给用户）
- **不**删工作区文件（只动 staging）
- 大文件提示不阻断（>10MB 只 warn，不 unstage）— 因为有时 sample data 合理入仓
- 不识别**业务语义**派生（e.g. `report.docx` 是不是手写还是脚本生成，无法判断）
