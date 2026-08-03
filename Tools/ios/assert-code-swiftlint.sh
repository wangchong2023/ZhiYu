#!/bin/bash
#
#  assert-code-swiftlint.sh
#  ZhiYu
#
#  Created by Antigravity on 2026/08/02.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：独立封装 SwiftLint 静态质量检测脚本，暴露标准 Xcode/CI 错误行高亮与熔断状态码。
#

set -e

# 1. 补全 macOS 常用工具链 PATH
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/bin"

# 2. 检查 SwiftLint 可执行文件安装状态
if ! which swiftlint >/dev/null 2>&1; then
    echo "warning: [Gatekeeper] SwiftLint 未安装，跳过静态检查。请从 https://github.com/realm/SwiftLint 下载安装。"
    exit 0
fi

# 3. 运行 SwiftLint 并启用严格模式（--strict）与 Xcode 格式化输出
echo "🔍 [SwiftLint Audit] 开始执行 Swift 代码静态分析与规范校验..."
set +e
swiftlint lint --strict --reporter xcode
EXIT_CODE=$?
set -e

# 4. 根据结果响应并向外部透明暴露退出状态码
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ [SwiftLint Audit] 发现 Swift 静态质量或代码规范违规，构建阻断 (Exit Code: ${EXIT_CODE})。"
    exit $EXIT_CODE
else
    echo "✅ [SwiftLint Audit] 审计通过：Swift 代码无违反规范项。"
    exit 0
fi
