---
description: DOCX 工作流族 — read 读章节 / edit 改标题 / diff 对比 / review 审阅 / revise 修订 / batch-revise 批量改 / merge 合并 / fix 修编号 / md2word MD 转 Word
---

# /docx — DOCX 工作流统一入口

`/docx <subcommand> [args]`

| 子命令 | 干啥 | 工具 |
|---|---|---|
| `read` | 读 DOCX 指定章节内容（按标题定位）或 `--list` 列结构 | python-docx |
| `edit` | 批量改标题（rename/insert_after/delete） | docx_heading_edit.py |
| `diff` | 对比两 DOCX，产变更清单 MD + 可选批注 DOCX | python-docx |
| `review` | 审阅文档（格式检查 / LLM 深度审阅），输出 Word 批注 | docx_tools.py + review_deep.py |
| `revise` | 按审稿意见修改论文（修订标记+批注） | docx_tools.py track-changes |
| `batch-revise` | 批量将改动草稿 MD 转 track-changes 写入 DOCX | docx_tools.py track-changes |
| `merge` | md=MD 写入 DOCX 章节 / revisions=合并多修改稿 | python-docx |
| `fix` | refs=角标 / heading=编号 / numbering=表图 / all=全部 | fix_superscript_refs.py |
| `md2word` | MD/DOCX → Word 标准工作流（套模板 → 文本修复 → 图名居中） | md_docx_template.py |
| `renumber` | 图被增删/挪位后，按出现顺序重排 Figure 号 + 同步全部正文引用 | docx_renumber_figures.py |

⚠️ 文件名含中文引号时用 `glob` 或 `ls` 拿路径，不要手敲。

工具根：`/opt/homebrew/bin/python3 ~/Dev/tools/doctools/scripts/document/`

---

## read — 读 DOCX 章节

`/docx read <docx路径> <章节关键词|--list>`

示例：
- `/docx read path/to/report.docx 水效评估指标体系`
- `/docx read path/to/report.docx --list`
- `/docx read path/to/report.docx 3.1`

### 流程

1. **定位文件**：$ARGUMENTS 只给关键词没给路径 → 当前项目目录最新 `.docx`（排除 `~$`）
2. **解析标题结构**：python-docx 遍历段落识别 Heading 样式
3. **提取章节内容**：找到匹配标题后，从该标题到下一同级或更高级标题之间所有段落
4. **输出**：含段落索引标记，便于后续编辑定位

### 关键约束
- 只读，不修改源文件
- 标题匹配优先精确，找不到模糊匹配（关键词全部出现）
- 表格内容也提取（遍历 `doc.tables`）

---

## edit — 改标题

`/docx edit <docx> --list` 或 `/docx edit <docx> '<json_ops>' [--dry-run] [-o output]`

工具：`~/Dev/_archive/scripts-archive/document/docx_heading_edit.py`

支持操作：
- `rename`: `{"action":"rename", "index":185, "new_text":"新标题"}`
- `insert_after`: `{"action":"insert_after", "index":185, "heading_level":4, "new_text":"新标题"}`
- `delete`: `{"action":"delete", "index":208}` — 删标题及下属内容
- `delete_heading_only`: `{"action":"delete_heading_only", "index":208}` — 仅删标题段落

### 流程

1. 确定目标文件（路径用 `ls` 取，避免中文引号）
2. `--list` 列出当前标题，向用户展示标题树
3. 构建 JSON 操作列表（index 从 --list 输出获取）
4. `--dry-run` 预览
5. 用户确认去掉 `--dry-run` 执行
6. 再 `--list` 验证结果

---

## diff — 对比两 DOCX

`/docx diff <源文件> <目标文件> [--md-only|--docx-only]`

输出：变更清单 MD（章节树形 / 未改动 / 已修改 / 新增）+ 可选批注 DOCX（在改动章节标题加 Word 批注）

### 流程

