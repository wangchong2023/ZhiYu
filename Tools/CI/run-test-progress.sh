#!/bin/bash
# run-test-progress.sh
# 用法: xcodebuild test ... 2>&1 | Tools/ci-run-test-progress.sh | xcbeautify
# 兼容 XCTest 串行 (Test Case) 和并行 (Test case) 格式

set -o pipefail
declare -i passed=0 failed=0 total=0
declare start_time last_progress=0
start_time=$(date +%s)

readonly CACHE_FILE="build/.test_count"
readonly REFRESH_INTERVAL=2

declare -a failed_names=()
declare -i capture_errors=0

if [[ -f "$CACHE_FILE" ]]; then
    total=$(cat "$CACHE_FILE" 2>/dev/null) || total=0
fi

if ((total <= 0)); then
    estimated=$(grep -rc "^[[:space:]]*func test" Tests/ --include="*.swift" 2>/dev/null \
        | awk -F: '{sum += $2} END {print sum}')
    if [[ -n "$estimated" && "$estimated" -gt 0 ]]; then
        total=$estimated
    fi
fi

build_progress() {
    local executed=$((passed + failed))
    local elapsed=$(($(date +%s) - start_time))
    local line="[测试进度] 已执行 ${executed}"
    if ((total > 0 && total >= executed)); then
        local pct=$((executed * 100 / total))
        line+="/${total} (${pct}%)"
    fi
    line+=" | ✓ ${passed} 通过 | ✗ ${failed} 失败 | 已运行 ${elapsed}s"
    printf "\r\033[K%s\n" "$line" >&2
}

while IFS= read -r line; do
    # 透传到 stdout 供 xcbeautify
    echo "$line"

    if [[ "$line" =~ Test\ [Cc]ase.*passed ]]; then
        ((passed++))
    elif [[ "$line" =~ Test\ [Cc]ase.*failed ]]; then
        ((failed++))
        test_name=$(echo "$line" | grep -oE "[A-Za-z_]+\.[A-Za-z_]+\(\)" | head -1)
        if [[ -n "$test_name" ]]; then
            failed_names+=("$test_name")
            printf "\r\033[K❌ FAIL: %s\n" "$test_name" >&2
        fi
        capture_errors=10  # 捕获随后 10 行的错误详情
    fi

    # 输出失败后的错误详情行
    if ((capture_errors > 0)); then
        if [[ "$line" =~ (error:|XCTAssert|Failed to|caught|threw) ]]; then
            printf "    ↳ %s\n" "$(echo "$line" | sed 's/^[[:space:]]*//')" >&2
            ((capture_errors--))
        fi
    fi

    # 捕获汇总行更新精确总数
    if [[ "$line" =~ Executed\ [0-9]+\ tests ]]; then
        new_total=$(echo "$line" | grep -oE '[0-9]+' | head -1)
        if [[ -n "$new_total" && "$new_total" -gt 0 ]]; then
            total=$new_total
            echo "$new_total" > "$CACHE_FILE" 2>/dev/null || true
        fi
    fi

    executed=$((passed + failed))
    now=$(date +%s)
    if ((executed > 0 && now - last_progress >= REFRESH_INTERVAL)); then
        build_progress
        last_progress=$now
    fi
done

elapsed=$(($(date +%s) - start_time))
final_line="[测试完成] 共执行 $((passed + failed)) 个用例"
if ((total > 0 && total >= (passed + failed))); then
    final_line+=" / ${total}"
fi
final_line+=" | ✓ ${passed} 通过 | ✗ ${failed} 失败 | 耗时 ${elapsed}s"
printf "\r\033[K%s\n" "$final_line" >&2

if ((failed > 0)); then
    echo "" >&2
    echo "=== 失败测试汇总 (${failed} 个) ===" >&2
    for i in "${!failed_names[@]}"; do
        echo "  $((i+1)). ${failed_names[$i]}" >&2
    done
    echo "" >&2
fi
