# Pages deploy smoke

Every push to `main` runs `.github/workflows/pages.yml`: smoke test, Web export, force-push of
`build/web` to `gh-pages`, served at https://tangentstorm.github.io/arcade/. A user opening that
URL gets the gallery for the latest `main` commit.

## Sub-features

- `pages-up` `index.html` (title `tangentstorm arcade`), `index.pck`, `index.wasm`, `index.js` all return 200.
- `pages-current` the `gh-pages` head commit is `Deploy <origin/main sha>`.
- `pages-fresh` cache-busted fetches show the new `last-modified`/`etag` after a deploy.
- `pages-renders` (optional, browser) the gallery canvas renders and cards are clickable.

## How to get to it (user POV)

- Open https://tangentstorm.github.io/arcade/ in a browser (fresh profile/Incognito for a new build).
- Share the URL (og-image at `/arcade/og-image.png`).

## Driving it with pages.sh (curl + git)

Preconditions:

- Network to github.io and github.com; `git fetch` works in the checkout.
- For a just-merged change: the `Build Web & Deploy Pages` run for that sha finished
  (`gh run list -w "Build Web & Deploy Pages" -L 3` or the GitHub MCP `actions_list`).

- **Site up + build match.** Run `$H/pages.sh` (or `$H/pages.sh <sha>`). Prints headers per
  file, `title: tangentstorm arcade`, `gh-pages: Deploy <sha> (<UTC time>)`, `pages: deployed build matches`, `pages: PASS`.
- **Cache-bust proof.** Compare `last-modified` / `etag` of `index.pck` in `pages-headers.txt`
  to the gh-pages commit time; `age:` > 0 with `x-cache: HIT` means a CDN copy — the `?nocache=`
  query avoids it for curl.
- **Local equivalent of the artifact.** `mkdir -p build/web && /workspace/tools/godot4 --headless --path . --export-release "Web" build/web/index.html` (needs 4.7.2 export templates).
- **Rendered (optional, browser agent).** Open `https://tangentstorm.github.io/arcade/?nocache=<epoch>` in a fresh profile, wait for the gallery, screenshot to the run dir.
- **Proof.** `pages-headers.txt`, `pages-deploy.txt`, `pages-index.html`.

## Gotchas

- Pages sends `cache-control: max-age=600`; a normal reload can serve the previous build for 10
  minutes. The pck URL is not versioned — browsers may mix old pck with new html. Use Incognito or `?nocache=`.
- gh-pages is force-pushed with a single commit; its message is the only build stamp. The commit time is UTC — convert before reporting.
- `concurrency: cancel-in-progress` means rapid pushes skip deploys; a mismatch may be "pending", not "failed" — check the workflow run.
- curl 200 is not rendering proof (wasm/WebGL can still white-screen); say "served", not "works", without a browser screenshot.
