#!/bin/bash
# run-test-progress.sh
# 系统层级：[Tools] CI/CD 工具脚本
# 核心职责：管道式实时监控 xcodebuild 测试进展，输出进度百分比、通过/失败/跳过数、
#           失败即时提示 + 错误详情、Top 5 最慢用例、最终失败汇总。
# 兼容 XCTest 串行 (Test Case) 和并行 (Test case) 格式。
#
# 用法：
#   xcodebuild test ... 2>&1 | Tools/CI/run-test-progress.sh | xcbeautify
#
# 输出说明（全部输出到 stderr，stdout 透传原始日志供 xcbeautify 消费）：
#   [测试进度] 已执行 N/Total (P%) | ✓ passed | ✗ failed | ⊘ skipped | 已运行 Xs
#   ❌ FAIL: Suite.testMethod()
#       ↳ 错误详情行
#   [测试完成] 共执行 N 个用例 / Total | ✓ passed | ✗ failed | ⊘ skipped | 耗时 Xs
#   === Top 5 最慢用例 ===
#   === 失败测试汇总 (N 个) ===
#
# 注意：管道 while 循环在 bash 中运行于子 shell，数组修改不会传回父进程。
#       因此 Top N 最慢用例通过临时文件收集，避免子 shell 作用域限制。

set -o pipefail
declare -i passed=0 failed=0 skipped=0 total=0
declare start_time last_progress=0
start_time=$(date +%s)

readonly CACHE_FILE="build/.test_count"
readonly SLOW_FILE="build/.test_slow_entries"
readonly FAILED_FILE="build/.test_failed_names"
readonly REFRESH_INTERVAL=2

declare -i capture_errors=0

# 脚本退出时清理临时文件（覆盖正常退出和中断）
trap 'rm -f "$SLOW_FILE" "$FAILED_FILE" 2>/dev/null || true' EXIT

if [[ -f "$CACHE_FILE" ]]; then
    total=$(cat "$CACHE_FILE" 2>/dev/null) || total=0
fi

# 记录预计算的总数（来自 build/.test_count），用于判断是否信任 Suite 汇总行
declare -i initial_total=$total

if ((total <= 0)); then
    estimated=$(grep -rc "^[[:space:]]*func test" Tests/ --include="*.swift" 2>/dev/null \
        | awk -F: '{sum += $2} END {print sum}')
    if [[ -n "$estimated" && "$estimated" -gt 0 ]]; then
        total=$estimated
    fi
fi

# 清空临时文件
: > "$SLOW_FILE" 2>/dev/null || true
: > "$FAILED_FILE" 2>/dev/null || true

build_progress() {
    local executed=$((passed + failed + skipped))
    local elapsed=$(($(date +%s) - start_time))
    local line="[测试进度] 已执行 ${executed}"
    if ((total > 0 && total >= executed)); then
        local pct=$((executed * 100 / total))
        line+="/${total} (${pct}%)"
    fi
    line+=" | ✓ ${passed} 通过 | ✗ ${failed} 失败 | ⊘ ${skipped} 跳过 | 已运行 ${elapsed}s"
    printf "\r\033[K%s\n" "$line" >&2
}

# 输出 Top N 最慢用例（从临时文件读取，避免子 shell 作用域问题）
print_top_slow() {
    local n="${1:-5}"
    if [[ ! -s "$SLOW_FILE" ]]; then
        return
    fi
    echo "=== Top ${n} 最慢用例 ===" >&2
    sort -t'|' -rn "$SLOW_FILE" 2>/dev/null \
        | head -"$n" \
        | while IFS='|' read -r sec name; do
            printf "  %.3fs  %s\n" "$sec" "$name" >&2
        done
    echo "" >&2
}

while IFS= read -r line; do
    # 透传到 stdout 供 xcbeautify
    echo "$line"

    # 精确匹配测试结果：' passed/' failed/' skipped 后跟 (X.XXX seconds) 或行尾
    # 避免误匹配测试名中含 failed/passed/skipped 的用例
    if [[ "$line" =~ Test\ [Cc]ase.*\'\ passed\ \([0-9]+\.[0-9]+\ seconds\) ]]; then
        ((passed++))
        # 提取耗时和用例名写入临时文件，用于 Top N 最慢统计
        if [[ "$line" =~ \(([0-9]+\.[0-9]+)\ seconds\) ]]; then
            sec="${BASH_REMATCH[1]}"
            name=$(echo "$line" | grep -oE "\-\s*\[.*\]" | head -1 | sed 's/^-\s*//;s/^\[//;s/\]$//')
            [[ -n "$name" ]] && echo "${sec}|${name}" >> "$SLOW_FILE"
        fi
    elif [[ "$line" =~ Test\ [Cc]ase.*\'\ skipped\ \([0-9]+\.[0-9]+\ seconds\) ]]; then
        ((skipped++))
    elif [[ "$line" =~ Test\ [Cc]ase.*\'\ failed\ \([0-9]+\.[0-9]+\ seconds\) ]]; then
        ((failed++))
        # 提取用例名：兼容 -[Suite testMethod] 和 Suite.testMethod() 格式
        test_name=$(echo "$line" | grep -oE "\-\s*\[.*\]" | head -1 | sed 's/^-\s*//;s/^\[//;s/\]$//')
        if [[ -n "$test_name" ]]; then
            echo "$test_name" >> "$FAILED_FILE"
            printf "\r\033[K❌ FAIL: %s\n" "$test_name" >&2
        fi
        # 提取失败用例耗时
        if [[ "$line" =~ \(([0-9]+\.[0-9]+)\ seconds\) ]]; then
            sec="${BASH_REMATCH[1]}"
            name=$(echo "$line" | grep -oE "\-\s*\[.*\]" | head -1 | sed 's/^-\s*//;s/^\[//;s/\]$//')
            [[ -n "$name" ]] && echo "${sec}|${name}" >> "$SLOW_FILE"
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

    # 捕获汇总行更新精确总数（仅当缓存总数不可用时，累加各 Suite 的用例数）
    if [[ "$line" =~ Executed\ [0-9]+\ tests ]]; then
        new_total=$(echo "$line" | grep -oE '[0-9]+' | head -1)
        if [[ -n "$new_total" && "$new_total" -gt 0 ]]; then
            if ((initial_total <= 0)); then
                total=$((total + new_total))
                echo "$total" > "$CACHE_FILE" 2>/dev/null || true
            fi
        fi
    fi

    executed=$((passed + failed + skipped))
    now=$(date +%s)
    if ((executed > 0 && now - last_progress >= REFRESH_INTERVAL)); then
        build_progress
        last_progress=$now
    fi
done

elapsed=$(($(date +%s) - start_time))
final_line="[测试完成] 共执行 $((passed + failed + skipped)) 个用例"
if ((total > 0 && total >= (passed + failed + skipped))); then
    final_line+=" / ${total}"
fi
final_line+=" | ✓ ${passed} 通过 | ✗ ${failed} 失败 | ⊘ ${skipped} 跳过 | 耗时 ${elapsed}s"
printf "\r\033[K%s\n" "$final_line" >&2

echo "" >&2
print_top_slow 5

if [[ -s "$FAILED_FILE" ]]; then
    fail_count=$(wc -l < "$FAILED_FILE" | tr -d '[:space:]')
    echo "=== 失败测试汇总 (${fail_count} 个) ===" >&2
    local_i=1
    while IFS= read -r fname; do
        echo "  ${local_i}. ${fname}" >&2
        ((local_i++))
    done < "$FAILED_FILE"
    echo "" >&2
fi
