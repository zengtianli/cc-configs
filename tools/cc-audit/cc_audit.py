#!/usr/bin/env python3
"""cc_audit.py — CC 项目配置文档漂移检测器（read-only）。

检测 CC 项目的 CLAUDE.md / HANDOFF.md / MEMORY.md / README.md / paths registry /
harness.yaml 与 repo 实际状态之间的漂移。供 `/sync-cc` slash command 调用，
本身只产出 findings — 不做任何修复（修复由 command MD 编排 CC 完成）。

用法：
    python3 cc_audit.py                          # cwd 默认，文本表格
    python3 cc_audit.py --cwd ~/Dev/X            # 显式指定项目
    python3 cc_audit.py --json                   # JSON 输出
    python3 cc_audit.py --only CLAUDE.md HANDOFF.md   # 只跑某些维度
    python3 cc_audit.py --brief                  # 一行总结（severity 计数）

Detector 维度（key）：
    claude_md         — CLAUDE.md 文档结构 vs 实际目录漂移
    handoff_md        — HANDOFF.md 待办（git log 命中可能已 done）
    memory_md         — ~/.claude/projects/<encoded>/memory/MEMORY.md 引用死链
    readme_md         — README.md 内部 markdown 链接死链
    paths_registry    — ~/Dev/paths.yaml 注册表死链 (paths.py audit --brief)
    harness_yaml      — ~/Dev/tools/cc-configs/harness.yaml 注册检查

stdlib only（绝不 import yaml / 任何 pip 包）。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Iterable

# ── 配置 ──────────────────────────────────────────────

HOME = Path.home()
DEV_ROOT = HOME / "Dev"
HARNESS_YAML = DEV_ROOT / "tools" / "cc-configs" / "harness.yaml"
PATHS_PY = DEV_ROOT / "devtools" / "lib" / "tools" / "paths.py"

DIMENSIONS = (
    "claude_md",
    "handoff_md",
    "memory_md",
    "readme_md",
    "paths_registry",
    "harness_yaml",
)

# CLI key → dimension 别名映射（让 --only CLAUDE.md / claude_md 都 work）
DIMENSION_ALIASES = {
    "CLAUDE.md": "claude_md",
    "HANDOFF.md": "handoff_md",
    "MEMORY.md": "memory_md",
    "README.md": "readme_md",
    "paths": "paths_registry",
    "harness": "harness_yaml",
}

# severity 排序权重（用于汇总 / 高亮）
SEVERITY_RANK = {"info": 0, "warn": 1, "error": 2}

# ── Finding ───────────────────────────────────────────


@dataclass
class Finding:
    dimension: str
    severity: str  # info | warn | error
    title: str
    detail: str = ""
    suggestion: str = ""
    auto_fixable: bool = False

    def to_dict(self) -> dict:
        return asdict(self)


# ── Helpers ───────────────────────────────────────────


def _git_log_since(cwd: Path, since_epoch: float, limit: int = 50) -> list[str]:
    """git log subject 列表，since=<epoch> 之后；非 git repo / 出错返回 []."""
    try:
        result = subprocess.run(
            [
                "git",
                "-C",
                str(cwd),
                "log",
                f"--since=@{int(since_epoch)}",
                "--pretty=format:%s",
                f"-n{limit}",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            return []
        return [l.strip() for l in result.stdout.splitlines() if l.strip()]
    except Exception:
        return []


def _encoded_cwd(cwd: Path) -> str:
    """~/.claude/projects/ 编码：把绝对路径 / 替换为 -."""
    abs_path = str(cwd.resolve())
    return abs_path.replace("/", "-")


# ── Detector 1: CLAUDE.md ─────────────────────────────


_DOC_STRUCT_HEADERS = (
    "## 文档结构",
    "## 项目结构",
    "## Project Structure",
    "## 仓库结构",
    "## Repository Structure",
    "## 目录结构",
    "## Directory Structure",
)


def _extract_doc_struct_paths(md_text: str) -> set[str]:
    """从 ## 文档结构 / ## 项目结构 节抽取出现的 'foo/' 顶层目录路径。

    支持 3 种行模式：
      - **foo/** — desc
      - `foo/`
      - | foo/ | desc |    （表格首列）
    """
    lines = md_text.splitlines()
    # 找第一个匹配的节标题
    start = None
    for i, line in enumerate(lines):
        for hdr in _DOC_STRUCT_HEADERS:
            if line.strip().startswith(hdr):
                start = i + 1
                break
        if start is not None:
            break
    if start is None:
        return set()

    # 节内容：到下一个 ## 或 EOF
    end = len(lines)
    for j in range(start, len(lines)):
        if lines[j].lstrip().startswith("## "):
            end = j
            break
    section = "\n".join(lines[start:end])

    paths: set[str] = set()
    # 模式 1: **xxx/** 或 **xxx/yyy/**（bold 包围目录路径）— 取第一段顶级目录
    for m in re.finditer(r"\*\*([\w\-./]+/)\*\*", section):
        top = m.group(1).split("/", 1)[0]
        if top:
            paths.add(top)
    # 模式 2: 行首加粗 list  - **xxx/**
    for m in re.finditer(r"^\s*[-*]\s*\*\*([\w\-/]+/?)\*\*", section, re.MULTILINE):
        top = m.group(1).strip("/").split("/", 1)[0]
        if top:
            paths.add(top)
    # 模式 3: backtick `xxx/` 或 `xxx/yyy/`
    for m in re.finditer(r"`([\w\-./]+/)`", section):
        top = m.group(1).split("/", 1)[0]
        if top:
            paths.add(top)
    # 模式 4: 表格首列含 / 的格子（`xxx/` 或 xxx/yyy）
    for line in section.splitlines():
        if line.startswith("|") and "/" in line:
            cells = [c.strip().strip("*").strip("`") for c in line.split("|")[1:-1]]
            if cells:
                first = cells[0]
                m = re.match(r"^([\w\-]+)(?:/[\w\-./]*)?/?$", first)
                if m:
                    paths.add(m.group(1))
    # 排除 ".xxx" / 显式文件名（含 .md 等扩展）
    return {
        p for p in paths
        if p and not p.startswith(".") and "." not in p
    }


def detect_claude_md(cwd: Path) -> list[Finding]:
    findings: list[Finding] = []
    md = cwd / "CLAUDE.md"
    if not md.exists():
        findings.append(
            Finding(
                "claude_md",
                "warn",
                "未找到 CLAUDE.md",
                detail=f"path: {md}",
                suggestion="如项目需要 CC 上下文，建议建一份基础 CLAUDE.md",
            )
        )
        return findings

    text = md.read_text(encoding="utf-8", errors="replace")
    listed = _extract_doc_struct_paths(text)
    if not listed:
        findings.append(
            Finding(
                "claude_md",
                "info",
                "CLAUDE.md 未找到 ## 文档结构 / ## 项目结构 节",
                detail="跳过目录漂移检查（也可能是单文件项目）",
                suggestion="若项目有多目录，建议加 ## 文档结构 节列出顶层结构",
            )
        )
        return findings

    # 实际顶层目录（排除隐藏 / archive / build artifacts）
    SKIP = {".git", ".venv", "venv", "node_modules", "__pycache__", ".pytest_cache",
            ".idea", ".vscode", ".DS_Store", "dist", "build", ".next", "out",
            ".turbo", ".cache", ".mypy_cache", ".ruff_cache"}
    actual_dirs: set[str] = set()
    for entry in cwd.iterdir():
        if entry.is_dir() and entry.name not in SKIP and not entry.name.startswith("."):
            actual_dirs.add(entry.name)

    missing_in_md = sorted(actual_dirs - listed)
    stale_in_md = sorted(listed - actual_dirs)

    # 拿 mtime 之后的 commit 做参考（CC 看了能知道哪些 commit 引入了新目录）
    recent_commits: list[str] = []
    if missing_in_md or stale_in_md:
        try:
            recent_commits = _git_log_since(cwd, md.stat().st_mtime, limit=20)
        except Exception:
            pass

    if missing_in_md:
        findings.append(
            Finding(
                "claude_md",
                "warn",
                f"目录存在但 CLAUDE.md 未列：{', '.join(missing_in_md)}",
                detail="自 CLAUDE.md mtime 后的 commit:\n  - "
                + "\n  - ".join(recent_commits[:10])
                if recent_commits
                else "（无 git log 可参考）",
                suggestion=f"在 ## 文档结构 节添加这些目录：{missing_in_md}",
            )
        )

    if stale_in_md:
        findings.append(
            Finding(
                "claude_md",
                "error",
                f"CLAUDE.md 列了但实际不存在：{', '.join(stale_in_md)}",
                detail="可能是已删除 / 重命名 / 归档的目录",
                suggestion=f"从 ## 文档结构 节删除这些目录：{stale_in_md}",
            )
        )

    if not findings:
        findings.append(
            Finding(
                "claude_md",
                "info",
                "CLAUDE.md 文档结构与实际目录一致",
                detail=f"listed: {sorted(listed)} | actual: {sorted(actual_dirs)}",
            )
        )

    return findings


# ── Detector 2: HANDOFF.md ────────────────────────────


_STOP_WORDS = {
    "的", "了", "和", "或", "在", "是", "有", "无", "把", "被", "对", "从", "到",
    "this", "that", "the", "and", "or", "of", "to", "for", "with", "in", "on",
    "do", "does", "make", "做", "把", "需要", "需", "要", "请", "请求", "暂",
    "完成", "处理", "ok", "done", "todo", "task", "issue", "fix", "bug", "add",
    "update", "改", "加", "删", "用", "等", "把",
}


def _extract_keywords(line: str) -> list[str]:
    """从一行待办文本里抽 keyword（去停用词后的有效 token）"""
    # 去 markdown checkbox / 优先级 marker
    cleaned = re.sub(r"^\s*[-*]\s*\[\s*[\sxX]?\s*\]\s*", "", line)
    cleaned = re.sub(r"\*\*\[?[A-Z\d.-]+\]?\*\*", "", cleaned)  # 去 **[P0]** 类
    cleaned = re.sub(r"`([^`]+)`", r" \1 ", cleaned)
    # 抽英文 word + 中文短语（连续中文片段 ≥ 2 chars）
    tokens: list[str] = []
    for m in re.finditer(r"[A-Za-z][A-Za-z0-9_-]{2,}|[\u4e00-\u9fff]{2,}", cleaned):
        t = m.group(0).lower() if m.group(0).isascii() else m.group(0)
        if t in _STOP_WORDS:
            continue
        if len(t) < 2:
            continue
        tokens.append(t)
    return list(dict.fromkeys(tokens))[:5]  # 去重，截前 5


def _find_handoff(cwd: Path) -> Path | None:
    """选 cwd 下最新的 HANDOFF / HANDOFF-*.md"""
    cands: list[Path] = []
    for p in cwd.glob("HANDOFF*.md"):
        if p.is_file():
            cands.append(p)
    if not cands:
        return None
    cands.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return cands[0]


def detect_handoff_md(cwd: Path) -> list[Finding]:
    findings: list[Finding] = []
    handoff = _find_handoff(cwd)
    if handoff is None:
        findings.append(
            Finding(
                "handoff_md",
                "info",
                "未找到 HANDOFF*.md",
                suggestion="（无须处理）",
            )
        )
        return findings

    text = handoff.read_text(encoding="utf-8", errors="replace")
    todos: list[tuple[int, str]] = []  # (lineno, text)
    for i, line in enumerate(text.splitlines(), start=1):
        if re.match(r"^\s*[-*]\s*\[\s*\]", line):  # 未完成
            todos.append((i, line.rstrip()))

    if not todos:
        findings.append(
            Finding(
                "handoff_md",
                "info",
                f"{handoff.name} 无未完成待办",
                suggestion="（无须处理）",
            )
        )
        return findings

    # 拿 HANDOFF mtime 之后的 commit
    commits = _git_log_since(cwd, handoff.stat().st_mtime, limit=80)
    commits_lower = [c.lower() for c in commits]

    hits: list[tuple[int, str, list[str], str]] = []  # (lineno, todo, kws, matched_commit)
    for lineno, todo in todos:
        kws = _extract_keywords(todo)
        if not kws:
            continue
        for kw in kws:
            kw_lc = kw.lower() if kw.isascii() else kw
            for orig, lc in zip(commits, commits_lower):
                if kw_lc in lc:
                    hits.append((lineno, todo.strip(), kws, orig))
                    break
            else:
                continue
            break  # 一个 todo 命中一次就够

    if hits:
        detail_lines = []
        for lineno, todo, kws, commit in hits[:10]:
            detail_lines.append(
                f"  L{lineno}: {todo[:80]}"
                f"\n    keywords: {kws}"
                f"\n    matched commit: {commit[:80]}"
            )
        findings.append(
            Finding(
                "handoff_md",
                "info",
                f"{len(hits)} 个待办在 git log 中找到关键词命中（可能已 done）",
                detail=f"file: {handoff.name}\n" + "\n".join(detail_lines),
                suggestion=f"逐项核对 {handoff.name}，已完成的勾掉 [x]",
            )
        )
    else:
        findings.append(
            Finding(
                "handoff_md",
                "info",
                f"{handoff.name} {len(todos)} 个待办，git log 未命中",
                detail=f"file: {handoff} | commits since mtime: {len(commits)}",
                suggestion="（无须处理；如待办已停滞，考虑归档 HANDOFF）",
            )
        )

    return findings


# ── Detector 3: MEMORY.md ─────────────────────────────


_MD_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def detect_memory_md(cwd: Path) -> list[Finding]:
    findings: list[Finding] = []
    encoded = _encoded_cwd(cwd)
    mem_dir = HOME / ".claude" / "projects" / encoded / "memory"
    mem_md = mem_dir / "MEMORY.md"

    if not mem_md.exists():
        findings.append(
            Finding(
                "memory_md",
                "info",
                "项目无 MEMORY.md，跳过",
                detail=f"expected: {mem_md}",
                suggestion="（无须处理）",
            )
        )
        return findings

    text = mem_md.read_text(encoding="utf-8", errors="replace")
    dead: list[tuple[str, str]] = []
    for m in _MD_LINK_RE.finditer(text):
        link_text, target = m.group(1), m.group(2).split("#", 1)[0].strip()
        if not target:
            continue
        if target.startswith(("http://", "https://", "mailto:")):
            continue
        # 相对 mem_dir 解析
        candidate = (mem_dir / target).resolve()
        if not candidate.exists():
            dead.append((link_text, target))

    if dead:
        detail = "\n".join(f"  - [{t}]({tgt}) → 不存在" for t, tgt in dead[:20])
        findings.append(
            Finding(
                "memory_md",
                "error",
                f"MEMORY.md 有 {len(dead)} 个死链",
                detail=f"file: {mem_md}\n{detail}",
                suggestion=f"打开 {mem_md} 修复或删除失效引用",
            )
        )
    else:
        findings.append(
            Finding(
                "memory_md",
                "info",
                "MEMORY.md 引用全部健康",
                detail=f"file: {mem_md}",
            )
        )

    return findings


# ── Detector 4: README.md ─────────────────────────────


def detect_readme_md(cwd: Path) -> list[Finding]:
    findings: list[Finding] = []
    cands = [cwd / "README.md", cwd / "README_CN.md", cwd / "Readme.md", cwd / "readme.md"]
    readme = next((p for p in cands if p.exists()), None)
    if readme is None:
        findings.append(
            Finding(
                "readme_md",
                "info",
                "未找到 README.md（跳过）",
            )
        )
        return findings

    text = readme.read_text(encoding="utf-8", errors="replace")
    dead: list[tuple[str, str]] = []
    for m in _MD_LINK_RE.finditer(text):
        link_text, target = m.group(1), m.group(2).split("#", 1)[0].strip()
        if not target:
            continue
        if target.startswith(("http://", "https://", "mailto:", "tel:", "#")):
            continue
        # 排除纯 anchor / fragment
        candidate = (readme.parent / target).resolve()
        if not candidate.exists():
            dead.append((link_text, target))

    if dead:
        detail = "\n".join(f"  - [{t}]({tgt}) → 不存在" for t, tgt in dead[:20])
        findings.append(
            Finding(
                "readme_md",
                "warn",
                f"{readme.name} 有 {len(dead)} 个内部死链",
                detail=f"file: {readme}\n{detail}",
                suggestion=f"修复或删除 {readme.name} 的失效引用",
            )
        )
    else:
        findings.append(
            Finding(
                "readme_md",
                "info",
                f"{readme.name} 内部链接全部健康",
            )
        )

    return findings


# ── Detector 5: paths registry ────────────────────────


def detect_paths_registry(cwd: Path) -> list[Finding]:
    findings: list[Finding] = []

    # 仅当 cwd 在 ~/Dev 内才有意义
    try:
        cwd.resolve().relative_to(DEV_ROOT.resolve())
    except ValueError:
        findings.append(
            Finding(
                "paths_registry",
                "info",
                "cwd 不在 ~/Dev 内，跳过 paths registry 检查",
            )
        )
        return findings

    if not PATHS_PY.exists():
        findings.append(
            Finding(
                "paths_registry",
                "info",
                f"paths.py 不存在：{PATHS_PY}（跳过）",
            )
        )
        return findings

    try:
        result = subprocess.run(
            ["python3", str(PATHS_PY), "audit", "--brief"],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except Exception as exc:
        print(f"[cc_audit] paths.py audit failed: {exc}", file=sys.stderr)
        return findings

    out = (result.stdout or "").strip()
    err = (result.stderr or "").strip()
    if not out:
        findings.append(
            Finding(
                "paths_registry",
                "warn",
                "paths.py audit --brief 无输出",
                detail=err[:500],
            )
        )
        return findings

    # 期望格式: "paths: 56 registered / 41 dead / 0 drift"
    m = re.search(r"(\d+)\s*registered.*?(\d+)\s*dead.*?(\d+)\s*drift", out)
    if not m:
        findings.append(
            Finding(
                "paths_registry",
                "warn",
                f"paths.py audit 输出无法解析：{out[:120]}",
                detail=err[:300],
            )
        )
        return findings

    registered, dead, drift = (int(x) for x in m.groups())
    if dead > 0 or drift > 0:
        sev = "warn"
        findings.append(
            Finding(
                "paths_registry",
                sev,
                f"paths registry 漂移：{dead} dead / {drift} drift / {registered} registered",
                detail=out,
                suggestion=(
                    "跑详细诊断：python3 ~/Dev/tools/dev/lib/tools/paths.py audit\n"
                    "扫死链：python3 ~/Dev/tools/dev/lib/tools/paths.py scan-dead --strict"
                ),
            )
        )
    else:
        findings.append(
            Finding(
                "paths_registry",
                "info",
                f"paths registry 健康：{registered} registered / 0 dead / 0 drift",
            )
        )
    return findings


# ── Detector 6: harness.yaml ──────────────────────────


def _parse_harness_yaml(text: str) -> dict[str, dict]:
    """简易行 parser：返回 {project_name: {"path": "..."}}.

    只关心 projects: 节下面的 `<name>:\n  path: <path>`。
    skills: [...] 单行也跳过。
    格式假设很稳定（手写 yaml）。
    """
    out: dict[str, dict] = {}
    in_projects = False
    current: str | None = None
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if re.match(r"^projects\s*:\s*$", line):
            in_projects = True
            continue
        if in_projects and re.match(r"^[A-Za-z]", line) and not line.startswith(" "):
            # 顶级 key 重新出现 → 退出 projects 节
            in_projects = False
            continue
        if not in_projects:
            continue
        # project name (2 缩进)
        m = re.match(r"^  ([A-Za-z][\w-]*)\s*:\s*$", line)
        if m:
            current = m.group(1)
            out[current] = {}
            continue
        # path: <value>  (4 缩进)
        m = re.match(r"^    path\s*:\s*(.+?)\s*$", line)
        if m and current:
            value = m.group(1).strip().strip('"').strip("'")
            out[current]["path"] = value
            continue
    return out


def detect_harness_yaml(cwd: Path) -> list[Finding]:
    findings: list[Finding] = []

    # 仅 ~/Dev 内项目相关
    try:
        cwd.resolve().relative_to(DEV_ROOT.resolve())
    except ValueError:
        findings.append(
            Finding(
                "harness_yaml",
                "info",
                "cwd 不在 ~/Dev 内，跳过 harness.yaml 检查",
            )
        )
        return findings

    if not HARNESS_YAML.exists():
        findings.append(
            Finding(
                "harness_yaml",
                "info",
                f"harness.yaml 不存在：{HARNESS_YAML}",
            )
        )
        return findings

    try:
        text = HARNESS_YAML.read_text(encoding="utf-8", errors="replace")
    except Exception as exc:
        print(f"[cc_audit] read harness.yaml failed: {exc}", file=sys.stderr)
        return findings

    projects = _parse_harness_yaml(text)
    cwd_resolved = cwd.resolve()

    matched_name: str | None = None
    for name, attrs in projects.items():
        path_str = attrs.get("path")
        if not path_str:
            continue
        try:
            p = Path(os.path.expanduser(path_str)).resolve()
        except Exception:
            continue
        if p == cwd_resolved:
            matched_name = name
            break

    if matched_name is None:
        findings.append(
            Finding(
                "harness_yaml",
                "info",
                "当前项目未注册到 harness.yaml",
                detail=f"cwd: {cwd_resolved}\nharness.yaml: {HARNESS_YAML}",
                suggestion=(
                    "如需项目专属 skills 分发，编辑 harness.yaml `projects:` 节添加：\n"
                    f"  <name>:\n    path: {cwd_resolved}\n    skills: [...]"
                ),
            )
        )
    else:
        findings.append(
            Finding(
                "harness_yaml",
                "info",
                f"项目已注册到 harness.yaml: {matched_name}",
                detail=f"path: {cwd_resolved}",
            )
        )

    # 检查注册表里所有 path 是否都存在（顺手做一遍全表 audit）
    broken: list[tuple[str, str]] = []
    for name, attrs in projects.items():
        path_str = attrs.get("path")
        if not path_str:
            continue
        try:
            p = Path(os.path.expanduser(path_str))
        except Exception:
            continue
        if not p.exists():
            broken.append((name, path_str))

    if broken:
        detail = "\n".join(f"  - {n}: {p}" for n, p in broken)
        findings.append(
            Finding(
                "harness_yaml",
                "error",
                f"harness.yaml 有 {len(broken)} 条死链项目",
                detail=detail,
                suggestion="清理 harness.yaml 中已不存在的 project path",
            )
        )

    return findings


# ── 调度 / 输出 ───────────────────────────────────────


_DETECTORS = {
    "claude_md": detect_claude_md,
    "handoff_md": detect_handoff_md,
    "memory_md": detect_memory_md,
    "readme_md": detect_readme_md,
    "paths_registry": detect_paths_registry,
    "harness_yaml": detect_harness_yaml,
}


def _normalize_only(only: list[str] | None) -> list[str] | None:
    if not only:
        return None
    out: list[str] = []
    for token in only:
        key = DIMENSION_ALIASES.get(token, token)
        if key in DIMENSIONS:
            out.append(key)
        else:
            print(f"[cc_audit] warning: unknown dimension '{token}'", file=sys.stderr)
    return out or None


def run(cwd: Path, only: list[str] | None = None) -> list[Finding]:
    selected = _normalize_only(only) or list(DIMENSIONS)
    all_findings: list[Finding] = []
    for dim in selected:
        fn = _DETECTORS.get(dim)
        if fn is None:
            continue
        try:
            all_findings.extend(fn(cwd))
        except Exception as exc:
            print(f"[cc_audit] detector '{dim}' crashed: {exc}", file=sys.stderr)
            all_findings.append(
                Finding(
                    dim,
                    "error",
                    f"detector 内部错误：{type(exc).__name__}",
                    detail=str(exc),
                    suggestion="检查 cc_audit.py 此 detector 实现",
                )
            )
    return all_findings


def render_text(findings: list[Finding]) -> str:
    SEV_ICON = {"info": "i", "warn": "!", "error": "X"}
    grouped: dict[str, list[Finding]] = {d: [] for d in DIMENSIONS}
    for f in findings:
        grouped.setdefault(f.dimension, []).append(f)

    out: list[str] = []
    for dim in DIMENSIONS:
        items = grouped.get(dim) or []
        if not items:
            continue
        out.append(f"\n=== {dim} ===")
        for f in items:
            icon = SEV_ICON.get(f.severity, "?")
            out.append(f"  [{icon}] {f.title}")
            if f.detail:
                for line in f.detail.splitlines():
                    out.append(f"      {line}")
            if f.suggestion:
                for line in f.suggestion.splitlines():
                    out.append(f"      → {line}")
    counts = {"info": 0, "warn": 0, "error": 0}
    for f in findings:
        counts[f.severity] = counts.get(f.severity, 0) + 1
    out.append(
        f"\n--- summary: {len(findings)} findings "
        f"(error={counts.get('error',0)} warn={counts.get('warn',0)} info={counts.get('info',0)}) ---"
    )
    return "\n".join(out).lstrip()


def render_json(findings: list[Finding]) -> str:
    counts = {"info": 0, "warn": 0, "error": 0}
    for f in findings:
        counts[f.severity] = counts.get(f.severity, 0) + 1
    payload = {
        "findings": [f.to_dict() for f in findings],
        "summary": {
            "total": len(findings),
            "error": counts.get("error", 0),
            "warn": counts.get("warn", 0),
            "info": counts.get("info", 0),
        },
    }
    return json.dumps(payload, indent=2, ensure_ascii=False)


def render_brief(findings: list[Finding]) -> str:
    counts = {"info": 0, "warn": 0, "error": 0}
    for f in findings:
        counts[f.severity] = counts.get(f.severity, 0) + 1
    return (
        f"cc-audit: {len(findings)} findings "
        f"({counts.get('error',0)} error / {counts.get('warn',0)} warn / {counts.get('info',0)} info)"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="cc_audit",
        description="检测 CC 项目配置文档与 repo 实际状态的漂移（read-only）",
    )
    parser.add_argument("--cwd", type=str, default=".", help="项目目录（默认当前目录）")
    parser.add_argument("--json", action="store_true", help="JSON 输出")
    parser.add_argument("--brief", action="store_true", help="单行总结")
    parser.add_argument(
        "--only",
        nargs="+",
        default=None,
        help=(
            "只跑某些维度（dimension key 或别名）。"
            "可选：CLAUDE.md HANDOFF.md MEMORY.md README.md paths harness  "
            "或 claude_md / handoff_md / memory_md / readme_md / paths_registry / harness_yaml"
        ),
    )
    args = parser.parse_args()

    cwd = Path(os.path.expanduser(args.cwd)).resolve()
    if not cwd.is_dir():
        print(f"[cc_audit] cwd not a directory: {cwd}", file=sys.stderr)
        return 2

    findings = run(cwd, only=args.only)

    if args.json:
        print(render_json(findings))
    elif args.brief:
        print(render_brief(findings))
    else:
        print(render_text(findings))

    # exit code: 有 error → 1，其余 0
    has_error = any(f.severity == "error" for f in findings)
    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main())
