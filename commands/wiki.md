---
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, mcp__auggie__codebase-retrieval
description: Wiki 工作流族。默认 = cwd 本地 vault（平铺）。super vault 显式 --super。强制 frontmatter + [[wikilinks]] + README MOC。长度服务内容（把事情说清楚就行），不设硬上限。
---

# /wiki — 本地 vault 优先 wiki 工作流

把工作内容体系化进 vault。**默认目的地 = cwd 项目本地 vault（平铺）**，super vault 和任意路径必须显式指定。

```
/wiki entry <slug> [--super] [--vault <path>]
/wiki new <topic-slug> "<descrip>" --super   # 仅 super vault 需要分 topic
/wiki verify [<topic>] [--super] [--vault <path>]
/wiki link <project-path> --super
/wiki rebuild --super
```

> v0.4 (2026-05-12)：**默认 = cwd 本地平铺**（`<cwd>/wiki/<entry>.md`）。去掉 `.obsidian/` 父目录探测的子 vault 推断逻辑。super vault 用 `--super` 显式（取代旧 `--global`/`--here`）。
>
> v0.3 (2026-05-08)：加 `--here`（已被 v0.4 设为默认行为，flag 废弃）
> v0.2 (2026-05-07)：vault-scoped（已被 v0.4 简化）

约定参考 `~/Dev/tools/configs/playbooks/obsidian-wiki.md`。本 command 是该 playbook 的**自动化执行版**。

---

## 全局约定（所有子命令必守）

### 路径（两种模式）

| 模式 | 触发 | Vault 根 | Entry 路径 | MOC |
|---|---|---|---|---|
| **本地平铺**（默认） | 无 flag | cwd | `<cwd>/wiki/<entry>.md` | `<cwd>/wiki/README.md` |
| **super vault 分层** | `--super` | `~/Obsidian/dev-vault/` | `<vault>/topics/<topic>/<entry>.md` | `<vault>/topics/<topic>/_INDEX.md` |
| **任意路径** | `--vault <path>` | `<path>` | `<path>/wiki/<entry>.md`（平铺）或 `<path>/topics/<topic>/<entry>.md`（如 `<path>/topics/` 已存在） | 同 entry 所在目录 |

- 项目本地不需要分 topic — 直接平铺在 `wiki/` 下（reclaim 模式）。条目少时合理，>10 条建议升级到 super vault 立独立 topic
- super vault 必走 topics 分层（多领域知识汇聚）
- 跨项目项目级 wiki（symlink）：仅 super vault 场景 `--super` `topics/<topic-from-topic-index>/<project-name>/` ← 项目的 `wiki/`

### Frontmatter（每个 md 必有）

```yaml
---
tags: [<topic>, <subtag1>, <subtag2>]
aliases: [<别名 1>, <别名 2>]
created: YYYY-MM-DD
---
```

`_INDEX.md` 加 `moc` 进 tags。

### 链接风格

- **直接写在 vault 的 topic** → 全用 `[[wikilinks]]`，禁 `[](file.md)`
- **symlink 进来的项目 wiki** → 保持项目内原有 markdown link（不动）
- 跨 topic 引用：`[[../<topic>/<entry>]]` 或 `[[../<topic>/_INDEX|<别名>]]`

### 长度 · 内容驱动，不设硬上限（2026-05-13 用户原话「不能被行数限制，把事情说清楚就行」）

**铁律**：长度服务内容。把事情说清楚 — 该长就长，该短就短。**不允许为压在某个区间而牺牲深度或冗余填充**。

- 业务/反模式/SSOT 多 → 该 entry 就长（可能 300-500 行也合理）
- 元数据/数据型/工具型 entity → 该 entry 就短（30-50 行也合理）
- 拆条件**不是行数**，是**单一 entry 涵盖了多个本应独立的话题**（如方法论+流水+治理混写）
- 合并条件**不是行数**，是**多个 entry 讲同一件事的不同侧面**

### 数量

- 每 topic 建议 ≤ 8 entry（含 INDEX）— 软约束，超了不报错
- 超 15 entry 时 AskUserQuestion 复述边界（确认是否该拆 topic）

### MOC 必有（本地平铺 = `wiki/README.md`；分层 = `_INDEX.md`）

- 一句话定位
- 目录（按主题分组的 entry 列表）
- 关键速查表（2-4 表）
- 跨 topic 相关链接
- "改这里？去 SoT"指示

