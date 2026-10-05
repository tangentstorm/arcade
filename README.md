# tangentstorm arcade

Godot 4.7 monorepo: Direct + Enhanced ports of tangentstorm classics, plus OFCP (private build).

**Live (WIP):** https://tangentstorm.github.io/arcade/

## Run locally

```bash
/workspace/tools/godot4 --path .
```

## Web export

```bash
mkdir -p build/web
/workspace/tools/godot4 --headless --path . --export-release "Web" build/web/index.html
```

OFCP Direct ships as a thin WebSocket client to `wss://ofcp.tangentcode.com/ws`; the OFCP rules engine (`games/ofcp/shared/`), golden tests and any AI weights stay out of the public build. See `games/ofcp/README.md`.
