#!/usr/bin/env python3
"""retro_symlink — session-retro 双向链接管理

物理文件落主项目 docs/retros/，中央位置 ~/Dev/stations/docs/knowledge/ 留 symlink，
INDEX.md 维护时间线索引。

子命令：
  link <physical>          单文件：在中央位置建 symlink + 更新 INDEX.md
  migrate [--apply]        批量回迁：按 mapping.json 把中央 30+ retro 分发到主项目
  index                    重扫中央目录，重建 INDEX.md
  audit                    检查中央目录所有 .md 是否都对应有效 symlink/物理文件

用法：
  python3 retro_symlink.py link ~/Dev/stations/wpl-calc/docs/retros/session-retro-20260501-...md
  python3 retro_symlink.py migrate                # dry-run 默认
  python3 retro_symlink.py migrate --apply        # 真做
  python3 retro_symlink.py index
  python3 retro_symlink.py audit
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

CENTRAL = Path("~/Dev/stations/docs/knowledge").expanduser()
INDEX_FILE = CENTRAL / "INDEX.md"
MAPPING_FILE = Path(__file__).parent / "mapping.json"

DATE_RE = re.compile(r"session-retro-(\d{8})(?:-(.+))?\.md$")
INDEX_HEADER = """# Session Retros 索引

> 中央查询入口。物理文件分散在各项目 `docs/retros/`，本目录是 symlink 集合。

