#!/bin/bash
# FU ToDo · 构建脚本
#
# 本机没有完整 Xcode，只能用 CommandLineTools 的 Swift 工具链。这个环境有两处必须绕开的坑：
#   1) SwiftPM 默认把编译包在 sandbox-exec 里跑，本机不允许应用进程沙箱 → 必须加 --disable-sandbox
#   2) 默认的编译缓存/临时目录在沙箱外，会被拒写 → 统一改到 ~/.cache/yrjy
set -euo pipefail
cd "$(dirname "$0")"

export TMPDIR="$HOME/.cache/yrjy/tmp"
export CLANG_MODULE_CACHE_PATH="$HOME/.cache/yrjy/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$HOME/.cache/yrjy/swift-module-cache"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"

APP_DISPLAY_NAME="FU ToDo"
# 版本号单一来源：Sources/Core/AppVersion.swift
APP_VERSION=$(grep -o 'current = "[0-9.]*"' Sources/Core/AppVersion.swift | head -1 | cut -d'"' -f2)
APP_VERSION=${APP_VERSION:-0.1}
BUNDLE="dist/${APP_DISPLAY_NAME}.app"
MODE="${1:-build}"

echo "▶︎ 编译（release）"
swift build -c release --disable-sandbox

echo "▶︎ 业务规则自测"
.build/release/SelfTest

echo "▶︎ 组装 .app"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp .build/release/YiRiYiJian "$BUNDLE/Contents/MacOS/YiRiYiJian"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_DISPLAY_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_DISPLAY_NAME}</string>
  <key>CFBundleIdentifier</key><string>local.futodo.app</string>
  <key>CFBundleExecutable</key><string>YiRiYiJian</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <!-- 不恢复上次的窗口：启动时总是先出现主窗口，避免只弹出「设置」 -->
  <key>NSQuitAlwaysKeepsWindows</key><false/>
  <key>NSDisableAutomaticTermination</key><true/>
</dict>
</plist>
PLIST

# 许可证：每一份分发包都要带上条款（PolyForm 的 Notices 条款要求）
mkdir -p "$BUNDLE/Contents/Resources"
if [ -f "../LICENSE" ]; then
  cp "../LICENSE" "$BUNDLE/Contents/Resources/LICENSE"
fi

# 应用图标：resources/AppIcon.icns 存在就挂上（用 tools/make_icon.py 生成）
if [ -f "resources/AppIcon.icns" ]; then
  mkdir -p "$BUNDLE/Contents/Resources"
  cp "resources/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
else
  echo "（没有图标：跑 python3 tools/make_icon.py <图片> 生成后重新打包）"
fi

codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "（ad-hoc 签名跳过）"
echo "✓ 完成：$BUNDLE"

# 打包：把 .app 和一个 Applications 替身放进 dmg（拖进"应用程序"即可安装）
# 注意：hdiutil 需要创建 /dev 设备节点，在受限沙箱里会失败（报"目录非空"），需在普通终端执行。
if [ "$MODE" = "dmg" ]; then
  DMG="dist/${APP_DISPLAY_NAME}.dmg"
  STAGE="dist/dmg-staging"
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$BUNDLE" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$APP_DISPLAY_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" 2>&1 | grep -v WARNING
  rm -rf "$STAGE"
  echo "✓ 安装包：$DMG  ($(du -h "$DMG" | cut -f1))"
  exit 0
fi

case "$MODE" in
  run)  echo "▶︎ 启动"; open "$BUNDLE" ;;
  demo) echo "▶︎ 以示例数据启动"; open "$BUNDLE" --args --demo ;;
  shots)
    echo "▶︎ 渲染界面截图到 shots/"
    .build/release/RenderShots "$PWD/shots"
    ;;
esac
