#!/bin/bash
#
# 脚本名称: Tools/CI/check-code-swift-warnings.sh
#
# 职责说明:
#   在 CI 静态分析阶段执行 Swift 编译告警检查，强制零告警。
#   通过 xcodebuild build-for-testing 编译 iOS Simulator 目标，
#   并启用 SWIFT_TREAT_WARNINGS_AS_ERRORS=YES / GCC_TREAT_WARNINGS_AS_ERRORS=YES，
#   任何 Swift/GCC 编译告警都将升级为编译错误，从而阻断流水线。
#
#   设计理由：
#   - SwiftLint 只能捕获风格问题，无法捕获 Swift 6 编译器告警
#     （unreachable code、未使用变量、async 误用、Sendable 违规等）。
#   - 将告警检查前置到 static-analysis 阶段，可在流水线最早期暴露问题，
#     避免等到 build 阶段才发现告警，节省三平台构建时间。
#
#   本脚本仅编译 iOS Simulator 单平台（最快路径），作为告警门禁。
#   三平台完整构建仍由 build 阶段负责。
#
# 调用方式:
#   本地: bash Tools/CI/check-code-swift-warnings.sh
#   CI:   bash Tools/CI/check-code-swift-warnings.sh
#

set -euo pipefail

# ── 1. 加载 CI 公共库 ──────────────────────────────────────
# shellcheck source=./ci-common-shared.sh
source "$(dirname "$0")/ci-common-shared.sh"

# ── 2. 确保项目工程已生成 ──────────────────────────────────
# ci-common-shared.sh 已有自动 bootstrap 兜底逻辑，此处无需重复

# ── 3. 构造编译参数 ────────────────────────────────────────
# 使用 build-for-testing 而非 build，避免重复编译测试 target
# 仅编译 iOS Simulator 单平台，作为告警门禁的最快路径
LOG_FILE="${BUILD_DIR}/swift_warnings_check.log"
mkdir -p "${BUILD_DIR}"

echo "  [START] Swift Compiler Warnings Check (iOS Simulator, -warnings-as-errors)..."

XCODEBUILD_ARGS=(
    build-for-testing
    -project "${PROJECT}"
    -scheme "${SCHEME}"
    -destination 'generic/platform=iOS Simulator'
    -derivedDataPath "${BUILD_DIR}/DerivedData"
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    # 告警阻断核心：将所有 Swift/GCC 告警视为编译错误
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
    # 抑制第三方依赖的告警（仅检查本项目源码）
    SWIFT_SUPPRESS_WARNINGS=NO
)

# ── 4. 执行编译并捕获结果 ──────────────────────────────────
# xcodebuild 退出码非零即代表存在告警（已升级为错误）或编译失败
set +e
xcodebuild "${XCODEBUILD_ARGS[@]}" > "${LOG_FILE}" 2>&1
EXIT_CODE=$?
set -e

# ── 5. 结果汇总 ───────────────────────────────────────────
if [ $EXIT_CODE -ne 0 ]; then
    echo "  ❌ [FAILED] Swift Compiler Warnings Check (退出状态码: ${EXIT_CODE})"
    echo "     👉 编译告警已升级为错误，请修复以下告警："
    echo "--------------------------------------------------"
    # 仅提取 Swift 编译器输出的告警/错误（格式: 文件路径:行:列: warning:/error:）
    # 排除 Python 脚本输出（如 [App Store Readiness]）、note: 行、以及非编译器行
    grep -E "^[^ ]+:[0-9]+:[0-9]+: (warning|error):" "${LOG_FILE}" | grep -v "App Store Readiness" || tail -n 20 "${LOG_FILE}"
    echo "--------------------------------------------------"
    echo "     📄 完整日志: file://${PWD}/${LOG_FILE}"
    exit 1
else
    echo "  ✅ [PASSED] Swift Compiler Warnings Check (零告警)"
    exit 0
fi
