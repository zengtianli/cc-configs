---
name: zip-offload
description: 把 ~/Dev 下 raw 归档（.zip/.rar/.7z · >1 MB）外挪到 ~/zip/<Dev 镜像>，原位置留 _ZIP-INDEX.md 指针；不解压、不删除。用户说"zip 外挪 / 归档外挪 / Dev 太臃肿 / zip 太多 / raw 归档清理 / offload zip / 把压缩包挪走"时触发。
triggers: zip-offload / 归档外挪 / raw 归档清理 / Dev 太臃肿 / 把压缩包挪走 / offload zip / mirror archives
---

# /zip-offload · raw 归档外挪 + 留指针

**核心理念**（来自 memory `feedback_raw_archives_offload` · 用户原话："zip raw 不删要留 + 不留 Dev 太臃肿"）：

- raw 归档（zip/rar/7z）**不删不解压**，按 Dev 内位置 1:1 mv 镜像到 `~/zip/Dev/<rel-path>/`
- Dev 内原目录留 `_ZIP-INDEX.md` 指针（含原文件名 / 体积 / mtime / mirror 绝对路径）
- **幂等**：已有 mirror 且 md5 一致 → skip；不一致 → 报警人工
- 仅处理 raw 归档；不动 dist/build/产物压缩（那些可重生成）
- 默认排除 `_archive/` / `tools/configs/` / `tools/cc-configs/templates/` / `.git` / `.venv` / `node_modules`

---

## 1. when to use

- 用户嫌 `~/Dev` 太臃肿想瘦身
- 例行体检发现一堆 raw zip / rar 占空间
- 新装 Mac / 跨机迁移前压缩 Dev 工作树
- backup 前剥离 raw 归档（备份只动 working 文件 + 指针）

**不触发**：

- 已经在 `~/zip/` 里的不再处理
- 临时 build/dist 产物（`*.tar.gz` for release 等）→ 走 `/repo` clean 而非外挪
- 单个文件想看内容 → 用 `unzip -l` 直接列；不要为单文件起 skill

---

## 2. how it works（3 步）

### Step 1 — scan dry-run

```bash
python3 ~/Dev/tools/dev/lib/tools/zip_offload.py scan
```

输出：候选总数 + 总体积 + 按 action 分类（offload / skip-already-mirrored / conflict-md5-mismatch）+ 按体积降序的前 50 条。

机器读：`scan --json` 给 JSON。

### Step 2 — 让用户拍板

把 scan 输出贴给用户看，**显式列出**：

- 总外挪文件数 / 总体积
- 前 5 大文件路径（一眼判 raw vs derived）
- 任何 conflict-md5-mismatch（必须人工处理，不能 apply）

**推荐措辞**：「我推荐 apply，候选 N 个 / 总 XG，前 5 大文件都是 raw 归档（非 dist 产物）。冲突 0 条」

### Step 3 — apply

```bash
python3 ~/Dev/tools/dev/lib/tools/zip_offload.py apply
# 或 --yes 跳过交互（已经在 skill 内向用户确认过）
python3 ~/Dev/tools/dev/lib/tools/zip_offload.py apply --yes
```

实际动作：

1. `mkdir -p ~/zip/Dev/<rel dir>`
2. `mv <src>.zip ~/zip/Dev/<rel dir>/<name>.zip`
3. 在 src 原目录写/更新 `_ZIP-INDEX.md`（追加一行指针 · 同名行先去重再追加）

完工后报告：「已外挪 X 文件 / Y G · 0 失败」+ 提示用户后续可 `du -sh ~/Dev` 验证瘦身效果。

---

## 3. 硬约束

- **绝不解压**：raw 归档保持二进制原状
- **绝不删源**：`shutil.move` 等价 mv，源消失但内容完整搬到 mirror
- **md5 冲突必停**：mirror 已存在且内容不同 → 报警让人工对账，skill 不自动覆盖
- **不动 .git 内的 archive**：git 自身的 pack/object 不归本 skill 管
- **不动 `_archive/`**：归档目录已是冷数据，不需要再外挪
- **conflicts 必须 0** 才能 `--yes` 跑；有冲突必须显式让用户看到

---

## 4. 反模式

- 用 `find ... -delete` 删 raw zip → 违反"不删"规则
- 手动 `cp -r` 镜像 → 没 md5 校验、没指针、不幂等
- 把 `_archive/` 也外挪 → 套娃，归档目录本来就是归档
- apply 不先 scan 给用户看 → 违反"破坏性操作先批准"铁律

---

## 5. 相关

- memory: `feedback_raw_archives_offload`（用户原话 + 规则源）
- 配套 skill：`/tidy`（深度整理目录）· `/downloads-triage`（Downloads 派送）
- 实现：`~/Dev/tools/dev/lib/tools/zip_offload.py`（stdlib only · ~230 行）
