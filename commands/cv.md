---
description: 简历工作流族 — build 渲染简历 / tailor 岗位定制 / validate 校验 / new-app 新岗位骨架 / form 应聘登记表
---

# /cv — 简历工作流统一入口

`/cv <subcommand> [args]`

| 子命令 | 干啥 | 工具 |
|---|---|---|
| `build` | 从 profile.yaml 渲染简历（md/docx/pdf） | `bin/build.py` |
| `tailor` | 读 jd.md → 生成 meta.yaml + 装配岗位定制简历 | `bin/build.py role-tailored` |
| `validate` | 校验 profile.yaml 符合 schema | `bin/validate.py` |
| `new-app` | 新建 application 标准目录骨架 | mkdir + jd.md 模板 |
| `form` | 填应聘登记表 xlsx（合并 public + private） | `bin/build-form.py` |

**项目根**：`~/Dev/content/career/job-search/resume/`
**SSOT**：`profile/profile.yaml`（公开）+ `profile/profile.private.yaml`（gitignore PII）
**模板族**：`templates/{full-cn,concise-cn,full-en,role-tailored,registration-form}.md.j2`
**Python**：`~/Dev/.venv/bin/python`（共享 venv，已含 jinja2/pyyaml/jsonschema/openpyxl/docx2pdf）

---

## build — 渲染简历

`/cv build <template> [--out md|docx|pdf|all] [-o OUT_DIR] [--meta FILE]`

### 模板名（5 个）

| 模板 | 用途 | 输出大小 |
|---|---|---|
| `full-cn` | 完整中文，对标 `曾田力CV-CN.pdf` 4 页结构 | ~16k chars / 28k bytes docx |
| `concise-cn` | 1 页精简版 | ~2k chars / 14k bytes docx |
| `full-en` | 英文完整版（用 `*_en` 字段，缺则中文 fallback） | ~14k chars / 25k bytes docx |
| `role-tailored` | 岗位定制版（按 meta.yaml 选 sections + emphasis） | ~9k chars 默认 / ~3-5k chars 定制 |
| `registration-form` | 应聘登记表 markdown 版 | ~3.7k chars |

### 例子

```bash
cd ~/Dev/content/career/job-search/resume
~/Dev/.venv/bin/python bin/build.py full-cn --out pdf -o build/
~/Dev/.venv/bin/python bin/build.py concise-cn --out docx -o build/
~/Dev/.venv/bin/python bin/build.py all --out md -o build/             # 全部 5 模板
```

### 流程

1. 读 `profile/profile.yaml`（如果是 registration-form 还读 `profile.private.yaml`）
2. 加载 `templates/<template>.md.j2`，render 出 markdown
3. `--out docx|pdf|all`：pandoc md → docx（用 `templates/reference.docx` 如有）
4. `--out pdf|all`：docx2pdf docx → pdf（用 macOS Word，需 Word 已装）
5. 输出到 `<out_dir>/<template>.{md,docx,pdf}`

---

## tailor — 岗位定制简历

`/cv tailor <application-id>`

### 流程

1. 进入 `applications/<application-id>/`
2. 读 `jd.md`（必需）+ 已有 `meta.yaml`（如有）
3. 如果没有 `meta.yaml`，CC 自己根据 jd.md 生成：
   - 提取 JD 关键词 → `emphasis_tags`
   - 选择匹配的 project id → `include_projects`
   - 决定 sections 顺序与裁剪 → `sections`
   - 写 `target_role` / `target_company` / `expected_salary`
4. 调 `bin/build.py role-tailored --meta meta.yaml --out all -o .`
5. 输出 `resume.{md,docx,pdf}` 到 application 目录

### meta.yaml 字段

```yaml
target_role: 行业解决方案经理
target_company: 久瓴科技
expected_salary: 30 万+
sections: [header, objective, education, experience, projects, papers, copyrights, honors, skills]
emphasis_tags: [数字孪生, 行业解决方案, 全栈开发]
include_projects: [zhedong-twin, oa-dashboard]   # 可选，覆盖 emphasis_tags
exclude_projects: [flood-risk-mapping]            # 可选
top_n_skills: 8                                   # 每类技能最多 N 个
custom_summary: "...一句话定位..."                  # 可选，覆盖 basics.summary
```

