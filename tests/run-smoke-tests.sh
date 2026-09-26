#!/bin/sh
# wkhtmltopdf smoke tests.
#
# These are intentionally shallow: they prove that the binaries start, render,
# and produce structurally valid output on the current platform. They are not a
# substitute for comparing rendered output against known-good PDFs, which is
# what the layout-fidelity work needs.
#
# Usage: tests/run-smoke-tests.sh [path-to-bin-dir]
#
# Requires: pdftotext and pdfinfo (poppler-utils / poppler).

set -eu

BIN_DIR="${1:-./bin}"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SMOKE="$HERE/smoke"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

WKT="$BIN_DIR/wkhtmltopdf"
WKTIMG="$BIN_DIR/wkhtmltoimage"

# The test suite asserts on marker strings, and a missing font would silently
# turn every PDF into an empty one -- which is exactly the kind of failure that
# is invisible unless you check.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
export QTWEBKIT_DISABLE_COMPOSITING_MODE=1

# The binaries and libwkhtmltox.so are built side by side into ./bin, and the
# link line records no rpath for it, so the loader cannot find the library from
# the build tree unaided. The project's own `make install` man target works
# around this the same way. Installed builds put the library on the default
# search path instead, so this is only needed for an uninstalled build.
LD_LIBRARY_PATH="$BIN_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# Report *why* a binary would not start. The usual cause is a library the
# loader cannot find, and "exit status 1" on its own tells you nothing.
diagnose() {
    _bin=$1
    echo "--- ldd $_bin ---" >&2
    ldd "$_bin" 2>&1 | sed 's/^/    /' >&2 || true
    _missing=$(ldd "$_bin" 2>/dev/null | grep -c "not found" || true)
    if [ "${_missing:-0}" -gt 0 ]; then
        echo "--- $_missing library/ libraries not found by the loader ---" >&2
    fi
}

pass() {
    echo "ok: $*"
}

need() {
    command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

# assert_pdf_text <pdf> <expected-marker> [forbidden-marker]
assert_pdf_text() {
    _pdf=$1
    _want=$2
    _forbid=${3:-}
    [ -s "$_pdf" ] || fail "$_pdf is empty or missing"
    head -c 5 "$_pdf" | grep -q '%PDF-' || fail "$_pdf is not a PDF"

    _txt="$WORK/$(basename "$_pdf").txt"
    pdftotext "$_pdf" "$_txt" 2>/dev/null || fail "pdftotext failed on $_pdf"

    if ! grep -q "$_want" "$_txt"; then
        echo "--- extracted text of $_pdf ---" >&2
        cat "$_txt" >&2
        fail "$_pdf does not contain expected marker: $_want"
    fi
    if [ -n "$_forbid" ] && grep -q "$_forbid" "$_txt"; then
        fail "$_pdf unexpectedly contains marker: $_forbid"
    fi
    pass "$_pdf contains $_want"
}

assert_pdf_pages_min() {
    _pdf=$1
    _want=$2
    _got=$(pdfinfo "$_pdf" 2>/dev/null | awk '/^Pages:/ {print $2}')
    case "$_got" in
        ''|*[!0-9]*) fail "could not read the page count of $_pdf" ;;
    esac
    [ "$_got" -ge "$_want" ] || fail "$_pdf has $_got page(s), expected at least $_want"
    pass "$_pdf has $_got page(s) (at least $_want)"
}

echo "== wkhtmltopdf smoke tests =="
echo "bin dir: $BIN_DIR"
echo "work dir: $WORK"

need pdftotext
need pdfinfo

[ -x "$WKT" ] || fail "wkhtmltopdf not found or not executable at $WKT"
[ -x "$WKTIMG" ] || fail "wkhtmltoimage not found or not executable at $WKTIMG"

# --- 1. binaries start and report a version ---------------------------------
if ! _out=$("$WKT" --version 2>&1); then
    echo "--- wkhtmltopdf --version output ---" >&2
    echo "$_out" >&2
    diagnose "$WKT"
    fail "wkhtmltopdf --version failed"
fi
if ! _out=$("$WKTIMG" --version 2>&1); then
    echo "--- wkhtmltoimage --version output ---" >&2
    echo "$_out" >&2
    diagnose "$WKTIMG"
    fail "wkhtmltoimage --version failed"
fi
pass "both binaries run and report a version"

# --- 2. basic HTML -> PDF, with JavaScript executed -------------------------
"$WKT" --enable-javascript "$SMOKE/basic.html" "$WORK/basic.pdf" \
    || fail "wkhtmltopdf failed to render basic.html"
assert_pdf_text "$WORK/basic.pdf" "MARKER-BODY-TEXT"
# Proves JS ran before the page was painted, not just that a PDF was produced.
assert_pdf_text "$WORK/basic.pdf" "MARKER-JS-TEXT-RENDERED"

