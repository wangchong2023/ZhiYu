#!/usr/bin/env bash
# Tools/Utils/bootstrap.sh
# ZhiYu 项目一键初始化脚本
#
# 功能：
#   1. 加载本地环境变量（Config/.env.local）
#   2. 验证 OPENSRC_ROOT 已设置且路径存在
#   3. 运行 xcodegen generate 生成 Xcode 项目
#
# 使用方式：
#   bash Tools/Utils/bootstrap.sh
#
# 首次使用（新开发者）：
#   cp Config/.env.example Config/.env.local
#   编辑 Config/.env.local，填写 OPENSRC_ROOT 路径
#   bash Tools/Utils/bootstrap.sh
#

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_LOCAL="$PROJECT_DIR/Config/.env.local"
ENV_EXAMPLE="$PROJECT_DIR/Config/.env.example"

echo "🚀 ZhiYu Bootstrap"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 第一步：加载本地环境变量 ──
if [ -f "$ENV_LOCAL" ]; then
    echo "✅ 加载本地环境配置：Config/.env.local"
    # shellcheck source=/dev/null
    source "$ENV_LOCAL"
else
    echo "❌ 未找到 Config/.env.local"
    echo ""
    echo "   请执行以下步骤初始化本地环境："
    echo "   1. cp Config/.env.example Config/.env.local"
    echo "   2. 编辑 Config/.env.local，填写 OPENSRC_ROOT 路径"
    echo "   3. 重新运行 bash Tools/Utils/bootstrap.sh"
    exit 1
fi

# ── 第二步：验证 OPENSRC_ROOT ──
if [ -z "$OPENSRC_ROOT" ]; then
    echo "❌ OPENSRC_ROOT 未在 Config/.env.local 中设置"
    echo "   参考 Config/.env.example 中的说明"
    exit 1
fi

if [ ! -d "$OPENSRC_ROOT" ]; then
    echo "❌ OPENSRC_ROOT 路径不存在：$OPENSRC_ROOT"
    echo "   请确认开源库已克隆到该目录，或修改 Config/.env.local 中的路径"
    exit 1
fi

echo "✅ OPENSRC_ROOT=$OPENSRC_ROOT"

# ── 第三步：验证必要的开源库已克隆 ──
DEPS_FILE="$PROJECT_DIR/Config/opensource_dependencies.yml"
if [ ! -f "$DEPS_FILE" ]; then
    echo "❌ 未找到 Config/opensource_dependencies.yml"
    exit 1
fi

# ── 第三步：验证必要的开源库已克隆（从注册表读取） ──
echo ""
echo "📦 验证开源库克隆状态（来源：Config/opensource_dependencies.yml）..."
MISSING_LIBS=()

# 解析 YAML：提取 integration 为 project_yml_path 的库名
while IFS= read -r line; do
    # 提取 name: 行
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]name:[[:space:]]*(.+) ]]; then
        current_lib="${BASH_REMATCH[1]}"
    fi
    # 仅检查 project_yml_path 类型（需要本地克隆的库）
    if [[ "$line" =~ integration:[[:space:]]*project_yml_path ]] && [ -n "$current_lib" ]; then
        if [ ! -d "$OPENSRC_ROOT/$current_lib" ]; then
            MISSING_LIBS+=("$current_lib")
            echo "  ❌ $current_lib → 未找到 $OPENSRC_ROOT/$current_lib"
        else
            echo "  ✅ $current_lib"
        fi
        current_lib=""
    fi
done < "$DEPS_FILE"

if [ ${#MISSING_LIBS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  以下库缺失，请先克隆到 OPENSRC_ROOT，或查阅 Config/opensource_dependencies.yml 中的 git_url："
    for lib in "${MISSING_LIBS[@]}"; do
        # 尝试从 YAML 中提取 git_url
        git_url=$(grep -A5 "name: $lib" "$DEPS_FILE" 2>/dev/null | grep "git_url:" | head -1 | sed 's/.*git_url: //')
        echo "   git clone $git_url \$OPENSRC_ROOT/$lib"
    done
    echo ""
    echo "   继续执行 xcodegen（部分功能可能缺失）..."
fi

# ── 第四步：从模板生成 project.yml ──
TEMPLATE="$PROJECT_DIR/Config/project.yml.template"
PROJECT_YML="$PROJECT_DIR/project.yml"

if [ ! -f "$TEMPLATE" ]; then
    echo "❌ 未找到 Config/project.yml.template"
    exit 1
fi

echo "⚙️  从模板生成 project.yml..."
export OPENSRC_ROOT  # 确保已导出
envsubst '${OPENSRC_ROOT}' < "$TEMPLATE" > "$PROJECT_YML"
echo "✅ project.yml 已生成（OPENSRC_ROOT=$OPENSRC_ROOT）"

# ── 第五步：运行 xcodegen ──
echo "⚙️  运行 xcodegen generate..."
cd "$PROJECT_DIR"
xcodegen generate

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Bootstrap 完成！用 Xcode 打开 ZhiYu.xcodeproj"
