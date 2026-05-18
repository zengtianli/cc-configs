---
name: render-handoff
description: 把 HTML 报告里所有 .md href 批量渲染为同目录 .html（GitHub dark + 中文 + wikilinks 解析），本地 file:// 用不发 VPS。用户说 "render md / md 渲染 / 点进去看 / 链接没渲染 / md 转 html" 触发。
triggers: render-md / 渲染 md / md 转 html / 链接没渲染 / 浏览器看 md / batch render
---

# /render-handoff · HTML 报告内 .md 批量本地渲染

**核心理念**：dispatch / wrap / handoff 类 HTML 报告里大量 `<a href="file://*.md">` 入口，点进去是浏览器渲染的 raw markdown，难看且 wikilinks 不解析。本 skill 一键扫 + 批量渲染 + 同目录落 .html + 父 HTML href 重写。

**与 [[/share]] 区别**：

| 维度 | `/share` | `/render-handoff`（本 skill） |
|---|---|---|
| 目标 | 发别人看 | 自己浏览器看 |
| 输出 | `tianlizeng.cloud/share/<slug>.html`（VPS） | 同目录 `<name>.html`（本地 file://） |
| 输入 | 单个 .md | 一个 HTML 报告（含 N 个 .md href）批量 |
| 副作用 | rsync + systemctl restart | 0 网络 |
| CSS | `share-style.html`（亮色友好） | `dark-theme.css`（与 dispatch HTML 同色板） |

---

## 1. when to use

- dispatch HTML 报告 / wrap retro / handoff index 产出后，里面 .md 链接想点进去本地看
- 单独要把一批 handoff/memory/wiki .md 转 HTML 给浏览器开
- 私域内容（memory / handoff / 中间产物）不要发 VPS

**不触发**：

- 发别人看 → 走 `/share`
- 单文件 ad-hoc 看 → 用 Read 工具 / `glow` / `bat` 即可
- HTML 报告里没 .md href → 没活干

---

## 2. how it works（4 步）

### Step 1 — 扫输入 HTML

提取所有 `<a href="file://*.md">` 的 .md 绝对路径列表（去重 + 过滤不存在的）。

### Step 2 — 批量 pandoc 渲染

对每个 .md：

```bash
pandoc <md> -f markdown -t html5 \
  --standalone --metadata title="<filename>" \
  -H ~/.claude/skills/render-handoff/templates/dark-theme.css \
  -o <md>.html  # 同目录同名
```

`templates/render.py` 已封装。

### Step 3 — wikilinks 解析（可选）

`[[topic-name]]` 风格 wikilink → 在同目录 / 兄弟目录 grep 找对应 .md，重写为 `<a href="...html">`。找不到的留 raw，不报错。

### Step 4 — 父 HTML href 重写

把输入 HTML 里所有 `file://<md>` → `file://<html>`，原地写回。完成 = 浏览器刷新就能点进去。

---

## 3. md-to-html 模板

`templates/render.py` 单文件 stdlib + pandoc subprocess。完整支持：

- frontmatter 提取 → 顶部卡（title / date / tags）
- `[[wikilinks]]` regex 解析 → 本地 .html 跳转
- CSS via `-H` include-in-header
- pandoc 失败时 print warn 但不中断（其他文件继续）

调用：

```bash
python3 ~/.claude/skills/render-handoff/templates/render.py <html-file>
```

或本 skill 直接执行（默认行为）。

---

## 4. href-rewrite 模板

最简版用字符串 replace（不靠 BS4，0 依赖）：

```python
text = html_path.read_text()
for md_abs, html_abs in mapping.items():
    text = text.replace(f"file://{md_abs}", f"file://{html_abs}")
html_path.write_text(text)
```

只重写**渲染成功**的 .md（mapping 里只放成功项）。失败 / 不存在的 .md 保持原 href，浏览器仍按原样打开。

---

## 反模式

- 把 .md 推到 VPS 当 share → 不是本 skill 目标，走 `/share`
- 重写 href 前不验证 .html 已生成 → 写出指向不存在文件的 href
- pandoc 失败整批中断 → 必须 per-file try / except，单个失败不影响其他
- CSS 用网络 CDN → 必须内联（用户可能在飞机上无网）
- 假设 .md 都在 git repo → 本 skill 接受任意绝对路径（memory / wiki / Downloads 均可）

---

## 关联

- [[user-facing-output-is-html]] — 用户对话窗口里要 HTML 不要 markdown 入口
- [[html-must-drill-down]] — clickable 入口必须真能点进去看到渲染好的页面
- [[/share]] — 发别人看的姊妹 skill（VPS 路径）
- [[/dispatch]] — 本 skill 经常配合 dispatch HTML 报告使用
