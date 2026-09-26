#!/bin/sh
# Package a built wkhtmltopdf into a distributable tarball.
#
# Usage: scripts/make-dist.sh <bin-dir> <output.tar.gz>
#
# The tarball is labelled with the libc it was built against and with the
# feature limitations of a stock-QtWebKit build. That labelling is not
# decoration: these binaries are dynamically linked, so they only run on
# systems at least as new as the libc they were built on, and they silently
# ignore 53 command-line switches. Both facts have caused real pain with the
# 0.12.6 static releases, so they belong on the artifact itself rather than
# only in the repository documentation.

set -eu

BIN_DIR="${1:-./bin}"
OUT="${2:-out/wkhtmltox.tar.gz}"

[ -x "$BIN_DIR/wkhtmltopdf" ] || { echo "no wkhtmltopdf in $BIN_DIR" >&2; exit 1; }
[ -x "$BIN_DIR/wkhtmltoimage" ] || { echo "no wkhtmltoimage in $BIN_DIR" >&2; exit 1; }

VERSION=$(cat VERSION 2>/dev/null || echo unknown)
ARCH=$(uname -m)

# Identify the libc so the artifact says what it needs. Static binaries would
# make this moot; these are not static.
LIBC="unknown"
if ldd --version >/dev/null 2>&1; then
    LIBC=$(ldd --version 2>&1 | head -1)
elif [ -f /etc/alpine-release ]; then
    LIBC="musl $(cat /etc/alpine-release)"
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT INT TERM

DEST="$STAGE/wkhtmltox-$VERSION-$ARCH"
mkdir -p "$DEST/bin" "$DEST/lib"
cp "$BIN_DIR/wkhtmltopdf" "$BIN_DIR/wkhtmltoimage" "$DEST/bin/"
# Ship the shared library too, so the tarball is self-contained and does not
# depend on the build tree's layout.
for so in "$BIN_DIR"/libwkhtmltox.so*; do
    [ -e "$so" ] || continue
    cp "$so" "$DEST/lib/"
done

cat >"$DEST/BUILD-INFO.txt" <<EOF
wkhtmltopdf $VERSION
architecture:   $ARCH
libc:            $LIBC
engine:          QtWebKit 5.212 from the distribution's Qt 5 packages
built from:      $(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo unknown)

IMPORTANT -- REDUCED FEATURE SET
--------------------------------
This build links a stock QtWebKit. Much of wkhtmltopdf is implemented in
wkhtmltopdf's patches to Qt rather than in wkhtmltopdf itself, so the
following are IGNORED -- silently, with exit status 0 and a PDF still
written:

  --header-* and --footer-*          (all 14 header/footer switches)
  --outline, --outline-depth, --dump-outline, --default-header
  --enable-forms, --disable-forms    (AcroForms)
  --page-offset
  --print-media-type                 (print stylesheets)
  --disable-smart-shrinking, --enable-smart-shrinking
  --image-dpi, --image-quality, --no-pdf-compression, --viewport-size
  --xsl-style-sheet, --replace, and the TOC switches
  wkhtmltoimage: --transparent, --disable-smart-width

Do not use this build if you rely on any of them. See docs/status.md for why,
and for the work needed to restore them.

These binaries are DYNAMICALLY linked, so they run only on systems with a libc
at least as new as the one above. That is inherent to building against the
distribution's own Qt, and is the deliberate trade-off against the 0.12.6
static releases, which broke on newer systems and never worked on musl.
EOF

cat >"$DEST/README" <<'EOF'
wkhtmltopdf / wkhtmltoimage

Quick start:
  LD_LIBRARY_PATH=$PWD/lib ./bin/wkhtmltopdf input.html output.pdf
  LD_LIBRARY_PATH=$PWD/lib ./bin/wkhtmltoimage input.html output.png

Read BUILD-INFO.txt before using this: these binaries are dynamically linked
and ignore a substantial part of the wkhtmltopdf command line.
EOF

# Reproducibility: fixed owner/mtime and sorted input, so identical inputs give
# an identical tarball.
( cd "$STAGE" && find . -exec touch -t 197001010000.00 {} + )
mkdir -p "$(dirname "$OUT")"
tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mtime='1970-01-01 00:00:00Z' \
    -czf "$OUT" -C "$STAGE" "$(basename "$DEST")"

# Checksums alongside, so a download can be verified.
if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$(dirname "$OUT")" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
elif command -v shasum >/dev/null 2>&1; then
    ( cd "$(dirname "$OUT")" && shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
fi

echo "created $OUT"
ls -l "$OUT"
