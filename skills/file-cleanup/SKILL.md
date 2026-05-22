---
name: file-cleanup
description: 文件清理族 — downloads 子命令把 ~/Downloads 顶层 entry 按规则派送到 ~/Dev / personal-vault；zip 子命令把 ~/Dev 下 raw 归档（.zip/.rar/.7z）外挪到 ~/zip/<Dev 镜像>，原位置留 _ZIP-INDEX.md 指针。触发：整理下载目录 / Downloads 太乱 / 下载里的东西归一下 / zip 外挪 / 归档外挪 / Dev 太臃肿 / 把压缩包挪走 / raw 归档清理。
---

# file-cleanup · 文件清理族

两子命令，按关键词分支：

- **触发词含 "download / 下载 / Downloads"** → `## downloads` 子命令
- **触发词含 "zip / 归档 / 外挪 / 压缩包 / 臃肿"** → `## zip` 子命令

底层实现仍是原脚本，本 skill 只做编排 + 用户拍板。

---

## downloads — ~/Downloads 派送

把 `~/Downloads/` 顶层 entry 自动派送到合适项目，未识别的提示人工补规则，决策落 rules.yaml 供下次复用。

### 流程：scan → plan → 人工补规则 → apply

```bash
# 1. 看现状
python3 ~/Dev/tools/dev/lib/tools/downloads_triage/triage.py scan

# 2. 出 plan.md（dry-run）
python3 ~/Dev/tools/dev/lib/tools/downloads_triage/triage.py plan

# 3. 看 ⚠ 未知 entry：
#    a) pdftotext / pandoc / Read 判内容
#    b) rules.yaml entry_rules 加一条
#    c) 敏感证件 target 必须 ~/Dev 之外
#    d) 重跑 scan 验证

# 4. 执行
python3 ~/Dev/tools/dev/lib/tools/downloads_triage/triage.py apply
```

### 规则 SSOT

`~/Dev/tools/dev/lib/tools/downloads_triage/rules.yaml`

四层匹配（优先级：exact > prefix > regex > keyword）：

- `skip_dirs`: 永远不动的顶层目录
- `skip_ext`: 永远跳过的扩展名（.zip/.exe/.dmg/.iso/.vsix 安装包压缩包）
- `trash_patterns`: 见即 trash（hash png / .DS_Store / Office lock）
- `entry_rules`: 顶层名 → 派送目标

### 未知 entry 内容判断

| 文件类型 | 手段 |
|---|---|
| `*.pdf` | `pdftotext -l 1 file.pdf - \| head -c 300` |
| `*.docx` | `pandoc file.docx -t plain \| head -50` 或 `/docx read` |
| `*.xlsx` | `pandas.read_excel('f.xlsx', nrows=5)` |
| 目录 | `ls 目录/ \| head` |
| hash/uuid 命名 | 必须 pdftotext / mdls metadata，不准凭文件名瞎猜 |

### ~/Dev 分层目标速查

| 内容类型 | 目标 |
|---|---|
| 水利业务 | `~/Dev/Work/projects/zdwp/workspace/inbox/<date>-from-downloads/` |
| 公司共享（法规/标准） | `~/Dev/Work/shared/resources/` |
| 行政/财务 | `~/Dev/content/admin/` |
| 法律/案件 | `~/Archives/ip-legal/legal/` |
| 投资/税务 | `~/Archives/investment/` |
| 简历/求职 | `~/Dev/content/career/job-search/` |
| 学术 | `~/Dev/content/learn/<主题>/` |
| 工具源码 | `~/Dev/apps/<name>/` |
| 🔒 个人证件 | `~/Documents/personal-vault/`（必 ~/Dev 之外，git 风险） |

### downloads 反模式

- ❌ 敏感证件 mv 到 `~/Dev/content/`（git 泄露）
- ❌ LLM 逐文件分类（应该补规则一次复用 N 次）
- ❌ 直接 rm（走 `~/.Trash/` 保回溯）
- ❌ 跳过 ⚠ 未知 entry 不补规则（下次重复扫）

---

## zip — ~/Dev raw 归档外挪

**核心**（memory `feedback_raw_archives_offload` · 用户原话："zip raw 不删要留 + 不留 Dev 太臃肿"）：

- raw 归档（zip/rar/7z）**不删不解压**，按 Dev 位置 1:1 mv 到 `~/zip/Dev/<rel-path>/`
- Dev 原目录留 `_ZIP-INDEX.md` 指针（原文件名 / 体积 / mtime / mirror 绝对路径）
- **幂等**：已有 mirror 且 md5 一致 → skip；不一致 → 报警人工
- 仅处理 raw 归档；不动 dist/build 产物（可重生成）
- 默认排除：`_archive/` / `tools/configs/` / `tools/cc-configs/templates/` / `.git` / `.venv` / `node_modules`

### 何时用

- 用户嫌 `~/Dev` 太臃肿想瘦身
- 体检发现一堆 raw zip / rar 占空间
- 新装 Mac / 跨机迁移前压缩 Dev 工作树
- backup 前剥离 raw 归档

不触发：已在 `~/zip/` 的不再处理；release tar.gz 走 `/repo` clean；单文件看内容用 `unzip -l`。

### 3 步

```bash
# 1. scan dry-run
python3 ~/Dev/tools/dev/lib/tools/oneshot/zip_offload.py scan
# 输出：候选数 + 总体积 + offload/skip/conflict + 前 50 大

# 2. 让用户拍板（推荐措辞）
#    「我推荐 apply，候选 N 个 / 总 XG，前 5 大都是 raw 归档，冲突 0」

# 3. apply
python3 ~/Dev/tools/dev/lib/tools/oneshot/zip_offload.py apply
# 或 --yes 跳交互（已经确认过）
```

实际动作：`mkdir -p ~/zip/Dev/<rel>` → `mv <src>.zip <mirror>` → 原目录写/更新 `_ZIP-INDEX.md`（同名去重再追加）。

### zip 硬约束

- **绝不解压**：raw 保持二进制原状
- **绝不删源**：`shutil.move` 等价 mv，内容完整搬到 mirror
- **md5 冲突必停**：mirror 已存在且内容不同 → 报警人工对账
- **不动 `_archive/`**：套娃
- **conflicts 必须 0** 才能 `--yes`

### zip 反模式

- `find ... -delete` 删 raw zip → 违反"不删"
- 手动 `cp -r` 镜像 → 没 md5、没指针、不幂等
- apply 不先 scan → 违反"破坏性操作先批准"

---

## 相关

- 配套：`/tidy`（深度整理目录）
- 实现：`~/Dev/tools/dev/lib/tools/downloads_triage/triage.py` · `~/Dev/tools/dev/lib/tools/oneshot/zip_offload.py`（stdlib only）
- memory: `feedback_raw_archives_offload`
