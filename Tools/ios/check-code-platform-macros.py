#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-code-platform-macros.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/22.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：检查 Sources/Features/ 和 Sources/Domain/ 层禁止使用 #if os() 平台宏。
#           正确做法：通过 L0 协议 + PlatformRegistrar DI 注入，而非在业务层直接判断平台。
#

import sys
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"

# 需要检查的目录（禁止使用 #if os）
CHECK_DIRS = [
    SOURCES_DIR / "Features",
    SOURCES_DIR / "Domain",
]

OS_MACRO_PATTERN = re.compile(r'#if\s+os\(')


def _scan_directory(check_dir: Path) -> list[tuple[Path, list[tuple[int, str]]]]:
    """
    扫描指定目录下所有 Swift 文件中的 #if os() 宏。
    
    :param check_dir: 需要扫描的目录路径
    :return: (文件路径, 违规列表) 的列表
    """
    results = []
    if not check_dir.exists():
        return results
    for swift_file in check_dir.rglob("*.swift"):
        violations = []
        try:
            with open(swift_file, 'r') as f:
                for i, line in enumerate(f, 1):
                    if OS_MACRO_PATTERN.search(line):
                        violations.append((i, line.strip()))
        except Exception:
            pass
        if violations:
            rel_path = swift_file.relative_to(PROJECT_ROOT)
            results.append((rel_path, violations))
    return results


def _report_failure(files_with_violations: list, total_count: int) -> int:
    """
    打印平台宏违规报告并返回退出码 1。
    
    :param files_with_violations: 违规文件列表
    :param total_count: 违规总数
    :return: 退出码 1
    """
    print(f"❌ FAIL: 发现 {total_count} 处 #if os() 平台宏在 {len(files_with_violations)} 个文件中")
    print()
    print("业务层应通过 L0 协议 + @Inject DI 注入替代平台宏：")
    print("  Core/Base/Protocols/  → 定义跨平台协议")
    print("  Platforms/{platform}/  → 实现具体平台逻辑")
    print("  PlatformRegistrar      → 注册到 DI 容器")
    print("  @Inject var xxx: any XxxProtocol → 业务层消费")
    print()
    for rel_path, violations in files_with_violations:
        print(f"  {rel_path}:")
        for line_no, content in violations:
            print(f"    L{line_no}: {content}")
    return 1


def main():
    """扫描 Features/Domain 层是否包含 #if os() 平台宏并报告结果。"""
    all_violations = []
    for check_dir in CHECK_DIRS:
        all_violations.extend(_scan_directory(check_dir))
    total_count = sum(len(v[1]) for v in all_violations)

    if total_count == 0:
        print("✅ PASS: Features/Domain 层无 #if os() 平台宏")
        return 0
    return _report_failure(all_violations, total_count)


if __name__ == "__main__":
    sys.exit(main())
