---
name: share
description: 把 markdown 文件渲染成 HTML 发布到 tianlizeng.cloud/share/<slug>.html，给人分享链接用。pandoc 渲染（含中文友好 CSS）→ 推 VPS public/share/ → restart website → 验 HTTP 200 → 打印 URL。
---

把任意 .md 一键发布到自己域名下，拿一条 https 链接发给别人看。

## 用法

```bash
/share <md-path>                              # slug = 文件 basename
/share <md-path> <slug>                       # 指定 slug
/share <md-path> <slug> --title "自定义标题"  # 指定 <title>（默认取首行 # H1）
```

例子：
```bash
/share ~/Dev/content/ip-legal/legal/yanyuan/broker-defense-v1-legal-opinion.md
# → https://tianlizeng.cloud/share/broker-defense-v1-legal-opinion.html

/share ~/Dev/.../analysis.md yanyuan-analysis --title "燕园暴雷分析"
# → https://tianlizeng.cloud/share/yanyuan-analysis.html
```

## 执行

```bash
bash ~/Dev/devtools/scripts/tools/share_md.sh $ARGUMENTS
```

## 脚本行为

- pandoc 渲染（`--standalone` + `--include-in-header=~/Dev/devtools/lib/templates/share-style.html`，自带中文 + 暗色模式 CSS）
- 落本地 `~/Dev/stations/website/public/share/<slug>.html`（同时被下次 `pnpm build` 带上，不会丢）
- rsync 单文件到 `$VPS:/opt/website/public/share/`
- `systemctl restart website` 让 Next.js 看到新静态文件（不重启会 404）
- `curl --noproxy '*'` 验 200，不 200 报错退出

## 注意

- slug 自动小写化 + 非 `[a-z0-9_-]` 替成 `-`
- 同 slug 重复发布 = 覆盖更新（pandoc 重渲，rsync 覆盖）
- 默认是公开 URL（无 CF Access），不要发敏感原件 — 发草稿/对外稿前自己脱敏
- 改 CSS 改 `~/Dev/devtools/lib/templates/share-style.html`，下次 share 自动生效