1. **解析章节**：两文件各自按标题拆 `(标题原文, 层级, 标题归一化, [内容段落])`

   归一化：去序号前缀 `^[0-9]+[）)]\s*` + 去内部标注 `（[^）]*标注[^）]*）`

2. **对比内容**：归一化标题匹配
   - 匹配 + 内容相同 → 未改动
   - 匹配 + 内容不同 → 已修改（计算差异：删/改/增几段）
   - 未匹配 → 新增

3. **生成变更清单 MD**：树形缩进 + 顶部统计表 → `{源文件名}-变更清单.md`

4. **生成批注 DOCX**（可选）：对已修改章节标题加 Word 批注

   **写入方法**（避免 Word "无法读取内容" 错误）：
   1. python-docx 插入 commentRangeStart/End + commentReference
   2. 构建 comments XML
   3. `doc.save(temp_path)` 先保存
   4. zipfile 打开 temp，补写 word/comments.xml + Content_Types + Relationships
   5. 保存最终文件 → `{目标文件名}-批注.docx`

### 关键约束
1. 只读对比，不改源/目标
2. 批注人：从 `git config user.name`，找不到用 "Review"
3. 标题用 Heading style 判断，不靠文本格式猜
4. 批注 DOCX 必须 zip 补丁法（python-docx Part API 注册 comments 会导致 Content_Types 缺失）
5. 内容对比粒度：段落级，忽略纯空白差异

---

## review — 审阅文档

`/docx review <file>` — 默认格式审阅（禁用词、英文标点、单位、数据来源、重复表述）

模式：
- **格式审阅**（默认）：禁用词 / 英文标点 / 单位格式 / 数据无来源 / 重复表述
- **深度审阅**（`--deep`）：4 维度 LLM 审阅（完整性/结构性/立场措辞/数据一致性）
- **全量审阅**（`--all`）：先格式再深度，两轮批注

工具：
- 提取：`docx_tools.py extract <file>`
- 写批注：`docx_tools.py track-changes review <file> -o <output> -r <rules.json>`
- 深度：`review_deep.py <file> --rules <rule-name>`
- 规则目录：`~/Dev/tools/cc-configs/rules/review-deep/`

### 格式审阅流程

1. 提取文档文本
2. 分析问题类型 → 生成 rules JSON：
   - 禁用词："确保"/"我们"/"我司"/"贵司" → 替换 + 批注原因
   - 英文标点 → 中文标点 + 批注
   - 单位：平方米/立方米 → m²/m³ + 批注
   - 数据无来源、重复表述 → 仅批注（find=replace）
3. rules JSON 同目录 `_review_rules.json`
4. 写入批注 → `<输出文件>`

### 深度审阅

```bash
review_deep.py <file> --rules eco-flow-report --model haiku
```

参数：`--dim completeness structure tone consistency` / `--model haiku|sonnet`（默认 haiku，重要文档建议 sonnet）/ `--dry-run` / `-o`

`--all` 模式深度审阅的输入文件用格式审阅的输出文件。

### 完成
- `open` 打开
- 报告：按类型/维度汇总问题数
- 清理临时 rules JSON

---

## revise — 按审稿意见修改论文

`/docx revise <docx> [--comments <file>] [--rules <file>] [--dry-run] [--author <name>]`

将修改以 Word 修订标记 + 批注形式写入文档。

工具：
- 提取：`docx_tools.py extract`
- 写修订：`docx_tools.py track-changes review <file> -o <output> -r <rules.json> -a <author>`
- 读修订：`docx_tools.py track-changes read <file>`

### 流程

1. **确定输入**：论文文件存在且 `.docx`；`--comments` 读审稿意见，否则从论文文档提取

2. **分析审稿意见**：分三类
   - 可直接修改：文字改写 / 补数据 / 可视化
   - 需要计算支撑：先写脚本运行，用结果撰写
   - 无法修改：批注说明所需素材

