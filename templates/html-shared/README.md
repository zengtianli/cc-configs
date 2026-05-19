# html-shared/ — CC 生成 HTML 的强制共享 snippet

> SSOT: 所有 CC 生成的 user-facing HTML 必须 inject `cc-select-quote.html` 三段（meta / badge / footer+script）

## 内容

| 文件 | 用途 |
|---|---|
| `cc-select-quote.html` | meta 溯源 + 顶角 session badge + 框选→clipboard quote + 底部 session footer |

## 使用

### 新生成 HTML（手工）

把 `cc-select-quote.html` 三段分别插到对应位置，替换 4 个占位符：
- `{{SESSION_UUID}}` · 完整 UUID（从 `/private/tmp/claude-*/<cwd>/<UUID>/` 反推 或 `~/.claude/projects/<cwd>/<UUID>.jsonl`）
- `{{SESSION_UUID_SHORT}}` · 前 8 位
- `{{GENERATED_AT}}` · ISO8601（如 `2026-05-19T01:15:00+08:00`）
- `{{CWD}}` · 当时 cwd（如 `/Users/tianli/Dev/Work`）
- `{{HTML_PATH}}` · 生成的 HTML 绝对路径

### 批量 patch / backfill

跑 `~/Dev/tools/dev/lib/tools/html_provenance_backfill.py`，自动扫 ~/Dev 内 mtime 范围内的 HTML，幂等注入。

```bash
# 过去 24h
python3 ~/Dev/tools/dev/lib/tools/html_provenance_backfill.py --hours 24 [--session <UUID>] [--dry-run]

# 单文件
python3 ~/Dev/tools/dev/lib/tools/html_provenance_backfill.py --file <path> [--session <UUID>]
```

## Rules（memory link）

- `[[html-text-selection-quote]]` — 框选 → clipboard 引用块的产品语义
- `[[html-session-provenance]]` — 每个 HTML 必含 session UUID
- `[[user-facing-output-is-html]]` — 总规则
- `[[html-inline-options]]` — 决策选项 inline 不弹框
