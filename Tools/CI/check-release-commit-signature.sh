#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/ci/check-release-commit-signature.sh
# 脚本功能: 校验最近一次 Git 提交是否通过 GPG 签名，并打印警告。本步骤非阻断。
# ==============================================================================
set -euo pipefail

echo "===> Commit Signature"
if git log --show-signature -1 | grep -q "Good signature"; then
    echo "  ✅ Commit signed (已验证签名)"
else
    echo "  ⚠️  Commit NOT signed — 请配置本地 GPG 签名以增强供应链安全 (git config commit.gpgsign true)"
fi
exit 0