3. **生成修改规则**（`_revise_rules.json`）：

   ```json
   [
     {
       "find": "原文中需要修改的段落或句子",
       "replace": "修改后的内容",
       "comment": "【回应审稿意见第N条】修改说明"
     }
   ]
   ```

   要点：
   - `find` 必须**唯一匹配**
   - 只插不替 → `replace` 保留原文 + 追加新内容
   - 只批注不改正文 → `find` = `replace`
   - 每条 `comment` 以 `【回应审稿意见第N条】` 开头
   - 需计算支撑的，先跑脚本，结果填 `replace`

4. **写入**：

   ```bash
   docx_tools.py track-changes review <input> -o <output> -r <rules> -a <author>
   ```

   输出：`（修改稿）原文件名.docx`

5. **验证**：`track-changes read` 读输出确认修订/批注；`open` 打开；汇总报告（已修条目 / 未修原因 / 辅助文件）

---

## batch-revise — 批量改动草稿 MD → DOCX

无参数：扫 `成果/md/*-改动草稿.md` 全部处理。
指定文件：`成果/md/3.5-xxx-改动草稿.md`
`--dry-run`：只生成 rules JSON，不写入
`--author <name>`：默认"审阅"

### 流程

1. **确定输入**：基准 DOCX 在 `招标文件/` 下找主文档（排除 `~$`、`copy`、`修改稿`），优先最新合并稿/原始稿；改动草稿 MD 按参数 / glob

2. **逐个 MD 生成 rules JSON**：
   1. 读 MD 解析改动条目（"原文"/"改为" 配对，"删除"/"新增" 指令）
   2. 读 DOCX 对应段落，python-docx 提取原文，确保 `find` 唯一匹配
   3. **用 Python `json.dump` 生成 rules JSON**（绝对不用 Write 工具写 JSON，避免中文引号解析失败）
      - 命名：`招标文件/_revise_rules_{章节号}.json`
   4. 验证 JSON 可解析

3. **批量写入**：每个 rules JSON 调 `track-changes review`，**每个 MD 独立修改稿 DOCX**（不累加）

4. **验证与报告**：`track-changes read` 验证；汇总表（MD 文件 / 改动数 / 输出 DOCX / 状态）；`open` 打开全部

### 关键约束

1. **JSON 必须 Python 生成** `json.dump(rules, f, ensure_ascii=False, indent=2)`
2. **find 必须唯一匹配**（多处引用 → 加更多上下文）
3. **删除**：`replace = ""`
4. **新增**：插入点前段落作 `find`，`replace = 原文 + "\n" + 新内容`
5. **中文引号文件名**：用 Python glob 取路径
6. **每草稿 MD 独立输出**（不累加）
7. **大段替换 (>10 段) 改用直接重建**：delete old paras + insert new（参考 rebuild 脚本），不走 track-changes

---

## merge — 合并文档内容

`/docx merge <md|revisions> <args>`

### md — MD 内容写入 DOCX 指定章节

1. 解析 MD 结构（标题层级 / 段落 / 表格）
2. DOCX 中定位目标章节（匹配第一个标题）
3. 替换范围：从目标标题到下一同级标题之前
4. 保留原 DOCX 表格和图片
5. 正确映射 MD 标题层级 → Word Heading 样式
6. 输出 `-merged.docx` 后缀

### revisions — 合并多修改稿

将多个修改稿 DOCX 的修订内容合并到基准文档：

1. 读修订规则 JSON（`_revise_rules_{section}.json`）
2. 按规则将所有修改作直接替换（非 track changes）
3. **倒序应用**规则避免索引漂移
4. 输出 `标书大纲-合并稿-{MMDD}.docx`

---

## fix — 修复 DOCX 格式

`/docx fix <refs|heading|numbering|all> <file>`

第一参数为子命令，其余为路径和 flags。

### refs — 引用角标修复

`[1]` `[3-4]` `[18-19]` 等文献引用 → 右上角上标。

工具：`fix_superscript_refs.py`

1. `--dry-run` 预览
2. 执行（默认覆盖原文件，`-o` 指定输出）
3. `open` 打开

