#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-build/macos/Build/Products/Release/Zero Type.app}"
EXPECTED_VERSION="${EXPECTED_VERSION:-}"
WORK_DIR=""
DMG_ATTACHED=false

cleanup() {
  if [[ "$DMG_ATTACHED" == true ]] && [[ -n "$WORK_DIR" ]]; then
    hdiutil detach "$WORK_DIR" -force >/dev/null 2>&1 || true
  fi
  if [[ -n "$WORK_DIR" ]] && [[ -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

if [[ "$TARGET" == *.dmg ]]; then
  WORK_DIR="$(mktemp -d /tmp/zerotype-release.XXXXXX)"
  hdiutil attach -nobrowse -readonly -mountpoint "$WORK_DIR" "$TARGET" >/dev/null
  DMG_ATTACHED=true
  APP="$WORK_DIR/Zero Type.app"
elif [[ "$TARGET" == *.zip ]]; then
  WORK_DIR="$(mktemp -d /tmp/zerotype-release.XXXXXX)"
  ditto -x -k "$TARGET" "$WORK_DIR"
  APP="$WORK_DIR/Zero Type.app"
else
  APP="$TARGET"
fi

if [[ ! -d "$APP" ]]; then
  echo "找不到 App：$APP" >&2
  exit 1
fi

echo "驗證 code signature：$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

INFO_PLIST="$APP/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/Zero Type")"
SIGNATURE="$(codesign -dvv "$APP" 2>&1 | grep '^Signature=' || true)"

echo "版本：$VERSION ($BUILD_NUMBER)"
echo "架構：$ARCHS"
echo "簽章：${SIGNATURE:-未知}"

if [[ -n "$EXPECTED_VERSION" ]] && [[ "$VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "版本不符：預期 $EXPECTED_VERSION，實際 $VERSION" >&2
  exit 1
fi

if [[ "$ARCHS" != *"arm64"* ]]; then
  echo "App 不包含 arm64 架構" >&2
  exit 1
fi

echo "macOS Release 簽章封印驗證通過"
