#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/CI/run-test-with-coverage.sh
# 脚本功能: 集合执行测试计数、单元测试执行、代码覆盖率阈值审计、性能回归比对。
# ==============================================================================
set -euo pipefail

# ── 打印构建版本信息 ──
PLIST="Sources/Info.plist"
if [ -f "$PLIST" ]; then
    ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "N/A")
    build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "N/A")
    hash=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" 2>/dev/null || echo "N/A")
    ts=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" 2>/dev/null || echo "N/A")
    echo "📦 版本: ${ver} (build ${build}) | commit: ${hash} | 构建时间: ${ts}"
fi

# 1. 统计测试用例总数
echo "===> Count Test Cases"
TEST_COUNT=0
if [ -d "Tests" ]; then
    TEST_COUNT=$(grep -r "^    func test" Tests/ --include="*.swift" | wc -l | tr -d ' ')
fi
echo "  Total Tests Counted: $TEST_COUNT"
mkdir -p build
echo "$TEST_COUNT" > build/.test_count

# 2. 执行单元测试 (CI 模式下执行)
echo "===> Run Unit Tests"
bash Tools/CI/run-test-unit.sh --ci

# 3. 代码覆盖率门禁熔断校验
echo "===> Code Coverage Check"
python3 Tools/CI/assert-test-coverage.py

# 4. 性能回归阻断校验
echo "===> Performance Regression Check"
python3 Tools/CI/check-pipeline-perf-regression.py

# 5. 导出覆盖率产物供 GitLab CI artifacts 归档
echo "===> Export Coverage Artifacts"
COVERAGE_DIR="build/coverage"
mkdir -p "$COVERAGE_DIR"

# 复制最新 .xcresult 包
LATEST_XCRESULT=$(python3 -c "
import glob, os
results = glob.glob('build/DerivedData-ios/**/*.xcresult', recursive=True)
if results:
    results.sort(key=os.path.getmtime, reverse=True)
    print(results[0])
" 2>/dev/null || true)

if [ -n "$LATEST_XCRESULT" ] && [ -d "$LATEST_XCRESULT" ]; then
    echo "  导出 .xcresult: $LATEST_XCRESULT"
    cp -R "$LATEST_XCRESULT" "$COVERAGE_DIR/"
    # 生成可读的覆盖率摘要
    xcrun xccov view --report --json "$LATEST_XCRESULT" \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
total_covered = 0
total_executable = 0
def walk(node):
    global total_covered, total_executable
    if isinstance(node, dict):
        if 'coveredLines' in node and 'executableLines' in node:
            total_covered += node['coveredLines']
            total_executable += node['executableLines']
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)
walk(data)
if total_executable > 0:
    pct = (total_covered / total_executable) * 100
    summary = f'Total Coverage: {pct:.2f}%\nCovered Lines: {total_covered}\nExecutable Lines: {total_executable}'
    print(summary)
" > "$COVERAGE_DIR/summary.txt"
    echo "  覆盖率摘要: $COVERAGE_DIR/summary.txt"

    # ── 生成 SonarQube Generic Coverage XML（含分支数据）──
    # 使用 SonarSource 官方脚本 xccov-to-sonarqube-generic.sh 从 .xcresult 提取
    # 该脚本用 xccov view --archive（文本格式）提取，包含 branchesToCover/coveredBranches
    # 替代旧 slather 方案（slather 不提取分支数据，只提取行覆盖率）
    echo "  生成 SonarQube 覆盖率报告（含分支数据，SonarSource 官方脚本）..."
    XCCOV_SCRIPT="Tools/CI/coverage/xccov-to-sonarqube-generic.sh"
    if [ -x "$XCCOV_SCRIPT" ]; then
        # 官方脚本输出绝对路径，需转为相对路径（SonarQube 要求相对路径）
        PROJECT_ROOT=$(pwd)
        "$XCCOV_SCRIPT" "$LATEST_XCRESULT" \
            | sed "s|$PROJECT_ROOT/||g" \
            > "$COVERAGE_DIR/sonarqube-generic-coverage.xml" 2>/dev/null
        if [ -s "$COVERAGE_DIR/sonarqube-generic-coverage.xml" ]; then
            BRANCH_COUNT=$(grep -c "branchesToCover" "$COVERAGE_DIR/sonarqube-generic-coverage.xml" || echo 0)
            LINE_COUNT=$(grep -c "lineToCover" "$COVERAGE_DIR/sonarqube-generic-coverage.xml" || echo 0)
            echo "  ✅ SonarQube 覆盖率报告: $COVERAGE_DIR/sonarqube-generic-coverage.xml"
            echo "     行覆盖率节点: $LINE_COUNT | 分支覆盖率节点: $BRANCH_COUNT"
        else
            echo "  ⚠️  官方脚本未生成覆盖率报告，降级到 slather"
            _fallback_slather "$COVERAGE_DIR" "$LATEST_XCRESULT"
        fi
    else
        echo "  ⚠️  官方脚本不存在: $XCCOV_SCRIPT，降级到 slather"
        _fallback_slather "$COVERAGE_DIR" "$LATEST_XCRESULT"
    fi
else
    echo "  ⚠️  未找到 .xcresult 测试结果包，跳过产物导出"
fi

echo "✅ 跑测、覆盖率门禁及性能回归校验全部通过！"

# ── slather 降级方案（无分支数据，仅行覆盖率）──
_fallback_slather() {
    local coverage_dir="$1"
    local xcresult="$2"
    local derived_data_dir
    derived_data_dir=$(dirname "$(dirname "$xcresult")")
    if command -v slather >/dev/null 2>&1; then
        slather coverage --sonarqube-xml \
            --output-directory "$coverage_dir" \
            --build-directory "$derived_data_dir" \
            ZhiYu.xcodeproj 2>&1 | grep -v "^warning:" || true
        if [ -f "$coverage_dir/sonarqube-generic-coverage.xml" ]; then
            echo "  ✅ slather 降级报告（仅行覆盖率，无分支数据）: $coverage_dir/sonarqube-generic-coverage.xml"
        else
            echo "  ⚠️  slather 降级也失败，跳过"
        fi
    else
        echo "  ⚠️  slather 未安装，跳过覆盖率报告生成"
    fi
}

# ── 打印构建版本信息 ──
if [ -f "$PLIST" ]; then
    ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "N/A")
    build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "N/A")
    hash=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" 2>/dev/null || echo "N/A")
    ts=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" 2>/dev/null || echo "N/A")
    echo "📦 版本: ${ver} (build ${build}) | commit: ${hash} | 构建时间: ${ts}"
fi
