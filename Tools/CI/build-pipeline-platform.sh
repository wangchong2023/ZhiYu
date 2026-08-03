#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/ci/build-pipeline-platform.sh
# 脚本功能: 单平台编译验证，失败时自动汇总编译错误。
# 用法: ./Tools/ci/build-pipeline-platform.sh <scheme> <destination> <label> [spm_cache_dir]
# 示例: ./Tools/ci/build-pipeline-platform.sh ZhiYu 'generic/platform=iOS Simulator' iOS
# ==============================================================================
set -euo pipefail

# 引入持续集成公共基础底座
source "$(dirname "$0")/ci-common-shared.sh"

SCHEME="${1:?缺少 scheme 参数}"
DEST="${2:?缺少 destination 参数}"
LABEL="${3:?缺少 label 参数}"
SPM_CACHE="${4:-$SPM_CACHE_DIR}"
LOG_FILE="${BUILD_DIR}/${LABEL}_build.log"

mkdir -p "$BUILD_DIR" "$SPM_CACHE"

# ── 打印构建版本信息 ──
PLIST="$(dirname "$0")/../../../Sources/Info.plist"
if [ -f "$PLIST" ]; then
    ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "N/A")
    bld=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "N/A")
    hash=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" 2>/dev/null || echo "N/A")
    ts=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" 2>/dev/null || echo "N/A")
    echo "📦 版本: ${ver} (build ${bld}) | commit: ${hash} | 构建时间: ${ts}"
fi

echo "===> Build ${LABEL}"
echo "     日志: ${LOG_FILE}"

set +e
set -o pipefail
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    -derivedDataPath "${BUILD_DIR}/DerivedData-${LABEL}" \
    -clonedSourcePackagesDirPath "$SPM_CACHE" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $EXIT_CODE -ne 0 ]; then
    summarize_xcodebuild_errors "$LOG_FILE" "${LABEL}" "$EXIT_CODE"
    exit $EXIT_CODE
fi

echo "  ✅ ${LABEL} Build Passed"

# ── 打印构建版本信息 ──
if [ -f "$PLIST" ]; then
    ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "N/A")
    bld=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "N/A")
    hash=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" 2>/dev/null || echo "N/A")
    ts=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" 2>/dev/null || echo "N/A")
    echo "📦 版本: ${ver} (build ${bld}) | commit: ${hash} | 构建时间: ${ts}"
fi
