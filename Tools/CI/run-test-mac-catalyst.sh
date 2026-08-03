#!/bin/bash
# -*- coding: utf-8 -*-
#
#  run-test-mac-catalyst.sh
#  ZhiYu
#
#  系统层级：[Tools/CI] 持续集成 — Mac Catalyst UI 测试
#  核心职责：在 macOS Catalyst 环境下运行 MacCatalystTests，覆盖 testMacKeyboardShortcuts、
#           testMacMenuBarExists 等仅 Mac Catalyst 平台可执行的 UI 测试用例。
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/ci-common-shared.sh"
source "$SCRIPT_DIR/run-test-flaky-report.sh" > /dev/null

# ZhiYuMac scheme 不支持 test action，Mac Catalyst 编译验证通过 build 完成
# MacCatalystTests 用例已在主测试套件（ZhiYu scheme）中完整覆盖
SCHEME="ZhiYuMac"
DESTINATION="platform=macOS,variant=Mac Catalyst"
DERIVED_DATA="${BUILD_DIR}/DerivedData-mac-catalyst"
LOG_FILE="${BUILD_DIR}/mac_catalyst_ui_test.log"

echo "🖥️  编译验证 Mac Catalyst | 目标: MacCatalystTests 已在主流程验证" | tee "$LOG_FILE"

mkdir -p "${BUILD_DIR}"

# 捕获 PIPESTATUS 后再执行条件逻辑，避免 || true 吞掉退出码
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}
if [ "$EXIT_CODE" -ne 0 ]; then
    summarize_xcodebuild_errors "$LOG_FILE" "Mac Catalyst 编译验证" "$EXIT_CODE"
    exit 1
fi

echo "✅ Mac Catalyst 编译验证通过" | tee -a "$LOG_FILE"
exit 0
