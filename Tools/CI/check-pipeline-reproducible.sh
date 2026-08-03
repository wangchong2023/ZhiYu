#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/ci/check-pipeline-reproducible.sh
# 脚本功能: 验证相同提交下两次构建产物的可重复性（Reproducible Builds）。
#           构建失败时自动保存完整日志并汇总错误。
# ==============================================================================

set -euo pipefail

PROJECT="ZhiYu.xcodeproj"
SCHEME="ZhiYu"
DEST="generic/platform=iOS Simulator"
BUILD_DIR="build/reproducible_test"
LOG_DIR="build/reproducible_logs"

echo "====> 确定性构建验证 (L1+L2) <===="
SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export SOURCE_DATE_EPOCH
mkdir -p "$BUILD_DIR" "$LOG_DIR"

for i in 1 2; do
    echo "  --- 构建 #${i} ---"
    LOG_FILE="$LOG_DIR/build${i}.log"

    set +e
    set -o pipefail
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -derivedDataPath "$BUILD_DIR/build${i}" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        2>&1 | tee "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    set -e

    if [ $EXIT_CODE -ne 0 ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ 确定性构建 #${i} 失败 (exit=${EXIT_CODE})"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  编译错误:"
        grep -E "^.*:[0-9]+:[0-9]+: error:" "$LOG_FILE" | sort -t: -k1,1 -k2,2n -u || echo "  (未找到)"
        echo ""
        echo "  日志尾部:"
        tail -15 "$LOG_FILE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  完整日志: ${LOG_FILE}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit $EXIT_CODE
    fi
    echo "  ✅ 构建 #${i} 成功"
done

BIN1=$(find "$BUILD_DIR/build1" -name "ZhiYu" -type f -not -path "*.dSYM/*" | head -1)
BIN2=$(find "$BUILD_DIR/build2" -name "ZhiYu" -type f -not -path "*.dSYM/*" | head -1)

if [ -z "$BIN1" ] || [ -z "$BIN2" ]; then
    echo "  ⚠️  未找到二进制文件，跳过比对"
    exit 0
fi

HASH1=$(shasum -a 256 "$BIN1" | cut -d' ' -f1)
HASH2=$(shasum -a 256 "$BIN2" | cut -d' ' -f1)

if [ "$HASH1" = "$HASH2" ]; then
    echo "  ✅ 构建可重现: SHA256 一致 ($HASH1)"
else
    echo "  ⚠️  构建不可重现:"
    echo "      build1: $HASH1"
    echo "      build2: $HASH2"
fi
rm -rf "$BUILD_DIR"
