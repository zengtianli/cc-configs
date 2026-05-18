---
name: vault-inject
description: 把富 HTML 改造为 vault citizen — 顶部 nav + 侧边 aside + 底部 backlinks + body wikilink 解析。配合本地 Quartz 服务（127.0.0.1:8080）。用户说 'vault 注入 / 双链 / HTML 加 vault nav' 触发
triggers: vault inject / 双链注入 / 富 HTML 双链 / html-vault-citizen / inject-vault-nav / 加 vault nav
---

# /vault-inject · 富 HTML → vault citizen 改造协议

**核心理念**：dispatch 出的 HTML 报告 / handoff render 出的 HTML 默认是孤岛 — 没 nav / 没 backlinks / [[wikilink]] 是纯文本。本 skill 三步流水线把它接进本地 vault（`~/Dev/wiki/`）双链网络。

**与铁律的关系**：是「零尾巴」(铁律 3) 的产物收口环节 — HTML 落盘后跑 vault-inject 才算 vault citizen，不跑就只是临时文件。

---

## 1. when to use

任一触发即用：

- dispatch HTML 报告生成后想加 vault 双链 + backlinks
- 一批已有 HTML（`~/Dev/*.html` / handoffs/*.html）集体改造
- 想验证某 HTML 是否已被 vault 索引（看注入后的 aside 是否有"反向引用"段）
- `/render-handoff` 把 .md 渲成 .html 之后

**不触发**：

- 公开分享 HTML（`/share` 推 VPS 那条线）— vault-inject 是 local-only
- 纯 markdown 工作（vault 内 .md 已经是 vault citizen，不需要注入）

---

## 2. how it works（3 步流水线）

### Step 1 — 重建 vault 索引（vault 改了才需要）

```bash
python3 ~/Dev/devtools/lib/tools/vault_index.py
```

扫 `~/Dev/wiki/` 所有 .md → 出 `~/Dev/wiki/.vault_index.json`（当前 202 entries）。包含 slug / title / path / tags / aliases，供 wikilink 解析。

### Step 2 — 重建反向链 map（新增 HTML 后需要）

```bash
python3 ~/Dev/devtools/lib/tools/backlinks_map.py
```

扫所有源（.md + .html）→ 出 `~/Dev/wiki/.backlinks_map.json`（当前 899 backlinks keys）。供注入时查"谁引用了我"。

### Step 3 — 注入单 HTML

```bash
python3 ~/Dev/devtools/lib/tools/inject_vault_nav.py /path/to/report.html
```

幂等改写 HTML：顶部 nav（vault home / search / graph 链）+ 侧边 aside（同 tag 邻居）+ 底部 backlinks（反向引用列表）+ body 内 `[[wikilink]]` 解析成 `<a href>`。原文件备份到 `.bak.pre-vault-inject`。

---

## 3. 调用模板

```bash
# 单 HTML 注入
python3 ~/Dev/devtools/lib/tools/inject_vault_nav.py /path/to/report.html

# 批量
for f in ~/Dev/*.html; do
  python3 ~/Dev/devtools/lib/tools/inject_vault_nav.py "$f"
done

# 完整三步（vault 有改动 + 新增 HTML 后）
python3 ~/Dev/devtools/lib/tools/vault_index.py
python3 ~/Dev/devtools/lib/tools/backlinks_map.py
python3 ~/Dev/devtools/lib/tools/inject_vault_nav.py <html>

# 只注入（索引没变，仅新增/修改 HTML）
python3 ~/Dev/devtools/lib/tools/inject_vault_nav.py <html>
```

---

## 4. 约束

- **自动备份**：原 HTML 写到 `<file>.bak.pre-vault-inject`，可回滚
- **幂等**：重跑同一 HTML 不重复插入 nav/aside/backlinks（检测已注入标记跳过）
- **依赖本地 Quartz**：nav 链指向 `http://127.0.0.1:8080/<slug>`；Quartz 不在跑 nav 链失效但报告主体仍可看，不阻塞
- **不进 git**：`.vault_index.json` / `.backlinks_map.json` / `.bak.pre-vault-inject` 都应 gitignore（local-only 派生物）
- **wikilink 找不到**：保留原 `[[xxx]]` 文本不报错（提示 vault 缺该 entry）

---

## 5. 与其他 skill 衔接

- **`/dispatch`** — 多 agent 跑完产出 HTML 报告 → 收尾跑 vault-inject 让所有产物 vault citizen，不再是孤岛
- **`/render-handoff`** — MD → HTML 渲染完 → 跑 vault-inject 加 nav + backlinks，handoff 点进去能跳到相关 wiki
- **`/share`** — 推 VPS public 路径，**不冲突且不应叠加** — share 出去的是 public，vault-inject 是 local-only vault 内循环
- **`/wiki`** — 改 vault 内 .md 后，下次 vault-inject 前先跑 Step 1 重建索引（不然新增的 wiki entry wikilink 解析不到）
