---
name: api-smoke
description: 本地 FastAPI 烟雾测试 — 起 uvicorn → curl /api/health+meta[+compute?format=json] → pkill。端口从 services.ts 读，踩坑（zsh noclobber / clashx / CJK）全封装。
---

一键本地 smoke test 任意 hydro-* 站的 FastAPI，不用手写 `pkill + uvicorn + curl + pkill` 四件套。

## 用法

```bash
/api-smoke hydro-capacity              # health + meta 轻量（~5s）
/api-smoke hydro-capacity --compute    # + /api/compute?format=json，用 data/sample/ 自动识别样例
/api-smoke all                         # 10 站轻量扫一轮
/api-smoke all --compute               # 10 站全端到端（慢，~2min）
```

## 执行

```bash
bash ~/Dev/tools/dev/scripts/api-smoke.sh $ARGUMENTS
```

## 脚本行为

- 从 `~/Dev/stations/website/lib/services.ts` 读 streamlit port → 推算 FastAPI port = streamlit + 100（audiobook 例外保持 9200）
- 启动：`pkill -f "uvicorn api:app.*$port"` → `rm -f /tmp/$name-api.log` → `uv run uvicorn api:app --host 127.0.0.1 --port $port >| /tmp/$name-api.log 2>&1 &`（`>|` 防 zsh noclobber）
- 等 4 秒
- `curl --noproxy '*'`（绕 clashx）依次：
  - `/api/health` 必须 `{"status":"ok"}`
  - `/api/meta` 必须有 `title` 字段（toolkit 例外用 `/api/plugins`）
- 若 `--compute`：自动在 `data/sample/` 找 xlsx/zip（大小 ≤ 20MB），POST `format=json` 验证返回含 `preview`+`results`+（`xlsxBase64` 或 `zipBase64`）
- 最后 `pkill` 清干净，任何步骤失败整体 exit 非 0 并 dump log 末尾 20 行

## 什么时候跑

- 改完 api.py 立即跑一次（替代手写 uvicorn 启停）
- 部署前最后一关
- 排查"怎么 header 是空的 / JSON 缺字段"

## 不做

- 不改 VPS 上的服务（本地起本地 uvicorn）
- 不测前端 build（那个走 `pnpm build`）
- 不跑生产环境（走 `verify.py` 或 curl 生产 URL）

## 相关

- `~/Dev/stations/web-stack/infra/deploy/verify.py` — 生产环境浏览器端验证
- `~/Dev/tools/dev/lib/hydro_api_helpers.py` — 所有 api.py 共享的 Python 工具
- `playbooks/hydro.md` — 完整编排上下文
