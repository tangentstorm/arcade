# tangentstorm arcade

Godot 4.7 monorepo: Direct + Enhanced ports of tangentstorm classics, plus OFCP (private build).

**Live (WIP):** https://tangentstorm.github.io/arcade/

## Run locally

```bash
/workspace/tools/godot4 --path .
```

Gallery notes: `docs/GALLERY.md`. Before you touch the card grid, read the layout gotchas in `docs/GALLERY_LAYOUT.md` (checked by `tools/test_gallery_layout.gd`).

## Web export

```bash
mkdir -p build/web
/workspace/tools/godot4 --headless --path . --export-release "Web" build/web/index.html
```

The preset uses a slim custom release template (`tools/export_templates/web_nothreads_release_slim.zip`, about half the engine download of the stock one). See `docs/SLIM_WEB_ENGINE.md` for what is compiled out, how to rebuild it, and the browser smoke (`tools/web_smoke/web_smoke.sh`).

OFCP Direct ships as a thin WebSocket client to `wss://ofcp.tangentcode.com/ws`; the OFCP rules engine (`games/ofcp/shared/`), golden tests and any AI weights stay out of the public build. See `games/ofcp/README.md`.
