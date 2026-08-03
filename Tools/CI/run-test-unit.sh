#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/ci/run-test-unit.sh
# 脚本功能: 构建、执行单元测试并收集覆盖率。支持本地及 CI 两种模式，可自动过滤指定不稳定/耗时测试。
# 调用方式:
#   本地运行: ./Tools/ci/run-test-unit.sh
#   CI 运行:  ./Tools/ci/run-test-unit.sh --ci
# ==============================================================================

set -euo pipefail

# 引入持续集成公共基础底座
source "$(dirname "$0")/ci-common-shared.sh"

# ── 1. 常量与环境配置 ──────────────────────────────────────────
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData-ios"

# 获取动态寻找出的最新可用模拟器
SIM_NAME=$(find_simulator)
DESTINATION="platform=iOS Simulator,name=${SIM_NAME}"

# ── 2. 从 @flaky 注释自动收集不稳定测试 ─────────────────────────────
echo "🔍 收集 @flaky 标记的不稳定测试..."
FLAKY_ARGS=()
HAS_FLAKY=false
while IFS= read -r skip_arg; do
    if [ -n "$skip_arg" ]; then
        FLAKY_ARGS+=("$skip_arg")
        HAS_FLAKY=true
    fi
done < <(bash Tools/ci/run-test-flaky-report.sh)

# ── 3. 模式解析 ──────────────────────────────────────────────
CI_MODE="false"
if [ "${1:-}" = "--ci" ] || [ "${CI:-}" = "true" ]; then
    CI_MODE="true"
fi

# ── 3.5 动态并行度调度 ─────────────────────────────────────────
# 进程级并行：xcodebuild 自动克隆并 round-robin 分配测试至各模拟器实例
# 区别于线程级并行 (-parallel-testing-enabled)，每个模拟器是独立 OS 进程，完全避免 actor 冲突。
# 在 CI 环境下（CPU 和内存资源受限）使用 2 个实例，防止 4 实例导致 CPU 饥饿引发测试超时；
# 在本地开发模式下默认保留 4 个实例，充分发挥本地高性能多核主机的优势。
if [ "${CI_MODE}" = "true" ]; then
    PARALLEL_COUNT=2
else
    PARALLEL_COUNT=4
fi

PARALLEL_DESTINATIONS=()
for ((i=0; i<PARALLEL_COUNT; i++)); do
    PARALLEL_DESTINATIONS+=("-destination" "${DESTINATION}")
done
echo "📱 使用模拟器: ${SIM_NAME}（进程级并行 ×${PARALLEL_COUNT}）"

# ── 4. 构造 xcodebuild 参数 ──────────────────────────────────
XCODEBUILD_ARGS=(
    test
    -project "${PROJECT}"
    -scheme "${SCHEME}"
    -only-testing:ZhiYuTests
    "${PARALLEL_DESTINATIONS[@]}"
    -derivedDataPath "${DERIVED_DATA_PATH}"
    -enableCodeCoverage YES
    # 不启用线程级并行（-parallel-testing-enabled NO 为默认值），
    # 改用进程级并行：多 -destination 标志让 xcodebuild 将测试分布到多个模拟器实例。
    # 每个模拟器是独立 OS 进程，拥有独立的 MainActor，完全避免
    # _swift_task_dealloc_specific 等 actor 隔离冲突。
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
)

# 追加不稳定测试跳过参数（用 flag 守护，避免 bash 3.2 空数组触发 set -u）
if $HAS_FLAKY; then
    for skip_arg in "${FLAKY_ARGS[@]}"; do
        XCODEBUILD_ARGS+=("$skip_arg")
    done
fi

# 如果是 CI 模式，指定共享的 SPM 缓存目录以提速构建
if [ "${CI_MODE}" = "true" ]; then
    XCODEBUILD_ARGS+=("-clonedSourcePackagesDirPath" "${SPM_CACHE_DIR}")
fi

# 确保 build 目录存在
mkdir -p build

# ── 4.5 打印构建版本信息 ──────────────────────────────────────
print_version_info() {
    local PLIST="Sources/Info.plist"
    if [ -f "$PLIST" ]; then
        local ver build hash ts
        ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "N/A")
        build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "N/A")
        hash=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" 2>/dev/null || echo "N/A")
        ts=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" 2>/dev/null || echo "N/A")
        echo "📦 版本: ${ver} (build ${build}) | commit: ${hash} | 构建时间: ${ts}"
    else
        echo "📦 版本: Info.plist 不可用"
    fi
}

# ── 5. 执行测试逻辑 ──────────────────────────────────────────
print_version_info
echo "===> 开始运行单元测试..."
echo "模式: $([ "${CI_MODE}" = "true" ] && echo "CI 自动化模式" || echo "本地开发模式")"

set +e
if [ "${CI_MODE}" = "true" ]; then
    # CI 模式下，使用管道流进行进度统计并用 xcbeautify 生成 JUnit 报告
    set -o pipefail
    xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1 \
        | tee "${BUILD_DIR}/test_raw.log" \
        | Tools/ci/run-test-progress.sh \
        | xcbeautify --report junit --report-path "${BUILD_DIR}/test_report.junit"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
else
    # 本地模式直接在前台输出，方便查看详细堆栈
    xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1 | tee "${BUILD_DIR}/test_raw.log"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
fi
set -e

# ── 6. 结果判定 ──────────────────────────────────────────────
print_version_info
if [ ${TEST_EXIT_CODE} -eq 0 ]; then
    echo "✓ 所有单元测试通过！"
    exit 0
else
    summarize_xcodebuild_errors "${BUILD_DIR}/test_raw.log" "单元测试" "${TEST_EXIT_CODE}"
    exit ${TEST_EXIT_CODE}
fi
