# Tangent Games Arcade

Godot 4.7 monorepo: Direct + Enhanced ports of tangentstorm classics, plus OFCP (private build).

**Live (WIP):** https://tangentstorm.github.io/tangentgames/

## Run locally

```bash
/workspace/tools/godot4 --path .
```

## Web export

```bash
mkdir -p build/web
/workspace/tools/godot4 --headless --path . --export-release "Web" build/web/index.html
```

OFCP rules/AI are excluded from the public Pages build until a private packaging path exists.
