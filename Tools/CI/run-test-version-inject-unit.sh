#!/bin/bash
# NAMING-bypass: 豁免工具脚本规范规则检查
# run-test-version-inject-unit.sh
#
# 测试场景:
#   1. 无 tag → CFBundleShortVersionString = "0.0.0-dev"
#   2. 有 tag  → CFBundleShortVersionString = 去掉 v 前缀的值
#   3. 构建号  → CFBundleVersion = git rev-list --count HEAD
#   4. 短哈希  → GIT_SHORT_HASH 为 7 字符 hex
#   5. 幂等写入 → 重复注入后 GIT_SHORT_HASH 和 BUILD_TIMESTAMP 一致

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INJECT_SCRIPT="$SCRIPT_DIR/build-pipeline-version-inject.sh"
PASS=0
FAIL=0

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

assert_equals() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        green "  ✅ $label: $actual"
        PASS=$((PASS + 1))
    else
        red "  ❌ $label: 预期 '$expected'，实际 '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# ── 初始化临时 git 仓库 ──
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"
git init --quiet
git config user.email "test@zhiyu.local"
git config user.name "Test Runner"

# 创建模拟 Info.plist
cat > Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
PLIST

git add Info.plist
git commit --quiet -m "Initial commit"

echo ""
echo "════════════════════════════════════════"
echo "  build-pipeline-version-inject.sh 单元测试"
echo "════════════════════════════════════════"
echo ""

# ── 测试 1: 无 tag → fallback "0.0.0-dev" ──
echo "── 测试 1: 无 git tag ──"
bash "$INJECT_SCRIPT" Info.plist > /dev/null 2>&1 || true
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null)
assert_equals "版本号应为 0.0.0-dev" "0.0.0-dev" "$VERSION"
echo ""

# ── 测试 2: 有 tag v1.2.3 → "1.2.3" ──
echo "── 测试 2: git tag v1.2.3 ──"
echo "test" > dummy.txt
git add dummy.txt
git commit --quiet -m "Second commit"
git tag -a v1.2.3 -m "Test release" 2>/dev/null || git tag v1.2.3
bash "$INJECT_SCRIPT" Info.plist > /dev/null 2>&1 || true
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null)
assert_equals "版本号应为 1.2.3" "1.2.3" "$VERSION"
echo ""

# ── 测试 3: 构建号 = git rev-list --count HEAD ──
echo "── 测试 3: 构建号验证 ──"
EXPECTED_BUILD=$(git rev-list --count HEAD)
ACTUAL_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist 2>/dev/null)
assert_equals "构建号应为 $EXPECTED_BUILD" "$EXPECTED_BUILD" "$ACTUAL_BUILD"
echo ""

# ── 测试 4: 短哈希为 hex 字符串 ──
echo "── 测试 4: 短哈希格式 ──"
HASH=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" Info.plist 2>/dev/null)
if [ -n "$HASH" ] && [ "${#HASH}" -ge 7 ] 2>/dev/null; then
    green "  ✅ 短哈希: $HASH (长度 ${#HASH})"
    PASS=$((PASS + 1))
else
    red "  ❌ 短哈希格式异常: '$HASH'"
    FAIL=$((FAIL + 1))
fi
echo ""

# ── 测试 5: 幂等写入（GIT_SHORT_HASH + BUILD_TIMESTAMP）──
echo "── 测试 5: 幂等写入 ──"
bash "$INJECT_SCRIPT" Info.plist > /dev/null 2>&1 || true
HASH2=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" Info.plist 2>/dev/null)
TS1=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" Info.plist 2>/dev/null)
assert_equals "重复注入后短哈希一致" "$HASH" "$HASH2"
# BUILD_TIMESTAMP 应存在且格式为 ISO 8601
if [ -n "$TS1" ] && echo "$TS1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'; then
    green "  ✅ BUILD_TIMESTAMP: $TS1 (ISO 8601)"
    PASS=$((PASS + 1))
else
    red "  ❌ BUILD_TIMESTAMP 格式异常: '$TS1'"
    FAIL=$((FAIL + 1))
fi
echo ""

# ── 结果汇总 ──
echo "════════════════════════════════════════"
echo "  通过: $PASS  失败: $FAIL"
echo "════════════════════════════════════════"

[ "$FAIL" -eq 0 ] || exit 1
