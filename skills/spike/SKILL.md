---
name: spike
description: 抛弃式 spike / poc / toy 实验协议。用户说"试一下 / 试试 X 行不行 / 看 Y 可不可行 / 快速验证 / 玩具版 / spike / poc / 抛弃式实验"时触发。**显式豁免**"每个项目必配 CLAUDE.md + .claude/ 脚手架"铁律 — 因为 spike 本质就是用完即弃。
---

# Spike — 抛弃式探索协议

**核心理念**：Karpathy K2/K4 — toy-first + 极简代码。code is cheap, judgment is scarce。先用 < 50 行验证 idea 能不能跑，再决定要不要"提级"为正式项目。

**与铁律的关系**：全局 `~/.claude/CLAUDE.md` "每个项目必配 CLAUDE.md + .claude/ 脚手架"是为**长寿项目**立的。spike 是**用完即弃**，本 skill 是这条铁律的**显式豁免出口**。豁免范围明确写在下面"硬约束 - 豁免"节，不豁免的还是要守。

---

## 触发

用户说以下任一：
- "试一下 / 试试 X 行不行 / 看 Y 可不可行"
- "快速验证 / 玩具版 / 最小可跑"
- "spike / poc / proof of concept"
- "抛弃式实验 / 一次性脚本"
- "先随便写个看看"

**不触发**：用户明确说"做正式版 / 新项目 / 长期用"。

---

## 硬约束

### 代码
- 单文件 **< 50 行**（含注释、空行）
- 一个文件解决一个问题；超出 → 已经不是 spike，停手并问用户

### 位置
- 所有产物落 `~/Dev/_archive/spikes/YYYY-MM-DD-<slug>.{py,sh,ts,md}`
- **禁止**在 `~/Dev/` 根下、`~/Dev/stations/`、`~/Dev/apps/` 等正式区落 spike 产物
- slug 用 kebab-case，无空格

### 豁免（这些铁律 spike 期不适用）
- ✗ 不配 `CLAUDE.md`
- ✗ 不建 `.claude/` 脚手架
- ✗ 不写 `handoffs/<slug>.md`
- ✗ 不 commit（除非用户明确说"留下"）
- ✗ 不查 playbook META.md domain 索引
- ✗ 不 `AskUserQuestion` 颗粒度对齐（spike 就是为了快速试错，不要把决策推回用户）
- ✗ 不立 SSOT / 不写 README / 不建 reference wiki

### 仍守
- ✓ 中文交流
- ✓ 凭证从 `~/.personal_env` 读
- ✓ 破坏性操作（rm / drop / 写生产 DB）仍要确认 — spike 是探索，不是放飞
- ✓ 用户提**提级**（"留下 / 做正式版"）→ 立即切换到 `/start --bootstrap` 流程，开始守所有铁律

---

## 执行流程

1. **确认 idea + 范围**（一句话）：复述给用户"我打算用 < 50 行 <语言> 验证 <X>，落 `~/Dev/_archive/spikes/<YYYY-MM-DD>-<slug>.<ext>`"，**不**问颗粒度、**不**列方案、**不**起 plan mode
2. **直接写**：在指定路径写 < 50 行代码
3. **跑通**：本地执行一次，把输出贴给用户
4. **询问后续**："spike 跑通，要提级为正式项目吗？(y/n)"
   - 用户说 **要**（"留下 / 做正式版 / 提级"）→ 引导走 `/start --bootstrap` 或手工迁移到 `~/Dev/<name>/`，**此时**才开始配 CLAUDE.md / .claude/
   - 用户说 **不要** / 默认 → spike 留在 `_archive/spikes/`，**不** commit，**不** 写 handoff，会话结束

---

## 反模式

- ❌ spike 跑超 50 行还在加功能 → 已经不算 spike，立即停手并问用户"这个 idea 看起来值得提级，要走 /start --bootstrap 吗？"
- ❌ spike 产物落 `~/Dev/` 根 / `stations/` / `labs/`（应该全在 `_archive/spikes/`）
- ❌ 给 spike 配 SSOT / playbook / handoff / CLAUDE.md（违反 spike 的"用完即弃"本质）
- ❌ 拿 spike 的产物当线上代码用（不审查、不测试、不部署 review）
- ❌ spike 没跑通就开始"重构 / 抽象 / 加配置"（先证明能跑，再谈别的）
- ❌ 用户说"试一下"被解读成"做个正式 MVP"，触发全套脚手架协议（直接走 spike，别问）

---

## 何时提级为正式项目

只有用户**明确**说以下任一才提级：
- "这个挺好 / 留下 / 做正式版 / 提级"
- "迁到 ~/Dev/<name>/"
- "加 CLAUDE.md / 配脚手架"

提级动作：
1. `mv ~/Dev/_archive/spikes/<YYYY-MM-DD>-<slug>.<ext> ~/Dev/<name>/<entry>.<ext>`
2. 走 `/start --bootstrap` 或手工补 `CLAUDE.md` + `.claude/{settings.json,skills/,commands/}`
3. 从这一刻起，所有"每个项目必配脚手架"铁律全部生效，不再豁免

**判别**：用户没明说就**不提级**。spike 的默认归宿是留在 `_archive/spikes/` 当历史档案，不是 "下一个项目种子"。