---

## validate — 校验

`/cv validate [<file>]`

```bash
cd ~/Dev/content/career/job-search/resume
~/Dev/.venv/bin/python bin/validate.py                      # 校验 public + private
~/Dev/.venv/bin/python bin/validate.py profile/profile.yaml # 单文件
```

### 检查项

- profile.yaml 符合 `profile.schema.yaml`（JSON Schema 2020-12）
- profile.private.yaml 符合 `profile.private.schema.yaml`
- 必填字段（basics.{name,email,phone}）齐全
- enum 字段值合法（degree / honors.level / paper.role 等）

---

## new-app — 新建 application 骨架

`/cv new-app <公司名-岗位名>`

创建标准目录：

```
applications/<公司-岗位>/
├── jd.md             # 岗位描述（CC 让用户粘贴 / 或从 URL 抓）
├── meta.yaml         # role/sections/emphasis 配置（带占位）
├── interview/        # 面试材料（编号 txt 进这里）
└── supporting/       # 公司 PDF / 资料
```

`jd.md` 模板：

```markdown
# <岗位名> - JD

> 来源：<URL 或公司名>
> 收集日期：YYYY-MM-DD

## 岗位职责
...

## 任职要求
...

## 关键词提取
...
```

`meta.yaml` 模板：

```yaml
target_role: <岗位名>
target_company: <公司名>
expected_salary: 30 万+
sections: [header, objective, education, experience, projects, papers, copyrights, honors, skills]
emphasis_tags: []     # 待 CC 从 jd.md 提取
include_projects: []  # 待 CC 选择
top_n_skills: 8
```

---

## form — 应聘登记表

`/cv form [-o OUT_DIR] [--name suffix]`

```bash
cd ~/Dev/content/career/job-search/resume
~/Dev/.venv/bin/python bin/build-form.py -o build/
# 输出：build/应聘登记表-2026-04-29-曾田力.xlsx
```

### 流程

1. 读 `profile.yaml` + `profile.private.yaml`
2. 加载 `common/应聘登记表.xlsx` 模板
3. 按 cell map 填入：
   - 个人信息（姓名/性别/年龄/出生/电话/政治面貌/身份证/户籍/现住址）
   - 学历表（最高学历优先）
   - 软著 + 专利表
   - 工作经历
   - 婚姻 / 家庭成员（父母/配偶/子女）
   - 紧急联系人
4. 输出 `应聘登记表-<日期>-<姓名>.xlsx`

---

## 改了 SSOT 后做什么

修改 `profile/profile.yaml` → 跑 build 重新生成所有产物：

```bash
cd ~/Dev/content/career/job-search/resume
~/Dev/.venv/bin/python bin/validate.py            # 必先校验
~/Dev/.venv/bin/python bin/build.py all --out pdf -o build/
~/Dev/.venv/bin/python bin/build-form.py -o build/
```

每个 application 也要重新跑 tailor（如果数据变更影响）：
```bash
for app in applications/*/; do
    [ -f "$app/meta.yaml" ] && ~/Dev/.venv/bin/python bin/build.py role-tailored \
        --meta "$app/meta.yaml" --out all -o "$app"
done
```

---

## 不做

- 不自动投递 / 不发邮件
- 不做 LLM 内容真实性 review
- 不机翻中文 → 英文（用 `*_en` 字段，缺则保留中文）
- registration-form markdown 不替代 xlsx；xlsx 是公司提交格式

---

## 相关

- SSOT: `~/Dev/content/career/job-search/resume/profile/profile.yaml`
- Schema: `~/Dev/content/career/job-search/resume/profile/profile.schema.yaml`
- 模板族: `~/Dev/content/career/job-search/resume/templates/`
- 项目说明: `~/Dev/content/career/job-search/resume/CLAUDE.md`
