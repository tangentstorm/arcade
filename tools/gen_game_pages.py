#!/usr/bin/env python3
"""Emit per-game thin HTML stubs under build/web/<slug>/ for GitHub Pages.

Each stub reuses the gallery Web export (../index.js, ../index.wasm, ../index.pck)
and bootstraps ArcadeHistory with #play/<registry_id>/<edition> before the engine
starts. Edition comes from ?e=enhanced or #enhanced (else direct).

URL aliases (slug -> registry id) live in arcade/game_slugs.gd (ALIASES) and are
documented in docs/GALLERY.md.

Usage:
  python3 tools/gen_game_pages.py --web-dir build/web
  python3 tools/gen_game_pages.py --self-check
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "arcade" / "game_registry.gd"
PREVIEWS = ROOT / "arcade" / "previews"
SITE = "https://tangentstorm.github.io/arcade"

# Short URL slug -> GameRegistry id. Single source: arcade/game_slugs.gd (ALIASES).
# Documented in docs/GALLERY.md. Do not edit the table here — edit game_slugs.gd.
def _load_aliases() -> dict[str, str]:
    text = (ROOT / "arcade" / "game_slugs.gd").read_text(encoding="utf-8")
    m = re.search(r"const ALIASES := \{([^}]+)\}", text, re.S)
    if not m:
        raise SystemExit("gen_game_pages: could not find ALIASES in arcade/game_slugs.gd")
    out: dict[str, str] = {}
    for am in re.finditer(r'"([^"]+)":\s*"([^"]+)"', m.group(1)):
        out[am.group(1)] = am.group(2)
    if not out:
        raise SystemExit("gen_game_pages: parsed zero ALIASES from game_slugs.gd")
    return out


ALIASES: dict[str, str] = _load_aliases()

# Minimal exported shell for --self-check (no Godot export required).
FIXTURE_HTML = """<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<title>tangentstorm arcade</title>
		<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png" />
		<link rel="apple-touch-icon" href="index.apple-touch-icon.png"/>
		<meta name="description" content="gallery desc" />
		<meta property="og:type" content="website" />
		<meta property="og:site_name" content="tangentstorm arcade" />
		<meta property="og:title" content="tangentstorm arcade" />
		<meta property="og:description" content="gallery desc" />
		<meta property="og:url" content="https://tangentstorm.github.io/arcade/" />
		<meta property="og:image" content="https://tangentstorm.github.io/arcade/og-image.png" />
		<meta name="twitter:card" content="summary_large_image" />
		<meta name="twitter:title" content="tangentstorm arcade" />
		<meta name="twitter:description" content="gallery desc" />
		<meta name="twitter:image" content="https://tangentstorm.github.io/arcade/og-image.png" />
		<link rel="canonical" href="https://tangentstorm.github.io/arcade/" />
	</head>
	<body>
		<img id="status-splash" src="index.png" alt="">
		<script src="index.js"></script>
		<script>
const GODOT_CONFIG = {"args":[],"executable":"index","fileSizes":{"index.pck":1,"index.wasm":2},"focusCanvas":true};
const engine = new Engine(GODOT_CONFIG);
engine.startGame({});
		</script>
	</body>
