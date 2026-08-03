#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/ci/run-test-ui.sh
# 脚本功能: UI 测试（并行多 Worker，独立阶段），失败时自动汇总错误。
# 用法: ./Tools/ci/run-test-ui.sh
# ==============================================================================
set -euo pipefail

# 引入持续集成公共基础底座
source "$(dirname "$0")/ci-common-shared.sh"

# 获取动态寻找出的最新可用模拟器
SIM_NAME=$(find_simulator)
DEST="platform=iOS Simulator,name=${SIM_NAME}"
DERIVED="${BUILD_DIR}/DerivedData"
LOG_FILE="${BUILD_DIR}/ui_test_output.log"

# ── 从 @flaky 注释自动收集不稳定测试 ─────────────────────────────
echo "🔍 收集 @flaky 标记的不稳定测试..."
FLAKY_ARGS=()
HAS_FLAKY=false
while IFS= read -r skip_arg; do
    if [ -n "$skip_arg" ]; then
        FLAKY_ARGS+=("$skip_arg")
        HAS_FLAKY=true
    fi
done < <(bash Tools/ci/run-test-flaky-report.sh)

# ── 构造 xcodebuild 参数 ──────────────────────────────────
XCODEBUILD_ARGS=(
    test-without-building
    -project "${PROJECT}"
    -scheme "${SCHEME}"
    -destination "${DEST}"
    -only-testing:ZhiYuUITests
    -enableCodeCoverage YES
    -derivedDataPath "${DERIVED}"
    -parallel-testing-enabled YES
    -parallel-testing-worker-count 4
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
)

if $HAS_FLAKY; then
    for skip_arg in "${FLAKY_ARGS[@]}"; do
        XCODEBUILD_ARGS+=("$skip_arg")
    done
fi

set +e
set -o pipefail
xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1 | tee "$LOG_FILE"

UI_EXIT=${PIPESTATUS[0]}
set -e

if [ ${UI_EXIT} -ne 0 ]; then
  summarize_xcodebuild_errors "$LOG_FILE" "UI 自动化测试" "${UI_EXIT}"
  exit ${UI_EXIT}
fi
