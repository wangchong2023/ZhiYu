#!/bin/bash
# -*- coding: utf-8 -*-
#
#  run-test-ipad-ui.sh
#  ZhiYu
#
#  系统层级：[Tools/CI] 持续集成 — iPad UI 测试
#  核心职责：在 iPad 模拟器上运行面向 iPad 平台的 UI 测试（iPadTests + ResponsiveLayoutTests），
#           覆盖 testOrientationChange 等受设备类型限制的用例。
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../ci-common-shared.sh"
source "$SCRIPT_DIR/run-test-flaky-report.sh" > /dev/null

SIM_NAME=$(find_ipad_simulator)
DESTINATION="platform=iOS Simulator,name=${SIM_NAME}"
DERIVED_DATA="${BUILD_DIR}/DerivedData-ipad"
LOG_FILE="${BUILD_DIR}/ipad_ui_test.log"
FLAKY_ARGS=$(cat "${BUILD_DIR}/.flaky_tests" 2>/dev/null | sed 's/^/-skip-testing:/' | tr '\n' ' ' || true)

echo "📱 运行 iPad UI 测试 | 模拟器: ${SIM_NAME} | 目标: iPadTests + ResponsiveLayoutTests" | tee "$LOG_FILE"

mkdir -p "${BUILD_DIR}"

xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:ZhiYuUITests/iPadTests \
    -only-testing:ZhiYuUITests/ResponsiveLayoutTests \
    -enableCodeCoverage YES \
    $FLAKY_ARGS \
    2>&1 | tee -a "$LOG_FILE" | grep -E "Test Suite|Test Case|passed|failed|error" || true

EXIT_CODE=${PIPESTATUS[0]}
if [ "$EXIT_CODE" -ne 0 ]; then
    summarize_xcodebuild_errors "$LOG_FILE" "iPad UI Tests" "$EXIT_CODE"
    exit 1
fi

echo "✅ iPad UI 测试全部通过" | tee -a "$LOG_FILE"
exit 0