# --- 3. JavaScript really can be disabled ------------------------------------
# The fixture's <p> starts out as "MARKER-JS-TEXT" and the inline script
# rewrites it to "MARKER-JS-TEXT-RENDERED". With JS disabled we must therefore
# still see the original text and must NOT see the rewritten one.
"$WKT" --disable-javascript "$SMOKE/basic.html" "$WORK/nojs.pdf" \
    || fail "wkhtmltopdf failed with --disable-javascript"
assert_pdf_text "$WORK/nojs.pdf" "MARKER-BODY-TEXT"
assert_pdf_text "$WORK/nojs.pdf" "MARKER-JS-TEXT" "MARKER-JS-TEXT-RENDERED"

# --- 4. page geometry --------------------------------------------------------
# Note: there is no plain --margin switch; the four per-side switches are the
# only spelling the parser accepts.
"$WKT" --page-size A4 \
    --margin-top 10mm --margin-bottom 10mm \
    --margin-left 10mm --margin-right 10mm \
    "$SMOKE/basic.html" "$WORK/a4.pdf" \
    || fail "wkhtmltopdf failed with explicit page size/margins"
assert_pdf_text "$WORK/a4.pdf" "MARKER-BODY-TEXT"

# --- 5. multi page + header/footer ------------------------------------------
cat >"$WORK/hdr.html" <<'EOF'
<html><body><div style="font-size:8pt; text-align:center">MARKER-HEADER</div></body></html>
EOF
cat >"$WORK/ftr.html" <<'EOF'
<html><body><div style="font-size:8pt; text-align:center">MARKER-FOOTER page [page]</div></body></html>
EOF
# Header/footer URLs go through MultiPageLoader::guessUrlFromString, which turns
# a plain absolute path into a local file URL for us.
"$WKT" \
    --header-html "$WORK/hdr.html" \
    --footer-html "$WORK/ftr.html" \
    --header-spacing 5 --footer-spacing 5 \
    "$SMOKE/multipage.html" "$WORK/multi.pdf" \
    || fail "wkhtmltopdf failed with header/footer"
assert_pdf_text "$WORK/multi.pdf" "MARKER-PAGE-ONE"
assert_pdf_text "$WORK/multi.pdf" "MARKER-PAGE-THREE"
assert_pdf_text "$WORK/multi.pdf" "MARKER-HEADER"
assert_pdf_text "$WORK/multi.pdf" "MARKER-FOOTER"
# Assert a minimum rather than an exact count: whether a trailing page-break
# emits a blank page is a WebKit detail that has changed between versions, and
# that is not what this test is for. Collapsing to a single page would still
# fail here.
assert_pdf_pages_min "$WORK/multi.pdf" 3

# --- 6. bookmarks / outline --------------------------------------------------
"$WKT" --outline "$SMOKE/multipage.html" "$WORK/outline.pdf" \
    || fail "wkhtmltopdf failed with --outline"
assert_pdf_text "$WORK/outline.pdf" "MARKER-PAGE-ONE"

# --- 7. reading HTML from stdin ----------------------------------------------
# Exercises a code path (readArgsFromStdin) that has broken before.
cat "$SMOKE/basic.html" | "$WKT" - "$WORK/stdin.pdf" \
    || fail "wkhtmltopdf failed reading HTML from stdin"
assert_pdf_text "$WORK/stdin.pdf" "MARKER-BODY-TEXT"

# --- 8. wkhtmltoimage --------------------------------------------------------
"$WKTIMG" --format png --width 400 "$SMOKE/basic.html" "$WORK/out.png" \
    || fail "wkhtmltoimage failed to render a PNG"
[ -s "$WORK/out.png" ] || fail "wkhtmltoimage produced an empty PNG"
head -c 8 "$WORK/out.png" | grep -q 'PNG' || fail "$WORK/out.png is not a PNG"
pass "wkhtmltoimage produced a valid PNG"

"$WKTIMG" --format jpeg --quality 80 "$SMOKE/basic.html" "$WORK/out.jpg" \
    || fail "wkhtmltoimage failed to render a JPEG"
[ -s "$WORK/out.jpg" ] || fail "wkhtmltoimage produced an empty JPEG"
# Check the SOI marker without bash-only $'...' quoting, so this also runs
# under Alpine's ash.
jpeg_magic=$(od -An -tx1 -N2 "$WORK/out.jpg" | tr -d ' \n')
[ "$jpeg_magic" = "ffd8" ] || fail "$WORK/out.jpg is not a JPEG (magic: $jpeg_magic)"
pass "wkhtmltoimage produced a valid JPEG"

# --- 9. errors are reported, not swallowed ----------------------------------
# A missing input must produce a non-zero exit status. wkhtmltopdf has
# historically exited 0 on some failure paths, so this is a real regression
# guard rather than a formality.
if "$WKT" "$WORK/definitely-does-not-exist.html" "$WORK/nope.pdf" >/dev/null 2>&1; then
    fail "wkhtmltopdf exited 0 for a missing input file"
fi
pass "wkhtmltopdf reports failure for a missing input file"

echo
echo "All wkhtmltopdf smoke tests passed."
