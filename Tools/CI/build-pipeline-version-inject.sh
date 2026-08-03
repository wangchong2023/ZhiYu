#!/bin/bash
# build-pipeline-version-inject.sh — 注入版本号到 Info.plist（双 CI 通用）
#
# 用法: ./build-pipeline-version-inject.sh <info_plist_path>
# 示例: bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist

set -euo pipefail

PLIST="${1:?用法: $0 <info_plist_path>}"

if [ ! -f "$PLIST" ]; then
    echo "[inject_version] ERROR: Info.plist 不存在: $PLIST"
    exit 1
fi

# ── 1. SemVer：从 Swift 源码常量读取（防抵赖，tag 做一致性校验）──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_SWIFT="$(cd "$SCRIPT_DIR/../../.." && pwd)/Sources/Core/Base/Constants/AppConstants.swift"
if [ -f "$VERSION_SWIFT" ]; then
    VERSION=$(grep 'static let semVer' "$VERSION_SWIFT" | grep -o '"[0-9.]*"' | tr -d '"' | head -1)
fi
VERSION="${VERSION:-0.0.0}"
# CI 环境下校验 Swift 源码版本号与 git tag 一致性
TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$TAG" ] && [ "${TAG#v}" != "$VERSION" ]; then
    echo "[inject_version] WARNING: AppConstants.Version.semVer (${VERSION}) 与 git tag (${TAG}) 不一致！以源码为准。" >&2
fi

# ── 2. 构建号：提交总数（跨 CI 系统一致）──
BUILD=$(git rev-list --count HEAD)

# ── 3. 短哈希：精确回溯 commit ──
HASH=$(git rev-parse --short HEAD)

# ── 4. 构建时间：ISO 8601 格式 ──
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── 4. 写入 Info.plist ──
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

# 自定义键 GIT_SHORT_HASH（Info.plist 无标准字段）
if /usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" &>/dev/null; then
    /usr/libexec/PlistBuddy -c "Set :GIT_SHORT_HASH $HASH" "$PLIST"
else
    /usr/libexec/PlistBuddy -c "Add :GIT_SHORT_HASH string $HASH" "$PLIST"
fi

# 自定义键 BUILD_TIMESTAMP（ISO 8601 构建时间）
if /usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" &>/dev/null; then
    /usr/libexec/PlistBuddy -c "Set :BUILD_TIMESTAMP $BUILD_TIME" "$PLIST"
else
    /usr/libexec/PlistBuddy -c "Add :BUILD_TIMESTAMP string $BUILD_TIME" "$PLIST"
fi

# ── 5. 将动态构建信息同步注入 Swift 源码常量（防抵赖：每次构建可追溯）──
if [ -f "$VERSION_SWIFT" ]; then
    sed -i '' "s/static let gitShortHash = \"[^\"]*\"/static let gitShortHash = \"$HASH\"/" "$VERSION_SWIFT"
    sed -i '' "s/static let buildTimestamp = \"[^\"]*\"/static let buildTimestamp = \"$BUILD_TIME\"/" "$VERSION_SWIFT"
    echo "[inject_version] Swift 源码常量已同步: gitShortHash=$HASH  buildTimestamp=$BUILD_TIME"
fi

echo "[inject_version] CFBundleShortVersionString=$VERSION  CFBundleVersion=$BUILD  GIT_SHORT_HASH=$HASH  BUILD_TIMESTAMP=$BUILD_TIME"
