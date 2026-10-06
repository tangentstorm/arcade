#!/usr/bin/env bash
# Rebuild the slim Godot web export template used by the "Web" export preset.
#
# Output: tools/export_templates/web_nothreads_release_slim.zip (committed, so CI and
# Pages use exactly the bytes that were smoke-tested). Re-run this script and commit the
# new zip when the Godot version or the flags below change. See docs/SLIM_WEB_ENGINE.md.
#
# Env overrides:
#   GODOT_SRC  Godot source checkout (cloned at $GODOT_TAG if missing)  [default: .cache/godot-src]
#   EMSDK      emsdk checkout (installed at $EM_VERSION if missing)     [default: .cache/emsdk]
#   JOBS       scons -j                                                [default: 4]
#
# Do NOT switch to lto=full: the link OOMs on a 16 GB box. lto=thin works, but on this
# template it makes the wasm ~6% BIGGER (21.78 MB vs 20.52 MB), so we use lto=none.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_TAG="${GODOT_TAG:-4.7.2-stable}"
GODOT_COMMIT="ed1daf0bf"            # must match the editor: 4.7.2.stable.official.ed1daf0bf
EM_VERSION="${EM_VERSION:-4.0.11}"  # the Emscripten that Godot 4.7's own web CI uses
GODOT_SRC="${GODOT_SRC:-$ROOT/.cache/godot-src}"
EMSDK="${EMSDK:-$ROOT/.cache/emsdk}"
JOBS="${JOBS:-4}"
OUT="$ROOT/tools/export_templates/web_nothreads_release_slim.zip"

# Keep in sync with the table in docs/SLIM_WEB_ENGINE.md.
# Must stay ENABLED (used by the arcade): 2D physics, 3D *rendering* classes (fnarb_binary_adder
# uses WorldEnvironment for 2D canvas glow; disable_3d=yes would drop it), websocket (OFCP),
# mp3/ogg/vorbis, freetype, svg (default theme icons), webp/png, gdscript, text_server_fb,
# advanced GUI (CodeEdit, RichTextLabel, ItemList, LineEdit, OptionButton).
SCONS_FLAGS=(
  platform=web target=template_release threads=no
  optimize=size_extra debug_symbols=no lto=none
  # 3D physics / 3D navigation / XR (3D rendering classes stay; see above)
  disable_physics_3d=yes disable_navigation_3d=yes disable_xr=yes
  module_gltf_enabled=no module_fbx_enabled=no module_csg_enabled=no module_gridmap_enabled=no
  module_meshoptimizer_enabled=no module_vhacd_enabled=no module_raycast_enabled=no
  module_navigation_3d_enabled=no module_godot_physics_3d_enabled=no module_jolt_physics_enabled=no
  module_openxr_enabled=no module_mobile_vr_enabled=no module_webxr_enabled=no
  module_lightmapper_rd_enabled=no module_xatlas_unwrap_enabled=no
  # Text: fallback text server only (no BiDi / complex shaping; all arcade text is Latin)
  module_text_server_adv_enabled=no module_text_server_fb_enabled=yes
  # Unused runtime features (no references in arcade/ or games/; see doc for the grep)
  disable_navigation_2d=yes
  module_theora_enabled=no module_webrtc_enabled=no module_enet_enabled=no module_upnp_enabled=no
  module_msdfgen_enabled=no module_noise_enabled=no module_camera_enabled=no module_jsonrpc_enabled=no
  module_interactive_music_enabled=no module_multiplayer_enabled=no module_regex_enabled=no
  module_visual_shader_enabled=no module_zip_enabled=no module_objectdb_profiler_enabled=no
  # Image/texture codecs not needed at runtime (textures ship as lossless ctex)
  module_basis_universal_enabled=no module_ktx_enabled=no module_dds_enabled=no module_tga_enabled=no
  module_hdr_enabled=no module_bmp_enabled=no module_jpg_enabled=no module_tinyexr_enabled=no
  module_astcenc_enabled=no module_etcpak_enabled=no module_cvtt_enabled=no module_betsy_enabled=no
  module_bcdec_enabled=no module_glslang_enabled=no
  # TLS: on the web, WebSocketPeer uses the browser's WebSocket, which does wss:// itself
  module_mbedtls_enabled=no
)

if [ ! -x "$EMSDK/emsdk" ]; then
  git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$EMSDK"
fi
"$EMSDK/emsdk" install "$EM_VERSION" >/dev/null
"$EMSDK/emsdk" activate "$EM_VERSION" >/dev/null
# shellcheck disable=SC1091
source "$EMSDK/emsdk_env.sh" >/dev/null 2>&1
emcc --version | sed -n 1p

if [ ! -d "$GODOT_SRC/.git" ] && [ ! -f "$GODOT_SRC/.git" ]; then
  git clone --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$GODOT_SRC"
fi
got="$(git -C "$GODOT_SRC" rev-parse --short=9 HEAD)"
[ "$got" = "$GODOT_COMMIT" ] || { echo "Godot source is $got, expected $GODOT_COMMIT ($GODOT_TAG)" >&2; exit 1; }

if command -v scons >/dev/null; then SCONS=(scons); else
  python3 -m pip install --user scons 2>/dev/null || python3 -m pip install --user --break-system-packages scons
  SCONS=(python3 -m SCons)
fi
(cd "$GODOT_SRC" && "${SCONS[@]}" "${SCONS_FLAGS[@]}" -j"$JOBS")

mkdir -p "$ROOT/.cache" && touch "$ROOT/.cache/.gdignore"
cp "$GODOT_SRC/bin/godot.web.template_release.wasm32.nothreads.zip" "$OUT"
ls -l "$OUT"
sha256sum "$OUT"