---

## Vault 解析（默认行为）

`/wiki` 默认 = **cwd 本地 vault**，不再探测 `.obsidian/` 父目录、不再推断各种"子 vault"。语义简洁：你在哪个项目跑 /wiki，wiki 就立在那个项目里。

| Flag | Vault 根 | 用途 |
|---|---|---|
| 无（默认） | **cwd** | 项目本地 wiki，平铺 `<cwd>/wiki/<entry>.md` |
| `--super` | **`~/Obsidian/dev-vault/`** | super vault（提炼层 / Obsidian 应用可见），分层 `topics/<topic>/<entry>.md` |
| `--vault <path>` | **`<path>`** | 任意路径（如 `~/Dev/stations/` 这种大 vault）；存在 `<path>/topics/` 则走分层，否则平铺 |

> **Obsidian 不是默认** — 是 `--super` 一种选项。

### 实例

```bash
# 默认 = 项目本地 vault（reclaim 模式）
cd ~/Dev/Work/reclaim && /wiki entry water-efficiency-method
# → 写到 ~/Dev/Work/reclaim/wiki/water-efficiency-method.md（平铺）

# super vault 立 topic（跨项目可发现）
/wiki new water-efficiency "工业园区水效评估方法论" --super
# → 写到 ~/Obsidian/dev-vault/topics/water-efficiency/

# 在 super vault 既有 topic 下加 entry
/wiki entry zdwp-water/industrial-water-efficiency-method --super
# → 写到 ~/Obsidian/dev-vault/topics/zdwp-water/industrial-water-efficiency-method.md

# 显式指任意大 vault
/wiki entry mega-navbar --vault ~/Dev/stations
# → 自动检测 vault 下 topics/ 是否存在，存在则分层，否则平铺
```

**多目的地的实务建议**：默认走本地（cwd）。需要跨项目复用 / Obsidian 应用查看 → `--super`。**不复制内容到多处** —— SoT 单一，多处 = 漂移。本地 wiki 可外链到 super vault entry，反之亦然。

---

## /wiki new

**仅 super vault / 大 vault 用** — 立新 topic 目录 + _INDEX.md + 引导多 entry 生成。本地平铺模式**无需**立 topic（直接 `/wiki entry` 就行）。

### 流程

```
0. 必须有 --super 或 --vault（本地平铺不需要 new；直接 /wiki entry）
1. 校验 topic-slug：kebab-case，不带空格
2. 检查是否已存在：`[[ -e <vault>/topics/<slug> ]]` (super) 或 `<vault>/wiki/topics/<slug>` (--vault) → 已存在则报告 + exit
3. AskUserQuestion 3 项：
   ├─ 内容源（哪些 path / repo 抽？）
   ├─ 估几个 entry（4-6 推荐，>8 必复述）
   └─ 是否跨 topic 引用（哪些 sibling topic）
4. 第一动作 mcp__auggie__codebase-retrieval（如内容源 indexable）拿主题清单
5. `mkdir -p <topic-dir>`
6. Write _INDEX.md 骨架（按下方模板）
7. 列建议的 entry 名 + 主题给用户拍板
8. 用户批准 → 进 /wiki entry 流程逐个生成
9. 完成后 → /wiki verify <slug>
```

### _INDEX.md 模板

```markdown
---
tags: [moc, <topic>]
aliases: [<topic 中文名>]
created: <YYYY-MM-DD>
---

# <topic 中文名> · MOC

> <一句话定位>。SoT 在 `<源路径>`。这里是阅读副本。

## 目录

- [[<entry-1>]] — <一句话简介>
- [[<entry-2>]] — <一句话简介>
- ...

## 关键速查（2-4 个表，按 topic 实际）

| ... | ... |
|---|---|

## 来源

| 这里的条目 | 原始 SoT |
|---|---|
| [[<entry-1>]] | `<源文件路径>` |
| ... | ... |

**改文档去 SoT，不要改这里**。

## 相关 topic

- [[../<sibling-1>/_INDEX]]
- [[../<sibling-2>/_INDEX]]
```

---

## /wiki entry

加 entry。**默认 = cwd 本地平铺**（最常用）；super/--vault 分层模式下作为既有 topic 内加 entry。

### 流程

