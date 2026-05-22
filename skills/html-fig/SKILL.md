---
name: html-fig
description: 作图默认方法 — 自包含 HTML/SVG 所见即所得预览（多样式）→ 用户批准 → 导出 SVG+PNG+PDF 多格式 + 带下载/复制按钮的 HTML。任何"作图/可视化/改样式/好看点/热图/出图/preview"触发；尤其投稿级、需反复调样式、用户给旧图截图要复刻的场景。
triggers: /html-fig / 作图 / 出图 / 画图 / 可视化 / 改样式 / 好看点 / 热图 heatmap / 配色 / preview 预览 / 导出图片 / 所见即所得 / matplotlib 太丑
---

# /html-fig · HTML/SVG 所见即所得作图法

**核心理念（铁律 #21）**：作图默认走这套，不默认手搓 matplotlib 反复跑。
**所见即所得**：HTML 渲染 SVG，调样式即时可见、可多变体并排比；用户拍板后再导出实际文件。
**必导出多格式**：SVG（矢量·投稿）+ PNG（高清·粘贴）+ PDF，落交付目录；HTML 带下载+复制按钮。
**不止屏幕展示**：渲染完必落文件，"多导出"是默认，不是等用户问"你导出什么了"。

---

## 5 步流程

1. **取数据**（铁律 #20：先用现成）。从现成生成器/CSV/SSOT 拿数据 + 顺序 + 分组，dump 成 JSON。不重造数据管线。
2. **HTML 多样式预览**。自包含 HTML（自带配色插值，**无 CDN**），同一份数据并排渲染 N 种样式变体（配色/版面/标注/分组序）。`open` 给用户。每变体配一句审美说明 + 推荐项。
3. **用户批准**（铁律 #8/#21）。用户选编号 / 提修改（"B 的配色 + E 的下三角"）。改样式 = 改 HTML 参数，即时重渲染再确认。**未批准不落地。**
4. **导出多格式**。Python 生成最终 SVG（移植预览 render 逻辑）→ `rsvg-convert -z 3 x.svg -o x.png`（高清 PNG）+ `rsvg-convert -f pdf x.svg -o x.pdf`（矢量 PDF）。多尺度/多图全导。
5. **可复制 HTML**。出一页内嵌成品图 + 每图 **下载 SVG / 下载 PNG / 复制图片** 按钮（`XMLSerializer` + canvas `toBlob` + `navigator.clipboard.write`）。用户可直接粘进 Word/PPT。

## 复用库 `lib/htmlfig.py`

```python
import sys; sys.path.insert(0, '<this skill>/lib')
from htmlfig import RAMPS, mako, ramp, textcolor, export_svg, download_page
# RAMPS: 预置 mako / rdylbu_r / rdbu_r / mako_r / sunset 等(自带插值,无 seaborn 依赖)
# export_svg(svg_str, '/path/out/fig_3m')  -> 写 .svg + rsvg-convert .png/.pdf, 返回三路径
# download_page({'3m':svg3,'6m':svg6,...}, '/path/out/figs.html', title=...) -> 下载/复制 HTML
```

## 为什么不用 matplotlib（默认）
- 调样式慢：每次改要重跑脚本看 PNG；HTML 即时可见、可并排比变体。
- 某些版面 matplotlib 做不到：如 `sns.heatmap` 无法在分组间留间隙（"色块盖掉"），SVG 一行搞定。
- 投稿要矢量：SVG 原生矢量，`rsvg-convert` 直转 PDF，字体可编辑（`svg.fonttype=none`）。
- **例外**：已有现成 matplotlib 生成器且能产出目标样式 → 走铁律 #20 改它的 config，别为用 HTML 而推翻现成代码。

## 反模式
- HTML 渲染完只截图/只展示，不导文件（违 #21）。
- 只出单一格式 / 等用户追问才补导。
- 用户给旧图截图，照像素手搓复刻，而不先找产它的代码（违 #20）。
- 预览用了 CDN（断网即废）—— 配色/渲染必自包含。
- 未经批准直接落地最终样式（违 #8）。

## 实战参考
zdys 降雨论文相关热图 F1：`deliverables/学术/期刊论文/data_process/fig_correlation_23-25.py`
（Python 生 SVG → rsvg-convert 多格式 → `correlation_heatmaps_F1.html` 下载/复制）。
