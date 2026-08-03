#!/bin/bash

# lint_layer_markers.sh
# 验证 Swift 文件是否包含合法的架构层级标记 [L0], [L0.5], [L1], [L1.5], [L2], [L3] 或者 [Shared]
# 用于 Git pre-commit hook 

# 开启严格模式
set -euo pipefail

# 允许的层级标记正则表达式
VALID_MARKERS="\[(L0|L0\.5|L1|L1\.5|L2|L3|Shared)\]"

# 获取暂存区中修改或新增的 .swift 文件 (排除 Tests 目录和第三方代码)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' | grep -v '^Tests/' | grep -v 'Tools/' | grep -v 'Packages/' || true)

if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

# 记录错误状态
ERRORS_FOUND=0

echo "🔍 [Lint] 开始执行架构层级标记校验..."

for FILE in $STAGED_FILES; do
    # 检查文件前 20 行是否包含合法标记
    if ! head -n 20 "$FILE" | grep -E "$VALID_MARKERS" > /dev/null; then
        echo "❌ [Error] 文件缺少架构层级标记: $FILE"
        echo "   👉 请在文件头部的说明注释中添加如 [L1] 或 [L2] 等层级标记。"
        ERRORS_FOUND=1
    fi
done

if [ $ERRORS_FOUND -ne 0 ]; then
    echo "🔴 [Lint] 架构层级标记校验失败。请修复上述文件后重新 commit。"
    echo "   如果此文件不需要标记（如简单的协议或配置），请添加 [Shared] 标记。"
    exit 1
fi

echo "✅ [Lint] 所有变动的业务文件均符合架构层级标记规范。"
exit 0
