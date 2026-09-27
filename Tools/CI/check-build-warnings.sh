#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/CI/check-build-warnings.sh
# 脚本功能: 从编译日志中提取 Swift 编译告警，若有告警则打印全部并阻断流水线。
#           仅检查项目代码告警，排除第三方开源库（opensrc/）告警。
# 调用方式:
#   bash Tools/CI/check-build-warnings.sh <日志文件路径>
# 退出码:
#   0 — 无告警
#   1 — 发现告警
#   2 — 参数错误或文件不存在
# ==============================================================================
set -euo pipefail

LOG_FILE="${1:-}"

if [ -z "$LOG_FILE" ]; then
    echo "❌ 用法: bash Tools/CI/check-build-warnings.sh <日志文件路径>"
    exit 2
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ 日志文件不存在: $LOG_FILE"
    exit 2
fi

# 提取编译告警，排除第三方库（opensrc/ 路径）和已知豁免项
# 匹配两种告警格式：
#   1. TTY 模式：⚠️ 标记（xcodebuild 输出到终端时使用）
#   2. 非 TTY 模式：warning: 关键词（xcodebuild 输出重定向到文件时使用）
# 清理 ANSI 颜色码，清理 ⚠️ 之前的 CI 时间戳/runner 前缀
#
# 豁免白名单（已知的无法消除的第三方 API 废弃告警）：
#   - TestWindowHelper.swift: UIWindow(frame:) iOS 26 废弃，单元测试无 windowScene 时的必要回退
#   - scene.windows: UIWindowScene.windows iOS 15 废弃，需逐文件迁移至 keyWindow API
#   - 非 Swift 编译器告警：libpng、appintentsmetadataprocessor、Input PNG
WARNINGS=$(grep -E "⚠️|warning:" "$LOG_FILE" \
    | sed -E 's/\x1b\[[0-9;]*m//g' \
    | grep -v "opensrc/" \
    | grep -v "check-build-warnings" \
    | grep -v "slather" \
    | grep -v "TestWindowHelper.swift" \
    | grep -v "libpng" \
    | grep -v "appintentsmetadataprocessor" \
    | grep -v "Input PNG" \
    | grep -v "'init(frame:)' was deprecated in iOS 26.0" \
    | grep -v "'windows' was deprecated in iOS 15.0" \
    | sed -E 's/^[^⚠️]*⚠️/⚠️/' \
    || true)

if [ -n "$WARNINGS" ]; then
    WARNING_COUNT=$(echo "$WARNINGS" | wc -l | tr -d ' ')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ 编译阶段发现 ${WARNING_COUNT} 条告警，阻断流水线"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$WARNINGS"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "请修复以上告警后重新提交。"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi

echo "✅ 编译阶段无告警"
exit 0
