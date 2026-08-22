#!/bin/bash
#
# test-progress-monitor.sh
#
# 系统层级：[Tools] CI/CD 工具脚本
# 核心职责：监控 xcodebuild 全量测试进展，每 60 秒输出用例数、通过/失败/跳过数、
#           已用时长、Top 5 最慢用例。测试结束后输出最终汇总（整体运行时长 + Top 5 + 失败清单）。
#
# 用法：
#   bash Tools/ios/test-progress-monitor.sh <PID> <LOG_PATH>
#
# 参数：
#   PID       — xcodebuild 进程 PID
#   LOG_PATH  — 测试输出日志路径
#
# 示例：
#   nohup xcodebuild test ... > /tmp/test.log 2>&1 &
#   bash Tools/ios/test-progress-monitor.sh $! /tmp/test.log
#

set -uo pipefail

if [ "$#" -lt 2 ]; then
    echo "用法: bash $0 <PID> <LOG_PATH>"
    echo "示例: bash $0 12345 /tmp/test.log"
    exit 1
fi

PID="$1"
LOG="$2"
START_TS=$(date +%s)

# 输出 Top N 最慢用例（从已完成的 passed/failed 用例中提取）
print_top_slow() {
    local n="${1:-5}"
    # xcodebuild 格式: Test Case '-[Suite testMethod]' passed (0.123 seconds).
    # 用 sed 提取秒数前缀，sort 降序，取 Top N
    grep -E "Test Case.*' (passed|failed) \([0-9]+\.[0-9]+ seconds\)" "$LOG" 2>/dev/null \
        | sed -E "s/.*\(([0-9]+\.[0-9]+) seconds\).*/\1|&/" \
        | sort -t'|' -rn \
        | head -"$n" \
        | cut -d'|' -f2 \
        | sed 's/^/  /'
}

# 格式化时长
fmt_duration() {
    local total="$1"
    local mins=$((total / 60))
    local secs=$((total % 60))
    echo "${mins}m${secs}s"
}

# 输出当前统计 + Top 5
print_stats() {
    local label="$1" pas="$2" fai="$3" ski="$4" tot="$5" wall="$6"
    local dur
    dur=$(fmt_duration "$wall")
    echo "[$label] 总用例: $tot | 通过: $pas | 失败: $fai | 跳过: $ski | 已用时: $dur"
    local slow
    slow=$(print_top_slow 5)
    if [ -n "$slow" ]; then
        echo "--- Top 5 最慢用例 ---"
        echo "$slow"
    fi
    echo ""
}

while true; do
    if ! ps -p "$PID" > /dev/null 2>&1; then
        END_TS=$(date +%s)
        WALL_TIME=$((END_TS - START_TS))
        PASSED=$(grep -c "Test Case.*' passed" "$LOG" 2>/dev/null || true)
        FAILED=$(grep -E "^Test Case.*' failed " "$LOG" 2>/dev/null | wc -l | tr -d '[:space:]')
        SKIPPED=$(grep -c "Test Case.*' skipped" "$LOG" 2>/dev/null || true)
        [ -z "$PASSED" ] && PASSED=0
        [ -z "$FAILED" ] && FAILED=0
        [ -z "$SKIPPED" ] && SKIPPED=0
        TOTAL=$((PASSED + FAILED + SKIPPED))
        echo "========================================"
        echo "测试已结束"
        print_stats "最终" "$PASSED" "$FAILED" "$SKIPPED" "$TOTAL" "$WALL_TIME"
        if [ "$FAILED" -gt 0 ]; then
            echo "--- 失败用例 ---"
            grep -E "^Test Case.*' failed " "$LOG" 2>/dev/null || true
        fi
        echo "========================================"
        break
    fi

    sleep 60
    NOW_TS=$(date +%s)
    WALL_TIME=$((NOW_TS - START_TS))

    PASSED=$(grep -c "Test Case.*' passed" "$LOG" 2>/dev/null || true)
    FAILED=$(grep -E "^Test Case.*' failed " "$LOG" 2>/dev/null | wc -l | tr -d '[:space:]')
    SKIPPED=$(grep -c "Test Case.*' skipped" "$LOG" 2>/dev/null || true)
    [ -z "$PASSED" ] && PASSED=0
    [ -z "$FAILED" ] && FAILED=0
    [ -z "$SKIPPED" ] && SKIPPED=0
    TOTAL=$((PASSED + FAILED + SKIPPED))

    if [ "$TOTAL" -eq 0 ]; then
        COMPILE_LINE=$(tail -1 "$LOG" 2>/dev/null | head -c 120)
        echo "[$(fmt_duration "$WALL_TIME")] 编译中... | $COMPILE_LINE"
        echo ""
    else
        print_stats "$(fmt_duration "$WALL_TIME")" "$PASSED" "$FAILED" "$SKIPPED" "$TOTAL" "$WALL_TIME"
    fi
done
