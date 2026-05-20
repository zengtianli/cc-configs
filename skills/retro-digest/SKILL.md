---
name: retro-digest
description: 把一批散落的 retro/会话记录按主题线合并成少数 HTML 知识节点（起因→迭代→现状），原文归档到 _archive，织入 wiki 知识网。用户说"4月所有会话讲了啥+修到哪""合并/整合 retro 不要思维负担""摘要这些 retro/会话"时触发。
---

# /retro-digest · retro 摘要整合

**核心理念**：散落的 N 条 retro = 思维负担。按**主题线**合并成少数 HTML 知识节点（每节点讲清「起因→迭代→现状」），原文 trash-safe 归档，全部织入 wiki 零 orphan。降负担又不丢历史。

触发：用户说「X 月/这些 retro 讲了啥+修到哪+迭代到哪」「合并/删/整合 retro」「不要思维负担」「摘要这些会话」。

---

## 执行流程（goal-loop · 未达标不停）

### 1. 先钉 GOAL（machine-checkable）
写 `~/Dev/jobs/retro-digest/GOAL.md` + `check_retro.sh`，验收标准至少：
- D1 ≤8 个 digest 节点存在
- D2 每节点含 起因/迭代/现状 三段 + 状态 badge
- D3 原始 retro 全移出 live tree 到 _archive（live 计数=0）
- D4 每 digest 引用其源 retro slug（可追溯）
- D5 wiki `check_goal.sh` 不回归（orphan=0）
- D6 本 skill 存在

### 2. 看数据 + partition（铁律 #9：先看 5 条）
- 列全部目标 retro：`find ~/Dev/wiki/topics/retros -name 'retro-<期>*.md'`，读 frontmatter `project:` + slug + 抽样正文。
- 按**主题线**partition 成 5-8 组（SSOT / stations / cc-meta / 基建工作流 / 产品线 …），**每条 retro 恰好归一组**（无重叠全覆盖），写进 GOAL。

### 3. 并发派主题 agent（铁律 #1：默认并行）
每组 1 个 agent（audit+write，**禁 commit/禁动别人文件/不归档**）：
- 读自己那组全部 retro 原文。
- **追现状**：`git log` 相关 repo + 读当前 CLAUDE.md/SSOT 文件/wiki topic，判断这条线现在 ✅闭环 / 🔄进行中 / ⚠废弃-被X取代。
- 写 1 个 digest HTML 到 `~/Dev/wiki/topics/retros/digest-<期>-<theme>.html`：
  - dark vault 模板（`:root` 调色板同全站，见 `templates/html-shared/`）。
  - 三段：**起因/背景** → **迭代时间轴**（每条 retro 一里程碑 + 日期 + 源 slug）→ **现状**（彩色状态 badge）。
  - body 顶 `<nav class="wiki-nav" data-wiki-nav="1"></nav>` + 末 `<section data-wiki-backlinks="1"></section>` 空占位。
  - see-also 交叉引用（幂等 `<!--see-also-->`）链兄弟 digest + 相关 topic，防 orphan。
  - 正文点名每条源 slug（D4 可追溯）。

### 4. 主进程整合（防 race，主进程独占）
- **归档原文**：`mv` 28 条原始 retro 的 .md + .html 到 `_archive/`（先 trash 兜底：`mv -n <t> ~/.Trash/cc-pre-destruct-$(date +%s)/` 再 mv 到 _archive）。_archive 已被 wiki_build 排除出 net。
- **重建网**：`python3 ~/Dev/tools/dev/lib/tools/wiki_build.py --root ~/Dev/wiki`（注入 nav/backlinks + 重生 index + 力导向图，digest 节点入网）。
- **跑验收**：`bash ~/Dev/jobs/retro-digest/check_retro.sh` → 有 FAIL 自主修/补 see-also/重跑 → 循环到全 PASS。

### 5. commit + 反馈
全 PASS 才 commit wiki（local subrepo）+ 反馈用户。HTML 已 open 给用户看。

---

## 反模式
- 一条条摘要不合并 → 没降负担（违反用户"不要思维负担"）
- 原文 `rm` 不归档 → 违反 [[trash-everything-protocol]]，丢历史
- digest 不追现状只复述 retro → 用户要的是"迭代到哪了"，不是 retro 复读
- digest 成 orphan / 不织网 → 违反 [[wiki-is-bidirectional-graph]]
- 不先钉 GOAL 就开干 → 违反 [[agent-goal-loop-until-met]]

## 关联
- [[wiki-is-bidirectional-graph]] · [[agent-goal-loop-until-met]] · [[trash-everything-protocol]]
- [[user-facing-output-is-html]] · [[/debrief]] · [[/wrap]]
- 引擎：`~/Dev/tools/dev/lib/tools/wiki_build.py`（注入+force graph+orphan 检测）
