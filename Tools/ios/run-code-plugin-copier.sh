#!/bin/bash
# 将本地和远程插件压缩包复制到 iOS 模拟器
set -e

BUNDLE_ID="com.zhiyu.app"
DEVICE_ID=$(xcrun simctl list devices | grep "iPhone.*Booted" | grep -o "[A-F0-9\-]\{36\}" | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ 未找到运行中的 iPhone 模拟器"
    echo "请先在 Xcode 中运行应用"
    exit 1
fi

APP_CONTAINER=$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data 2>/dev/null)

if [ -z "$APP_CONTAINER" ]; then
    echo "❌ 应用未安装，请先在 Xcode 中运行"
    exit 1
fi

PLUGINS_DIR="$APP_CONTAINER/Documents/Plugins"
mkdir -p "$PLUGINS_DIR"

echo "📱 模拟器: $DEVICE_ID"
echo "📂 插件目录: $PLUGINS_DIR"
echo ""

# 复制所有本地插件
cp -v Tools/Plugins/Local/*.zyplugin "$PLUGINS_DIR/" 2>/dev/null || true
# 复制所有远程插件
cp -v Tools/Plugins/Remote/*.zyplugin "$PLUGINS_DIR/" 2>/dev/null || true
# 复制原有插件
cp -v Tools/Plugins/smart-cleaner.zyplugin "$PLUGINS_DIR/" 2>/dev/null || true

echo ""
echo "✅ 插件已全部复制到模拟器"
echo "📦 已安装:"
ls -lh "$PLUGINS_DIR"
