# tangentstorm/arcade — Architecture

**Status:** Proposed layout for a **single** Godot 4 arcade app (monorepo).  
**Companion:** [`PLAYBOOK.md`](./PLAYBOOK.md) · [`DECISION_LOG.md`](./DECISION_LOG.md)  
**Date:** 2026-10-05 (America/New_York)

---

## 1. Goals

- One browser URL hosts many old games, each as **direct** + **enhanced** editions.
- Shared **arcade shell** only: title menu, picker, pause, return. Games keep their own look.
- **Vendored** assets (copies with source attribution) — **no git submodules** (they break shallow Pages/CI clones).
- Web-first: nothreads export, minimal/stripped engine surface, CI → GitHub Pages WIP.
- Levers: registration schema + `GameHost` lifecycle + vendor/CI scripts — not N hand-wired menus.

---

## 2. Proposed repository layout

```
arcade/                            # repo root (formerly tangentgames)
  README.md
  LICENSE                          # MIT (confirm in decision log)
  DECISION_LOG.md
  project.godot                    # single project; gl_compatibility
  export_presets.cfg               # Web (minimal)
  icon.svg

  arcade/                          # shared shell only
    main.tscn                      # root: hosts menus + GameHost
    title_menu.tscn
    game_picker.tscn
    pause_overlay.tscn
    game_host.gd                   # loads/unloads edition scenes
    arcade_catalog.gd              # autoload: discovers manifests
    theme/                         # optional shell chrome only (not forced on games)
      shell_theme.tres

  autoload/
    # Prefer registering via project.godot:
    # ArcadeCatalog, ArcadeAudio (optional mute), SceneRelay

  games/
    _fixture/                      # Phase B stub — keep until CI uses real titles
      manifest.tres
      direct/
        main.tscn
        entry.gd
      enhanced/
        main.tscn
        entry.gd
    ld48/                          # example slug
      PORT.md                      # source repo + commit SHA + omissions
      manifest.tres
      direct/
        main.tscn
        …vendored/adapted scenes…
      enhanced/
        main.tscn
        …
    mineswpr/
      …
    <slug>/
      manifest.tres
      direct/
      enhanced/

  shared/                          # truly cross-cutting libs ONLY (rare)
    # e.g. input_helpers.gd — do NOT put visual themes here for “consistency”

  tools/
    vendor_from.sh                 # copy files from a cloned source into games/<slug>/…
    dump_catalog.gd                # headless catalog listing
    measure_key_size.py            # gzip/brotli KEY download stats
    smoke_http.sh                  # local server + curl MIME checks

  build/                           # gitignored export output
    web/
      index.html
      index.js
      index.wasm
      index.pck
      …

  evidence/                        # phase proofs (or .gitignore large PNGs)
  .github/
    workflows/
      pages.yml                    # export + deploy gh-pages / Pages artifact
  .gitignore                       # build/, .godot/, *.translation caches, etc.
```

**Single `project.godot`.** Do not make each game its own Godot project — the arcade is one export, one wasm.

---

## 3. Arcade shell behavior

```
[TitleMenu] --Start--> [GamePicker] --Select edition--> [GameHost loads edition]
                              ^                                |
                              |         Pause / Return         |
                              +--------------------------------+
```

| Surface | Responsibility |
|---------|----------------|
| **Title menu** | Splash, Start, optional Credits/Mute |
| **Game picker** | Lists catalog entries; filters WIP vs ready; chooses `direct` vs `enhanced` |
| **Pause overlay** | Shell-owned (Esc); does not assume game UI; game receives `edition_pause()` |
| **Return to arcade** | `GameHost.unload()` → free edition tree → picker; restore shell InputMap |
| **GameHost** | Parent node for the active edition; sole owner of load/unload |

Games **must not** change `get_tree().change_scene_to_*` to escape the arcade; they call `GameHost.request_return()` or emit a signal the host connects.

---

## 4. How editions register with the shell

### 4.1 Manifest (per slug)

`games/<slug>/manifest.tres` (Resource) — suggested fields:

