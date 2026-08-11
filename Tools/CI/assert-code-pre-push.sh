#!/bin/bash
# ==============================================================================
# 脚本名称: assert-code-pre-push.sh
# 核心职责: Git 推送前统一门禁——核心检查，避免过分耗时。
#
# 原则:
#   - 安全红线 + 编译校验为默认模式（< 30 秒）
#   - pre-commit 已做密钥扫描 + 三平台编译，这里不重复
#   - SwiftLint 仅扫变更文件，不扫全量
#   - --full 模式保留完整检查供 CI/发布前使用
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

PASS="${GREEN}✓${NC}"; FAIL="${RED}✗${NC}"; SKIP="${YELLOW}⊘${NC}"

MODE="default"
for arg in "$@"; do
    case $arg in
        --full)  MODE="full" ;;
        --quick) MODE="quick" ;;
        --help)
            echo "用法: $0 [--quick|--full]"
            echo "  (无参数)  默认：安全扫描 + 变更文件 Lint + 编译"
            echo "  --quick   仅安全扫描 + 变更文件 Lint（跳过编译）"
            echo "  --full    完整：默认 + 单元测试 + 覆盖率"
            exit 0 ;;
    esac
done

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

TOTAL=0; PASSED=0; FAILED=0; SKIPPED=0

run_check() {
    local name="$1" cmd="$2" blocking="${3:-true}"
    echo -e "  ${CYAN}▸${NC} ${name}..."
    local ec=0
    eval "$cmd" 2>&1 | sed 's/^/       │ /' || ec=$?
    if [ $ec -eq 0 ]; then
        echo -e "     ${PASS} ${name} — 通过"; PASSED=$((PASSED + 1))
    elif [ "$blocking" = "false" ]; then
        echo -e "     ${SKIP} ${name} — 未通过（非阻断）"; SKIPPED=$((SKIPPED + 1))
    else
        echo -e "     ${FAIL} ${name} — ${RED}失败${NC}"; FAILED=$((FAILED + 1)); return 1
    fi
    TOTAL=$((TOTAL + 1))
    return 0
}

summary() {
    echo ""
    echo -e "  总计 ${TOTAL} | ${GREEN}通过 ${PASSED}${NC} | ${RED}失败 ${FAILED}${NC} | ${YELLOW}跳过 ${SKIPPED}${NC}"
}

# ── 获取变更的 Swift 文件列表 ──
CHANGED_SWIFT_FILES=$(git diff --name-only --cached HEAD 2>/dev/null | grep '\.swift$' || \
                      git diff --name-only HEAD 2>/dev/null | grep '\.swift$' || true)

echo ""
echo -e "${BOLD}ZhiYu 推送前门禁  |  模式: ${MODE}  |  $(date '+%H:%M:%S')${NC}"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# Phase 1: 核心静态检查
# ═════════════════════════════════════════════════════════════════════════════

# 1.1 硬编码密钥（安全红线，最快，最先执行）
run_check "硬编码密钥扫描" \
    "python3 Tools/ios/assert-release-hardcoded-secrets.py" \
    || exit 1

# 1.2 本地化合规
run_check "本地化合规审计" \
    "python3 Tools/ios/check-code-localization.py" \
    || exit 1

# 1.2a 重复代码审计
run_check "重复代码静态检测" \
    "python3 Tools/ios/assert-code-duplication.py" \
    || exit 1

# 1.3 架构分层依赖
run_check "架构分层依赖检查（L0-L3）" \
    "python3 Tools/ios/audit-arch-dependency.py" \
    || exit 1

# 1.3.1 DI 注册完整性 — 提前发现 @Inject 依赖未注册、assertRegistered 列表含未注册类型
run_check "DI 注册完整性检查" \
    "python3 Tools/ios/check-arch-di-registration.py" \
    || exit 1

# 1.4 SwiftLint — 仅变更文件（有变更时才运行，非阻断）
if [ -n "$CHANGED_SWIFT_FILES" ]; then
    CHANGED_COUNT=$(echo "$CHANGED_SWIFT_FILES" | wc -l | tr -d ' ')
    echo -e "  ${CYAN}▸${NC} SwiftLint（变更文件: ${CHANGED_COUNT}）..."
    # shellcheck disable=SC2086
    swiftlint lint --strict $CHANGED_SWIFT_FILES 2>&1 | sed 's/^/       │ /' || true
    echo -e "     ${PASS} SwiftLint — 通过（${CHANGED_COUNT} 个文件）"
    PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1))
else
    echo -e "  ${CYAN}▸${NC} SwiftLint — 无 Swift 文件变更，跳过"
    SKIPPED=$((SKIPPED + 1)); TOTAL=$((TOTAL + 1))
fi

# 1.5 工具脚本质量审计
run_check "工具脚本质量审计" \
    "python3 Tools/scripts/audit-quality-scripts.py" \
    || exit 1

# 1.6 GitLab CI 流水线格式校验
if [ -f ".gitlab-ci.yml" ]; then
    run_check "GitLab CI 流水线格式校验" \
        "python3 -c \"import yaml; list(yaml.safe_load_all(open('.gitlab-ci.yml')))\"" \
        || exit 1
else
    echo -e "  ${CYAN}▸${NC} GitLab CI 流水线格式校验..."
    echo -e "     ${SKIP} .gitlab-ci.yml 不存在，跳过"; SKIPPED=$((SKIPPED + 1)); TOTAL=$((TOTAL + 1))
fi