## 时间线
"""


@dataclass
class Retro:
    filename: str
    physical: Path  # 实际物理文件位置
    central: Path   # 中央位置（symlink 或同一文件）
    is_symlink: bool
    date: str       # YYYY-MM-DD
    slug: str       # topic-slug，可能空


def parse_filename(filename: str) -> tuple[str, str]:
    """从 session-retro-YYYYMMDD[-slug].md 解析日期 + slug。"""
    m = DATE_RE.search(filename)
    if not m:
        return ("", "")
    yyyymmdd = m.group(1)
    slug = m.group(2) or ""
    date = f"{yyyymmdd[:4]}-{yyyymmdd[4:6]}-{yyyymmdd[6:8]}"
    return (date, slug)


def resolve_physical(central_path: Path) -> Path:
    """中央路径 → 物理路径（如是 symlink 则跟链接）。"""
    if central_path.is_symlink():
        return central_path.resolve()
    return central_path


def expand(p: str) -> Path:
    return Path(os.path.expanduser(p))


def project_label(physical: Path) -> str:
    """从物理路径推断主项目标签。"""
    p = str(physical)
    home = str(Path.home())
    if p.startswith(home):
        rel = p[len(home) + 1:]  # 去掉 ~/
    else:
        rel = p
    # ~/Dev/X/docs/retros/file.md → X
    parts = rel.split("/")
    if parts[0] == "Dev" and len(parts) >= 4:
        # ~/Dev/stations/wpl-calc/...   → wpl-calc
        # ~/Dev/stations/web-stack/... → stations/web-stack
        # ~/Dev/content/investment/... → content/investment
        if parts[1] in ("stations", "labs", "content", "tools", "migrated") and len(parts) >= 5:
            return f"{parts[1]}/{parts[2]}"
        return parts[1]
    return "central"


def read_index_existing() -> dict[str, str]:
    """读 INDEX.md 现有时间线条目（filename → 完整行）。"""
    if not INDEX_FILE.exists():
        return {}
    content = INDEX_FILE.read_text()
    entries = {}
    in_timeline = False
    for line in content.splitlines():
        if line.startswith("## 时间线"):
            in_timeline = True
            continue
        if in_timeline and line.startswith("## "):
            break
        if in_timeline and line.startswith("- ") and "→" in line:
            # 提 filename：找 session-retro-*.md
            m = re.search(r"(session-retro-[\w\-.]+\.md)", line)
            if m:
                entries[m.group(1)] = line
    return entries


def collect_retros() -> list[Retro]:
    """扫中央目录，收集所有 retro 信息。"""
    retros = []
    for p in sorted(CENTRAL.glob("session-retro-*.md")):
        physical = resolve_physical(p)
        is_symlink = p.is_symlink()
        date, slug = parse_filename(p.name)
        if not physical.exists():
            print(f"WARN: 死链 {p} → {physical}", file=sys.stderr)
            continue
        retros.append(Retro(
            filename=p.name,
            physical=physical,
            central=p,
            is_symlink=is_symlink,
            date=date,
            slug=slug,
        ))
    return retros


def render_index(retros: list[Retro]) -> str:
    """按日期倒序生成 INDEX.md 内容。"""
    out = [INDEX_HEADER]
    # 按日期倒序，同日期按文件名
    sorted_retros = sorted(retros, key=lambda r: (r.date, r.filename), reverse=True)
    for r in sorted_retros:
        label = project_label(r.physical)
        slug_display = r.slug if r.slug else "—"
        # 物理路径以 ~/ 开头显示
        phys_display = str(r.physical).replace(str(Path.home()), "~", 1)
        line = f"- {r.date} · {label} · {slug_display} → {phys_display}"
        out.append(line)
    return "\n".join(out) + "\n"


def cmd_index(args: argparse.Namespace) -> int:
    """重扫 + 重建 INDEX.md。"""
    retros = collect_retros()
    content = render_index(retros)
    if args.dry_run:
        print(content)
        return 0
    INDEX_FILE.write_text(content)
    print(f"✅ INDEX.md 重建：{len(retros)} entries → {INDEX_FILE}")
    return 0


def cmd_link(args: argparse.Namespace) -> int:
    """单文件：在中央建 symlink + 更新 INDEX.md。"""
    physical = expand(args.physical).resolve()
    if not physical.exists():
        print(f"ERROR: 物理文件不存在 {physical}", file=sys.stderr)
        return 1
    if not physical.name.startswith("session-retro-"):
        print(f"ERROR: 文件名不以 session-retro- 开头 {physical.name}", file=sys.stderr)
        return 1

    central_link = CENTRAL / physical.name

    # 已存在处理
    if central_link.exists() or central_link.is_symlink():
        if central_link.is_symlink() and central_link.resolve() == physical:
            print(f"INFO: symlink 已存在且正确 {central_link}")
        else:
            if not args.force:
                print(f"ERROR: {central_link} 已存在（非目标 symlink）。--force 覆盖", file=sys.stderr)
                return 1
            central_link.unlink()
            print(f"INFO: 删除旧文件 {central_link}")

    if not central_link.exists():
        # 建相对 symlink
        rel = os.path.relpath(physical, CENTRAL)
        if args.dry_run:
            print(f"DRY: ln -s {rel} {central_link}")
        else:
            central_link.symlink_to(rel)
            print(f"✅ symlink: {central_link} → {rel}")

    # 更新 INDEX
    if not args.dry_run:
        cmd_index(argparse.Namespace(dry_run=False))
    return 0


def cmd_migrate(args: argparse.Namespace) -> int:
    """批量回迁 30+ retro 到主项目 docs/retros/。"""
    if not MAPPING_FILE.exists():
        print(f"ERROR: mapping 不存在 {MAPPING_FILE}", file=sys.stderr)
        return 1
    mappings = json.loads(MAPPING_FILE.read_text())

    plans = []
    for entry in mappings:
        filename = entry["file"]
        target = entry["primary_project_path"]
        confidence = entry.get("confidence", "?")
        reason = entry.get("reason", "")
        central_path = CENTRAL / filename
        if not central_path.exists():
            plans.append((filename, "missing", target, "中央目录无此文件，跳过"))
            continue
        if central_path.is_symlink():
            plans.append((filename, "skip-symlink", target, "已是 symlink"))
            continue
        if target == "central":
            plans.append((filename, "keep-central", target, reason))
            continue
        # 移动到 <target>/docs/retros/
        dest_dir = expand(target) / "docs" / "retros"
        dest_path = dest_dir / filename
        if dest_path.exists():
            plans.append((filename, "dest-exists", target, f"已存在 {dest_path}"))
            continue
        plans.append((filename, "migrate", target, f"{confidence}: {reason[:60]}"))

    # 打印计划
    print(f"\n=== 迁移计划（共 {len(plans)} 项） ===\n")
    counts = {"migrate": 0, "keep-central": 0, "skip-symlink": 0, "dest-exists": 0, "missing": 0}
    for filename, action, target, note in plans:
        counts[action] = counts.get(action, 0) + 1
        action_disp = {
            "migrate": "→ MOVE",
            "keep-central": "  KEEP",
            "skip-symlink": "  SKIP",
            "dest-exists": "  DEST已存在",
            "missing": "  MISSING",
        }.get(action, action)
        target_short = target.replace(str(Path.home()), "~", 1) if target != "central" else "central"
        print(f"  [{action_disp}] {filename:60s}  → {target_short}")
        if action in ("dest-exists", "missing"):
            print(f"           {note}")

    print(f"\n汇总：")
    for k, v in counts.items():
        print(f"  {k}: {v}")

    if not args.apply:
        print("\n⚠️  Dry-run 模式 — 加 --apply 真做")
        return 0

    print("\n=== 应用 ===\n")
    moved = 0
    failed = 0
    for filename, action, target, _ in plans:
        if action != "migrate":
            continue
        central_path = CENTRAL / filename
        dest_dir = expand(target) / "docs" / "retros"
        dest_path = dest_dir / filename
        try:
            dest_dir.mkdir(parents=True, exist_ok=True)
            # 1. 移动物理文件
            shutil.move(str(central_path), str(dest_path))
            # 2. 在中央建相对 symlink
            rel = os.path.relpath(dest_path, CENTRAL)
            central_path.symlink_to(rel)
            print(f"  ✅ {filename} → {target}/docs/retros/")
            moved += 1
        except Exception as e:
            print(f"  ❌ {filename}: {e}", file=sys.stderr)
            failed += 1

    print(f"\n迁移完成：{moved} 成功 / {failed} 失败")

    # 重建 INDEX
    print("\n=== 重建 INDEX.md ===\n")
    cmd_index(argparse.Namespace(dry_run=False))
    return 0 if failed == 0 else 1


def cmd_audit(args: argparse.Namespace) -> int:
    """检查中央目录所有 .md 是否都对应有效 symlink/物理文件。"""
    issues = 0
    for p in sorted(CENTRAL.glob("session-retro-*.md")):
        if p.is_symlink():
            target = p.resolve()
            if not target.exists():
                print(f"❌ 死链 symlink: {p} → {target}")
                issues += 1
            else:
                rel = os.path.relpath(target, CENTRAL)
                # symlink 应该是相对路径（便于迁移整个目录）
                actual_link = os.readlink(p)
                if actual_link.startswith("/"):
                    print(f"⚠️  绝对路径 symlink: {p} → {actual_link}（建议改相对）")
                    issues += 1
        # 物理文件不需检查
    if issues == 0:
        print(f"✅ audit OK — 中央目录所有 retro symlink 健康")
    return 0 if issues == 0 else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_link = sub.add_parser("link", help="单文件：建 symlink + 更新 INDEX")
    p_link.add_argument("physical", help="物理文件路径")
    p_link.add_argument("--dry-run", action="store_true")
    p_link.add_argument("--force", action="store_true", help="覆盖中央位置已有文件")
    p_link.set_defaults(func=cmd_link)

    p_migrate = sub.add_parser("migrate", help="批量回迁中央 retro 到主项目")
    p_migrate.add_argument("--apply", action="store_true", help="不加默认 dry-run")
    p_migrate.set_defaults(func=cmd_migrate)

    p_index = sub.add_parser("index", help="重建 INDEX.md")
    p_index.add_argument("--dry-run", action="store_true")
    p_index.set_defaults(func=cmd_index)

    p_audit = sub.add_parser("audit", help="检查 retro symlink 健康")
    p_audit.set_defaults(func=cmd_audit)

    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