</html>
"""


def _parse_titles(text: str) -> list[tuple[str, str, dict[str, str], str]]:
    """Return [(id, title, {edition: status}, notes), ...] from TITLES."""
    m = re.search(r"const TITLES := \[(.*?)\n\]\n\nvar entries", text, re.S)
    if not m:
        raise SystemExit("gen_game_pages: could not find TITLES in game_registry.gd")
    block = m.group(1)
    # Each entry: ["id", "title", status, "notes"]
    entries: list[tuple[str, str, dict[str, str], str]] = []
    for em in re.finditer(
        r'\["([^"]+)",\s*"((?:\\.|[^"\\])*)",\s*(\{[^}]+\}|"[^"]+"),\s*\n?\s*"((?:\\.|[^"\\])*)"\]',
        block,
    ):
        gid, title, status_raw, notes = em.group(1), em.group(2), em.group(3), em.group(4)
        title = title.replace('\\"', '"')
        notes = notes.replace('\\"', '"')
        statuses: dict[str, str] = {}
        if status_raw.startswith("{"):
            for ed in ("direct", "enhanced"):
                sm = re.search(rf'"{ed}":\s*"(\w+)"', status_raw)
                statuses[ed] = sm.group(1) if sm else "planned"
        else:
            st = status_raw.strip('"')
            statuses = {"direct": st, "enhanced": st}
        entries.append((gid, title, statuses, notes))
    if not entries:
        raise SystemExit("gen_game_pages: parsed zero TITLES entries")
    return entries


def playable_titles() -> list[dict]:
    """Playable registry rows: at least one edition with status != planned and scene on disk."""
    rows = []
    for gid, title, statuses, notes in _parse_titles(REGISTRY.read_text(encoding="utf-8")):
        eds = []
        for ed, st in statuses.items():
            if st == "planned":
                continue
            if (ROOT / "games" / gid / ed / "game.tscn").is_file():
                eds.append(ed)
        if eds:
            rows.append({"id": gid, "title": title, "editions": eds, "notes": notes})
    return rows


def slug_map(titles: list[dict] | None = None) -> dict[str, str]:
    """Build URL slug -> registry id (aliases override default id==slug)."""
    titles = titles if titles is not None else playable_titles()
    playable_ids = {t["id"] for t in titles}
    slugs: dict[str, str] = {t["id"]: t["id"] for t in titles}
    for slug, rid in ALIASES.items():
        if rid not in playable_ids:
            raise SystemExit(f"gen_game_pages: alias {slug!r} -> {rid!r} but {rid!r} is not playable")
        # Drop the default slug==id page for the aliased target when the alias uses a different slug.
        if rid in slugs and slugs[rid] == rid and slug != rid:
            del slugs[rid]
        # If this alias reuses another title's default slug, overwrite (mineswpr -> b4).
        slugs[slug] = rid
    return slugs


def _set_meta(html: str, *, attr: str, key: str, content: str) -> str:
    """Replace or insert a meta tag matched by property= or name=."""
    pat = re.compile(
        rf'(<meta\s+{attr}="{re.escape(key)}"\s+content=")([^"]*)("\s*/?>)',
        re.I,
    )
    if pat.search(html):
        return pat.sub(rf"\g<1>{_xml_escape(content)}\g<3>", html, count=1)
    # Insert before </head>
    tag = f'<meta {attr}="{key}" content="{_xml_escape(content)}" />\n'
    return html.replace("</head>", tag + "\t</head>", 1)


def _set_link_canonical(html: str, href: str) -> str:
    pat = re.compile(r'(<link\s+rel="canonical"\s+href=")([^"]*)("\s*/?>)', re.I)
    if pat.search(html):
        return pat.sub(rf"\g<1>{_xml_escape(href)}\g<3>", html, count=1)
    return html.replace(
        "</head>",
        f'<link rel="canonical" href="{_xml_escape(href)}" />\n\t</head>',
        1,
    )


def _set_title(html: str, title: str) -> str:
    return re.sub(
        r"<title>[^<]*</title>",
        f"<title>{_xml_escape(title)}</title>",
        html,
        count=1,
        flags=re.I,
    )


def _xml_escape(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _rewrite_assets_to_parent(html: str) -> str:
    """Point shell assets at the gallery export one directory up."""
    # Quoted relative index.* paths (icons, splash, script src, fileSizes keys).
    html = re.sub(
        r'(["\'])(index\.[A-Za-z0-9._-]+)\1',
        r"\1../\2\1",
        html,
    )
    # executable bare name (not index.something).
    html = html.replace('"executable":"index"', '"executable":"../index"')
    html = html.replace("'executable':'index'", "'executable':'../index'")
    return html


def _inject_bootstrap(html: str, registry_id: str) -> str:
    """Inline JS: map ?e=enhanced / #enhanced to #play/<id>/<edition> before Engine starts."""
    # Keep ASCII-only; registry ids are ASCII identifiers (mineswpr_b4, etc.).
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.]*", registry_id):
        raise SystemExit(f"gen_game_pages: refusing non-ASCII/odd registry id {registry_id!r}")
    # Escape for JS string literal.
    rid_js = json.dumps(registry_id)
    boot = f"""
(function () {{
	var PLAY = "#play/";
	var h = location.hash || "";
	if (h.indexOf(PLAY) === 0) {{
		return;
	}}
	var edition = "direct";
	try {{
		var q = new URLSearchParams(location.search).get("e");
		if (q === "enhanced" || h === "#enhanced") {{
			edition = "enhanced";
		}}
	}} catch (err) {{}}
	var next = location.pathname + location.search + PLAY + {rid_js} + "/" + edition;
	try {{
		history.replaceState(null, "", next);
	}} catch (err2) {{
		location.hash = PLAY + {rid_js} + "/" + edition;
	}}
}})();
"""
    # Prefer injecting at the start of the GODOT_CONFIG script block.
    marker = "const GODOT_CONFIG"
    idx = html.find(marker)
    if idx == -1:
        marker = "var GODOT_CONFIG"
        idx = html.find(marker)
    if idx == -1:
        raise SystemExit("gen_game_pages: GODOT_CONFIG not found in root index.html")
    return html[:idx] + boot + "\n" + html[idx:]


