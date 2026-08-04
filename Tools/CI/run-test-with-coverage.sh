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

    # ── 用 slather 生成 SonarQube Generic Coverage XML ──
    # slather 从 .xcresult 提取行级覆盖率，生成 SonarQube 原生支持的 XML 格式
    # 配置文件: .slather.yml (source_files 白名单仅含 Sources/**/*.swift)
    echo "  生成 SonarQube 覆盖率报告 (slather)..."
    DERIVED_DATA_DIR=$(dirname "$(dirname "$LATEST_XCRESULT")")
    if command -v slather >/dev/null 2>&1; then
        slather coverage --sonarqube-xml \
            --output-directory "$COVERAGE_DIR" \
            --build-directory "$DERIVED_DATA_DIR" \
            ZhiYu.xcodeproj 2>&1 | grep -v "^warning:" || true
        if [ -f "$COVERAGE_DIR/sonarqube-generic-coverage.xml" ]; then
            echo "  ✅ SonarQube 覆盖率报告: $COVERAGE_DIR/sonarqube-generic-coverage.xml"
        else
            echo "  ⚠️  slather 未生成覆盖率报告，跳过"
        fi
    else
        echo "  ⚠️  slather 未安装，跳过 SonarQube 覆盖率报告生成"
    fi
else
    echo "  ⚠️  未找到 .xcresult 测试结果包，跳过产物导出"
fi

echo "✅ 跑测、覆盖率门禁及性能回归校验全部通过！"

# ── 打印构建版本信息 ──
if [ -f "$PLIST" ]; then
    ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "N/A")
    build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "N/A")
    hash=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" 2>/dev/null || echo "N/A")
    ts=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" 2>/dev/null || echo "N/A")
    echo "📦 版本: ${ver} (build ${build}) | commit: ${hash} | 构建时间: ${ts}"
fi
