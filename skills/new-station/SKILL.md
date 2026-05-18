---
name: new-station
description: 一命令加新 station（站群），把现状 8 步压成 1 命令。用户说"加新站 / 新建一个工具站 / new station / 起一个 X 子域 / 加个 X-web"时触发。
---

# new-station — 站群 scaffolder 入口

把"加新 station 改 6 文件 / 8 步"折叠成一条 `new_station.py` 调用。配合现有 menus.py SSOT 链路，自动跑 4 个 regenerator + audit gate，不通过自动回滚。

---

## 触发

用户说以下任一：
- "加新 station / 加一个新站 / 起一个 X-web"
- "new station / scaffold a station"
- "起个 X 子域 / 上一个 X 工具"
- "加一个工具站到站群"

**不触发**（→ 走 `web-scaffold` playbook）：
- 静态站（非 Next.js / 非 web-stack 内）
- 外部 labs/ workspace 不进站群 monorepo

---

## 工具

```bash
python3 ~/Dev/devtools/lib/tools/new_station.py \
  --id <kebab-case>            # e.g. eco-flow, wpl-tracker
  --port <8510-8599>           # backend port; devPort 自动 = port - 5410, apiPort = port + 100
  --group <group_id>           # main | hydro-tools | applications | infra (见 entities/groups.yaml)
  --mode <subdomain|apex_subpath>  # 独立 X.tianlizeng.cloud / 还是 tianlizeng.cloud/X 子路径
  --label "<中文名>"
  --label-en "<English name>"
  --description "<一句话描述>"
  [--access cf-access|none]    # 默认 none (公开)
  [--backend none|fastapi]     # 默认 none (纯前端)
  [--service-dir <override>]   # 默认 = --id
  [--dry-run]                  # 不写文件，只打印
```

## 流程

1. **验参**：id kebab-case 不冲突 / port 8510-8599 唯一 / group ∈ groups.yaml / mode 合法
2. **写 SSOT**：append `entities/subdomains.yaml` + `relations/subdomain-group.yaml` + `navbar.yaml` 菜单项
3. **渲染前端**：`tools/configs/templates/station-app/` → `stations/web-stack/apps/<id>-web/`
4. **(可选) 渲染后端**：`--backend fastapi` → `stations/web-stack/services/<id>/`
5. **跑 4 regenerator**：
   - `menus.py build-services-ts -w`
   - `menus.py build-website-navbar -w`
   - `menus.py build-react-mega-navbar -w`
   - `menus.py audit` ← exit 0 才算成功
6. **任何步失败 → 自动回滚**（yaml 还原 + 新文件/目录删）

## 用法示例

### 1. 纯前端工具站（独立子域 + CF Access）

```bash
python3 ~/Dev/devtools/lib/tools/new_station.py \
  --id wpl-tracker --port 8525 --group applications --mode subdomain \
  --label "WPL 跟踪器" --label-en "WPL Tracker" \
  --description "WPL 余额/利息日跟踪面板" \
  --access cf-access --backend none
```

### 2. apex_subpath 子路径站（公开）

```bash
python3 ~/Dev/devtools/lib/tools/new_station.py \
  --id cost-calc --port 8526 --group applications --mode apex_subpath \
  --label "成本计算器" --label-en "Cost Calculator" \
  --description "项目成本快算工具"
```

URL = `https://tianlizeng.cloud/cost-calc`

### 3. 带 FastAPI 后端

```bash
python3 ~/Dev/devtools/lib/tools/new_station.py \
  --id eco-flow --port 8527 --group hydro-tools --mode apex_subpath \
  --label "生态流量评估" --label-en "Eco-Flow Assessment" \
  --description "河流生态流量评估与保障率计算" \
  --backend fastapi
```

会同时生成 `services/eco-flow/api.py` + `services/eco-flow/pyproject.toml`。

---

## 验收（done 标准）

- [ ] `menus.py audit` 退出 0（含 17 类 strict + paths-drift）
- [ ] `cd stations/web-stack/apps/<id>-web && pnpm install && pnpm dev` 起得来
- [ ] 浏览器 http://localhost:<devPort> 看到骨架页（含 `{{label}}` 标题）

如 audit 失败：scaffolder 已自动回滚 yaml。手工检查 `git status -- stations/web-stack/apps/<id>-web/` 残留可删。

## 兜底（scaffolder 异常时）

如 scaffolder 本身 bug，回退到手工 8 步 SOP：见 `~/Dev/tools/configs/playbooks/station-add-via-scaffold.md` § 兜底。
