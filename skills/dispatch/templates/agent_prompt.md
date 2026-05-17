# Subagent Prompt Template

复制下方块到 Agent tool call 的 prompt 参数；把 `{...}` 占位换成具体内容。

---

## Goal (machine-checkable)

{goal}

**验证判据**（满足任一即算成功）：

- [ ] {判据 1，e.g. `curl -sI https://x.tianlizeng.cloud | head -1` 含 `200`}
- [ ] {判据 2，e.g. `test -f ~/Dev/<path>/file.ext` exit 0}
- [ ] {判据 3，e.g. `sqlite3 db "SELECT COUNT(*) FROM t" = N`}

不满足上述判据 = 任务**未完成**。不允许只 "看起来对了" / "应该可以了"。

---

## Context

- 工作目录：{cwd 绝对路径}
- 相关 SSOT / 配置：{paths.yaml / settings.json / ...}
- 已知约束：{e.g. "stations/website 走 vercel"，"VPS systemd template"}
- 参考材料：{wiki path / handoff path / 上游 agent 报告 path}

**第一动作**：如果是搜索 / 探索 / 找 reference 类任务，必先调
`mcp__auggie__codebase-retrieval` (workspace=`{具体路径}`)。
召回不足才退 Grep/Glob/Read。

---

## Loop（retry-until-verified）

```
1. 读 context + 实测当前状态
2. 执行修复 / 实现
3. 跑判据脚本验证
4. 通过 → 写报告 → 结束
5. 不通过 → 自我诊断（"哪一步偏了 / 数据形态对吗 / 我假设的是不是错的"）
6. 回 2，最多 {N=5} 次
7. N 次仍不过 → 写"失败 + 已尝试 X/Y/Z + 怀疑 W + 建议下一步" 求助，不挂死
```

---

## 约束（违反 = 任务失败）

- **绝对禁止** `git add` / `git commit` / `git push` — 主进程统一收口
- **绝对禁止** 改 SSOT 派生产物（`paths_const.*` / `services.ts` / `*.generated.*`）
- **绝对禁止** 改 `~/.claude/settings.json` / `harness.yaml` — 输出 PATCH 段让主进程合并
- **硬时限 10 分钟** — 超时立即写"超时 + 当前进度"报告退出
- 破坏性命令（rm -rf / drop table / 写生产）— 立即停手报告，不自作主张
- 中文报告

---

## 报告格式（≤ 500 字）

```
## 结果

- [x] / [ ] 判据 1
- [x] / [ ] 判据 2
- [x] / [ ] 判据 3

## 做了什么

1. ...
2. ...

## 关键发现 / 踩坑

- ...

## 产物路径（绝对路径）

- `~/Dev/<file>` — 说明
- `~/Dev/<file>` — 说明

## 待主进程接力

- 需要 commit 的 repo: `<path>`
- 需要 merge 的 PATCH: ```...```
```
