#!/bin/bash
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明:
# 本脚本用于在本地一键构建 ZhiYu 项目的所有平台 target，包括 iOS 模拟器、macOS Catalyst 以及 watchOS 模拟器。
# 脚本清空并重新生成各平台的构建日志，分别调用 xcodebuild 编译，
# 并在编译完成后统计、提取各平台的 warning 和 error 计数以方便快速分析编译健康度。
#

echo "Building iOS..."
xcodebuild clean build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build_ios.log 2>&1

echo "Building macOS Catalyst..."
xcodebuild clean build -project ZhiYu.xcodeproj -scheme ZhiYuMac -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build_mac.log 2>&1

echo "Building watchOS..."
xcodebuild clean build -project ZhiYu.xcodeproj -scheme ZhiYuWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build_watch.log 2>&1

echo "iOS Warns/Errors:"
grep -i "warning:" build_ios.log | wc -l
grep -i "error:" build_ios.log | wc -l

echo "Mac Warns/Errors:"
grep -i "warning:" build_mac.log | wc -l
grep -i "error:" build_mac.log | wc -l

echo "Watch Warns/Errors:"
grep -i "warning:" build_watch.log | wc -l
grep -i "error:" build_watch.log | wc -l

