#!/usr/bin/env bash
# Pages proof doctor: record cache-bust + pack etag/stamp next to shots,
# or refuse a "fixed"/Pages-proof claim without that evidence.
#
#   pages_doctor.sh [--viewport WxH] [--out name]
#       Write $RUN/<name>.txt (default pages-proof.txt). Exit 0 on capture.
#   pages_doctor.sh --require [run-dir|proof-file]
#       Gate: exit 0 only if proof has cache-bust URL + pack etag + build stamp.
source "$(dirname "$0")/lib.sh"

require_mode=0
viewport="1280x720"
out_name="pages-proof"
require_target=""

while [ $# -gt 0 ]; do
	case "$1" in
	--require)
		require_mode=1
		shift
		# Optional path: only consume if it does not look like a flag.
		if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
			require_target="$1"
			shift
		fi
		;;
	--viewport)
		viewport="${2:?pages_doctor: --viewport needs WxH}"
		shift 2
		;;
	--out)
		out_name="${2:?pages_doctor: --out needs a name}"
		shift 2
		;;
	-h|--help)
		sed -n '2,10p' "$0"
		exit 0
		;;
	*)
		echo "pages_doctor: unknown arg: $1" >&2
		exit 2
		;;
	esac
done

# --- gate: refuse "fixed" without cache-bust + etag/stamp ---
if [ "$require_mode" -eq 1 ]; then
	RUN="$(run_dir)"
	f=""
	if [ -n "$require_target" ] && [ -f "$require_target" ]; then
		f="$require_target"
	elif [ -n "$require_target" ] && [ -d "$require_target" ]; then
		f="$require_target/pages-proof.txt"
	else
		f="$RUN/pages-proof.txt"
	fi
	hint='run: $H/pages_doctor.sh [--viewport WxH]  (writes pages-proof.txt)'
	fail() { echo "proof_gate: REFUSE fixed — $*"; echo "proof_gate: need $hint"; exit 1; }
	[ -f "$f" ] || fail "missing proof file: $f"
	cb="$(grep -E '^cache_bust_url:' "$f" | head -1 | sed 's/^cache_bust_url:[[:space:]]*//')"
	et="$(grep -E '^pack_etag:' "$f" | head -1 | sed 's/^pack_etag:[[:space:]]*//')"
	st="$(grep -E '^build_stamp:' "$f" | head -1 | sed 's/^build_stamp:[[:space:]]*//')"
	case "$cb" in *nocache=*) ;; *) fail "cache_bust_url missing or has no ?nocache=: '$cb'";; esac
	case "$et" in ""|"-"|"missing") fail "pack_etag missing: '$et'";; esac
	case "$st" in ""|"-"|"missing"*) fail "build_stamp missing: '$st'";; esac
	echo "proof_gate: OK ($f)"
	echo "  cache_bust_url: $cb"
	echo "  pack_etag: $et"
	echo "  build_stamp: $st"
	exit 0
fi

# --- record sidecar next to proof artifacts ---
RUN="$(run_dir)"
bust="nocache=$(date +%s)"
base="${PAGES_URL%/}"
cb_url="${PAGES_URL}?$bust"
pack_url="$base/index.pck?$bust"
hdr="$RUN/.pages-doctor-pack.headers"
curl -sSI --max-time 30 "$pack_url" >"$hdr" || true
etag="$(grep -i '^etag:' "$hdr" | head -1 | sed 's/^[Ee][Tt][Aa][Gg]:[[:space:]]*//;s/[[:space:]]*$//')"
lmod="$(grep -i '^last-modified:' "$hdr" | head -1 | sed 's/^[Ll]ast-[Mm]odified:[[:space:]]*//;s/[[:space:]]*$//')"
clen="$(grep -i '^content-length:' "$hdr" | head -1 | sed 's/^[Cc]ontent-[Ll]ength:[[:space:]]*//;s/[[:space:]]*$//')"
[ -n "$etag" ] || etag="missing"
git -C "$ROOT" fetch -q origin gh-pages 2>/dev/null || true
stamp="$(git -C "$ROOT" log -1 --format='%s (%cI)' origin/gh-pages 2>/dev/null || true)"
[ -n "$stamp" ] || stamp="missing (no origin/gh-pages)"
build_stamp="$stamp"
case "$stamp" in
missing*)
	if [ -n "$lmod" ]; then build_stamp="last-modified: $lmod"; fi
	;;
esac
out="$RUN/${out_name}.txt"
captured="$(date --iso-8601=seconds 2>/dev/null || date -Iseconds 2>/dev/null || date)"
{
	echo "# pages-proof — refuse \"fixed\" without cache-bust + etag/stamp"
	echo "viewport: $viewport"
	echo "cache_bust_url: $cb_url"
	echo "pack_url: $pack_url"
	echo "pack_etag: $etag"
	echo "pack_last_modified: ${lmod:-missing}"
	echo "pack_content_length: ${clen:-missing}"
	echo "build_stamp: $build_stamp"
	echo "captured_at: $captured"
} >"$out"
rm -f "$hdr"
echo "pages_doctor: wrote $out"
cat "$out"
case "$etag" in
missing)
	echo "pages_doctor: FAIL (no pack etag)"
	exit 1
	;;
esac
exit 0
