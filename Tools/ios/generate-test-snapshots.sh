#!/bin/bash
# ==============================================================================
# 脚本名称: Tools/ios/generate-test-snapshots.sh
# 作者: Antigravity AI (高级开发工程师)
# 功能说明: 自动定位 iOS 模拟器设备，并在录制模式（RECORD_MODE=1）下运行智宇 (ZhiYu) 快照测试。
#         该脚本会自动识别并启动 iPhone 17 Pro 模拟器，注入必要的环境变量与启动参数，
#         重新生成并覆盖 Tests/SnapshotTests/__Snapshots__ 目录下的快照基准图片。
# 使用方法:
#   1. 给脚本赋权: chmod +x Tools/ios-generate-test-snapshots.sh
#   2. 在项目根目录下运行: ./Tools/ios-generate-test-snapshots.sh
# ==============================================================================

# 强制脚本任何一步出错时立即退出，并捕获未定义变量
set -euo pipefail

# 物理日志存储目录
BUILD_DIR="build"
LOG_FILE="${BUILD_DIR}/update_snapshots.log"

# 创建构建目录 (如果不存在)
mkdir -p "${BUILD_DIR}"

echo "=================================================================="
echo "📸 智宇 (ZhiYu) 自动化快照基准图片更新工具启动..."
echo "=================================================================="

# ------------------------------------------------------------------------------
# 阶段 1: 智能获取 iPhone 17 Pro 模拟器 UDID
# ------------------------------------------------------------------------------
echo "🔍 正在扫描系统中的 iOS 模拟器列表，查找 'iPhone 17 Pro'..."

# 获取所有包含 'iPhone 17 Pro' 的模拟器行
DEVICES_LIST=$(xcrun simctl list devices | grep "iPhone 17 Pro" | grep -v "unavailable" || true)

if [ -z "${DEVICES_LIST}" ]; then
    echo "❌ 错误: 未能在系统中找到任何名为 'iPhone 17 Pro' 的 iOS 模拟器。"
    echo "💡 提示: 请在 Xcode -> Window -> Devices and Simulators 中手动添加一个 'iPhone 17 Pro' 模拟器。"
    exit 1
fi

echo "📋 发现以下备选设备:"
echo "${DEVICES_LIST}"
echo "------------------------------------------------------------------"

# 策略: 优先选取当前处于 'Booted' (已启动) 状态的模拟器
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
# 阶段 2: 确保模拟器已启动 (Booted)
# ------------------------------------------------------------------------------
STATUS=$(xcrun simctl list devices | grep "${UDID}" | grep -o "Booted" || true)
if [ -z "${STATUS}" ]; then
    echo "📱 目标模拟器当前处于关机状态，正在后台拉起模拟器 [${UDID}]..."
    xcrun simctl boot "${UDID}"
    # 等待模拟器完全启动就绪
    echo "⏳ 正在等待模拟器系统服务就绪..."
    xcrun simctl bootstatus "${UDID}"
    echo "✅ 模拟器已就绪。"
else
    echo "✅ 目标模拟器已处于运行中状态。"
fi
# 注入模拟器系统级全局环境变量 RECORD_SNAPSHOTS=1，确保模拟器内部沙盒 App 能完美读取此标识以激活录制模式
echo "🚀 正在向模拟器 [${UDID}] 注入录制模式全局环境变量..."
xcrun simctl spawn "${UDID}" launchctl setenv RECORD_SNAPSHOTS 1

# ------------------------------------------------------------------------------
# 阶段 3: 清理旧缓存与开启快照录制模式执行测试
# ------------------------------------------------------------------------------
echo "🧹 正在物理卸载模拟器 [${UDID}] 中的旧版智宇 App，以防止过往容器数据干扰..."
xcrun simctl uninstall "${UDID}" com.zhiyu.app || true

echo "🛠️ 正在清理 Xcode 编译缓存以排除旧编译干扰..."
xcodebuild clean \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination "platform=iOS Simulator,id=${UDID}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

echo "🚀 开始录制快照。仅运行 ComponentSnapshots 测试类..."
echo "📊 录制输出日志将实时记录至: ${LOG_FILE}"

# 在录制模式下仅执行快照测试套件 ComponentSnapshots
set +e

RECORD_SNAPSHOTS=1 xcodebuild test \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -only-testing:ZhiYuTests/ComponentSnapshots \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  | tee "${LOG_FILE}"

TEST_EXIT_CODE=${PIPESTATUS[0]}

# 清除模拟器全局环境变量，防止干扰后继的日常校验测试
echo "🧹 正在恢复模拟器 [${UDID}] 环境变量状态..."
xcrun simctl spawn "${UDID}" launchctl setenv RECORD_SNAPSHOTS 0

# ------------------------------------------------------------------------------
# 阶段 4: 结果分析
# ------------------------------------------------------------------------------
echo "=================================================================="
if [ ${TEST_EXIT_CODE} -eq 0 ]; then
    echo "✅ 成功！快照基准图片已自动重新录制并保存完毕。"
    echo "💡 提示: 请在 Tests/SnapshotTests/__Snapshots__ 目录中通过 git diff 核对更新后的基准图。"
else
    echo "❌ 警告: 快照重新录制失败，或编译过程中出现错误 (Exit Code: ${TEST_EXIT_CODE})。"
    echo "💡 调试建议: 请查看 ${LOG_FILE} 文件的结尾内容获取详细诊断信息。"
fi
echo "=================================================================="

exit ${TEST_EXIT_CODE}
