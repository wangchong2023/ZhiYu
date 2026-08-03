#!/bin/bash
# NAMING-bypass: 豁免工具脚本规范规则检查
# run-test-version-inject-integration.sh
#
# 与 ci-run-test-version-inject-unit.sh（纯单元测试，在临时 git 仓库中运行）不同，
# 本脚本在真实项目仓库中运行，验证 build-pipeline-version-inject.sh 对项目 Info.plist
# 的实际写入效果，穿通 "脚本 → plist → PlistBuddy 读取" 整条链路。
#
# 测试场景:
#   1. 真实项目 Info.plist 备份 → 注入 → 校验 → 恢复
#   2. 四个 key (CFBundleShortVersionString, CFBundleVersion,
#      GIT_SHORT_HASH, BUILD_TIMESTAMP) 全部存在且值合法
#   3. 版本号与当前 git 状态一致

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INJECT_SCRIPT="$PROJECT_ROOT/Tools/ci/build-pipeline-version-inject.sh"
PLIST="$PROJECT_ROOT/Sources/Info.plist"
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

assert_not_empty() {
    local label="$1" value="$2"
    if [ -n "$value" ]; then
        green "  ✅ $label: $value"
        PASS=$((PASS + 1))
    else
        red "  ❌ $label: 值为空"
        FAIL=$((FAIL + 1))
    fi
}

assert_matches() {
    local label="$1" pattern="$2" value="$3"
    if echo "$value" | grep -qE "$pattern"; then
        green "  ✅ $label: $value"
        PASS=$((PASS + 1))
    else
        red "  ❌ $label: '$value' 不匹配模式 '$pattern'"
        FAIL=$((FAIL + 1))
    fi
}

# ── 前置检查 ──
if [ ! -f "$PLIST" ]; then
    red "FATAL: Info.plist 不存在: $PLIST"
    exit 1
fi

if [ ! -f "$INJECT_SCRIPT" ]; then
    red "FATAL: build-pipeline-version-inject.sh 不存在: $INJECT_SCRIPT"
    exit 1
fi

echo ""
echo "══════════════════════════════════════════════════"
echo "  build-pipeline-version-inject.sh 集成测试（真实项目仓库）"
echo "══════════════════════════════════════════════════"
echo ""

# ── 备份原始 plist ──
BACKUP=$(mktemp)
cp "$PLIST" "$BACKUP"
trap "cp '$BACKUP' '$PLIST' && rm -f '$BACKUP'" EXIT

# ── 执行注入 ──
echo "── 执行 build-pipeline-version-inject.sh ──"
bash "$INJECT_SCRIPT" "$PLIST"
echo ""

# ── 测试 1: CFBundleShortVersionString 存在且非空 ──
echo "── 测试 1: SemVer 版本号 ──"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null)
assert_not_empty "CFBundleShortVersionString" "$VERSION"
# 应为 SemVer 格式（含 -dev 后缀）
assert_matches "版本号格式" '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$' "$VERSION"
echo ""

# ── 测试 2: CFBundleVersion 应为数字（git rev-list --count）──
echo "── 测试 2: 构建号 ──"
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null)
assert_not_empty "CFBundleVersion" "$BUILD"
assert_matches "构建号为数字" '^[0-9]+$' "$BUILD"
# 与当前 git rev-list --count HEAD 一致
EXPECTED_BUILD=$(git -C "$PROJECT_ROOT" rev-list --count HEAD)
assert_equals "构建号与 git rev-list --count 一致" "$EXPECTED_BUILD" "$BUILD"
echo ""

# ── 测试 3: GIT_SHORT_HASH 为 hex 字符串 ──
echo "── 测试 3: 短哈希 ──"
HASH=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" 2>/dev/null)
assert_not_empty "GIT_SHORT_HASH" "$HASH"
assert_matches "短哈希为 hex" '^[0-9a-f]{7,}$' "$HASH"
# 与 git rev-parse --short HEAD 一致
EXPECTED_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)
assert_equals "短哈希与 git rev-parse --short 一致" "$EXPECTED_HASH" "$HASH"
echo ""

# ── 测试 4: BUILD_TIMESTAMP 为 ISO 8601 格式 ──
echo "── 测试 4: 构建时间 ──"
TIMESTAMP=$(/usr/libexec/PlistBuddy -c "Print :BUILD_TIMESTAMP" "$PLIST" 2>/dev/null)
assert_not_empty "BUILD_TIMESTAMP" "$TIMESTAMP"
assert_matches "ISO 8601 格式" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$TIMESTAMP"
echo ""

# ── 测试 5: 恢复备份后 key 不存在（证明注入前 plist 无自定义 key）──
echo "── 测试 5: 恢复备份验证 ──"
cp "$BACKUP" "$PLIST"
if /usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" &>/dev/null; then
    red "  ⚠️ 备份恢复后 GIT_SHORT_HASH 仍存在，说明原始 Info.plist 已含此 key（非错误，仅提示）"
else
    green "  ✅ 备份恢复后 GIT_SHORT_HASH 已移除（注入前 plist 无此 key）"
    PASS=$((PASS + 1))
fi
echo ""

# ── 结果汇总 ──
echo "══════════════════════════════════════════════════"
echo "  通过: $PASS  失败: $FAIL"
echo "══════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ] || exit 1
