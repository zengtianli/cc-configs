---
description: 在任意目录生成「域 → 包 → 脚本」模块地图。扫直属子目录的 catalog.yaml（每个=一个域）→ 缺的派 agent team 补齐 → 确定性引擎渲染 HTML 拓扑 + 依赖图 + 平台总部↔子公司视图 + distill 上提候选。catalog 是 SSOT，地图从它派生。
---

# /module-map — 一句话看清一个工作区的模块拓扑

进任意一级 workspace / 项目目录跑这一句，得到一张 **域 → 包 → 脚本 + 依赖关系** 的 HTML 地图。每个直属子目录的 `catalog.yaml` 是 SSOT（机读三字段），缺的当场补齐，地图由确定性引擎从 catalog 派生 —— 不手搓 HTML、不编造内容。

```
/module-map              # 默认：目标 = cwd
/module-map ~/Apps       # 指定目录
/module-map ~/Dev/tools  # 任意一级 workspace
```

`$ARGUMENTS` 即目标目录（缺省 = cwd）。

---

## 它做什么（5 步）

### 1. 确定目标 + dry 扫描
`$ARGUMENTS` 解析为绝对路径目标 `<dir>`（默认 cwd）。先跑渲染引擎做 dry 扫描，看哪些直属子目录（像包/app：含 `.py` / `.sh` / `pyproject.toml` 等代码痕迹）**缺 `catalog.yaml`**：

```bash
python3 ~/Dev/tools/dev/lib/tools/report/catalog_module_map.py <dir>
```

缺 catalog 时引擎 **退出码 2** + stderr 列出缺失目录清单。把这份清单作为第 2 步的派单输入。

### 2. 补齐缺失的 catalog（缺则生成）
对每个缺 `catalog.yaml` 的包/app，**派并行 agent team**（铁律 #16 · 一次性 fan-out 不分波）：每个 agent 认领一个包 →

- 读该包真实代码（入口 / 模块 / import 关系），**不占位、不编造**；
- 写出包根的 `catalog.yaml`，根级三字段 `summary` / `key_scripts` / `depends_on`，多模块时用 `packages:` 分包声明（每包同样三字段）；
- catalog 是 **机读 SSOT**，三字段必须齐全，缺一不可。

已有 `catalog.yaml` 的目录 **跳过**（不重写已落地，铁律 #16）。

> agent prompt 必含：「读真实代码写 catalog.yaml，三字段齐全不占位；不准 commit；不开浏览器」。

### 3. 渲染
catalog 补齐后，确定性引擎渲染 + 打开：

```bash
python3 ~/Dev/tools/dev/lib/tools/report/catalog_module_map.py <dir> --open
```

产物：`~/Dev/wiki/handoffs/dev/<basename>-module-map.html`（`<basename>` = 目标目录名，如 `apps-module-map.html`）。`--open` 渲染完自动打开浏览器。需自定义输出路径用 `-o OUT`。

### 4. 验收（铁律 #11 · 不复述 agent）
主会话 **自己** 确认，不复述 subagent 报告：

- HTML 文件确实落地（`ls -la` 看 size > 0）；
- 可解析（grep 关键节点 / 简单 parse 不报错）；
- **SVG 依赖图节点数 = 包数**（域 × 包对账，节点对不上说明 catalog 漏声明）。

打印一行收尾：

```
module-map: N 域 / M 包 / K 脚本 · file://.../<basename>-module-map.html
```

### 5. distill 复盘（看「⬆ distill 候选」面板）
引擎渲染的 **⬆ distill 候选** 小节列出"值得上提到总部 ~/Dev 的包/脚本"——判据：纯 pypi/stdlib 自洽、无总部依赖、无本工作区专属数据、或含通用基建语义（client/util/render/parse…）。逐条**人工判断**：
- 确属通用能力 → **distill 到 `~/Dev/tools` 对应域**（成为总部共享服务），子公司改为绝对路径调用；**同步更新 `~/Dev/SSOT-INDEX.md` + 相关 catalog**。
- 仅本业务专用 → 留在子公司，标记排除。
> distill 是判断不是自动搬迁；候选面板给信号，落地要走「上提总部 + 更新 SSOT + 子公司改调用」三步，且总部不得反依赖子公司（见下「平台模型」不变量）。

### 6. 零尾巴（铁律 #3 + #4）
- 缺的 catalog **全部补齐**，不留 TODO、不留「下轮处理」；
- catalog 是新建文件 → 按铁律 #4 **自动** `git status → diff → commit → push` 所在 repo（不问）；该 repo 无远端 → 自动建私库再推。

---

## 平台总部 ↔ 子公司模型（引擎内置）

引擎把工作区读成**集团组织架构**（hub-and-spoke），渲染「🏛 平台总部 ↔ 子公司」面板：

