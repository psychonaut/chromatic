#!/usr/bin/env bash
# Build a Debian package from the meson install tree.
# Usage: ./build-deb.sh [output-dir]
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$SRC}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BUILD="$WORK/build"
ROOT="$WORK/root"
VERSION="$(sed -n "s/^ *version: *'\([^']*\)'.*/\1/p" "$SRC/meson.build" | head -1)"
ARCH="$(dpkg --print-architecture)"
PKG="chromatic"

meson setup "$BUILD" "$SRC" --buildtype=release --prefix=/usr
meson compile -C "$BUILD"
DESTDIR="$ROOT" meson install -C "$BUILD" --no-rebuild

strip --strip-unneeded "$ROOT/usr/bin/chromatic"

# Resolve shared library dependencies of the binary.
mkdir -p "$WORK/shlibs/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: any\n' "$PKG" "$PKG" > "$WORK/shlibs/debian/control"
DEPENDS="$(cd "$WORK/shlibs" && dpkg-shlibdeps -O "$ROOT/usr/bin/chromatic" 2>/dev/null \
  | sed -n 's/^shlibs:Depends=//p')"

mkdir -p "$ROOT/DEBIAN"
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Architecture: $ARCH
Maintainer: nate-xyz <https://github.com/nate-xyz/chromatic>
Installed-Size: $(du -sk "$ROOT/usr" | cut -f1)
Depends: $DEPENDS
Section: sound
Priority: optional
Homepage: https://github.com/nate-xyz/chromatic
Description: Fine-tune your instruments
 Chromatic is a GTK4/libadwaita instrument tuner that detects the
 frequency, musical note and cents offset of live audio input.
EOF

mkdir -p "$OUT"
dpkg-deb --root-owner-group --build "$ROOT" "$OUT/${PKG}_${VERSION}_${ARCH}.deb"
