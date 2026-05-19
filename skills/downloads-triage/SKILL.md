---
name: downloads-triage
description: 把 ~/Downloads/ 顶层 entry 按规则派送到 ~/Dev / ~/Documents/personal-vault；规则 SSOT 在 devtools/lib/tools/downloads_triage/rules.yaml。每次扫 → unknown 提示人工 → 决策落规则 → 下次自动识别。当用户说"整理下载目录 / Downloads 太乱了 / 把下载里的东西归一下"时触发。
---

# downloads-triage · 下载目录派送

把 `~/Downloads/` 顶层 entry 自动派送到合适项目，未识别的提示人工，决策落规则供下次复用。

## 流程：scan → plan → 人工补规则 → apply

```bash
# 1. 看现状（按当前规则分类）
python3 ~/Dev/devtools/lib/tools/downloads_triage/triage.py scan

# 2. 出 plan.md（dry-run，不动）
python3 ~/Dev/devtools/lib/tools/downloads_triage/triage.py plan

# 3. 看 ⚠ 未知 entry，每个：
#    a) 用 mdls / pdftotext / Read 看内容判断主题
#    b) 在 rules.yaml entry_rules 加一条（keyword/exact/regex）
#    c) 重跑 scan 验证
#    d) 敏感证件类 target 必须在 ~/Dev 之外（git 风险）

# 4. 执行
python3 ~/Dev/devtools/lib/tools/downloads_triage/triage.py apply
```

## 规则 SSOT

`~/Dev/devtools/lib/tools/downloads_triage/rules.yaml`

四层匹配（优先级：exact > prefix > regex > keyword）：
- `skip_dirs`: 永远不动的顶层目录（用户已自分类 / 不入 Dev 类）
- `skip_ext`: 永远跳过的扩展名（.zip/.exe/.dmg/.iso/.vsix 等安装包/压缩包）
- `trash_patterns`: 见即 trash 的特征（hash 命名 png / .DS_Store / Office lock 等）
- `entry_rules`: 顶层名 → 派送目标

## 未知 entry → LLM 读内容

脚本本身**不调 LLM**。匹配不到 → 标 `⚠ 未知 — 需人工分类`，由 CC 介入：

| 文件类型 | 内容判断手段 |
|---|---|
| `*.pdf` | `pdftotext -l 1 file.pdf - \| head -c 300` |
| `*.docx` | `pandoc file.docx -t plain \| head -50` 或 `/docx read` |
| `*.xlsx` | `python3 -c "import pandas; print(pandas.read_excel('f.xlsx', nrows=5))"` |
| `*.mp4/*.wav/*.m4a` | 看文件名（无内容则 ⚠ 留 Downloads） |
| 目录 | `ls 目录/ \| head` 看文件名特征 |
| hash/uuid 命名 | 必须 pdftotext / mdls 看 metadata，不能凭文件名瞎猜 |

判断后：
1. 决定 target（参考 ~/Dev 分层：stations/labs/content/Work/personal-kb）
2. **敏感证件类目标必须 ~/Dev 之外**（git 风险）—— 默认 `~/Documents/personal-vault/`
3. 加规则到 rules.yaml entry_rules
4. 重跑 scan 验证规则命中

## ~/Dev 分层目标速查

| 内容类型 | 目标 |
|---|---|
| 水利业务（生态流量/水库/灌区/水资源公报） | `~/Dev/Work/zdwp/workspace/inbox/<date>-from-downloads/`（二次精分） |
| 公司级共享（法规/标准/参考资料） | `~/Dev/Work/resources/` |
| 生态流量项目 | `~/Dev/Work/eco-flow/` |
| 行政/财务（发票/报销/预算） | `~/Dev/content/admin/` |
| 法律/案件/保单 | `~/Dev/content/ip-legal/legal/` |
| 投资/税务（hibor/IRS/Robinhood） | `~/Dev/content/investment/` |
| 简历/求职 | `~/Dev/content/career/job-search/` |
| 学术（论文/研究） | `~/Dev/content/learn/<主题>/` |
| 舆情站 | `~/Dev/stations/web-stack/services/yuqing/data/` |
| 工具/插件源码 | `~/Dev/apps/<name>/` |
| 🔒 个人证件（身份证/房产/社保/征信/学历） | `~/Documents/personal-vault/` |

## 默认跳过原则（不议）

- `*.zip / *.exe / *.dmg / *.iso / *.pkg / *.vsix` 安装包压缩包 — `skip_ext`
- 用户自分类的大目录：`归档/` `软件安装包/` `压缩包/` — `skip_dirs`
- 培训视频集 / 通讯软件下载目录 — 视情况加 `skip_dirs`

## 反模式

- ❌ 把敏感证件 mv 到 `~/Dev/content/`（content 在 git 中，可能泄露）
- ❌ 用 LLM 逐文件分类（应该用规则；新主题加规则一次，复用 N 次）
- ❌ 直接 rm（macOS 有 Trash，永远走 `~/.Trash/`，给用户回溯权）
- ❌ 跳过 ⚠ 未知 entry 不补规则（下次重复扫）

## 维护

每次跑完 apply 后：
1. unknown 列表里的 entry 都已被人工处理 → 把决策落 rules.yaml
2. commit `devtools/lib/tools/downloads_triage/rules.yaml` 到 git（规则演进留档）

## 触发场景

用户说：
- "整理下载目录"
- "Downloads 太乱了"
- "下载里的东西归一下"
- "把 ~/Downloads 里的 X 移到 Y"
