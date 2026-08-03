#!/bin/bash
# ==============================================================================
# 脚本名称: Tools/Utils/run-quality-tests.sh
# 作者: Antigravity AI (高级开发工程师)
# 功能说明: 智能定位 iOS 模拟器设备，一键物理执行智宇 (ZhiYu) 自动化单元与集成测试。
#         解析 xcrun simctl 列表，自动提取无冲突的 iPhone 17 Pro 模拟器 UDID，
#         完美解决因本地多系统版本重名导致 xcodebuild destination 冲突 (Exit Code 65) 的顽疾。
# 使用方法:
#   1. 给脚本赋权: chmod +x Tools/scripts-run-dev-tests.sh
#   2. 在项目根目录下运行: ./Tools/scripts-run-dev-tests.sh
# ==============================================================================

# 强制脚本任何一步出错时立即退出，并捕获未定义变量
set -euo pipefail

# 物理日志存储目录
BUILD_DIR="build"
LOG_FILE="${BUILD_DIR}/test_results.log"

# 创建构建目录 (如果不存在)
mkdir -p "${BUILD_DIR}"

echo "=================================================================="
echo "🚀 智宇 (ZhiYu) 自动化单元测试与集成测试运行中枢启动..."
echo "=================================================================="

# ------------------------------------------------------------------------------
# 阶段 1: 智能获取 iPhone 17 Pro 模拟器 UDID
# ------------------------------------------------------------------------------
echo "🔍 正在扫描系统中的 iOS 模拟器列表，查找 'iPhone 17 Pro'..."

# 获取所有包含 'iPhone 17 Pro' 的模拟器行
DEVICES_LIST=$(xcrun simctl list devices | grep "iPhone 17 Pro" || true)

if [ -z "${DEVICES_LIST}" ]; then
    echo "❌ 错误: 未能在系统中找到任何名为 'iPhone 17 Pro' 的 iOS 模拟器。"
    echo "💡 提示: 请在 Xcode -> Window -> Devices and Simulators 中手动添加一个 'iPhone 17 Pro' 模拟器。"
    exit 1
fi

echo "📋 发现以下备选设备:"
echo "${DEVICES_LIST}"
echo "------------------------------------------------------------------"

# 策略: 优先选取当前处于 'Booted' (已启动) 状态的模拟器以大幅缩短起机耗时
echo "⚡ 正在应用优先级策略过滤 UDID..."
UDID=$(echo "${DEVICES_LIST}" | grep "Booted" | head -n 1 | grep -oE "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}" || true)

if [ -z "${UDID}" ]; then
    # 若没有已启动的，则选取最后一个匹配到的设备 (通常对应最新安装的 iOS SDK 系统版本)
    echo "ℹ️  未检测到已启动的模拟器。正在自动选择最高 OS 系统版本的备选设备..."
    UDID=$(echo "${DEVICES_LIST}" | tail -n 1 | grep -oE "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}" || true)
fi

if [ -z "${UDID}" ]; then
    echo "❌ 错误: 无法解析模拟器 UDID，请检查 simctl 输出是否规范。"
    exit 1
fi

echo "✨ 成功精准锁定目标模拟器 [iPhone 17 Pro]，UDID: ${UDID}"

# ------------------------------------------------------------------------------
# 阶段 2: 清理旧缓存与测试一键执行
# ------------------------------------------------------------------------------
echo "🧹 正在物理卸载模拟器 [${UDID}] 中的旧版智宇 App，以彻底打破宿主容器缓存..."
xcrun simctl uninstall "${UDID}" com.zhiyu.app || true

echo "🛠️ 正在清理 Xcode 编译缓存以打碎 DerivedData 残留..."
xcodebuild clean \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination "platform=iOS Simulator,id=${UDID}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

echo "🚀 正在启动全量测试编译与装载流程..."
echo "📊 测试输出日志将实时记录至: ${LOG_FILE}"

# 启动测试。由于不需要对测试包进行签名验证，设置 CODE_SIGNING_ALLOWED=NO
# 动态拼接 UDID 目的地参数以消除歧义
set +e # 允许测试失败时不直接崩溃脚本，以便输出完整的错误摘要

xcodebuild test \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination "platform=iOS Simulator,id=${UDID}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  | tee "${LOG_FILE}"

TEST_EXIT_CODE=${PIPESTATUS[0]}

# ------------------------------------------------------------------------------
# 阶段 3: 解析并总结测试结果
# ------------------------------------------------------------------------------
echo "=================================================================="
if [ ${TEST_EXIT_CODE} -eq 0 ]; then
    echo "✅ 恭喜！智宇 (ZhiYu) 全量测试套件 (包含 Mock LLM、Accelerate 向量、熔断哨兵、LWW同步、CJK分块、快照和 Golden Set RAG 语义评估) 100% 绿码通过！"
else
    echo "❌ 警告: 测试套件执行失败，或编译过程中出现错误 (Exit Code: ${TEST_EXIT_CODE})。"
    echo "💡 调试建议: 请查看 ${LOG_FILE} 文件的结尾内容，定位具体的测试失败用例。"
fi
echo "=================================================================="

exit ${TEST_EXIT_CODE}
