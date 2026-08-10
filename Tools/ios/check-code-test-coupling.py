#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gatekeeper: 检查源码中的测试耦合反模式 — 生产代码不应包含测试专用分支。

业界最佳实践：测试逻辑应通过 launch argument 注入路由、Page Object、
Accessibility Identifier 等方式实现，而非在视图/服务层用 `if isUITesting` 分叉渲染。

规则：
1. Sources/ 目录（排除 @main 入口与平台适配层）中禁止出现测试耦合标识：
   - `isUITesting` 计算属性
   - `NSClassFromString("XCTest")` / `NSClassFromString("XCTestCase")`
   - `ProcessInfo.processInfo.environment["UITesting"]`
   - `CommandLine.arguments.contains("--uitesting")`
   - `--uitesting` / `--reset-state` / `--stay-on-hub` 等 UI 测试 launch argument 字面量
2. 允许的豁免位置：
   - `Sources/App/ZhiYuApp.swift`（@main 入口，解析 launch argument 跳转路由）
   - `Sources/App/AppEnvironment.swift`（环境初始化，可能根据测试模式跳过数据库）
   - `Sources/Platforms/`（平台适配层，可能含测试专用配置）
   - `Tests/`（测试目录本身）
   - `Sources/Core/System/`（Logger 等系统服务可能需要区分测试环境）

用法：python3 Tools/ios/check-code-test-coupling.py [--strict]
      --strict: 违规视为构建失败（CI 模式）
