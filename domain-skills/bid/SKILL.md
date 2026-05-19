---
name: bid
description: 标书撰写技能。当处理 ~/Dev/Work/shared/bids/ 下的标书项目，需要解析招标文件、搭建章节框架、盘点参考资料、走四阶段写作管线时触发。
---

# bid — 标书撰写

标书项目集中在 `~/Dev/Work/shared/bids/`，方法论沉淀在 `~/Dev/Work/shared/bids/CLAUDE.md`。本 skill 是入口，告诉你**做什么、按什么顺序、用哪个工具**。

## 核心原则

1. **三级优先级**：脚本 > skill > CC 直接。能脚本化的不要 AI，能 skill 的不要裸写。
2. **主会话不写正文**：只做规划、调度、验证。正文一律交 subagent，并带 4 维度约束。
3. **章节-评分硬绑定**：每章顶部必须贴"得满分要求"原文，写作 subagent 必须逐项响应。
4. **不问节奏**：拿到任务直接按"把它做好"全力推进，不要问截止日期/紧不紧。

## 标书撰写的 6 个阶段

### 阶段 1 — 项目初始化
```bash
cp -r ~/Dev/Work/shared/bids/_template ~/Dev/Work/shared/bids/{slug}
```
把招标文件原件丢进 `招标文件/`，把所有参考资料丢进 `参考/`。
填 `_project.yaml`（项目名、编号、采购人、预算、截止日期）。

### 阶段 2 — 招标文件解析

🚧 `zbwj_parse.py` 待立（未来合进 `~/Dev/tools/doctools/scripts/document/`）。当前先用 `bid_doc_parser.py` 做 doc/docx → md，评分表手工提取。

```bash
python3 ~/Dev/tools/scripts/scripts/document/bid_doc_parser.py ~/Dev/Work/shared/bids/{slug}/招标文件/
# 输出 招标文件/*.md；scoring.json 需手工从 md 里抽评分表
```

产物目标：
- `招标文件/*.md`（doc/docx → md，pandoc）
- `招标文件/scoring.json`（提取的评分表：序号 / 评分项 / 分值 / 得满分要求）
- `技术标框架.md`（按评分项生成章节骨架，每章贴好"得满分要求"）

人工复核 `scoring.json`，确保没漏分项。

### 阶段 3 — 参考资料盘点
让 Claude 读 `参考/` 下所有文档，生成 `参考/_index.md`：
```
| 文件 | 涵盖章节 | 可复用内容 | 是否最新 |
```
重点：标出"可直接复用 / 需更新数据 / 需新写"三类。
对延续项目，老中标稿是金矿，模板章（业绩、组织、质量、售后）几乎可以整段搬。

### 阶段 4 — 写作（subagent + 4 维度约束）
按 `技术标框架.md` 逐章派 subagent 写作，输出到 `成果/md/`。
每个 subagent prompt 必须包含：
- 该章的"得满分要求"
- D1-D4 维度约束（见 ~/Dev/Work/shared/bids/CLAUDE.md）
- 参考资料盘点结果（告诉它哪段抄哪里）
- 当前章节的数据来源约束

### 阶段 5 — 管线脚本（部分已立 / 部分 🚧）

**已立**（`~/Dev/tools/doctools/scripts/document/`）：`report_quality_check.py` / `md_docx_template.py` / `chart.py`

**🚧 待立**：`bid_standardize.py`（已归档 `_archive/scripts-archive/`，待重立到 doctools） / `chart_insert.py` / `md_merge.py`（只有 raycast .sh 包装）

```bash
cd ~/Dev/Work/shared/bids/{slug}/成果/

# 5.1 质量修复（禁用词、数据来源标注）
python3 ~/Dev/tools/doctools/scripts/document/report_quality_check.py md/ --bid --fix --output-dir md_clean/

# 5.2 🚧 结构标准化（bid_standardize.py 归档在 _archive/scripts-archive，待重立到 doctools）
#     暂时：手工过一遍评分引用 / 标题编号 / 加粗

# 5.3 生成图表 PNG（统一走 chart.py + JSON 配置）
python3 ~/Dev/tools/doctools/scripts/document/chart.py charts/*_config.json

# 5.4 🚧 ASCII art → PNG 引用（chart_insert.py 未立，先手工替换）

# 5.5 合并 + 转 docx
bash ~/Dev/tools/doctools/raycast/commands/md_merge.sh md_final/ -o merged.md  # md_merge.py 未立，用 .sh 包装
python3 ~/Dev/tools/doctools/scripts/document/md_docx_template.py merged.md -o 技术标.docx
```

### 阶段 6 — 终审
- 跑 `report_quality_check.py --check` 看残留问题
- 自审：每章是否都响应了"得满分要求"每一条
- D3 预判：扮演评审专家，能不能问倒自己

## 4 维度写作约束（subagent 必带）

| 维度 | 检查要点 |
|------|----------|
| D1 溯源链 | 每个结论有推导过程，筛选链条完整不跳步 |
| D2 立场措辞 | 站乙方立场，委婉表达，风险抛给甲方/政策 |
| D3 预判评审 | 写完假装审查专家，能否问倒自己 |
| D4 数据纵深 | 总量→结构→趋势→对比，先全貌后细节 |

## 模板章（跨项目高复用）

下列章节高度模板化，新项目可从老项目搬：
- **质量保证措施**（评分常 3 分）
- **售后服务方案**（注意各地"当天到现场"得满分的要求）
- **进度保障措施**
- **组织架构与人员配置**
- **业绩与资质**

参考：`~/Dev/Work/shared/bids/qiantang-monitoring-2026/成果/md_final/11.md` `12.md`

## 不要做的事

- ❌ 不要问用户"截止日期紧不紧 / 项目什么状态 / 今天做到哪一步"
- ❌ 主会话不要直接写正文，一定派 subagent
- ❌ 不要跳过 4 维度约束
- ❌ 不要手画图表，所有图走 chart_*.py + JSON 配置
- ❌ 不要在 md_final 之后再手动改文字（改 md_clean，重跑管线）