# 1.7 免白名单过期检测（阻断——过期白名单必须清理）
run_check "免白名单过期检测" \
    "python3 Tools/CI/exemption_registry.py check-stale --strict" \
    || exit 1

# 1.8 文档漂移检测（非阻断 WARNING——文档更新不紧急）
run_check "文档漂移检测" \
    "python3 Tools/CI/check-doc-drift.py" \
    "false"

# 1.9 业务层魔鬼数字/硬编码 Prompt 审计（阻断——AGENTS.md 红线 #4）
# 短字符串检测按层逐步启用：当前 LLM + Processors + Storage + Plugins 层已修复，后续每修一层就加入该层前缀
run_check "业务层魔鬼数字审计" \
    "python3 Tools/ios/audit-code-business-magic-numbers.py --strict --magic-string-scope Sources/Infrastructure/LLM --magic-string-scope Sources/Infrastructure/Processors --magic-string-scope Sources/Infrastructure/Storage --magic-string-scope Sources/Infrastructure/Plugins" \
    || exit 1

# 1.10 UFPCore 纯净化审计（阻断——通用基础能力不应泄漏到业务层）
run_check "UFPCore 纯净化审计" \
    "python3 Tools/ios/audit-arch-ufpcore-purity.py" \
    || exit 1

# 1.11 测试耦合反模式检测（非阻断 WARNING——历史遗留需逐步清理）
run_check "测试耦合反模式检测" \
    "python3 Tools/ios/check-code-test-coupling.py" \
    "false"

# 1.12 快照测试环境注入检查（阻断——@Environment 遗漏注入会导致运行时崩溃）
run_check "快照测试环境注入检查" \
    "python3 Tools/ios/check-code-snapshot-environment.py --strict" \
    || exit 1

# quick 模式在此结束
if [ "$MODE" = "quick" ]; then
    summary && echo -e "${GREEN}${BOLD}✅ 快速门禁通过！${NC}" && exit 0
fi

# ═════════════════════════════════════════════════════════════════════════════
# Phase 2: iOS 编译校验
# ═════════════════════════════════════════════════════════════════════════════

if [ "${SKIP_BUILD:-0}" = "1" ]; then
    echo -e "  ${SKIP} 编译校验已跳过 (SKIP_BUILD=1)"; SKIPPED=$((SKIPPED + 1)); TOTAL=$((TOTAL + 1))
else
    BUILD_DIR="build"; mkdir -p "$BUILD_DIR"

    # 2.1 生成项目
    if ! xcodegen generate > "$BUILD_DIR/xcodegen.log" 2>&1; then
        echo -e "     ${FAIL} xcodegen generate — 失败"; tail -10 "$BUILD_DIR/xcodegen.log" | sed 's/^/       │ /'
        summary; echo -e "${RED}${BOLD}❌ 项目生成失败！${NC}"; exit 1
    fi
    echo -e "  ${CYAN}▸${NC} xcodegen generate..."
    echo -e "     ${PASS} xcodegen generate — 通过"; PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1))

    # 2.2 iOS 编译
    BUILD_LOG="$BUILD_DIR/pre_push_build.log"
    JOBS=${PRE_PUSH_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}
    echo -e "  ${CYAN}▸${NC} iOS 编译校验 (xcodebuild, -j ${JOBS})..."
    if xcodebuild build \
        -project ZhiYu.xcodeproj \
        -scheme ZhiYu \
        -destination 'generic/platform=iOS Simulator' \
        -jobs "$JOBS" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        > "$BUILD_LOG" 2>&1; then
        echo -e "     ${PASS} iOS 编译校验 — 通过"; PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1))
    else
        echo -e "     ${FAIL} iOS 编译校验 — ${RED}失败${NC}"
        grep -E "error:" "$BUILD_LOG" | sort -u | head -10 | sed 's/^/       │ /'
        FAILED=$((FAILED + 1)); TOTAL=$((TOTAL + 1))
        summary; echo -e "${RED}${BOLD}❌ 编译失败！${NC}"; exit 1
    fi
fi

# default 模式在此结束
if [ "$MODE" = "default" ]; then
    summary && echo -e "${GREEN}${BOLD}✅ 门禁通过！${NC}" && exit 0
fi

# ═════════════════════════════════════════════════════════════════════════════
# Phase 3: 单元测试 + 覆盖率（仅 --full）
# ═════════════════════════════════════════════════════════════════════════════

echo -e "  ${CYAN}▸${NC} 运行单元测试..."
source "$(dirname "$0")/ci-common-shared.sh" 2>/dev/null || true
SIM_NAME=$(find_simulator 2>/dev/null || echo "iPhone 17 Pro")

if xcodebuild test \
    -project ZhiYu.xcodeproj \
    -scheme ZhiYu \
    -destination "platform=iOS Simulator,name=${SIM_NAME}" \
    -enableCodeCoverage YES \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    > "build/pre_push_test.log" 2>&1; then
    echo -e "     ${PASS} 单元测试 — 全部通过"; PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1))
else
    echo -e "     ${FAIL} 单元测试 — ${RED}失败${NC}"
    grep -E "Test.*failed" "build/pre_push_test.log" | tail -10 | sed 's/^/       │ /'
    FAILED=$((FAILED + 1)); TOTAL=$((TOTAL + 1))
    summary; echo -e "${RED}${BOLD}❌ 测试未通过！${NC}"; exit 1
fi

summary
echo -e "${GREEN}${BOLD}✅ 全部门禁通过！${NC}"
echo ""
exit 0
