#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gatekeeper: 检查快照测试中的 @Environment 注入反模式 — 禁止手动注入，强制使用 .snapshotEnvironment()。

背景：SwiftUI 的 @Environment 是隐式依赖，编译器不检查，测试中遗漏注入会导致
运行时崩溃（EnvironmentValues.subscript.getter → _assertionFailure）。
此问题在项目中反复发生 4 次（MarkdownRendererView/MarkdownEditorView/
TaskCenterView/Dashboard 子组件）。

根治方案：统一使用 `.snapshotEnvironment()` modifier 一次性注入全量依赖，
杜绝遗漏。此脚本强制执行该规范。

规则：
1. Tests/SnapshotTests/ 目录下的 .swift 文件中，禁止直接使用：
   - `.environment(`（@Observable 类型注入）
   - `.environmentObject(`（ObservableObject 类型注入）
2. 允许的替代方案：`.snapshotEnvironment()`（统一注入入口）
3. 豁免文件：
   - Tests/SnapshotTests/Support/SnapshotHelper.swift（.snapshotEnvironment() 定义本身）

用法：python3 Tools/ios/check-code-snapshot-environment.py [--strict]
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
SNAPSHOT_TESTS_ROOT = REPO_ROOT / "Tests" / "SnapshotTests"

# ── 豁免文件（.snapshotEnvironment() 定义本身）──
EXEMPT_FILES = {
    "Tests/SnapshotTests/Support/SnapshotHelper.swift",
}

# ── 禁止的手动注入模式 ──
PATTERNS = [
    (
        "manual_environment_inject",
        re.compile(r'\.environment\s*\('),
        "手动 `.environment()` 注入 — 快照测试应统一使用 `.snapshotEnvironment()`，"
        "杜绝 @Environment 依赖遗漏导致运行时崩溃",
    ),
    (
        "manual_environmentObject_inject",
        re.compile(r'\.environmentObject\s*\('),
        "手动 `.environmentObject()` 注入 — 快照测试应统一使用 `.snapshotEnvironment()`，"
        "杜绝 @EnvironmentObject 依赖遗漏导致运行时崩溃",
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
    """检查文件是否在豁免列表中。

    :param filepath: Swift 源文件绝对路径
    :return: 豁免返回 True
    """
    rel_path = filepath.relative_to(REPO_ROOT)
    rel_str = str(rel_path)
    return rel_str in EXEMPT_FILES


def scan_file(filepath: Path) -> List[Finding]:
    """扫描单个快照测试文件，返回手动环境注入发现。

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
        # 跳过注释行
        if stripped.startswith("//"):
            continue
        # 豁免标注：// snapshot_env_exempt 表示该行已确认必要
        if "// snapshot_env_exempt" in raw_line:
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
    print(f"\033[{COLOR_RED}m🔴 快照测试手动环境注入 ({len(findings)} 处)\033[0m")
    print("   快照测试应统一使用 `.snapshotEnvironment()` 注入全量依赖，杜绝遗漏。")
    print("   背景：@Environment 隐式依赖遗漏注入会导致运行时崩溃（已发生 4 次）。")
    print()
    print("   修复方式：")
    print("   • 将 `.environment(xxx)` / `.environmentObject(xxx)` 替换为 `.snapshotEnvironment()`")
    print("   • 新增 @Environment 依赖类型时，只需在 SnapshotHelper.swift 的")
    print("     `snapshotEnvironment()` 中追加一行 `.environment(...)`")
    print()
    for f in findings:
        print(f"  📄 {f.file}:{f.line}")
        print(f"     [{f.kind}] {f.detail}")
        print(f"     代码: {f.snippet}")
        print()


def main() -> int:
    """入口函数：扫描所有快照测试文件并输出手动环境注入报告。

    :return: 0 表示通过，1 表示 --strict 模式下有发现
    """
    parser = argparse.ArgumentParser(
        description="检查快照测试 @Environment 注入反模式 — 强制使用 .snapshotEnvironment()"
    )
    parser.add_argument(
        "--strict", action="store_true",
        help="发现违规视为构建失败（CI 模式）"
    )
    args = parser.parse_args()

    if not SNAPSHOT_TESTS_ROOT.exists():
        print(f"\033[{COLOR_YELLOW}m⚠️  快照测试目录不存在: {SNAPSHOT_TESTS_ROOT}\033[0m")
        return 0

    all_findings: List[Finding] = []
    for fp in SNAPSHOT_TESTS_ROOT.rglob("*.swift"):
        all_findings.extend(scan_file(fp))

    if not all_findings:
        print(f"\033[{COLOR_GREEN}m✅ 快照测试环境注入检查通过 — 全部使用 .snapshotEnvironment()\033[0m\n")
        return 0

    print(f"\n=== 快照测试手动环境注入检查 ({len(all_findings)} 处发现) ===\n")
    _print_findings(all_findings)

    if args.strict:
        print(f"\n❌ STRICT 模式：{len(all_findings)} 处手动环境注入，构建失败。")
        print("   修复建议：")
        print("   1. 将 `.environment(xxx)` 替换为 `.snapshotEnvironment()`")
        print("   2. 将 `.environmentObject(xxx)` 替换为 `.snapshotEnvironment()`")
        print("   3. 如需新增 @Environment 依赖，在 SnapshotHelper.swift 的")
        print("      `snapshotEnvironment()` 中追加，而非在测试中手动注入")
        return 1
    print(f"\n⚠️  非严格模式：{len(all_findings)} 处发现需要人工审核。")
    print("   运行 `python3 Tools/ios/check-code-snapshot-environment.py --strict` 以在 CI 中断构建。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
