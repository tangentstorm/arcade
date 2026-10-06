# Slim web engine (custom export template)

The "Web" export preset uses a custom Godot 4.7.2 **release** web template,
`tools/export_templates/web_nothreads_release_slim.zip`, built by
`tools/build_slim_web_template.sh`. It is the stock engine with the 3D physics/XR/navigation
stack and the modules the arcade never uses compiled out. Refs #7.

- The zip (6.1 MB) is **committed**, so CI and Pages ship exactly the bytes that were smoke-tested.
  CI does no emscripten build.
- `variant/extensions_support=false`: the export is one monolithic `index.wasm` (no GDExtension in
  this project), instead of the old `index.wasm` + 44 MB `index.side.wasm` dlink pair.
- The debug template is still the official one (`custom_template/debug=""`).

sha256 of the committed zip: `418cec468a8176005985ccbed0ecf0fd201a17ae5bd6cd302cfdc5cf8c886dac`
(Godot `4.7.2-stable` @ `ed1daf0bf`, Emscripten 4.0.11, `optimize=size_extra lto=none`).

## Sizes (same project, main @ a88963e)

"gz" = gzip -9, which is roughly what GitHub Pages sends (it serves the `.wasm`/`.pck` gzipped).
The "before" numbers match the live https://tangentstorm.github.io/arcade/ files byte for byte.

| File | Before raw | Before gz | After raw | After gz |
|---|---:|---:|---:|---:|
| `index.wasm` | 1,508,095 | 580,694 | 20,521,347 | 6,044,927 |
| `index.side.wasm` | 44,078,870 | 10,474,784 | — | — |
| `index.js` | 2,859,484 | 357,249 | 247,448 | 62,247 |
| `index.pck` | 7,635,404 | 7,206,535 | 7,635,404 | 7,206,535 |
| html + 2 audio worklets | 17,050 | 5,865 | 17,051 | 5,865 |
| **Engine (wasm + js)** | **48,446,449** | **11,412,727** | **20,768,795** | **6,107,174** |
| **KEY total** (wasm+js+pck+html+worklets) | **56,098,903** | **18,625,127** | **28,421,250** | **13,319,574** |

Engine: −27.7 MB raw (−57%), −5.3 MB gzip (−46%). KEY total: −49% raw, −28.5% gzip.
`index.pck` is unchanged here and became the biggest download; see the pck diet below.

## pck diet (main @ a06510a)

More games landed after the table above, so the pck had grown to 9.1 MB gz. Two changes:

1. **Gallery previews** (`arcade/previews/*.png`): 1280×720 → 640×360 (cards are 260–400 px
   wide), opaque RGB, `pngquant --quality 70-95` + `optipng -o5`. Sources 3.3 MB → 0.65 MB.
   `tools/capture_previews.gd` now saves at 640×360 so new captures stay small.
2. **Shep 800×575 art** (`games/shep/direct/assets/{bg*,fg*,blank_overlay}.png`, `screens/*.png`,
   25 files): imported as lossy WebP (`compress/mode=1`, `lossy_quality=0.8`) instead of lossless.
   Their `.png.import` files are committed (un-ignored in `.gitignore`) so CI uses the same
   settings. Sources are untouched; side-by-side at q80 shows no visible difference.

| | pck raw | pck gz | KEY raw | KEY gz |
|---|---:|---:|---:|---:|
| Before (main @ a06510a) | 9,728,188 | 9,142,190 | 30,514,499 | 15,272,322 |
| + previews 640×360 | 8,418,764 | 7,862,802 | 29,205,075 | 13,992,934 |
| + shep lossy WebP | 6,304,460 | 5,746,475 | 27,090,771 | **11,876,606** |

KEY gz is now **11.9 MB, under the PLAYBOOK 12 MB gate** (≈120 KB headroom). Next levers if a
new game pushes it over: lossy import for other large painted art (ld48 `tiles.png`, cupid
`bg-00.png`), or re-encoding the two big mp3s (shep `wah-danube.mp3` 0.96 MB, spiders
`sva-music.mp3` 0.66 MB). Pixel-art textures should stay lossless.

If an existing checkout already has untracked versions of those 25 `.import` files, `git pull`
refuses to overwrite them: delete them first (`rm games/shep/direct/assets/{bg,fg}*.png.import
games/shep/direct/assets/blank_overlay.png.import games/shep/direct/assets/screens/*.png.import`).

Variants measured on the way (engine `.wasm` only):

| Variant | raw | gz | Notes |
|---|---:|---:|---|
| Official template, dlink (old main) | 45,586,965 | 11,055,478 | `index.wasm` + `index.side.wasm` |
| Official template, monolithic | 39,514,754 | 10,054,758 | `extensions_support=false` only |
| **Slim, lto=none (shipped)** | **20,521,347** | **6,044,927** | flags below |
| Slim, lto=thin | 21,779,165 | 6,317,935 | thin LTO inlines more → **bigger**; not used |
| Slim + `disable_3d=yes` | 19,032,946 | 5,629,576 | breaks fnarb_binary_adder (see below); not used |

