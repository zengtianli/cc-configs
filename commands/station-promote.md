---
description: 把 ~/Dev/<name> 挪进 ~/Dev/stations/<name>，自动扫硬编码路径引用，可选 --auto-fix sed 批量替换；烟测 + 提示接下来 commit 哪些 repo。
argument-hint: <name> [--auto-fix] [--no-smoke] [--dry]
---

将 `~/Dev/<name>` promote 到 `~/Dev/stations/<name>`（生产站群目录）。

## 用法

```bash
/station-promote website                 # 只挪 + 扫引用
/station-promote website --auto-fix      # 挪 + 批量 sed 替换硬编码
/station-promote website --dry           # 不动，只打印计划
/station-promote website --no-smoke      # 跳过 api-smoke 烟测（静态站适用）
```

## 执行

```bash
bash ~/Dev/tools/dev/scripts/station-promote.sh "$@"
```

## 何时用

- 某个 `~/Dev/<xxx>/` 的项目已稳定上线，要归位到站群目录
- 触发词：「挪 X 进站群 / promote X / 把 X 加到 stations」

## 流程（脚本内部做的事）

1. 前置检查：`~/Dev/<name>` 存在 / `~/Dev/stations/<name>` 不存在 / git clean
2. `mv ~/Dev/<name> ~/Dev/stations/<name>`
3. 扫 `cc-configs/` `devtools/` `configs/` `memory/` 里的 `~/Dev/<name>` 硬编码引用
4. 若 `--auto-fix`：sed 批量替换 3 种写法（`~/Dev/` / `$HOME/Dev/` / `/Users/tianli/Dev/`）
5. 重建 raycast symlinks 指向新位置
6. `/api-smoke <name>` 烟测（若是 API 类站）
7. 打印摘要 + 提示接下来哪些 repo 要 commit

## 依赖

- `~/Dev/tools/dev/lib/station_path.sh` / `.py` — 路径发现函数（脚本/工具均用它）
- 核心脚本 `api-smoke.sh` / `menus.py` / `deploy-changed.sh` / `web-stack deploy.sh` 已接入 station_path，`mv` 后**零代码改动**就能正常工作
- `--auto-fix` 只针对文档级引用（cc-configs/commands/*.md 描述路径）

## 不做

- 不改 nginx / systemd / VPS 侧（VPS 路径与本地路径无耦合）
- 不改 GitHub remote
- 不 archive 源 repo
- 不回滚（要回滚：`mv ~/Dev/stations/<name> ~/Dev/<name>`，sed 改过的文件 `git checkout --`）