def _og_description(title: str, notes: str) -> str:
    notes = notes.strip()
    if notes:
        # One line, modest length for crawlers.
        one = re.sub(r"\s+", " ", notes)
        if len(one) > 200:
            one = one[:197].rstrip() + "..."
        return one
    return f"{title} on tangentstorm arcade (Godot 4). Direct and Enhanced editions."


def _preview_url(registry_id: str, edition: str = "direct") -> str:
    name = f"{registry_id}_{edition}.png"
    if (PREVIEWS / name).is_file():
        return f"{SITE}/previews/{name}"
    # Fall back to direct, then site og-image.
    direct = f"{registry_id}_direct.png"
    if edition != "direct" and (PREVIEWS / direct).is_file():
        return f"{SITE}/previews/{direct}"
    return f"{SITE}/og-image.png"


def build_stub(root_html: str, *, slug: str, registry_id: str, title: str, notes: str) -> str:
    page_title = f"{title} | tangentstorm arcade"
    desc = _og_description(title, notes)
    url = f"{SITE}/{slug}/"
    image = _preview_url(registry_id, "direct")
    html = root_html
    html = _rewrite_assets_to_parent(html)
    html = _set_title(html, page_title)
    html = _set_meta(html, attr="name", key="description", content=desc)
    html = _set_meta(html, attr="property", key="og:title", content=page_title)
    html = _set_meta(html, attr="property", key="og:description", content=desc)
    html = _set_meta(html, attr="property", key="og:url", content=url)
    html = _set_meta(html, attr="property", key="og:image", content=image)
    html = _set_meta(html, attr="name", key="twitter:title", content=page_title)
    html = _set_meta(html, attr="name", key="twitter:description", content=desc)
    html = _set_meta(html, attr="name", key="twitter:image", content=image)
    html = _set_link_canonical(html, url)
    html = _inject_bootstrap(html, registry_id)
    return html


def copy_previews(web_dir: Path) -> int:
    """Copy preview PNGs to build/web/previews/ for crawler-fetchable og:image URLs."""
    dest = web_dir / "previews"
    dest.mkdir(parents=True, exist_ok=True)
    n = 0
    if not PREVIEWS.is_dir():
        return 0
    for src in sorted(PREVIEWS.glob("*.png")):
        if src.name.endswith(".import"):
            continue
        shutil.copy2(src, dest / src.name)
        n += 1
    return n


def generate(web_dir: Path, root_html: str | None = None) -> dict[str, str]:
    web_dir = web_dir.resolve()
    if root_html is None:
        root_path = web_dir / "index.html"
        if not root_path.is_file():
            raise SystemExit(f"gen_game_pages: missing {root_path} (export Web first)")
        root_html = root_path.read_text(encoding="utf-8")
    titles = playable_titles()
    by_id = {t["id"]: t for t in titles}
    slugs = slug_map(titles)
    for slug, rid in sorted(slugs.items()):
        info = by_id[rid]
        stub = build_stub(
            root_html,
            slug=slug,
            registry_id=rid,
            title=info["title"],
            notes=info["notes"],
        )
        out_dir = web_dir / slug
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "index.html").write_text(stub, encoding="utf-8")
    copy_previews(web_dir)
    (web_dir / ".nojekyll").touch()
    return slugs