| Field | Type | Purpose |
|-------|------|---------|
| `slug` | String | Stable id (`ld48`) |
| `title` | String | Display name |
| `blurb` | String | One-liner for picker |
| `source_url` | String | Original repo or live demo |
| `source_commit` | String | Vendored SHA (direct) |
| `direct_scene` | PackedScene / path | `res://games/<slug>/direct/main.tscn` |
| `enhanced_scene` | PackedScene / path | may be empty until enhanced exists |
| `direct_ready` | bool | Picker enable |
| `enhanced_ready` | bool | Picker enable |
| `tags` | PackedStringArray | optional (`ld`, `godot-native`, …) |
| `sort_key` | int | Picker order |

### 4.2 Discovery

`ArcadeCatalog` autoload on boot:

1. Scan `res://games/*/manifest.tres` (DirAccess; skip `_` only if desired — `_fixture` may stay visible in debug builds).
2. Validate paths exist when `*_ready` is true.
3. Expose `list_editions() -> Array[EditionInfo]` for the picker.

**No** central handwritten array of every game in UI code. Adding a title = add folder + manifest (+ CI picks it up automatically).

### 4.3 Edition entry API

Each edition root script implements (duck-typed or via shared `EditionEntry` base):

```gdscript
# games/<slug>/<edition>/entry.gd  (attached to main.tscn root)
extends Node  # or Control / Node2D as needed
class_name EditionEntry  # optional global class

signal request_return

func edition_ready() -> void:
    # focus / start music after host adds child
    pass

func edition_pause() -> void:
    get_tree().paused = true  # or local pause; document choice in PORT.md
    pass

func edition_resume() -> void:
    get_tree().paused = false
    pass

func edition_exit() -> void:
    # stop audio, disconnect; host will queue_free
    pass
```

`GameHost` sequence:

1. `instantiate(manifest.direct_scene)` (or enhanced).
2. `add_child`, call `edition_ready()`.
3. On Esc: show shell pause → `edition_pause()`.
4. On Resume: hide pause → `edition_resume()`.
5. On Return: `edition_exit()` → `queue_free()` → show picker.

### 4.4 InputMap hygiene

- Shell actions prefixed `arcade_*` (`arcade_pause`, `arcade_confirm`, …).
- Games use their own action names; on unload, host removes any actions the edition registered **or** editions only use physical key checks / local maps that die with the node.
- **Verify:** after return, Esc opens shell pause only when a game is loaded; on picker, Esc is inert or “back to title”.

---

## 5. Asset import policy (vendored copies)

| Do | Don't |
|----|-------|
| Copy needed sources into `games/<slug>/…` | Git submodules for game content |
| Record origin in `PORT.md` (repo URL + commit + license) | Assume Pages will `git clone --recursive` |
| Run `tools/vendor_from.sh <src> <dest>` so copies are repeatable | Manually drag without SHA note |
| Commit Godot `.import` outputs as required by team practice **or** regenerate in CI before export (pick one; log it) | Link `res://` into directories outside the repo |

**Submodules break Pages** when Actions uses sparse/shallow checkouts or when humans forget `--recursive`. Vendoring keeps one tree, one zip, one export.

**Binary assets:** prefer lossless masters in-repo only if small; otherwise vendor compressed textures already sized for Web. Re-import with Web-friendly compression in Godot.

**Upstream updates:** bump by re-running vendor script → diff → update `source_commit` in manifest + PORT.md (not `git submodule update`).

---

## 6. Export presets (Web — minimal / stripped)

Align with proven `/workspace/b4-gd` + `/workspace/b4-godot-dig` practice unless decision log overrides.

### 6.1 Preset: `Web` (runnable)

| Option | Value | Why |
|--------|-------|-----|
| Platform | Web | Pages target |
| `variant/thread_support` | **false** | No COOP/COEP; static hosting Just Works |
| Renderer (project) | `gl_compatibility` | WebGL2-friendly, matches b4-gd |
| Export path | `build/web/index.html` | Relative sibling wasm/js/pck |
| Export filter | `all_resources` initially; tighten with exclude later | Simpler until pack bloats |
| Custom HTML shell | none (stock shell) | Loading-screen branding = boot splash + `head_include` CSS; see `GALLERY.md` |
| PWA | **off** | Avoid service-worker cache surprises on WIP |
| `custom_template/release` | empty → official; later → slim zip | Phase E |

### 6.2 Strip levers (prefer essentials)

