#!/bin/bash
# 把当前已构建的 app 安装到「应用程序」，避免手打带空格的路径。
# 用法：cd app && ./build.sh && ./tools/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."
APP="dist/FU ToDo.app"
[ -d "$APP" ] || { echo "没有构建产物：$APP（先跑 ./build.sh）" >&2; exit 1; }
DEST="/Applications/FU ToDo.app"
# 先退出正在运行的旧版本，避免替换失败
pkill -f "/Applications/FU ToDo.app/Contents/MacOS/YiRiYiJian" 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$APP" "$DEST"
echo "✓ 已安装：$DEST"
open "$DEST"