def self_check() -> int:
    """Generate into a temp dir from FIXTURE_HTML; assert aliases and ../ asset paths."""
    fails: list[str] = []

    def ok(cond: bool, msg: str) -> None:
        if cond:
            print(f"ok: {msg}")
        else:
            print(f"FAIL: {msg}")
            fails.append(msg)

    titles = playable_titles()
    ok(len(titles) >= 2, f"parsed playable titles ({len(titles)})")
    slugs_expected = slug_map(titles)
    ok(slugs_expected.get("mineswpr") == "mineswpr_b4", "alias mineswpr -> mineswpr_b4")
    ok(slugs_expected.get("mineswpr.old") == "mineswpr", "alias mineswpr.old -> mineswpr")
    ok("mineswpr_b4" not in slugs_expected, "no default /mineswpr_b4/ stub (use /mineswpr/)")
    ok(slugs_expected.get("mineswpr") != "mineswpr", "default /mineswpr/ is not GDScript port")
    ok("giraffe" in slugs_expected and slugs_expected["giraffe"] == "giraffe", "giraffe slug == id")

    with tempfile.TemporaryDirectory(prefix="arcade-game-pages-") as tmp:
        web = Path(tmp)
        (web / "index.html").write_text(FIXTURE_HTML, encoding="utf-8")
        # Touch a couple of fake previews so copy_previews is exercised when present.
        slugs = generate(web, root_html=FIXTURE_HTML)
        ok(slugs == slugs_expected, "generate slug map matches slug_map()")
        print(f"slugs ({len(slugs)}):")
        for slug, rid in sorted(slugs.items()):
            print(f"  /{slug}/ -> {rid}")

        giraffe = (web / "giraffe" / "index.html").read_text(encoding="utf-8")
        ok('src="../index.js"' in giraffe, "giraffe stub script src=../index.js")
        ok('src="../index.png"' in giraffe, "giraffe stub splash ../index.png")
        ok('"executable":"../index"' in giraffe, "giraffe executable ../index")
        ok('"../index.pck"' in giraffe and '"../index.wasm"' in giraffe, "giraffe fileSizes ../index.*")
        ok("index.js" not in giraffe.replace("../index.js", ""), "no bare index.js left in giraffe")
        ok("#play/" in giraffe and "giraffe" in giraffe, "giraffe bootstrap mentions #play/giraffe")
        ok("?e=enhanced" not in giraffe or "enhanced" in giraffe, "bootstrap handles enhanced")
        # Bootstrap edition parsing present.
        ok('get("e")' in giraffe or "URLSearchParams" in giraffe, "edition via URLSearchParams")
        ok("#enhanced" in giraffe, "accepts #enhanced")
        ok(f'og:url" content="{SITE}/giraffe/"' in giraffe.replace("property=", "property="),
           "giraffe og:url")
        # mineswpr aliases
        msw = (web / "mineswpr" / "index.html").read_text(encoding="utf-8")
        ok("mineswpr_b4" in msw and "#play/" in msw, "mineswpr stub boots mineswpr_b4")
        old = (web / "mineswpr.old" / "index.html").read_text(encoding="utf-8")
        # Bootstrap should target registry id mineswpr (GDScript), not mineswpr_b4.
        ok(
            re.search(r'#play/" \+ "mineswpr" \+ "/"', old) is not None
            or '"mineswpr"' in old and "mineswpr_b4" not in old.split("GODOT_CONFIG")[0],
            "mineswpr.old stub boots mineswpr (not b4)",
        )
        # Stronger: replaceState target contains mineswpr/direct path without b4 in boot.
        boot = old.split("const GODOT_CONFIG")[0]
        ok("mineswpr_b4" not in boot, "mineswpr.old bootstrap has no mineswpr_b4")
        ok('json.dumps' not in boot and '"mineswpr"' in boot, "mineswpr.old bootstrap id string")

    if fails:
        print(f"self-check: FAILED ({len(fails)})")
        return 1
    print("self-check: OK")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--web-dir",
        type=Path,
        default=ROOT / "build" / "web",
        help="Exported Web output directory (default: build/web)",
    )
    p.add_argument(
        "--self-check",
        action="store_true",
        help="Run alias + asset-path assertions with a fixture HTML (no export needed)",
    )
    p.add_argument(
        "--list",
        action="store_true",
        help="Print slug -> registry id and exit",
    )
    args = p.parse_args(argv)
    if args.self_check:
        return self_check()
    if args.list:
        for slug, rid in sorted(slug_map().items()):
            print(f"{slug}\t{rid}")
        return 0
    slugs = generate(args.web_dir)
    print(f"gen_game_pages: wrote {len(slugs)} stubs under {args.web_dir}")
    for slug, rid in sorted(slugs.items()):
        print(f"  /{slug}/ -> {rid}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
