#!/usr/bin/env bash
#
# 自动提升 MARKETING_VERSION / CURRENT_PROJECT_VERSION 并提交。
# 用法：
#   make version VERSION=1.6.0
#   SKIP_COMMIT=1 ./scripts/bump_version.sh 1.6.0
set -euo pipefail

VERSION="${1:?用法: $0 <新版本号>}"
PROJECT="Breathlet.xcodeproj/project.pbxproj"

[ -f "$PROJECT" ] || { echo "错误：找不到 $PROJECT" >&2; exit 1; }

echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || {
  echo "错误：版本号必须是 x.y.z 格式（当前：$VERSION）" >&2
  exit 1
}

# 构建号：去掉点，例如 1.6.0 -> 160
BUILD="${VERSION//./}"

# 只更新 app target（Debug/Release 两个配置块），测试 target 的版本号保持不动。
# 两个配置块的 ID 与 name 行组成 sed 行范围。
APP_DEBUG='1A0000912C00000100000001'
APP_RELEASE='1A0000922C00000100000001'

sed -i '' -E "/${APP_DEBUG} \/\* Debug \*\//,/name = Debug;/ {
	s/(MARKETING_VERSION = )[^;]+;/\1${VERSION};/
	s/(CURRENT_PROJECT_VERSION = )[^;]+;/\1${BUILD};/
}" "$PROJECT"
sed -i '' -E "/${APP_RELEASE} \/\* Release \*\//,/name = Release;/ {
	s/(MARKETING_VERSION = )[^;]+;/\1${VERSION};/
	s/(CURRENT_PROJECT_VERSION = )[^;]+;/\1${BUILD};/
}" "$PROJECT"

if [ "${SKIP_COMMIT:-0}" != "1" ]; then
  git add "$PROJECT"
  git commit -m "Bump version to ${VERSION}" >/dev/null
fi

echo "→ 版本已更新为 ${VERSION}（构建号 ${BUILD}）"
