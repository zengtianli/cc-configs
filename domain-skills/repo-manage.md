# Repo Management SOP

When the user wants to manage, audit, screenshot, or promote GitHub repositories under ~/Dev.

## Unified Tool: `repo_manager.py`

All three workflows consolidated into `~/Dev/tools/dev/repo_manager.py` with subcommands `audit` / `screenshot` / `promote`.

```bash
alias rm='python3 ~/Dev/tools/dev/repo_manager.py'
```

### 1. audit — 项目合规性审计
Checks README structure, badges, screenshots, gitignore, dependency pinning against DocKit gold standard template.

```bash
# Audit all projects
python3 ~/Dev/tools/dev/repo_manager.py audit

# Audit specific projects
python3 ~/Dev/tools/dev/repo_manager.py audit cc-configs dockit

# Audit + auto-fix gitignore gaps
python3 ~/Dev/tools/dev/repo_manager.py audit --fix-gitignore
```

**Checks performed:**
- README.md / README_CN.md: language selector, for-the-badge badges, separator lines, screenshot reference, feature table, install/quick start sections
- .gitignore: baseline entries (__pycache__, .env, venv, IDE, build artifacts, lint cache)
- requirements.txt: all dependencies must be version-pinned (>=X.Y.Z)

### 2. screenshot — 统一截图工具
Supports Streamlit apps (Playwright URL screenshots), CLI tools (terminal output rendering), and Tauri apps.

```bash
# Screenshot a Streamlit app
python3 ~/Dev/tools/dev/repo_manager.py screenshot streamlit hydro-rainfall https://hydro-rainfall.tianlizeng.cloud

# Screenshot a CLI tool
python3 ~/Dev/tools/dev/repo_manager.py screenshot cli cc-configs "python3 tools/harness/harness.py ~/Dev/stations/dockit"

# Screenshot a Tauri desktop app
python3 ~/Dev/tools/dev/repo_manager.py screenshot tauri <repo>

# Batch all Streamlit apps
python3 ~/Dev/tools/dev/repo_manager.py screenshot batch

# Batch all (including CLI)
python3 ~/Dev/tools/dev/repo_manager.py screenshot batch --include-cli
```

**Output:** `docs/screenshots/demo.png` (1280x800) in each project directory.

### 3. promote — 批量推广
Generates bilingual READMEs, SVG demo previews, badges, and pushes to GitHub.

```bash
# Promote all registered repos
python3 ~/Dev/tools/dev/repo_manager.py promote

# Promote specific repos
python3 ~/Dev/tools/dev/repo_manager.py promote hydro-rainfall dockit
```

**Note:** This tool generates from templates, overwriting existing READMEs. Use for initial setup only.

---

## SOP: New Project Setup

When creating a new project under ~/Dev:

1. **README** — Follow DocKit template:
   - Language selector: `**English** | [中文](README_CN.md)`
   - Badges: License + Python version, `for-the-badge` style, colors: License=green, Python=yellow, Demo=blue
   - Separator `---` after badges and after screenshot
   - Feature table, Install, Quick Start sections
   - README_CN.md as full Chinese mirror

2. **Screenshot** — `python3 ~/Dev/tools/dev/repo_manager.py screenshot {streamlit|cli|tauri} <name> [...]`

3. **.gitignore** — `python3 ~/Dev/tools/dev/repo_manager.py audit --fix-gitignore <name>`

4. **Dependencies** — Pin all versions: `package>=X.Y.Z`

5. **Verify** — `python3 ~/Dev/tools/dev/repo_manager.py audit <name>`

## SOP: Periodic Audit

```bash
python3 ~/Dev/tools/dev/repo_manager.py audit
```

Fix any issues found, then re-run to confirm clean.

## Gold Standard Template Reference

The definitive example is **dockit** (`~/Dev/stations/dockit/README.md`).

Badge colors:
- Live Demo: `blue`
- License: `green`
- Python version: `yellow`

All badges use `style=for-the-badge`.
