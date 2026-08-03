#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/ci/build-pipeline-env-prepare.sh
# 脚本功能: 生成 Xcode 工程结构文件，拉取并编译 SPM 包以预热测试与编译环境。
#           构建失败时自动提取并汇总错误信息。
# ==============================================================================
set -euo pipefail

# 1. 常量定义
PROJECT="ZhiYu.xcodeproj"
SCHEME="ZhiYu"
DESTINATION="generic/platform=iOS Simulator"
# SPM 缓存双路径：优先 /tmp（CI 共享），次选 ~/.cache（备份）
PERSISTENT_CACHE="${HOME}/.cache/zhiyu-spm"
SHARED_CACHE="/tmp/zhiyu-spm-cache"
if [ -d "$SHARED_CACHE/checkouts" ]; then
    SPM_CACHE_DIR="$SHARED_CACHE"
elif [ -d "$PERSISTENT_CACHE/checkouts" ]; then
    cp -a "$PERSISTENT_CACHE" "$SHARED_CACHE"
    SPM_CACHE_DIR="$SHARED_CACHE"
else
    SPM_CACHE_DIR="$SHARED_CACHE"
fi
LOG_FILE="build/test_compile.log"
ERROR_SUMMARY="build/test_compile_errors.txt"

# 2. 生成 Xcode 项目文件
echo "===> xcodegen generate"
xcodegen generate

# 3. 预热测试依赖环境
echo "===> Build-for-testing (SPM + compile)"
mkdir -p build "$SPM_CACHE_DIR"

set +e
set -o pipefail
xcodebuild build-for-testing \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -clonedSourcePackagesDirPath "$SPM_CACHE_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee "$LOG_FILE"
BUILD_EXIT_CODE=${PIPESTATUS[0]}
set -e

# 4. 错误汇总（构建失败时）
if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    ❌ BUILD FAILED                          ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Error Summary (full log: ${LOG_FILE})"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # 提取编译错误并直接输出到控制台，同时存副本到文件
    {
        echo "=== 编译错误（去重） ==="
        grep -E "^.*:[0-9]+:[0-9]+: error:" "$LOG_FILE" | sort -t: -k1,1 -k2,2n -u || echo "  (无)"
        echo ""
        echo "=== 致命错误 ==="
        grep -i "fatal error" "$LOG_FILE" || echo "  (无)"
        echo ""
        echo "=== 日志尾部 ==="
        tail -15 "$LOG_FILE"
    } | tee "$ERROR_SUMMARY"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "❌ prepare 失败 — 上方为错误详情，完整日志: $LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════"
    exit $BUILD_EXIT_CODE
fi

echo "✅ 编译预热与环境依赖加载就绪"
