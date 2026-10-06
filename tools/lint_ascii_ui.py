#!/usr/bin/env python3
"""Fail on non-ASCII string literals in arcade/games UI sources.

Default Godot fonts are Latin-focused; glyphs like arrows and card suits
render as tofu (□). Prefer ASCII UI text, or allowlist a path with a
documented font that covers the glyphs.

Scans:
  - arcade/**/*.gd, arcade/**/*.tscn
  - games/**/*.gd, games/**/*.tscn
Skips:
  - games/*/source/ (upstream snapshots, not playable editions)
  - .gd comment-only lines (leading # / ##)
  - allowlisted path or path:line entries (see tools/ascii_ui_allowlist.txt)

Exit 0 = clean, 1 = findings (or usage error).
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALLOWLIST_PATH = Path(__file__).resolve().parent / "ascii_ui_allowlist.txt"

STRING_RE = re.compile(
    r'("""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')'
)
TSCN_TEXT_RE = re.compile(
    r"^\s*(text|placeholder_text|tooltip_text|title)\s*=\s*"
    r'("(?:\\.|[^"\\])*")'
)
SCAN_ROOTS = ("arcade", "games")
SKIP_DIR_NAMES = {"source"}


def load_allowlist(path: Path) -> tuple[set[str], set[str]]:
    """Return (whole_files, file:line keys). Comments after # are ignored
    except we keep the line for documentation; keys are the path part."""
    files: set[str] = set()
    lines: set[str] = set()
    if not path.is_file():
        return files, lines
    for raw in path.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        # strip trailing doc comment: "path  # font: ..."
        key = s.split("#", 1)[0].strip()
        if not key:
            continue
        if re.search(r":\d+$", key):
            lines.add(key)
        else:
            files.add(key)
    return files, lines


def should_skip_dir(parts: tuple[str, ...]) -> bool:
    # games/<slug>/source/...
    if len(parts) >= 3 and parts[0] == "games" and parts[2] == "source":
        return True
    return False


def is_comment_line(line: str) -> bool:
    return line.lstrip().startswith("#")


def non_ascii_chars(s: str) -> list[str]:
    return [ch for ch in s if ord(ch) > 127]


def iter_sources(root: Path):
    for name in SCAN_ROOTS:
        base = root / name
        if not base.is_dir():
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            rel_dir = Path(dirpath).relative_to(root)
            parts = rel_dir.parts
            if should_skip_dir(parts):
                dirnames.clear()
                continue
            # prune nested source dirs
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES or name != "games"]
            for fn in filenames:
                if not (fn.endswith(".gd") or fn.endswith(".tscn")):
                    continue
                yield Path(dirpath) / fn


def scan_file(path: Path, root: Path) -> list[tuple[int, str, str]]:
    """Return list of (lineno, chars, snippet)."""
    rel = path.relative_to(root).as_posix()
    findings: list[tuple[int, str, str]] = []
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".tscn":
        for i, line in enumerate(text.splitlines(), 1):
            m = TSCN_TEXT_RE.match(line)
            if not m:
                continue
            bad = non_ascii_chars(m.group(2))
            if bad:
                findings.append((i, "".join(sorted(set(bad))), line.strip()[:160]))
        return findings

    # .gd — skip comment-only lines; scan string literals on code lines
    for i, line in enumerate(text.splitlines(), 1):
        if is_comment_line(line):
            continue
        for m in STRING_RE.finditer(line):
            bad = non_ascii_chars(m.group(0))
            if bad:
                findings.append((i, "".join(sorted(set(bad))), line.strip()[:160]))
                break
    return findings


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--root",
        type=Path,
        default=ROOT,
        help="project root (default: repo containing this script)",
    )
    ap.add_argument(
        "--allowlist",
        type=Path,
        default=ALLOWLIST_PATH,
        help="allowlist file path",
    )
    args = ap.parse_args()
    root: Path = args.root.resolve()
    allow_files, allow_lines = load_allowlist(args.allowlist.resolve())

    violations: list[str] = []
    scanned = 0
    for path in sorted(iter_sources(root)):
        scanned += 1
        rel = path.relative_to(root).as_posix()
        for lineno, chars, snippet in scan_file(path, root):
            key = f"{rel}:{lineno}"
            if rel in allow_files or key in allow_lines:
                continue
            shown = " ".join(f"U+{ord(c):04X}({c})" for c in chars)
            violations.append(f"{key}: non-ASCII {shown}: {snippet}")

    if violations:
        print(f"ascii-ui-lint: FAIL ({len(violations)} finding(s) in {scanned} files)", file=sys.stderr)
        for v in violations:
            print(v, file=sys.stderr)
        print(
            "\nFix: replace with ASCII, or add path[/ :line] to tools/ascii_ui_allowlist.txt "
            "with a '# font: <path>' note documenting glyph coverage.",
            file=sys.stderr,
        )
        return 1

    print(f"ascii-ui-lint: OK ({scanned} files, allowlist {args.allowlist.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