```
0. 解析 vault root（无 flag = cwd；--super = ~/Obsidian/dev-vault；--vault <path> = <path>）
1. 模式判定：
   ├─ 本地平铺：entry path = <vault>/wiki/<slug>.md
   │            如 wiki/ 不存在 → mkdir + 顺手 write wiki/README.md (MOC 占位)
   ├─ super vault：entry path = <vault>/topics/<topic>/<slug>.md（slug 含 topic/ 前缀，如 zdwp-water/xxx）
   └─ --vault <path>：检测 <path>/topics/ 决定模式
2. 校验 entry 不存在
3. 询问内容源（如未指定）
4. 第一动作 auggie（如适用）抽核心要点
5. Write entry md（按下方模板）
6. 更新 MOC（本地 = wiki/README.md；super = topics/<topic>/_INDEX.md）目录节加新行
7. /wiki verify 自动跑（不阻塞但报告问题）
```

### Entry 模板

```markdown
---
tags: [<topic>, <subtag>]
aliases: [<别名>]
created: <YYYY-MM-DD>
---

# <entry 标题>

> <一句话定位 / 价值>

## <主体节 1>

<高密度内容，不 transcribe。提炼 + 表格 + 速查清单>

## <主体节 2>

...

## 反模式 / 常见坑（如适用）

❌ ...
❌ ...

## 相关

- [[<sibling-entry>]]
- [[../<other-topic>/<entry>]]

---

_<可选脚注：触发事件 / 历史背景 1 行>_
```

---

## /wiki verify

检查 vault wiki 完整性。无参数 = 全 vault；传 topic = 只查那个 topic。

### 检查项（5 个 · 适配两模式）

**本地平铺模式**（默认）：扫 `<cwd>/wiki/*.md`，MOC = `wiki/README.md`，无 _INDEX.md 概念
**super/--vault 分层模式**：扫 `<vault>/topics/*/*.md`，MOC = `_INDEX.md`

```bash
# 默认 = cwd 本地平铺：扫 <cwd>/wiki/*.md
# --super：扫 ~/Obsidian/dev-vault/topics/*/*.md
# --vault <path>：扫 <path>/{wiki,topics}/*/*.md（按存在性）
SCAN_PATH="${1:-$(pwd)/wiki}"

# 1. Frontmatter 缺失
echo "=== Frontmatter ==="
missing=0
for f in $SCAN_PATH/*.md $SCAN_PATH/*/*.md; do
  [ -f "$f" ] || continue
  head -1 "$f" 2>/dev/null | grep -q '^---$' || { echo "❌ $f"; missing=$((missing+1)); }
done
[ $missing -eq 0 ] && echo "✅ 全部带 frontmatter"

# 2. 行数（50-200 范围；INDEX 可放宽）
echo "=== 行数检查 ==="
for f in $SCAN_PATH/*/*.md; do
  [ -f "$f" ] || continue
  lines=$(wc -l < "$f")
  if [[ $lines -lt 30 ]]; then echo "⚠ 太短 ($lines): $f"
  elif [[ $lines -gt 200 ]]; then echo "⚠ 太长 ($lines): $f"
  fi
done

# 3. markdown link（应该是 [[wikilinks]]，不应有 [text](xx.md)）
echo "=== markdown 死链 ==="
grep -rEn '\]\([a-zA-Z0-9_-]+\.md\)' $SCAN_PATH/ 2>/dev/null \
  | grep -vE '`\[\]|不要这样|wiki 用|建议|反例' | head -10 || echo "✅ 0"

# 4. broken wikilinks（跨 topic + 同 topic）
echo "=== broken wikilinks ==="
for f in $SCAN_PATH/*/*.md; do
  [ -f "$f" ] || continue
  for link in $(grep -oE '\[\[[a-zA-Z0-9/_-]+(\|[^]]+)?\]\]' "$f" | sed 's/\[\[//; s/|.*\]\]//; s/\]\]//' | sort -u); do
    dir=$(dirname "$f")
    if [[ "$link" == ../* ]]; then
      target_dir="$dir/$(dirname $link)"
      target_name=$(basename "$link")
      if [ ! -e "$target_dir/${target_name}.md" ] && [ ! -e "$target_dir/${target_name}/_INDEX.md" ]; then
        echo "⚠ broken: [[$link]] in $f"
      fi
    elif [ ! -e "$dir/${link}.md" ]; then
      # 排除代码块内的反例（[[wikilink]] 用做示例）
      grep -q "\`\[\[${link}\]\]\`" "$f" || echo "⚠ broken: [[$link]] in $f"
    fi
  done
done | sort -u | head -10

# 5. MOC 缺失
echo "=== MOC 缺失 ==="
if [ -d "$SCAN_PATH" ] && ls $SCAN_PATH/*.md 2>/dev/null | head -1 | grep -q .; then
  # 本地平铺模式：检查 wiki/README.md
  [ ! -f "$SCAN_PATH/README.md" ] && echo "⚠ 本地 wiki 缺 README.md (MOC): $SCAN_PATH"
fi
# 分层模式：每 topic 子目录必有 _INDEX.md
for d in $SCAN_PATH/*/; do
  [ -L "${d%/}" ] && continue   # 跳过 symlink
  [ ! -f "$d/_INDEX.md" ] && echo "⚠ no _INDEX.md: $d"
