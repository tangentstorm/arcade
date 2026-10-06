#!/usr/bin/env bash
# pages-deploy-smoke: is the live site up, and is it the build we expect?
# Usage: pages.sh [expected-sha]   (default: origin/main)
# Evidence -> $RUN/pages-{index.html,headers.txt,deploy.txt}
source "$(dirname "$0")/lib.sh"
RUN="$(run_dir)"
bust="nocache=$(date +%s)"
status=0
curl -sS -D "$RUN/pages-index.headers" -o "$RUN/pages-index.html" "${PAGES_URL}?$bust"
: >"$RUN/pages-headers.txt"
for f in index.html index.pck index.wasm index.js; do
	echo "## $f" >>"$RUN/pages-headers.txt"
	curl -sSI "${PAGES_URL}$f?$bust" | grep -iE "^(HTTP|etag|last-modified|cache-control|content-length|age|x-cache)" >>"$RUN/pages-headers.txt"
done
cat "$RUN/pages-headers.txt"
grep -q "^HTTP/[0-9.]* 200" "$RUN/pages-index.headers" || { echo "pages: index not 200"; status=1; }
grep -qi "<title>" "$RUN/pages-index.html" && echo "title: $(grep -oi '<title>[^<]*' "$RUN/pages-index.html" | head -1 | sed 's/<title>//I')"
git -C "$ROOT" fetch -q origin main gh-pages
want="${1:-$(git -C "$ROOT" rev-parse origin/main)}"
msg="$(git -C "$ROOT" log -1 --format='%s (%cI)' origin/gh-pages)"
echo "gh-pages: $msg" | tee "$RUN/pages-deploy.txt"
echo "expected: Deploy $want" | tee -a "$RUN/pages-deploy.txt"
case "$msg" in "Deploy $want"*) echo "pages: deployed build matches";; *) echo "pages: gh-pages is NOT $want (deploy pending or failed?)"; status=1;; esac
echo "pages: $([ $status -eq 0 ] && echo PASS || echo FAIL) (evidence $RUN)"
exit $status
