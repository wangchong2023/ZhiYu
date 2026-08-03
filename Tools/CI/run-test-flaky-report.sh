#!/bin/bash
# ==============================================================================
# run-test-flaky-report.sh
# 扫描 Tests/ 中 @flaky: 标记的测试，生成 CI 跳过列表
# 用法: ./Tools/ci/run-test-flaky-report.sh
# 输出: 打印 -skip-testing:Target/TestClass/testName 参数列表 (stdout)
# ==============================================================================
# 仅在直接执行时启用严格模式，source 引入时不改变父脚本设置
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../Tests" && pwd)"
OUTPUT_FILE="build/.flaky_tests"

echo "🔍 扫描 @flaky 标记的测试..." >&2

# 收集所有被 @flaky 标记的测试方法
FLAKY_TESTS=()
while IFS= read -r file; do
    # 从文件路径推断 test target
    if echo "$file" | grep -q "Tests/UI/"; then
        target="ZhiYuUITests"
    else
        target="ZhiYuTests"
    fi

    # 从文件名推断类名
    class_name=$(basename "$file" .swift)

    # 从文件中提取 @flaky 标记的测试方法（取 @flaky 行后紧跟的 func test 行）
    while IFS= read -r func_name; do
        [ -n "$func_name" ] && FLAKY_TESTS+=("${target}/${class_name}/${func_name}")
    done < <(grep -A1 '@flaky:' "$file" | grep -o 'func test[A-Za-z0-9_]*' | sed 's/^func //' || true)
done < <(grep -rl '@flaky:' "$TESTS_DIR" --include="*.swift" || true)

# 输出到文件
if [ ${#FLAKY_TESTS[@]} -eq 0 ]; then
    echo "" > "$OUTPUT_FILE"
    echo "✅ 未发现 @flaky 标记的测试" >&2
else
    printf '%s\n' "${FLAKY_TESTS[@]}" > "$OUTPUT_FILE"
    echo "📋 发现 ${#FLAKY_TESTS[@]} 个不稳定测试:" >&2
    for t in "${FLAKY_TESTS[@]}"; do
        echo "   - $t" >&2
    done
fi

# 输出 -skip-testing 参数 (stdout)
while IFS= read -r test_id; do
    [ -n "$test_id" ] && echo "-skip-testing:${test_id}"
done < "$OUTPUT_FILE"

# 仅在直接执行时退出，source 引入时 return（避免终止父脚本）
return 0 2>/dev/null || exit 0
