---
name: hsbc-statement
description: HSBC 结单一站式分析 — INVSTM0005 (Premier 综合) / INVSTM0019 (WPL 单日) / INVSTM0021 (WPL 月结) 自动识别 + 抽取 + 写 MD + 归档 PDF + 重生 README 索引
---

# /hsbc-statement

HSBC 任意结单 PDF 一键分析。链路：

```
加密 PDF → pdf-decrypt（密码） → pdftotext → 类型识别 → 抽字段 → 写 MD → 归档 PDF → 重生 索引
```

## 用法

```bash
/hsbc-statement <pdf>...                            # 批量
/hsbc-statement <pdf>... --hibor 2.65               # 月结：HIBOR 期间均值
/hsbc-statement <pdf>... --start-date 2026-04-22    # 月结：实际借款起始日
/hsbc-statement <pdf>... --no-archive               # 不移 PDF
/hsbc-statement --regen-index --out docs/statements/  # 仅重生索引
```

## 执行

```bash
python3 ~/Archives/investment/.claude/skills/hsbc-statement/scripts/analyze.py "$@"
```

## 何时跑

- 拖来 HSBC 结单 PDF（任意类型）
- 想看时间序列对比（多日 / 多月）
- 月结来了想知道"这月利息合不合理 / spread 漂没漂"

## 产物

```
docs/statements/
├── README.md              # 时间序列索引（自动）
├── raw/                   # 加密原件（gitignore）
├── decrypted/             # 解密产物（gitignore）
├── refs/                  # KFS / Tariff / 截图
└── <YYYY-MM-DD>_hsbc-<kind>.md
```

## 相关

- `/pdf-decrypt`（解密前置，自动调）
- `docs/hsbc.md`（HSBC 账户全景）
- `docs/statements/`（结单存档）
