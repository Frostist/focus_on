#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="FocusOn"
INSTALL_DIR="/Applications"

echo "Building $APP_NAME..."
xcodebuild \
  -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$PROJECT_DIR/.build" \
  build

BUILT_APP="$PROJECT_DIR/.build/Build/Products/Release/$APP_NAME.app"

echo "Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$BUILT_APP" "$INSTALL_DIR/"

# Relaunch if already running
if pgrep -x "$APP_NAME" > /dev/null; then
  echo "Relaunching $APP_NAME..."
  pkill -x "$APP_NAME" || true
  sleep 0.5
fi

open "$INSTALL_DIR/$APP_NAME.app"
echo "Done — $APP_NAME installed and launched."
