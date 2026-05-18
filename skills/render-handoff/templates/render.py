#!/usr/bin/env python3
"""Render .md files referenced from an HTML report into local .html files.

Usage:
    render.py <html-file>          # scan HTML, render all referenced .md, rewrite hrefs
    render.py --md <md-file> ...   # render specified .md files only (no parent rewrite)

Behaviour:
    1. Scan <html-file> for href="file://...md" links.
    2. For each existing .md, pandoc-render to a sibling <name>.html using dark-theme.css.
    3. Resolve [[wikilinks]] inside each .md to local .html paths when findable.
    4. Rewrite href="file://<md>" -> href="file://<html>" in the parent HTML.

stdlib + pandoc subprocess only.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from typing import Iterable

SKILL_DIR = Path(__file__).resolve().parent
CSS_FILE = SKILL_DIR / "dark-theme.css"

MD_HREF_RE = re.compile(r'href="file://([^"]+\.md)"')
WIKILINK_RE = re.compile(r"\[\[([^\]|#]+?)(?:#[^\]|]+)?(?:\|([^\]]+))?\]\]")


# ---------------------------------------------------------------------------
# HTML scanning
# ---------------------------------------------------------------------------

def find_md_links(html_text: str) -> list[str]:
    """Return ordered unique list of .md absolute paths referenced in HTML."""
    seen: set[str] = set()
    out: list[str] = []
    for path in MD_HREF_RE.findall(html_text):
        if path not in seen:
            seen.add(path)
            out.append(path)
    return out


# ---------------------------------------------------------------------------
# Wikilink resolution (preprocess MD content before pandoc)
# ---------------------------------------------------------------------------

def _wikilink_search_paths(md_path: Path) -> list[Path]:
    """Directories to search for wikilink targets, in priority order."""
    return [
        md_path.parent,
        md_path.parent.parent if md_path.parent.parent != md_path.parent else md_path.parent,
    ]


def resolve_wikilinks(md_text: str, md_path: Path) -> str:
    """Replace [[name]] / [[name|alt]] with [alt](relative.html) when resolvable.

    Unresolvable wikilinks become <span class="wikilink-unresolved">name</span>.
    pandoc passes the HTML span through verbatim (when --from markdown is used
    we use a raw_html-friendly inline substitution by emitting an <a> or span).
    """
    parents = _wikilink_search_paths(md_path)

    def repl(m: re.Match) -> str:
        name = m.group(1).strip()
        alt = (m.group(2) or name).strip()
        # search candidate filenames
        candidates = [f"{name}.md", f"{name}.html"]
        for parent in parents:
            for cand in candidates:
                p = parent / cand
                if p.exists():
                    # render-handoff target: if .md, sibling .html will exist after batch
                    html_rel = p.with_suffix(".html").name
                    return f"[{alt}]({html_rel})"
        # unresolved -> styled span via inline HTML (markdown passthrough)
        return f'<span class="wikilink-unresolved" title="unresolved wikilink">{alt}</span>'

    return WIKILINK_RE.sub(repl, md_text)


# ---------------------------------------------------------------------------
# Pandoc render
# ---------------------------------------------------------------------------

def render_md(md_path: Path) -> Path | None:
    """Render <md_path> to sibling .html. Returns output path or None on failure."""
    out = md_path.with_suffix(".html")
    try:
        text = md_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"  [skip] cannot read {md_path}: {e}", file=sys.stderr)
        return None

    text = resolve_wikilinks(text, md_path)

    title = md_path.stem
    cmd = [
        "pandoc",
        "-f", "markdown+yaml_metadata_block+raw_html",
        "-t", "html5",
        "--standalone",
        "--metadata", f"title={title}",
        "-H", str(CSS_FILE),
        "-o", str(out),
    ]
    try:
        subprocess.run(cmd, input=text, text=True, check=True,
                       capture_output=True, timeout=30)
    except subprocess.CalledProcessError as e:
        print(f"  [fail] pandoc {md_path}: {e.stderr.strip()[:200]}", file=sys.stderr)
        return None
    except subprocess.TimeoutExpired:
        print(f"  [fail] pandoc {md_path}: timeout", file=sys.stderr)
        return None
    return out


# ---------------------------------------------------------------------------
# Parent HTML rewrite
# ---------------------------------------------------------------------------

def rewrite_hrefs(html_path: Path, mapping: dict[str, str]) -> int:
    """Replace each `file://<md>` occurrence with `file://<html>` in html_path.

    Returns number of substitutions performed.
    """
    if not mapping:
        return 0
    text = html_path.read_text(encoding="utf-8")
    count = 0
    for md, html in mapping.items():
        before = text.count(f"file://{md}")
        if before:
            text = text.replace(f"file://{md}", f"file://{html}")
            count += before
    if count:
        html_path.write_text(text, encoding="utf-8")
    return count


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def render_batch(md_paths: Iterable[Path]) -> dict[str, str]:
    """Render each .md, return mapping <md-abs-str> -> <html-abs-str> for successes."""
    mapping: dict[str, str] = {}
    for md in md_paths:
        if not md.exists():
            print(f"  [skip] missing: {md}", file=sys.stderr)
            continue
        out = render_md(md)
        if out is not None:
            mapping[str(md)] = str(out)
            print(f"  [ok]  {md.name} -> {out.name}")
    return mapping


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2

    if not CSS_FILE.exists():
        print(f"FATAL: CSS not found at {CSS_FILE}", file=sys.stderr)
        return 2

    # --md mode: render specified files, no parent rewrite
    if argv[1] == "--md":
        md_paths = [Path(p).resolve() for p in argv[2:]]
        if not md_paths:
            print("--md requires at least one .md path", file=sys.stderr)
            return 2
        mapping = render_batch(md_paths)
        print(f"\nRendered {len(mapping)}/{len(md_paths)} files.")
        return 0 if mapping else 1

    # Default: scan HTML, batch render, rewrite hrefs
    html_path = Path(argv[1]).resolve()
    if not html_path.exists():
        print(f"FATAL: HTML not found: {html_path}", file=sys.stderr)
        return 2

    html_text = html_path.read_text(encoding="utf-8")
    md_links = find_md_links(html_text)
    print(f"Scanned {html_path.name}: {len(md_links)} unique .md href(s)")

    md_paths = [Path(p) for p in md_links]
    mapping = render_batch(md_paths)

    rewrites = rewrite_hrefs(html_path, mapping)
    print(f"\nRendered {len(mapping)}/{len(md_links)} files. "
          f"Rewrote {rewrites} hrefs in {html_path.name}.")
    return 0 if mapping else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
