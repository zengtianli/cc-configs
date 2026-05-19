---
name: harness-sync
description: 把 ~/Dev/tools/cc-configs/ 里的项目专属 skills/commands/agents 分发到各项目 .claude/，并审计跨项目 CC 配置漂移（status/sync/init/audit 四子命令，注册表在 harness.yaml）。当用户说「同步 skills / 分发 skills / 把 X skill 也加到 Y 项目 / harness sync / 跨项目 skill 一致性 / .claude/skills 漂移 / 新项目初始化 .claude/ / 审计项目 CC 配置 / cc-configs 改了推到所有项目」时触发。区别于 /sync-cc（单项目漂移）和 /start（单项目入场只读诊断）— 本 skill 专管多项目分发。
---

# Harness — CC 配置分发管理

Source of truth 在 `~/Dev/tools/cc-configs/`，通过 symlink 提供全局 skills/commands/agents，通过 sync 分发项目专属 skills。

## 用法

```bash
python3 ~/Dev/tools/cc-configs/tools/harness/harness.py status              # 查看同步状态
python3 ~/Dev/tools/cc-configs/tools/harness/harness.py sync [--force]      # 同步到各项目
python3 ~/Dev/tools/cc-configs/tools/harness/harness.py sync --dry-run      # 预览
python3 ~/Dev/tools/cc-configs/tools/harness/harness.py init <project-path> # 初始化项目
python3 ~/Dev/tools/cc-configs/tools/harness/harness.py audit <project-path> # 审计项目 CC 配置
```

## 子命令

| 命令 | 说明 |
|------|------|
| `status` | 扫描注册表，报告 synced / missing / drifted |
| `sync` | 从 repo 复制项目专属 skills。全局 skills 通过 symlink 自动生效 |
| `init <path>` | 给项目创建 .claude/skills/ 并复制注册的 skills |
| `audit <path>` | 六维度审计项目 CC 配置质量 |

## 注册表

`~/Dev/tools/cc-configs/harness.yaml`（symlink 到 `~/.claude/harness.yaml`）

## 规则

- Source of truth: `~/Dev/tools/cc-configs/`（GitHub 版本管理）
- 全局 skills/commands/agents 通过 symlink 自动生效，不需要 sync
- 项目专属 skills 需要 `sync` 分发
- drifted 的 skill 默认不覆盖，需 `--force`

## 何时用 harness-sync vs /start

| 场景 | 用 |
|---|---|
| **单项目入场**（看本项目当前 CC 配置 + harness.yaml 注册状态） | `/start`（Phase 1 已做只读诊断） |
| **本项目漂移修复**（CLAUDE.md / README / harness 注册等单项目级） | `/sync-cc` |
| **跨项目状态扫**（注册表所有项目同步状态一览） | `harness-sync status` |
| **新项目初始化**（创建 .claude/skills/ + 复制注册的项目专属 skills） | `harness-sync init <path>` |
| **批量分发**（cc-configs 改了项目专属 skill，推到所有注册项目） | `harness-sync sync [--force]` |
| **外部项目六维度 CC 配置审计** | `harness-sync audit <path>` |

`/start` 不调 `harness sync` —— 入场是只读诊断，不修改其他项目。批量分发是 harness-sync 独占职责，多项目语义。
