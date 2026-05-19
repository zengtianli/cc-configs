---
description: Cloudflare 统一管理 — DNS / Origin Rules / Access Applications / Audit 对账
---

替代已归档的 `/cf-dns` `/cf-audit`。后端：`~/Dev/tools/dev/lib/tools/cf_api.py` + `cf_audit.py`，凭证自动从 `~/.personal_env` 读取。

## 用法

`/cf <subcommand> <action> [args]`

### DNS

```bash
/cf dns list [--filter NAME]
/cf dns add <subdomain>              # A 记录指向 VPS_IP，proxied
/cf dns delete <subdomain>
```

### Origin Rules（子域名 → 回源端口）

```bash
/cf origin list
/cf origin add <hostname> <port>     # e.g. stack.tianlizeng.cloud 8443
```

### Access Applications（Zero Trust）

```bash
/cf access list                      # 看所有 app 和 policy 邮箱
/cf access add <hostname>            # 自动沿用现有 app 的邮箱约定
/cf access add <hostname> --email X  # 覆盖邮箱
/cf access delete <hostname>
```

**关键保障**：`access add` 会**先 GET 现有 app 的 policy** 拿邮箱作为默认。杜绝"用错邮箱把自己锁外"的 2026-04-17 事故。

### Audit（5 源对账，替代旧 /cf-audit）

```bash
/cf audit                            # 跨 5 源只读对账
```

执行：

```bash
python3 ~/Dev/tools/dev/lib/tools/cf_audit.py
```

**报告分类**：

- `orphan-in-cf-dns` — CF DNS A 记录存在，但 services.ts 里没有（冗余 DNS）
- `missing-cf-dns` — services.ts 声明了，但没建 DNS（注册表虚假）
- `nginx-missing` — 有 DNS，VPS 却无对应 sites-enabled（可能走 CF Origin Rule → port 直连而不经 nginx）
- `nginx-orphan` — VPS nginx 有配置，但 DNS/services.ts 都没对应（遗留配置）
- `origin-rule-missing` — services.ts 有 `port`，但 Origin Rule expression 里没这个 host
- `access-declared-missing` — services.ts 标 `cf-access`，但无 Access app（应加保护）
- `access-orphan-app` — 有 Access app，但 services.ts 没标 `cf-access`（应同步声明）

**退出码**：
- `0` — 零漂移
- `1` — 有任一漂移（可用作 CI gate）

**Audit 规则**：
- 只读，无副作用
- 直接 import `cf_api._request`，避免 `origin-rules list` 的 120 字符截断
- grep 用 `-RhD read` 才能跟 symlink（sites-enabled/ → sites-available/）

下游消费：`/site rename` / `/site archive` / `/health sites` 用 `/cf audit` 输出作输入。

## 执行规则

1. 所有调用直接执行 `python3 ~/Dev/tools/dev/lib/tools/cf_api.py <args>`，把 $ARGUMENTS 原样传过去
2. 不要自己调 curl 或 urllib — 工具已覆盖
3. 凭证在 `~/.personal_env`，脚本自动 source，不问用户要

## 参考

- 已归档版：`commands/archive/cf-dns.md`
- 治理原则：新建任何 CF 配置前先 `list` 看现有 zone/origin/access 约定，避免重复创建