Operator preference: packager/path that **strips Godot to essentials**. Concrete ladder:

1. **Official nothreads release template** (Phase A default) — zero maintenance.
2. **Compression verification** on Pages (curl `Content-Encoding`) — largest UX win for free.
3. **Custom template** (Phase E): SCons `platform=web threads=no optimize=size_extra disable_3d=yes` + module allowlist / `.gdbuild` build profile — see `b4-godot-dig/SLIM-BUILD.md`.
4. Optional `wasm-opt` post-pass — measure before adopting.

There is no separate third-party “JS packager” required for Godot 4; the export **is** the JS+wasm loader. “Strip” means **custom web template + feature/modules off**, not a different bundler. If a community strip tool is later preferred, log it and keep the same `build/web/` artifact contract.

### 6.3 MIME / headers (Pages)

GitHub Pages serves static files; nothreads needs **no** COOP/COEP. Confirm:

| Ext | Expect |
|-----|--------|
| `.wasm` | `application/wasm` (or acceptable fallback documented) |
| `.js` | javascript |
| `.pck` | octet-stream |

All asset URLs in `index.html` must stay **relative** so the app works under `/arcade/`.

---

## 7. CI for GitHub Pages WIP

### 7.1 Workflow sketch (`.github/workflows/pages.yml`)

```yaml
name: pages-wip
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Cache Godot + templates
        uses: actions/cache@v4
        with:
          path: |
            ~/.local/share/godot/export_templates
            ~/godot
          key: godot-4.7.2-web-nothreads
      - name: Install Godot 4.7.2 + web templates
        run: |
          set -euo pipefail
          # download official Linux editor + export templates zip for 4.7.2
          # unpack templates to ~/.local/share/godot/export_templates/4.7.2.stable/
          # exact URLs pinned in-repo under tools/ci/ once implemented
      - name: Export Web
        run: |
          ~/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
            --export-release "Web" build/web/index.html
      - name: Measure KEY size
        run: python3 tools/measure_key_size.py build/web
      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy:
    needs: export
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

**Notes**

- Pin Godot **patch** version in cache key and decision log.
- Fail the job if `index.wasm` missing or KEY gzip exceeds gate (env `KEY_GZIP_MAX_BYTES`).
- WIP is fine: broken games stay `*_ready=false` so picker hides them; CI still exports shell + ready editions.

### 7.2 Local parity (box)

```bash
GODOT=/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path /path/to/arcade \
  --export-release "Web" build/web/index.html
python3 tools/measure_key_size.py build/web
(cd build/web && python3 -m http.server 8765)
```

### 7.3 Repo / Pages settings (when creating repo)

- Settings → Pages → Deploy from **GitHub Actions** (preferred) or `gh-pages` branch.
- Site: `https://tangentstorm.github.io/arcade/`
- Do **not** enable forced HTTPS-only quirks that break local smoke; Pages is already HTTPS.

---

## 8. Fan-out seams (implementation detail)

| Path glob | Parallel? | Contract |
|-----------|-----------|----------|
| `games/<slug>/**` | Yes, one slug per worker | Manifest valid; implements EditionEntry; PORT.md present |
| `arcade/**` | **No** (serial) | Host API stable; changelog in decision log if broken |
| `tools/**` | Cautious PRs | Must not require network at export time |
| `.github/workflows/**` | Serial | Pin versions; no secrets beyond Pages token |

---

## 9. Non-goals / anti-patterns

- One Godot project per game with a meta-launcher (multiplies wasm downloads).
- Shared “arcade skin” forced onto enhanced editions.
- Submodules or LFS-only workflows that CI cannot fetch without tokens.
- Threaded Web export “for speed” on Pages without documenting COOP/COEP (reject unless decision log + custom headers story).
- Mass-cloning every legacy repo before Phase C needs a source.

---

## 10. Open points (resolve in DECISION_LOG before coding)

1. First real slug for Phase C (`ld48` vs `mineswpr` vs other).
2. Manifest format: `.tres` Resource vs `manifest.json` (JSON is friendlier to non-Godot tooling; `.tres` is native).
3. Whether `.import` files are committed or regenerated in CI.
4. License for vendored Flash/AS3 assets vs code (cupid private).
5. When to schedule custom slim wasm vs ship official template indefinitely.
