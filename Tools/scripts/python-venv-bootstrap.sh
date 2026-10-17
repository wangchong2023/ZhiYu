#!/bin/bash
#
# python-venv-bootstrap.sh — 幂等引导 Python 虚拟环境（env/venv，Python ≥3.10）
#
# 职责:
#   探测可用的 ≥3.10 解释器，创建/复用 env/venv 并安装审计依赖（radon + pyyaml），
#   供本地 make audit 与 CI 流水线静态分析统一使用，规避系统默认 python3(3.9)
#   对 `dict | None` 等 3.10+ 运行时语法的 TypeError。
#   pyyaml 用于加载 manual_whitelist.yml 豁免（缺失会导致审计脚本静默跳过豁免而误报）。
#
# 用法:
#   VENV_PY="$(bash Tools/scripts/python-venv-bootstrap.sh)"   # 输出 venv python 绝对路径
#   "$VENV_PY" Tools/ios/check-arch-dependency-registry.py
#
# 幂等性:
#   - venv 已存在且解释器版本 ≥3.10 → 直接复用（补装 pyyaml 后返回），不重建
#   - 否则用探测到的 ≥3.10 解释器重建，并安装 radon + pyyaml（安装失败仅告警不阻断）
set -uo pipefail

VENV_DIR="${VENV_DIR:-env/venv}"
PY_BIN="$VENV_DIR/bin/python3"
REQUIRED_MINOR=10

# 输出 python 版本主.次（如 3.14），失败为空
py_minor() {
    "$1" -c 'import sys; sys.stdout.write("%d.%d" % sys.version_info[:2])' 2>/dev/null
}

# 版本是否 ≥3.10
at_least_310() {
    local ver="$1" major minor
    major="${ver%%.*}"
    minor="${ver#*.}"
    if [ "${major:-0}" -gt 3 ]; then
        return 0
    fi
    [ "${major:-0}" -eq 3 ] && [ "${minor:-0}" -ge "$REQUIRED_MINOR" ]
}

# 输出 venv python 的绝对路径
venv_py_abs() {
    echo "$(cd "$(dirname "$VENV_DIR")" && pwd)/$(basename "$VENV_DIR")/bin/python3"
}

# 1) venv 已就绪且 ≥3.10 → 直接复用（补装 pyyaml 保证豁免可加载）
if [ -x "$PY_BIN" ] && at_least_310 "$(py_minor "$PY_BIN")"; then
    "$PY_BIN" -m pip install --quiet pyyaml >/dev/null 2>&1 || true
    venv_py_abs
    exit 0
fi

# 2) 探测可用的 ≥3.10 系统解释器（优先高版本）
BASE_PY=""
for cand in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$cand" >/dev/null 2>&1 && at_least_310 "$(py_minor "$cand")"; then
        BASE_PY="$(command -v "$cand")"
        break
    fi
done
if [ -z "$BASE_PY" ]; then
    echo "❌ 未找到 Python ≥3.10 的解释器，无法引导 venv。请安装 python3.10+ 后重试。" >&2
    exit 1
fi

# 3) 创建 venv 并安装审计依赖
echo "⚙️  使用 $BASE_PY ($($BASE_PY --version 2>&1)) 引导 venv $VENV_DIR ..." >&2
mkdir -p "$(dirname "$VENV_DIR")"
if ! "$BASE_PY" -m venv --clear "$VENV_DIR"; then
    echo "❌ 创建 venv 失败" >&2
    exit 1
fi
# radon/pyyaml 安装失败不阻断（CI 无网时可降级，相关脚本会自行提示）
"$PY_BIN" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
"$PY_BIN" -m pip install --quiet radon pyyaml >/dev/null 2>&1 || true

venv_py_abs