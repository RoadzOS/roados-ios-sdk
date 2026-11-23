#!/usr/bin/env bash
# Builds Binaries/RoadOSCore.xcframework from the pinned RoadOS Graphics Core
# (external/roados-graphics-core) and copies the RVHL bundle into the Swift
# package resources.
#
# The xcframework contains ONE static library per slice: the core's binding,
# RVHL and graphics libraries merged with Skia (built from source by the
# core's scripts/bootstrap_skia.sh). Headers are the core's public C++ headers;
# only the Objective-C++ bridge includes them.
#
# Slices: macos-arm64 (for `swift test` on the Mac), ios-arm64, iossim-arm64.
#
# Environment:
#   ROADOS_CORE_DIR   core checkout   (default: external/roados-graphics-core)
#   ROADOS_SKIA_DIR   Skia checkout   (default: <core>/third_party/skia; share one
#                                      checkout between repositories to save disk)
#   DEVELOPER_DIR     Xcode to use    (default: /Applications/Xcode.app/Contents/Developer
#                                      when xcode-select points at the Command Line Tools)
#   ROADOS_IOS_MIN    iOS deployment target (default 17.0; the core needs iOS 16.3+ for floating-point std::to_chars)
#   ROADOS_MACOS_MIN  macOS deployment target (default 14.0)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="${ROADOS_CORE_DIR:-$ROOT/external/roados-graphics-core}"
CORE="$(cd "$CORE" && pwd)"
export ROADOS_SKIA_DIR="${ROADOS_SKIA_DIR:-$CORE/third_party/skia}"
export ROADOS_IOS_MIN="${ROADOS_IOS_MIN:-17.0}"
MACOS_MIN="${ROADOS_MACOS_MIN:-14.0}"
BUILD="$ROOT/.build-core"
OUT="$ROOT/Binaries/RoadOSCore.xcframework"
RES="$ROOT/Sources/RoadOSGraphics/Resources/rvhl"

if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p)" == *CommandLineTools* && -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
command -v cmake >/dev/null || { echo "cmake ≥ 3.24 is required" >&2; exit 1; }
[[ -f "$CORE/CMakeLists.txt" ]] || { echo "core not found at $CORE (git submodule update --init)" >&2; exit 1; }

log() { printf '\033[1;35m[roados-ios]\033[0m %s\n' "$*"; }

SKIA_LIBS=(svg skshaper skresources skia skcms png zlib expat)

build_slice() { # slice skia-target skia-out-name cmake-args…
  local slice="$1" skiaTarget="$2" skiaOut="$3"; shift 3
  local skiaDir="$ROADOS_SKIA_DIR/out/Release-$skiaOut"
  if [[ ! -f "$skiaDir/libskia.a" ]]; then
    log "Skia for $slice"
    "$CORE/scripts/bootstrap_skia.sh" Release "$skiaTarget"
  fi
  log "core for $slice"
  cmake -S "$CORE" -B "$BUILD/$slice" -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release -DROADOS_BUILD_TESTS=OFF -DROADOS_BUILD_EXAMPLES=OFF -DROADOS_BUILD_TOOLS=OFF \
    -DROADOS_SKIA_DIR="$ROADOS_SKIA_DIR" -DROADOS_SKIA_OUT="$skiaDir" "$@" >/dev/null
  cmake --build "$BUILD/$slice" --target roados_binding -j"$(sysctl -n hw.ncpu)" >/dev/null
  local libs=("$BUILD/$slice/src/libroados_binding.a" "$BUILD/$slice/src/libroados_rvhl.a" "$BUILD/$slice/src/libroados_graphics.a")
  # Skia's GN iOS build emits fat arm64+arm64e archives; our libraries are arm64
  # only, so thin Skia to arm64 to keep every slice architecturally complete.
  mkdir -p "$BUILD/$slice/skia"
  for l in "${SKIA_LIBS[@]}"; do
    local src="$skiaDir/lib$l.a" dst="$BUILD/$slice/skia/lib$l.a"
    if lipo -info "$src" 2>/dev/null | grep -q "Architectures in the fat file"; then
      lipo -thin arm64 "$src" -output "$dst"
    else
      cp "$src" "$dst"
    fi
    libs+=("$dst")
  done
  xcrun libtool -static -no_warning_for_no_symbols -o "$BUILD/$slice/libRoadOSCore.a" "${libs[@]}"
}

build_slice macos-arm64 host mac-arm64 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN"
build_slice ios-arm64 ios-arm64 ios-arm64 \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$ROADOS_IOS_MIN"
build_slice iossim-arm64 iossim-arm64 iossim-arm64 \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$ROADOS_IOS_MIN"

log "headers"
rm -rf "$BUILD/headers" && mkdir -p "$BUILD/headers"
cp -R "$CORE/include/roados" "$BUILD/headers/"

log "xcframework"
rm -rf "$OUT"
xcodebuild -create-xcframework \
  -library "$BUILD/macos-arm64/libRoadOSCore.a" -headers "$BUILD/headers" \
  -library "$BUILD/ios-arm64/libRoadOSCore.a" -headers "$BUILD/headers" \
  -library "$BUILD/iossim-arm64/libRoadOSCore.a" -headers "$BUILD/headers" \
  -output "$OUT" >/dev/null

log "RVHL bundle → package resources"
rm -rf "$RES" && mkdir -p "$(dirname "$RES")"
cp -R "$CORE/assets/rvhl" "$RES"

CORE_REV="$(git -C "$CORE" rev-parse HEAD 2>/dev/null || echo unknown)"
SKIA_REV="$(git -C "$ROADOS_SKIA_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
cat > "$ROOT/Binaries/RoadOSCore.version" <<EOF
core=$CORE_REV
skia=$SKIA_REV
ios_min=$ROADOS_IOS_MIN
macos_min=$MACOS_MIN
EOF
log "done: $OUT (core ${CORE_REV:0:12}, skia ${SKIA_REV:0:12})"
du -sh "$OUT" | cut -f1 | sed 's/^/size: /'