"""

import argparse
import re
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import List

# ── ANSI 颜色代码常量 ──
COLOR_RED = 91
COLOR_YELLOW = 93
COLOR_GREEN = 92

# ── 代码片段截取最大长度 ──
MAX_SNIPPET_LENGTH = 120

# 仓库根目录
REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCES_ROOT = REPO_ROOT / "Sources"

# ── 豁免目录/文件（这些位置允许出现测试耦合代码）──
EXEMPT_PATHS = {
    "Sources/App/ZhiYuApp.swift",          # @main 入口，解析 launch argument
    "Sources/App/AppEnvironment.swift",    # 环境初始化
    "Sources/Platforms",                   # 平台适配层
    "Sources/Core/System",                 # 系统服务（Logger 等）
}

# ── 测试耦合反模式正则 ──
PATTERNS = [
    (
        "isUITesting_property",
        re.compile(r'\bprivate\s+var\s+isUITesting\b|\bvar\s+isUITesting\b'),
        "测试模式标识属性 `isUITesting` — 生产代码不应包含测试专用分支",
    ),
    (
        "xctest_class_check",
        re.compile(r'NSClassFromString\s*\(\s*"(XCTest|XCTestCase)"\s*\)'),
        "XCTest 类检测 `NSClassFromString(\"XCTest\")` — 用 launch argument 注入路由替代",
    ),
    (
        "uitesting_env_var",
        re.compile(r'ProcessInfo\.processInfo\.environment\s*\[\s*"UITesting"\s*\]'),
        "UITesting 环境变量检查 — 应在 @main 入口集中处理，不在视图/服务层散布",
    ),
    (
        "uitesting_launch_arg",
        re.compile(r'CommandLine\.arguments\.contains\s*\(\s*"--uitesting"\s*\)'),
        "`--uitesting` launch argument 检查 — 应在 @main 入口集中处理",
    ),
    (
        "reset_state_launch_arg",
        re.compile(r'CommandLine\.arguments\.contains\s*\(\s*"--reset-state"\s*\)'),
        "`--reset-state` launch argument 检查 — 应在 @main 入口集中处理",
    ),
    (
        "stay_on_hub_launch_arg",
        re.compile(r'CommandLine\.arguments\.contains\s*\(\s*"--stay-on-hub"\s*\)'),
        "`--stay-on-hub` launch argument 检查 — 应在 @main 入口集中处理",
    ),
    (
        "uitest_mockdata_arg",
        re.compile(r'CommandLine\.arguments\.contains\s*\(\s*"-UITest_MockData"\s*\)'),
        "`-UITest_MockData` launch argument 检查 — 应在 @main 入口集中处理",
    ),
    (
        "reset_userdefaults_arg",
        re.compile(r'CommandLine\.arguments\.contains\s*\(\s*"-ResetUserDefaults"\s*\)'),
        "`-ResetUserDefaults` launch argument 检查 — 应在 @main 入口集中处理",
    ),
]


@dataclass
class Finding:
    """单次检查发现项。

    :param file: 相对于仓库根目录的文件路径
    :param line: 行号（1-based）
    :param kind: 发现类型标识
    :param detail: 具体的代码片段描述
    :param snippet: 违规行原文
    """
    file: str
    line: int
    kind: str
    detail: str
    snippet: str


def _is_exempt(filepath: Path) -> bool:
    """检查文件是否在豁免路径中。

    :param filepath: Swift 源文件绝对路径
    :return: 豁免返回 True
    """
    rel_path = filepath.relative_to(REPO_ROOT)
    rel_str = str(rel_path)
    for exempt in EXEMPT_PATHS:
        if rel_str == exempt or rel_str.startswith(exempt + "/"):
            return True
    return False


def scan_file(filepath: Path) -> List[Finding]:
    """扫描单个 Swift 源文件，返回测试耦合反模式发现。

    :param filepath: Swift 源文件绝对路径
    :return: 该文件中的发现列表
    """
    findings: List[Finding] = []
    if _is_exempt(filepath):
        return findings

    rel_path = str(filepath.relative_to(REPO_ROOT))
    try:
        content = filepath.read_text(encoding="utf-8")
    except Exception:
        return findings

    for i, raw_line in enumerate(content.splitlines(), start=1):
        stripped = raw_line.strip()
        if stripped.startswith("//"):
            continue
        # 豁免标注：// test_coupling_exempt 表示该行已确认必要
        if "// test_coupling_exempt" in raw_line:
            continue
        for kind, pattern, detail in PATTERNS:
            if pattern.search(raw_line):
                findings.append(Finding(
                    file=rel_path,
                    line=i,
                    kind=kind,
                    detail=detail,
                    snippet=stripped[:MAX_SNIPPET_LENGTH],
                ))
    return findings


def _print_findings(findings: List[Finding]) -> None:
    """输出所有发现项。

    :param findings: 发现列表
    """
    if not findings:
        return
    print(f"\033[{COLOR_RED}m🔴 测试耦合反模式 ({len(findings)} 处)\033[0m")
    print("   生产代码不应包含测试专用分支。业界做法：")
    print("   • launch argument 注入路由（在 @main 入口解析参数，设 router 状态）")
    print("   • Page Object 模式（测试侧封装导航逻辑）")
    print("   • Accessibility Identifier（仅标识元素，不分叉渲染）")
    print()
    for f in findings:
        print(f"  📄 {f.file}:{f.line}")
        print(f"     [{f.kind}] {f.detail}")
        print(f"     代码: {f.snippet}")
        print()


def main() -> int:
    """入口函数：扫描所有 Swift 源文件并输出测试耦合反模式报告。

    :return: 0 表示通过，1 表示 --strict 模式下有发现
    """
    parser = argparse.ArgumentParser(
        description="检查源码测试耦合反模式 — 生产代码不应包含测试专用分支"
    )
    parser.add_argument(
        "--strict", action="store_true",
        help="发现违规视为构建失败（CI 模式）"
    )
    args = parser.parse_args()

    all_findings: List[Finding] = []
    for fp in SOURCES_ROOT.rglob("*.swift"):
        all_findings.extend(scan_file(fp))

    if not all_findings:
        print(f"\033[{COLOR_GREEN}m✅ 源码测试耦合检查通过 — 无测试专用分支\033[0m\n")
        return 0

    print(f"\n=== 测试耦合反模式检查 ({len(all_findings)} 处发现) ===\n")
    _print_findings(all_findings)

    if args.strict:
        print(f"\n❌ STRICT 模式：{len(all_findings)} 处测试耦合反模式，构建失败。")
        print("   修复建议：")
        print("   1. 将 launch argument 解析移至 Sources/App/ZhiYuApp.swift（@main 入口）")
        print("   2. 视图层用 Accessibility Identifier 标识元素，而非 `if isUITesting` 分叉")
        print("   3. 测试侧用 Page Object 封装导航，不依赖源码测试分支")
        return 1
    print(f"\n⚠️  非严格模式：{len(all_findings)} 处发现需要人工审核。")
    print("   运行 `python3 Tools/ios/check-code-test-coupling.py --strict` 以在 CI 中断构建。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
