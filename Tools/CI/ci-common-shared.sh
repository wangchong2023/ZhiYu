#!/bin/bash
# -*- coding: utf-8 -*-
#
#  ci-common-shared.sh
#  ZhiYu
#
#  Created by Antigravity on 2026/06/21.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/CI] 持续集成公共底座
#  核心职责：集中定义项目级别的公共路径与变量，提供高可用模拟器自动寻找函数、
#           不稳定测试（Flaky）列表参数化组装、以及统一的 xcodebuild 编译错误拦截汇总 Helper。
#

# ==============================================================================
# MARK: - 环境变量与离线依赖自动加载
# ==============================================================================

# 自动载入离线开源依赖环境变量 (OPENSRC_ROOT)
if [ -f "Config/.env.local" ]; then
    source "Config/.env.local"
elif [ -f "../Config/.env.local" ]; then
    source "../Config/.env.local"
fi

# 确保 CI 执行环境包含基础工具链路径
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

# 如果 ZhiYu.xcodeproj 不存在，自动跑 bootstrap 一键修复
if [ ! -d "ZhiYu.xcodeproj" ] && [ -f "Tools/scripts/run-quality-bootstrap.sh" ]; then
    echo "⚙️  CI 环境缺失 Xcode 项目文件，自动触发 bootstrap 一键生成..."
    bash Tools/scripts/run-quality-bootstrap.sh
fi

# 项目工程文件名
export PROJECT="ZhiYu.xcodeproj"

# 默认构建 Scheme
export SCHEME="ZhiYu"

# SPM 依赖库共享缓存目录
# 策略：优先 /tmp（CI 与宿主机共享），其次 ~/.cache（持久化），自动互为备份
PERSISTENT_CACHE="${HOME}/.cache/zhiyu-spm"
SHARED_CACHE="/tmp/zhiyu-spm-cache"

if [ -d "$SHARED_CACHE/checkouts" ]; then
    export SPM_CACHE_DIR="$SHARED_CACHE"
elif [ -d "$PERSISTENT_CACHE/checkouts" ]; then
    echo "📦 /tmp 缓存不存在，从 ~/.cache 恢复..."
    cp -a "$PERSISTENT_CACHE" "$SHARED_CACHE"
    export SPM_CACHE_DIR="$SHARED_CACHE"
else
    export SPM_CACHE_DIR="$SHARED_CACHE"
    echo "⚠️  SPM 缓存为空，将从 GitHub 下载依赖（需代理）"
fi

# 集中化构建输出根目录
export BUILD_DIR="build"

# ==============================================================================
# MARK: - 公共方法函数库
# ==============================================================================

# 
# 函数名称: find_simulator
# 函数功能: 动态寻找本机可用的最新 iOS 模拟器。
#          优先寻找 iPhone 17 Pro，若无则回退至任意可用的最新 iPhone 模拟器，
#          若全部缺失，则默认回退到 iPhone 16。
# 返回结果: 打印模拟器名称（stdout），并可由调用者捕获
# 
find_simulator() {
    local sim
    # 优先精确匹配 iPhone 17 Pro
    sim=$(xcrun simctl list devices available -j 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if 'iPhone 17 Pro' in d.get('name','') and d.get('isAvailable', False):
            print(d['name']); exit()
" 2>/dev/null)

    if [ -n "${sim}" ]; then
        echo "${sim}"
        return
    fi

    # 二级回退：查找任意可用的最新 iPhone 模拟器
    sim=$(xcrun simctl list devices available -j 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
candidates = []
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime and 'iPhone' not in runtime:
        continue
    for d in devices:
        name = d.get('name', '')
        if 'iPhone' in name and d.get('isAvailable', False):
            candidates.append((runtime, name))
candidates.sort(reverse=True)
if candidates:
    print(candidates[0][1])
" 2>/dev/null)

    echo "${sim:-iPhone 16}"
}

#
# 函数名称: find_ipad_simulator
# 函数功能: 动态寻找本机可用的最新 iPad 模拟器（供 iPad 专用 UI 测试使用）。
#          优先寻找 iPad Pro 13-inch (M5)，若无则回退至最新 iPad。
# 返回结果: 打印模拟器名称（stdout），并可由调用者捕获
#
find_ipad_simulator() {
    local sim
    # 优先精确匹配列表
    local preferred=("iPad Pro 13-inch (M5)" "iPad Pro 11-inch (M5)" "iPad Air 13-inch (M4)")
    for name in "${preferred[@]}"; do
        sim=$(xcrun simctl list devices available -j 2>/dev/null \
            | python3 -c "
import json, sys
target = '$name'
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('name') == target and d.get('isAvailable', False):
            print(d['name']); exit()
" 2>/dev/null)
        if [ -n "${sim}" ]; then
            echo "${sim}"
            return
        fi
    done

    # 二级回退：任意可用 iPad
    sim=$(xcrun simctl list devices available | grep -i "ipad" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ ([A-F0-9-]*)$//')
    echo "${sim:-iPad Pro 13-inch (M5)}"
}

# 
# 函数名称: summarize_xcodebuild_errors
# 函数功能: 统一提取并输出 xcodebuild 执行失败时的日志摘要信息。
#          提取包含的标准编译器错误、致命运行错误，并截取日志尾部，以便在 Xcode 中高亮显示或 CI 中快速排查。
# 参数说明:
#   $1 - 原始日志文件路径 (必填)
#   $2 - 构建任务标识标签 (必填，如 "iOS", "UI Tests")
#   $3 - 异常退出状态码 (必填)
# 
summarize_xcodebuild_errors() {
    local log_file="$1"
    local label="$2"
    local exit_code="$3"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ ${label} 执行失败 (退出状态码: ${exit_code})"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  编译/构建错误:"
    # 提取符合 Xcode 错误格式的错误行，排序去重后最多输出 20 行
    grep -E "^.*:[0-9]+:[0-9]+: error:" "$log_file" | sort -t: -k1,1 -k2,2n -u | head -20 || echo "  (未匹配到标准编译错误)"
    echo ""
    echo "  致命运行错误:"
    grep -i "fatal error" "$log_file" | head -10 || echo "  (无致命运行错误)"
    echo ""
    echo "  失败测试用例 (若有):"
    grep -E "Test case.*failed|Test Suite.*failed|failed" "$log_file" | grep -v "check_hardcoded" | tail -20 || echo "  (无失败测试用例)"
    echo ""
    echo "  日志尾部 (最后 15 行):"
    tail -15 "$log_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  完整日志文件路径: file://${PWD}/${log_file}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