`lto=full` was not tried again: the link OOMs on the 16 GB box.

## What is disabled

| Flag(s) | Why it's safe |
|---|---|
| `disable_physics_3d`, `disable_navigation_3d`, `disable_xr`; modules `godot_physics_3d`, `jolt_physics`, `navigation_3d`, `openxr`, `mobile_vr`, `webxr`, `gltf`, `fbx`, `csg`, `gridmap`, `meshoptimizer`, `vhacd`, `raycast`, `lightmapper_rd`, `xatlas_unwrap` | No 3D physics, nav, XR, or 3D asset import anywhere in `arcade/` or `games/` |
| `module_text_server_adv=no` (fallback text server only) | All arcade text is Latin; no BiDi/complex shaping. Fonts still load (freetype on) |
| `disable_navigation_2d` | No `Navigation*` usage |
| modules `theora`, `webrtc`, `enet`, `upnp`, `msdfgen`, `noise`, `camera`, `jsonrpc`, `interactive_music`, `multiplayer`, `regex`, `visual_shader`, `zip`, `objectdb_profiler` | No references (grep below); no font imports use MSDF |
| modules `basis_universal`, `ktx`, `dds`, `tga`, `hdr`, `bmp`, `jpg`, `tinyexr`, `astcenc`, `etcpak`, `cvtt`, `betsy`, `bcdec`, `glslang` | Runtime image loaders/encoders: textures ship as ctex (lossless, or lossy WebP for shep art) and there are no jpg/tga/bmp/hdr/exr/dds/ktx/basis files |
| `module_mbedtls=no` | On the web `WebSocketPeer` uses the browser's WebSocket, which does `wss://` itself. Verified: OFCP's `wss://ofcp.tangentcode.com/ws` reaches `STATE_OPEN` |

**Kept on purpose:** 3D *rendering* classes (`disable_3d` stays off: `games/fnarb_binary_adder`
uses `WorldEnvironment` for its 2D canvas glow and colour adjustment, and with `disable_3d=yes`
the browser logs `Cannot get class 'WorldEnvironment'` and the effect is lost), 2D physics,
websocket, mp3/ogg/vorbis, freetype, svg (default theme icons), webp/png, gdscript, advanced GUI
(CodeEdit, RichTextLabel, ItemList, LineEdit, OptionButton are used).

Audit grep (run on main, empty result except comments):

```sh
rg -l -g '!**/source/**' --type-add 'g:*.{gd,tscn,tres,godot,cfg}' -t g \
  -e '\b(RegEx|FastNoiseLite|Noise\w*|Navigation\w*|VisualShader\w*|ZIPReader|ZIPPacker|Crypto|HMACContext|X509Certificate|StreamPeerTLS|ENet\w*|WebRTC\w*|UPNP\w*|JSONRPC|VideoStream\w*|AudioStream(Synchronized|Playlist|Interactive)|SceneMultiplayer|Multiplayer(Spawner|Synchronizer)|CameraFeed|GLTF\w*|OpenXR\w*|XRServer|HTTPRequest|HTTPClient)\b' .
```

If a new game needs one of these, flip its flag in `tools/build_slim_web_template.sh`, rebuild,
commit the new zip, and re-run the browser smoke.

## Verification

1. `GODOT=/workspace/tools/godot4 ./tools/smoke_headless.sh` → `smoke: OK` (editor-side, unchanged).
2. `GODOT=/workspace/tools/godot4 ./tools/web_smoke/web_smoke.sh` exports a temp copy of the project
   with the slim template plus an injected `web_smoke.gd` autoload, serves it gzipped, and loads it
   in headless Chrome (SwiftShader WebGL). It checks the needed classes exist, opens every playable
   scene (32), opens the OFCP wss:// socket, and fails on any console error. Result:
   `WEBSMOKE DONE failures=0 scenes=32`, `wss state=1 (OPEN)`, 0 console errors.
3. Plain export served with `python3 -m http.server`: `index.html` (title "tangentstorm arcade")
   lists only `index.pck` and `index.wasm` in `fileSizes`, and all files return 200.

## Rebuilding

```sh
JOBS=6 ./tools/build_slim_web_template.sh       # clones Godot + emsdk into .cache/ (gitignored)
# or reuse existing checkouts:
GODOT_SRC=/workspace/godot EMSDK=/workspace/emsdk JOBS=6 ./tools/build_slim_web_template.sh
```

A clean build takes about 5–6 min with `-j6` on the box and fit in the ~4 GB of RAM that was free.
When bumping Godot, update `GODOT_TAG`/`GODOT_COMMIT` (must match the editor's commit) and
`GODOT_VERSION` in `.github/workflows/pages.yml` together.