- **总部 HQ / Shared Kernel** = `~/Dev/tools`，持 8 项共享服务（llm_client / paths SSOT / menus SSOT / cf_api / deploy 家族 / doctools / kb / CC skills·hooks·playbooks）。
- **子公司 spoke** = `~/Apps`（个人 app）/ `~/Work`（客户业务）/ `~/Archives`（归档），各自独立、**只按绝对路径消费总部能力**。
- **核心不变量（唯一）**：依赖永远向上 —— ✅ 子→总（绝对路径 import 总部共享件）；❌ 总→子（总部绝不反依赖业务）；❌ 子↔子（要共享就上提总部，不横向耦合）。
- 引擎据此：把 `depends_on` 指向 `~/Dev/...` 的标为 **🏛 调用总部**（金色 HQ 节点 + 子→总向上边）；侦测到 **子↔子 / 反向**依赖画**红色违规边**；聚合「本工作区消费了哪些总部服务」表 + 登记处提示（`~/Dev/SSOT-INDEX.md` / `paths.yaml`）。
- **每张包卡片必显「连接行」**（2026-05-22 强化）：醒目标出 **🏛 引用总部: <服务名>**（金色,最显眼,纯客户/无依赖项目显示「引用总部: —」）/ **🔗 内部** / **📦 外部 N** / **⚠ 造轮子** / **🔼 可上提总部**——让人看**单个项目**就一眼清楚它消费总部什么、有无造轮子、能否上提，不必翻聚合表。裸服务短名(llm_client/doctools/hydro-qgis…)经 `HQ_TOKEN_MAP` 识别为 🏛HQ。**Why**：用户「你没说引用总部什么……我的主要目的是逼避免造轮子+distill 上提」「这样我看项目就清晰」。

**第一性原则**：子公司**尽可能调用总部脚本库**（不重造轮子）；子公司若沉淀出好的脚本/包/域 → **distill 上提到总部 + 更新 SSOT**（见第 5 步）。模型详解见 `~/Dev/wiki/handoffs/dev/platform-subsidiary-model.html`。

---

## 复用场景

- 进任意一级 workspace（`~/Dev` / `~/Apps` / `~/Dev/tools` …）或单个项目目录，想快速看清 **域 → 包 → 脚本** 拓扑 + 包间依赖图；
- 接手陌生 / 久未动的工作区，先出地图再决定从哪入手；
- **与入场协议联动**：全局 CLAUDE.md 已锁「进 `~/Dev` / `~/Apps` 一级目录必查 module-map」。`/start` Phase 1 的「module-map 检查」发现 **缺 catalog / map 过期** 时，直接 `/module-map <dir>` 当场补齐 + 刷新。

---

## catalog.yaml 是 SSOT

地图 **从 catalog 派生**，不是反过来。改 catalog 即改图 —— 想更新某个域的描述 / 依赖，改它的 `catalog.yaml` 重跑引擎即可，不手改 HTML。

schema（根级 + 每个 `packages` 条目同构）：

```yaml
summary:      # 这个域/包是干啥的（一两句，机读）
key_scripts:  # 关键脚本/入口清单（路径 + 一句话用途）
depends_on:   # 依赖的其它域/包（画依赖图用）
packages:     # （可选）多模块时分包声明，每包同样这三字段
  <pkg-name>:
    summary: ...
    key_scripts: ...
    depends_on: ...
```

直属子目录里每个 **含 `catalog.yaml` 的目录 = 一个域**；`packages` 下每条 = 一个包。三字段必须齐全机读，引擎才能正确渲染拓扑与依赖边。

---

## 不做

- **不手搓 HTML** — 一律走确定性引擎 `catalog_module_map.py`，不在主会话 / agent 里拼 HTML 字符串；
- **不编造 catalog** — 三字段必须读真实代码得出，禁止占位 / 想当然；
- **不留缺失 catalog** — dry 扫描列出的缺失项必须本轮全部补齐，不允许「先渲染已有的，剩下下次补」；
- **子公司不重造总部已有能力** — 子公司能调总部共享服务（llm_client/paths/kb…）的就绝对路径调用，不 vendor 一份；好脚本沉淀了就 distill 上提总部 + 更新 SSOT，不让能力散在各子公司（违反 hub-spoke 不变量）。

---

## 相关

- `module_map_render.py`（`~/Dev/tools/dev/lib/tools/report/`）— `~/Dev` 专属老渲染器，已被通用引擎 `catalog_module_map.py` 取代（通用引擎任意目录可跑）；
- **入场协议「module-map 检查」** — 全局 CLAUDE.md：进 `~/Dev` / `~/Apps` 一级目录必查 map，缺/过期当场补；
- `/start` — 入场命令，Phase 1 warmup 含 module-map 检查，发现缺口转本命令补齐。
