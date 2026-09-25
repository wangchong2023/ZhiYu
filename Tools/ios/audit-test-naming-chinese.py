#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-test-naming-chinese.py
#  ZhiYu
#
#  系统层级：[Tools/ios] 代码质量门禁
#  核心职责：检测 Tests/ 目录下测试函数名中的中文字符，强制测试函数使用英文命名。
#           防止中文命名的测试函数再次出现，确保测试代码国际化规范。
#

import re
import sys
from pathlib import Path

TESTS_DIR = Path("Tests")

# 匹配测试函数定义：func testXXX()，其中 XXX 包含中文字符
TEST_FUNC_PATTERN = re.compile(r'^\s*(?:@Test\s+)?func\s+(test[^\(]*[\u4e00-\u9fa5][^\(]*)\s*\(')

# 匹配所有函数名中的中文字符（用于检测非 test 前缀的中文函数名）
CHINESE_CHAR_PATTERN = re.compile(r'[\u4e00-\u9fa5]')


def check_file(filepath: Path) -> list:
    """检查单个 Swift 文件中的中文测试函数名，返回违规列表。"""
    violations = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"WARNING: 无法读取文件 {filepath}: {e}", file=sys.stderr)
        return violations

    for line_no, line in enumerate(lines, 1):
        match = TEST_FUNC_PATTERN.match(line)
        if match:
            func_name = match.group(1)
            violations.append({
                'file': str(filepath),
                'line': line_no,
                'func_name': func_name,
                'source': line.strip(),
            })

    return violations


def main():
    """主入口：扫描 Tests/ 目录下所有 Swift 文件，检测中文命名的测试函数并报告违规。"""
    if not TESTS_DIR.exists():
        print(f"ERROR: Tests 目录不存在: {TESTS_DIR}", file=sys.stderr)
        sys.exit(2)

    all_violations = []
    files_checked = 0

    for swift_file in TESTS_DIR.rglob("*.swift"):
        files_checked += 1
        violations = check_file(swift_file)
        all_violations.extend(violations)

    print(f"=== 测试函数中文命名审计 ===")
    print(f"扫描文件数: {files_checked}")
    print(f"违规数量: {len(all_violations)}")
    print()

    if all_violations:
        print("=== 违规详情 ===")
        for v in all_violations:
            print(f"  {v['file']}:{v['line']}")
            print(f"    函数名: {v['func_name']}")
            print(f"    源码: {v['source']}")
            print()

        print(f"=== 修复指南 ===")
        print("所有测试函数名必须使用英文 camelCase 命名，禁止包含中文字符。")
        print("示例:")
        print("  ❌ func testLoadCachedLanguageMode_DI未就绪_不崩溃()")
        print("  ✅ func testLoadCachedLanguageModeDINotReadyNoCrash()")
        print()
        print(f"共发现 {len(all_violations)} 个中文命名的测试函数，请全部重命名为英文。")
        sys.exit(1)
    else:
        print("✅ 所有测试函数名均为英文命名，审计通过。")
        sys.exit(0)


if __name__ == "__main__":
    main()
