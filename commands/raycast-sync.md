---
description: 同步各 repo 的 Raycast 命令到 hub（symlink） + 重生成 COMMANDS.md。新增/改了 raycast/commands/ 必跑。
---

`~/Dev/tools/raycast/commands/` 是 Raycast **唯一**扫描的目录。各 repo 的 `raycast/commands/*.{sh,py}` 通过 absolute-path symlink 汇集到此处。任何加/删源命令的动作都必须跑 `/raycast-sync`，不然 Raycast 找不到。

## 用法

```bash
/raycast-sync          # dry-run，看 diff
/raycast-sync apply    # 实际同步 + 重生成 COMMANDS.md
```

## 执行

```bash
# 1. dry-run 看 diff
python3 ~/Dev/tools/raycast/sync.py

# 2. apply：同步 symlink + 重生成 docs
python3 ~/Dev/tools/raycast/sync.py --apply
python3 ~/Dev/tools/raycast/docs.py --write

# 3. commit hub repo（COMMANDS.md 是派生，跟 sync 一起 commit）
cd ~/Dev/tools/raycast && git add -A && git commit -m "sync: <脚本名> 加入/移除"
```

## Hub 架构

```
源命令（每个 repo 自己管）
  ~/Dev/tools/dev/raycast/commands/<name>.sh
  ~/Dev/tools/mactools/raycast/commands/<name>.{sh,py}
  ~/Dev/tools/doctools/raycast/commands/<name>.sh
                  ↓ sync.py absolute-path symlink ↓
Hub（Raycast 唯一扫描目录）
  ~/Dev/tools/raycast/commands/<name> -> ~/Dev/<repo>/raycast/commands/<name>
                  ↓ docs.py ↓
派生文档
  ~/Dev/tools/raycast/COMMANDS.md（53+ commands by package）
```

**核心原则**：源命令跟 repo 走 git，hub 只是发现层。repo 怎么重构（搬目录/改层级）都不影响 Raycast。

## 加新命令的流程（必读）

1. 在某个 repo 的 `raycast/commands/<name>.{sh,py}` 写源命令
2. **顶部必须有 @raycast 元数据头**（title 用**英文**，schemaVersion 1，mode/icon/packageName/description 全配）
3. `chmod +x <name>.{sh,py}`
4. 用依赖 `pyyaml` 等的 Python：shebang 用 `#!/Users/tianli/Dev/tools/mactools/.venv/bin/python3`（或对应 repo 的 venv）
5. 纯 stdlib Python：`#!/usr/bin/env python3`
6. **跑 `/raycast-sync apply`**（不跑 = Raycast 看不到 = 等于没加）
7. commit 源 repo 和 hub repo（COMMANDS.md 跟着改）

## 必守约束

- **title 英文**（中文混排在 Raycast 列表里识别度差，且某些情况下排序异常）
- 不在 hub 里直接写源命令文件 — hub 只能有 symlink
- yaml 等数据文件不收进 hub（sync.py 的 EXTENSIONS 限定 .sh + .py）
- 命名冲突时 sync.py 保留先发现的（按 repo 字典序），警告但不报错 → 重名前先想好

## sync.py 的 3 个历史 bug（已修，仅备查）

修复时间 2026-04-26：
1. `HUB_DIR` 还指 `~/Dev/tools/raycast/commands/`（migration 前旧路径）→ 改 `~/Dev/tools/raycast/commands/`
2. 不扫 `~/Dev/tools/<sub>/raycast/commands/`（mactools/clashx/doctools 全在 tools/ 下）→ 加两层 glob
3. 只 glob `*.sh`，忽略 `*.py` → EXTENSIONS = ("*.sh", "*.py")

## 不做

- 不 push（让用户 diff 后决定）
- 不动源命令 repo 的 commit（auto-sync hook 会处理）
- 不解决命名冲突（直接报警，让用户重命名）

## 相关

- 源工具：`~/Dev/tools/raycast/sync.py` + `~/Dev/tools/raycast/docs.py`
- 文档：`~/Dev/tools/raycast/COMMANDS.md`（派生，AUTO-GENERATED）
- 与 Hammerspoon 的边界：见 `~/Dev/stations/docs/knowledge/raycast-vs-hammerspoon-20260427.md`
