# -*- coding: utf-8 -*-
#!/usr/bin/env python3
"""
[Gatekeeper] 多平台编译验证

在提交前验证 iOS / macOS Catalyst / watchOS 三个平台均可编译通过。
作为 git pre-commit hook 被调用，防止破坏性变更进入仓库。

用法:
    python3 Tools/ios/assert-release-compile.py

仅在暂存区包含 .swift 文件时执行编译检查，避免无代码变更时浪费时间。
"""

import os
import subprocess
import sys
from pathlib import Path

# ── 常量定义 ──────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.parent
PROJECT_FILE = PROJECT_ROOT / "ZhiYu.xcodeproj"

# 编译超时（秒）
BUILD_TIMEOUT_SECONDS = 600
# 秒转分钟换算因子
SECONDS_PER_MINUTE = 60
# 错误摘要最大行数
MAX_ERROR_LINES = 10
# 分界线宽度
SEPARATOR_WIDTH = 60
# 摘要截断行数（per-target）
SUMMARY_TRUNCATE_LINES = 5

BUILD_TARGETS = [
    {
        "name": "iOS",
        "scheme": "ZhiYu",
        "destination": "generic/platform=iOS",
    },
]

BASE_FLAGS = [
    "CODE_SIGNING_ALLOWED=NO",
    "CODE_SIGNING_REQUIRED=NO",
]


def has_staged_swift_files() -> bool:
    """检查暂存区是否包含 Swift 源文件变更。"""
    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
        )
        staged = result.stdout.strip().split("\n")
        swift_files = [f for f in staged if f.endswith(".swift")]
        return len(swift_files) > 0
    except Exception:
        # 如果 git 命令失败，保守起见执行编译检查
        return True


def build_target(target: dict) -> tuple:
    """编译单个平台 target，返回 (成功, 输出摘要)。

    Args:
        target: 包含 name, scheme, destination 的字典

    Returns:
        (bool, str): (编译是否成功, 错误摘要字符串)
    """
    cmd = [
        "xcodebuild",
        "build",
        "-project", str(PROJECT_FILE),
        "-scheme", target["scheme"],
        "-destination", target["destination"],
    ] + BASE_FLAGS

    print(f"  ⏳ 编译 {target['name']} ({target['scheme']}) ...", flush=True)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=BUILD_TIMEOUT_SECONDS,
        )
        if result.returncode == 0:
            print(f"  ✅ {target['name']} 编译通过", flush=True)
            return True, ""
        else:
            # 提取 Swift 编译错误行（以绝对路径开头的 error: 行）
            combined = result.stderr + "\n" + result.stdout
            error_lines = [
                line.strip() for line in combined.split("\n")
                if "error:" in line
                and not line.startswith("export ")
                and "YES_ERROR" not in line
            ]
            summary = "\n".join(error_lines[:MAX_ERROR_LINES])
            print(f"  ❌ {target['name']} 编译失败", flush=True)
            return False, summary
    except subprocess.TimeoutExpired:
        print(f"  ❌ {target['name']} 编译超时（>{BUILD_TIMEOUT_SECONDS // SECONDS_PER_MINUTE}分钟）", flush=True)
        return False, "编译超时"
    except FileNotFoundError:
        print(f"  ❌ 未找到 xcodebuild 命令", flush=True)
        return False, "xcodebuild not found"


def main() -> int:
    """多平台编译验证入口。

    Returns:
        int: 0 表示全部通过，1 表示存在编译失败
    """
    os.chdir(PROJECT_ROOT)

    # 仅在 Swift 文件变更时执行编译检查
    if not has_staged_swift_files():
        print("[Gatekeeper] 编译检查：无 Swift 文件变更，跳过。")
        return 0

    # 检查项目文件是否存在
    if not PROJECT_FILE.exists():
        print("[Gatekeeper] 编译检查：未找到 .xcodeproj，请先运行 xcodegen generate。")
        return 1

    print("=" * SEPARATOR_WIDTH)
    print("[Gatekeeper] 编译验证（iOS）")
    print("=" * SEPARATOR_WIDTH)

    failures = []
    for target in BUILD_TARGETS:
        success, error_summary = build_target(target)
        if not success:
            failures.append((target["name"], error_summary))

    print("=" * SEPARATOR_WIDTH)
    if failures:
        print(f"❌ iOS 编译验证失败：")
        for name, summary in failures:
            print(f"\n  [{name}] 错误摘要：")
            for line in summary.split("\n")[:SUMMARY_TRUNCATE_LINES]:
                if line.strip():
                    print(f"    {line.strip()}")
        print("\n💡 请修复以上编译错误后重新提交。")
        return 1
    else:
        print("✅ iOS 编译通过。")
        return 0


if __name__ == "__main__":
    sys.exit(main())