done
```

输出格式：每项一行 ✅ / ⚠ / ❌。

---

## /wiki link

把项目的 `wiki/` symlink 进 vault（封装现成的 `obsidian_sync.py link`）。

### 流程

```
0. 解析 vault root（仅 super vault 场景，必须 `--super`；本地平铺无意义）
1. 校验 project-path 存在 + 有 wiki/ 子目录
2. `python3 ~/Dev/tools/dev/lib/tools/obsidian_sync.py link <project-path> --super`
3. 自动反查 topic-index.yaml 找该项目对应 topic
4. 建 symlink 到 `<vault>/wiki/topics/<topic>/<project-name>/`（提炼层 `<vault>/topics/<topic>/<project-name>/`）
5. 报告 md_files 数 + topic 归属
```

无 `wiki/` 怎么办：
- 提示用户先用 `/wiki new` 立 topic 把内容直接写进 vault
- 或在项目内先建 `wiki/` + `obsidian-wiki.md` playbook 拆了再 link

---

## /wiki rebuild

重生 `_meta/projects-index.md` + `_meta/topic-graph.md`。

```bash
python3 ~/Dev/tools/dev/lib/tools/obsidian_sync.py rebuild-index
```

什么时候用：
- `/wiki link <new-project>` 后
- `/wiki unlink <old-project>` 后（如有 unlink）
- 怀疑 _meta 漂移时

---

## 反模式（命令运行时立即纠正）

❌ topic-slug 用驼峰 / 含空格 / 含中文 → 强制 kebab-case
❌ 没 INDEX 就生 entry → /wiki entry 必须先确认 INDEX 存在
❌ 单 topic 写 15+ entry → AskUserQuestion 复述边界
❌ 把 STATUS / README 放进 wiki/ → /wiki 拒绝接受根目录 MD 入 wiki
❌ entry 用 markdown link 而非 wikilink → /wiki verify 报红
❌ 为了凑长度填充冗余 / 为了压短度漏掉必要业务深度 → 反模式（2026-05-13 立 · 用户原话「把事情说清楚就行」）

---

## 与其他 skill 的分工

| 场景 | 用谁 |
|---|---|
| 在当前项目立本地 wiki | **本 command** 默认 — `cd <project> && /wiki entry <slug>` |
| 跨项目方法论沉淀 | **本 command** `--super` — 写到 `~/Obsidian/dev-vault/topics/` |
| 大 vault（如 stations）立子 wiki | **本 command** `--vault ~/Dev/stations` |
| 拆长 reference 多条目（项目内） | 走 `~/Dev/tools/configs/playbooks/obsidian-wiki.md` 流程 |
| 整理目录文件命名 | `/tidy` |
| 写项目 README / CLAUDE / STATUS | 不走 wiki，单文件高密度 |
| 命令本身的 SSOT 治理 | `/refresh-site` `/menus-audit` |

---

## 完成定义

**本地平铺**：
- [ ] `<cwd>/wiki/<slug>.md` 写完，含 frontmatter + ≥2 个 `[[wikilinks]]`（长度服务内容，不卡区间）
- [ ] `<cwd>/wiki/README.md` MOC 存在并已加新 entry 行
- [ ] `/wiki verify` 全 ✅
- [ ] 报告：N 文件 / 总行数 / wikilinks 数

**super / --vault 分层**：
- [ ] 新 topic 目录 + `_INDEX.md` + N entry 全写完
- [ ] `/wiki verify <topic>` 全 ✅
- [ ] 报告：N 文件 / 总行数 / 跨 topic 引用清单
- [ ] 提示用户在 Obsidian 里 `Cmd+G` 看 graph view 验证