自动跳过参考文献列表行和已上标引用。

### heading — 标题编号体系

7 级体系：1 → 1.1 → 1.1.1 → 1.1.1.1 → （1） → 1） → ①

DOCX 三步修复：
1. **numbering.xml** — 确保 H5/H6 绑定 numPr
2. **标题级别** — **两遍扫描法**修复层级跳跃（第一遍只读分析，第二遍批量写入）
3. **去硬编码前缀** — 跨 run 逐字符消耗，去掉手动编号

⚠️ 关键：不能边修边检测，必须两遍扫描。

### numbering — 表/图编号一致性

1. 扫描标题段落（"表"/"图"开头，<80 字符）和正文引用
2. 诊断：编号不连续 / 顺序不一致 / 引用不匹配
3. 替换处理 w:t 跨节点（"表" 和数字可能分属不同 w:t）
4. 避免冲突用 `_tmp` 临时后缀

### all — 全部修复

按顺序：heading → numbering → refs，中间不需用户确认。

---

## renumber — 图重排后重编号 + 同步正文引用

`/docx renumber <docx> [-o OUT | --inplace] [--dry-run] [--prefix Figure]`

工具：`docx_renumber_figures.py`。用于**图被增删/挪位后**：扫所有图题（caption），按它们在文档里**实际出现的物理顺序**重编号为 1..N，并把 captions + 全部正文引用（含范围 `Figures N–M`、列举 `Figures N, M and K`）一并改对。

与 `fix numbering` 区别：`fix numbering` 是诊断+修不连续；本子命令是**给定一份已被人工挪好位置的稿，按位置强制顺排**（典型场景：reviewer 让加/删图、作者在 Word 里拖动图位置后）。

### 流程
1. `--dry-run` 先看 `现号→新号` 映射 + 变动（置换/轮转都支持）。
2. 确认后 `-o` 出新档 或 `--inplace`（自动留 `.bak`）。
3. 脚本自验重编号后 captions 连续 1..N，不连续退出码 2。

### 关键实现（踩坑封装，直接用别重写）
- **跨 run 分裂**：Word 把 `Figure ` 和 `23` 拆进相邻 w:t；脚本按"段落 concat + 字符偏移定位"改，朴素正则会漏。
- **置换防碰撞**：逐 token 读旧值原子写新值（朴素全局 replace 会 23→25 又被 25→27 二次串改）。
- **排除 w:del**：track-changes 删除态旧文本不改。
- ⚠ **python-docx 陷阱**：`Paragraph.text` 静默漏 `w:ins`（修订插入）run 文本 → 用它扫图题会漏"修订态插入的图/引用"。脚本走 lxml 遍历 w:t（含 w:ins 排除 w:del），不踩坑。**任何在修订态 docx 上做图/引用统计，都不能信 python-docx 的 .text，要走 XML。**

### 重复图号
若多个 caption 共用同一现号（引用无法安全 remap）→ 退出码 2 + 列出重复号，先消重再跑。

---

## md2word — MD/DOCX → Word 标准工作流

`/docx md2word <file>` — 套模板 → 文本修复 → 图名居中

脚本根：`~/Dev/tools/doctools/scripts/document/`，Python：`/opt/homebrew/bin/python3`

### 流程

1. **确定输入**：`.md` 或 `.docx`

2. **根据类型转换**：
   - `.md` → `md_docx_template.py "<input>"` → 同目录同名 `.docx`
   - `.docx` → `docx_apply_template.py "<input>"` → `<原名>_styled.docx`

3. **文本格式修复**：`docx_text_formatter.py "<上一步docx>"` → `<原名>_fixed.docx`（标点/引号/单位）

4. **图名样式**：`docx_apply_image_caption.py "<上一步docx>"`（就地修改，应用图片+图名居中样式）

5. **完成**：
   - `open` 打开最终 docx
   - 报告每步处理结果摘要（替换标点数 / 处理图片数等）
   - 列出中间文件路径
