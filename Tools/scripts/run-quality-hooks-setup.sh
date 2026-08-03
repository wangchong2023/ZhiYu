#!/bin/bash
# ==============================================================================
# 脚本名称: run-quality-hooks-setup.sh
# 核心职责: 将 Git Hooks 从 Tools/Hooks/ 安装到 .git/hooks/
# 调用方式:
#   ./Tools/scripts/run-quality-hooks-setup.sh            # 安装（默认符号链接）
#   ./Tools/scripts/run-quality-hooks-setup.sh --copy     # 拷贝安装（兼容 Windows/CI）
#   ./Tools/scripts/run-quality-hooks-setup.sh --verify   # 验证 hooks 是否已安装且可执行
# ==============================================================================

set -euo pipefail

HOOKS_SRC="$(cd "$(dirname "$0")" && pwd)/Hooks"
HOOKS_DST="$(cd "$(dirname "$0")/.." && pwd)/.git/hooks"

MODE="symlink"

for arg in "$@"; do
    case $arg in
        --copy)   MODE="copy" ;;
        --verify) MODE="verify" ;;
        --help)
            echo "用法: $0 [--copy | --verify | --help]"
            echo ""
            echo "  无参数      使用符号链接安装（推荐，更新源文件自动生效）"
            echo "  --copy      拷贝安装（适用于不支持符号链接的环境）"
            echo "  --verify    验证 hooks 是否已正确安装"
            exit 0
            ;;
        *) echo "未知参数: $arg"; exit 1 ;;
    esac
done

# 函数: is_content_match
# 描述: 判断已安装 hook 与源文件内容是否一致（符号链接视为一致，普通文件则 diff 校验）
# 参数: $1=源文件路径 $2=目标文件路径
# 返回: 0=一致 1=不一致
is_content_match() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        local link_target
        link_target=$(readlink "$dst")
        if [ "$link_target" = "$src" ]; then
            return 0
        fi
        if [ -f "$link_target" ] && diff -q "$src" "$link_target" >/dev/null 2>&1; then
            return 0
        fi
        return 1
    fi
    diff -q "$src" "$dst" >/dev/null 2>&1
}

if [ "$MODE" = "verify" ]; then
    echo "🔍 验证 Git Hooks 安装状态..."
    ALL_OK=true
    for hook in "$HOOKS_SRC"/*; do
        hook_name=$(basename "$hook")
        if [[ "$hook_name" == .* ]] || [ ! -f "$hook" ]; then
            continue
        fi
        target="$HOOKS_DST/$hook_name"
        if [ ! -e "$target" ]; then
            echo "  ❌ $hook_name — 未安装"
            ALL_OK=false
            continue
        fi
        if [ ! -x "$target" ]; then
            echo "  ⚠️  $hook_name — 已安装但不可执行"
            ALL_OK=false
            continue
        fi
        if ! is_content_match "$hook" "$target"; then
            echo "  ❌ $hook_name — 内容与源文件不一致（可能引用了过时路径）"
            ALL_OK=false
            continue
        fi
        echo "  ✅ $hook_name — 已安装、可执行、内容一致"
    done
    if [ "$ALL_OK" = true ]; then
        echo ""
        echo "✅ 所有 hooks 已正确安装且内容与源文件一致。"
    else
        echo ""
        echo "❌ 部分 hooks 未安装或不可执行，请运行: ./Tools/scripts/run-quality-hooks-setup.sh"
        exit 1
    fi
    exit 0
fi

echo "🔧 安装 Git Hooks..."
echo "  源目录: $HOOKS_SRC"
echo "  目标目录: $HOOKS_DST"

if [ ! -d "$HOOKS_DST" ]; then
    echo "❌ .git/hooks 目录不存在，请确保当前目录是 Git 仓库。"
    exit 1
fi

COUNT=0
for hook in "$HOOKS_SRC"/*; do
    hook_name=$(basename "$hook")

    # 跳过非脚本文件（如 .DS_Store, README 等）
    if [[ "$hook_name" == .* ]] || [ ! -f "$hook" ]; then
        continue
    fi

    target="$HOOKS_DST/$hook_name"

    # 备份已存在的 hook（但跳过 .sample 或符号链接）
    if [ -f "$target" ] && [ ! -L "$target" ]; then
        backup="$target.backup-$(date +%Y%m%d%H%M%S)"
        cp "$target" "$backup"
        echo "  📦 已备份: $hook_name → $(basename "$backup")"
    fi

    if [ "$MODE" = "copy" ]; then
        cp "$hook" "$target"
        echo "  📋 已拷贝: $hook_name"
    else
        ln -sf "$hook" "$target"
        echo "  🔗 已链接: $hook_name"
    fi

    chmod +x "$target"
    COUNT=$((COUNT + 1))
done

echo ""
echo "✅ 完成！已安装 $COUNT 个 Git Hooks。"
echo ""
echo "💡 提示:"
echo "  - 修改 Tools/Hooks/ 下的文件后，hook 自动生效（符号链接）"
echo "  - 新 clone 仓库后，运行 ./Tools/scripts/run-quality-hooks-setup.sh 即可安装"
echo "  - 使用 ./Tools/scripts/run-quality-hooks-setup.sh --verify 验证安装状态"
