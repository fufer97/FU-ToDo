#!/usr/bin/env bash
#
# 一条命令发版：改版本号 → 构建 + 自测 + 打包 → 提交推送 → 发布到 GitHub。
#
#   ./tools/release.sh 0.5 "这次改了什么"
#   ./tools/release.sh 0.5 "说明" --dry-run     # 只改版本号并检查，不构建不发布
#
# 安装包**只发到 fufer97/FU-ToDo**（应用里的「检查更新」读的就是这个仓库），
# 不再有第二个下载仓库。
set -euo pipefail

REPO="fufer97/FU-ToDo"
VERSION="${1:-}"
NOTES="${2:-}"
DRY=""
[ "${3:-}" = "--dry-run" ] && DRY=1

if [ -z "$VERSION" ]; then
  echo "用法：./tools/release.sh <版本号> [\"这次改了什么\"] [--dry-run]"
  echo "例：  ./tools/release.sh 0.5 \"修复拖动抖动\""
  exit 1
fi

cd "$(dirname "$0")/.."   # → app/

# 1) 版本号（单一来源：Sources/Core/AppVersion.swift）
/usr/bin/sed -i '' -E "s/current = \"[0-9.]+\"/current = \"$VERSION\"/" Sources/Core/AppVersion.swift
echo "版本号 → $(grep -o 'current = "[0-9.]*"' Sources/Core/AppVersion.swift)"

if [ -n "$DRY" ]; then
  echo "（dry-run：只改了版本号，未构建、未发布）"
  exit 0
fi

# 2) 构建 + 自测 + 出包
./build.sh dmg

# 3) 提交并推送到源码仓库
cd ..
git add -A
git commit -m "发布 $VERSION${NOTES:+：$NOTES}"
git push origin main

# 4) 发布到 GitHub —— 只有这一个仓库
gh release create "v$VERSION" "app/dist/FU ToDo.dmg" \
  --repo "$REPO" \
  --title "FU ToDo $VERSION" \
  --notes "${NOTES:-见提交记录}"

echo
echo "✓ 已发布：https://github.com/$REPO/releases/tag/v$VERSION"
echo "✓ 应用内「设置 → 更新 → 检查更新」读到的就是它"
