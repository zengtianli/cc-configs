---
description: 把 cc-configs/ 内 skills/commands/agents 分发到各项目 .claude/ + 跨项目漂移 audit（status/sync/init/audit 4 子命令）
---

# /harness-sync — 跨项目分发

显式入口给用户手键；不再 skill auto-trigger（主动维护操作，对话中误触发风险高，降级为 command）。

**trigger keywords**（供 README 检索，不进 auto-trigger）：同步 skills / 分发 skills / cc-configs 改了推到所有项目 / 跨项目 skill 一致性 / .claude/skills 漂移 / 新项目初始化 .claude/ / 审计项目 CC 配置

## 调用

```bash
/harness-sync [status|sync|init|audit]
# ↓ 实质执行
python3 ~/Dev/tools/cc-configs/tools/harness/harness.py <subcmd>
```

| 子命令 | 说明 |
|------|------|
| `status` | 扫描注册表 → synced / missing / drifted |
| `sync [--force] [--dry-run]` | 从 cc-configs 复制项目专属 skills 到各项目（全局走 symlink 不需 sync；drifted 默认不覆盖，--force 强推） |
| `init <project-path>` | 给新项目创建 .claude/skills/ + 复制注册的 skills |
| `audit <project-path>` | 六维度审计项目 CC 配置质量 |

## SSOT

- 注册表：`~/Dev/tools/cc-configs/harness.yaml`（symlink 到 `~/.claude/harness.yaml`）
- Source: `~/Dev/tools/cc-configs/`（GitHub 版本管理）

## vs 邻居

| 场景 | 用 |
|---|---|
| 单项目入场只读诊断 | `/start` |
| 单项目漂移修复 | `/sync-cc` |
| **跨项目状态/分发/初始化/审计** | `/harness-sync` |

`/start` 不调 harness sync — 入场是只读诊断，不改其他项目。批量分发是 harness-sync 独占职责。
