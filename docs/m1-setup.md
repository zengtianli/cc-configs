# M1 机器 bootstrap — Claude Code 配置同步

把本机（主机）的 Claude Code 自定义配置在 M1 机器上一键复刻。两个 repo 已是 SSOT，clone + install 即可。

## 同步范围

| 内容 | 来源 repo | 目标 symlink |
|---|---|---|
| commands / skills / agents / hooks / harness.yaml | `cc-configs` | `~/.claude/{commands,skills,agents,hooks,harness.yaml}` |
| `CLAUDE.md` (全局铁律) / `settings.json` | `configs` 下 `_dotfiles/claude/` | `~/.claude/{CLAUDE.md,settings.json}` |
| `keybindings.json` / 其他 dotfiles | `configs` 下 `_dotfiles/` | 各自位置 |

**不同步**（机器/会话 local 的）：

- `~/.claude/{sessions,projects,history.jsonl,plans,backups,plugins,daemon*}` — CC 自身管理
- `~/.claude.json` — 会话/state 大杂烩，整文件不入 git
- `~/.augment/.auggie.json` — auggie 登录态，每台机器单独 `auggie login`
- `~/.personal_env` — API key/token，**手动从 1Password / 主机 scp**

## 步骤

### 1. clone 两个 repo

```bash
mkdir -p ~/Dev/tools
cd ~/Dev/tools
git clone git@github.com:zengtianli/cc-configs.git
git clone git@github.com:zengtianli/configs.git
```

### 2. 装 cc-configs（symlink skills/commands/agents/hooks/harness.yaml）

```bash
cd ~/Dev/tools/cc-configs
./install.sh
```

会自动把 `~/.claude/{skills,commands,agents,hooks,harness.yaml}` 指向 cc-configs/。
如果 ~/.claude/ 已有同名目录，会备份为 `.bak`。

### 3. 装 configs dotfiles（CLAUDE.md + settings.json + 其他）

```bash
cd ~/Dev/tools/configs
# 查 _dotfiles/ 下有什么 + 看是否有 install.sh / Makefile
ls _dotfiles/claude/
# 手动 symlink（暂未提供 install.sh）：
ln -sf ~/Dev/tools/configs/_dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/Dev/tools/configs/_dotfiles/claude/settings.json ~/.claude/settings.json
```

### 4. MCP / 凭证 / 第三方工具

```bash
# auggie（每台机器单独登录）
npm install -g @augmentcode/auggie  # 或 brew，看 README
auggie login

# personal_env（手动从主机 scp，或粘贴）
scp main:~/.personal_env ~/.personal_env

# ~/.claude.json 的 mcpServers section（仅 auggie，env 空）
# 让 claude 自己 /mcp add 配置，或手动编辑
```

### 5. 验证

```bash
ls -la ~/.claude/{skills,commands,agents,hooks,CLAUDE.md,settings.json}
# 应全部为 symlink → ~/Dev/tools/{cc-configs,configs}/...

# 开 claude，跑 /help，确认 skills 列表正常
claude
```

## 平时维护

- 加/改 skill / command / hook → 改 `~/Dev/tools/cc-configs/` 下 → commit + push → M1 pull
- 改 CLAUDE.md / settings.json → 改 `~/Dev/tools/configs/_dotfiles/claude/` → commit + push → M1 pull
- 主机改完别忘 `git push`；M1 用前 `git pull` 一次

## 故障

- `install.sh` 报"already linked"是正常的（幂等）
- `~/.claude/hooks.bak-YYYYMMDD` 是 install 留下的备份，确认 symlink 工作正常后可删
- auggie 在 M1 上要 `auggie login` 一次，不复用主机 session
