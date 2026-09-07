#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-test-anti-patterns.py
#  ZhiYu
#
#  Created by Antigravity on 2026/09/04.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/CI] 测试质量守卫网关
#  核心职责：单元测试语义质量反模式静态扫描门禁，依据 unit-test-quality-review 技能规范自动化拦截无断言测试与常量断言。
#

"""
单元测试质量语义反模式静态扫描门禁
依据 unit-test-quality-review 规范，扫描测试用例中的无断言、永真断言及浅层断言。
"""

import os
import re
import sys
import argparse

BANNER_WIDTH = 80
MAX_PREVIEW_COUNT = 25
CONTEXT_HEAD_OFFSET = 20
CONTEXT_TAIL_OFFSET = 20
ASSERTION_HEAD_OFFSET = 5
ASSERTION_TAIL_OFFSET = 15
MAX_EMPTY_CATCH_LENGTH = 100
ASSERT_ARG_PREVIEW_LENGTH = 80
SHALLOW_VIEW_EXPR_BLOCKLIST = frozenset([
    "host.view", "hosting.view", "hostingController.view", "host", "true", "false", "",
])

TEST_FUNC_PATTERN = re.compile(
    r"^\s*(?:@\w+\s+)*func\s+(test\S*?)\s*\([^)]*\)\s*(?:async\s*)?(?:throws\s*)?\{",
    re.MULTILINE
)
ASSERT_PATTERN = re.compile(r"\b(?:XCTAssert\w*|XCTUnwrap|XCTFail|fulfillment|assert[A-Z]\w*)\b")
CONST_ASSERT_PATTERN = re.compile(
    r"\bXCTAssert(?:True\s*\(\s*true\b|False\s*\(\s*false\b|Equal\s*\(\s*(\d+|true|false)\s*,\s*\1\s*\))"
)
EMPTY_CATCH_PATTERN = re.compile(r"catch\s*\{\s*\}")
TASK_OR_PRIORITY_FUNC_PATTERN = re.compile(r"^test(?:Bug\d+|P\d+|Batch\d+)")
TASK_OR_PRIORITY_FILE_PATTERN = re.compile(r"(?:BugHunt|Batch\d+|Exploratory|Pilot|P\d+)")


SKIP_OFFSET_TWO = 2
SKIP_OFFSET_TRIPLE = 3


def skip_comment(content, idx):
    """跳过单行与多行注释。"""
    if content[idx:idx + SKIP_OFFSET_TWO] == "//":
        end_nl = content.find("\n", idx)
        return len(content) if end_nl == -1 else end_nl + 1
    if content[idx:idx + SKIP_OFFSET_TWO] == "/*":
        end_comment = content.find("*/", idx)
        return len(content) if end_comment == -1 else end_comment + SKIP_OFFSET_TWO
    return idx


def skip_string_literal(content, idx):
    """跳过各种 Swift 字符串字面量。"""
    if content[idx:idx + SKIP_OFFSET_TWO] == '#"':
        end_raw = content.find('"#', idx + SKIP_OFFSET_TWO)
        return idx + SKIP_OFFSET_TWO if end_raw == -1 else end_raw + SKIP_OFFSET_TWO
    if content[idx:idx + SKIP_OFFSET_TRIPLE] == '"""':
        end_multi = content.find('"""', idx + SKIP_OFFSET_TRIPLE)
        return idx + SKIP_OFFSET_TRIPLE if end_multi == -1 else end_multi + SKIP_OFFSET_TRIPLE
    if content[idx] == '"':
        idx += 1
        while idx < len(content):
            if content[idx] == '\\':
                idx += SKIP_OFFSET_TWO
                continue
            if content[idx] == '"':
                return idx + 1
            idx += 1
        return idx
    return idx


def skip_string_or_comment(content, idx):
    """跳过注释或字符串字面量，返回跳过后的下标。"""
    c_idx = skip_comment(content, idx)
    if c_idx != idx:
        return c_idx
    return skip_string_literal(content, idx)



def find_matching_brace(content, start_pos):
    """查找对应闭合大括号的结束位置。"""
    brace_count = 1
    idx = start_pos
    while idx < len(content) and brace_count > 0:
        new_idx = skip_string_or_comment(content, idx)
        if new_idx != idx:
            idx = new_idx
            continue
        ch = content[idx]
        if ch == "{":
            brace_count += 1
        elif ch == "}":
            brace_count -= 1
        idx += 1
    return idx


def extract_functions(content):
    """提取文件中的所有测试函数及其函数体。"""
    matches = list(TEST_FUNC_PATTERN.finditer(content))
    functions = []
    for match in matches:
        func_name = match.group(1)
        start_pos = match.end()
        start_line = content[:match.start()].count("\n") + 1
        end_pos = find_matching_brace(content, start_pos)
        body = content[start_pos:end_pos - 1]
        functions.append((func_name, start_line, body))
    return functions



def check_assertions(body, start_line, filepath, func_name):
    """
    检查函数体中的断言有效性。
    """
    violations = []
    all_asserts = list(ASSERT_PATTERN.finditer(body))
    
    if not all_asserts:
        violations.append({
            "type": "NO_ASSERTIONS",
            "severity": "CRITICAL",
            "file": filepath,
            "line": start_line,
            "function": func_name,
            "msg": f"测试函数 {func_name} 体内没有任何断言 (XCTAssert/XCTFail)，属于虚胖测试"
        })
        return violations

    const_matches = list(CONST_ASSERT_PATTERN.finditer(body))
    for cm in const_matches:
        match_line = start_line + body[:cm.start()].count("\n")
        violations.append({
            "type": "CONSTANT_ASSERTION",
            "severity": "CRITICAL",
            "file": filepath,
            "line": match_line,
            "function": func_name,
            "msg": f"测试函数 {func_name} 使用了永真/常量断言: {cm.group(0)}"
        })

    return violations


def _collect_empty_catch_violations(body, start_line, filepath, func_name):
    """收集空 catch 块违规项"""
    violations = []
    empty_catches = list(EMPTY_CATCH_PATTERN.finditer(body))
    for ec in empty_catches:
        match_line = start_line + body[:ec.start()].count("\n")
        violations.append({
            "type": "EMPTY_CATCH",
            "severity": "HIGH",
            "file": filepath,
            "line": match_line,
            "function": func_name,
            "msg": f"测试函数 {func_name} 包含空 catch 块，静默吞掉了异常"
        })
    return violations


def _filter_non_trivial_asserts(body, all_asserts):
    """过滤出非浅层断言"""
    non_trivial = []
    for a in all_asserts:
        arg_slice = body[a.end():min(len(body), a.end() + ASSERT_ARG_PREVIEW_LENGTH)]
        end_p = arg_slice.find(")")
        if end_p != -1:
            arg_slice = arg_slice[:end_p]
        clean_arg = arg_slice.strip(" ( \t\n")
        expr = clean_arg.split(",")[0].strip()
        if expr in SHALLOW_VIEW_EXPR_BLOCKLIST:
            continue
        non_trivial.append(a.group(0))
    return non_trivial


def check_shallow_views(body, start_line, filepath, func_name):
    """
    检查是否仅包含浅层视图存在性断言。
    """
    violations = []
    all_asserts = list(ASSERT_PATTERN.finditer(body))
    if not all_asserts:
        return violations

    if "UIHostingController" not in body and "renderInWindow" not in body:
        violations.extend(_collect_empty_catch_violations(body, start_line, filepath, func_name))
        return violations

    non_trivial_asserts = _filter_non_trivial_asserts(body, all_asserts)

    if not non_trivial_asserts:
        violations.append({
            "type": "SHALLOW_VIEW_ASSERTION",
            "severity": "HIGH",
            "file": filepath,
            "line": start_line,
            "function": func_name,
            "msg": f"测试函数 {func_name} 仅包含 host.view != nil 等浅层断言，未验证视图内部属性或业务状态"
        })

    violations.extend(_collect_empty_catch_violations(body, start_line, filepath, func_name))

    return violations


def scan_file(filepath):
    """
    扫描单个 Swift 测试文件并汇总所有违规项。
    """
    violations = []
    filename = os.path.basename(filepath)
    if TASK_OR_PRIORITY_FILE_PATTERN.search(filename):
        violations.append({
            "type": "TASK_OR_PRIORITY_NAMING",
            "severity": "CRITICAL",
            "file": filepath,
            "line": 1,
            "function": "File",
            "msg": f"测试文件 {filename} 包含任务/批次/优先级命名，严禁以此类名称命名（只能以模块和特性命名）"
        })

    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    functions = extract_functions(content)
    for func_name, start_line, body in functions:
        if TASK_OR_PRIORITY_FUNC_PATTERN.search(func_name):
            violations.append({
                "type": "TASK_OR_PRIORITY_NAMING",
                "severity": "CRITICAL",
                "file": filepath,
                "line": start_line,
                "function": func_name,
                "msg": f"测试函数 {func_name} 包含 Bug/P/Batch 等前缀，严禁以任务或优先级命名用例（只能以模块和特性命名）"
            })
        violations.extend(check_assertions(body, start_line, filepath, func_name))
        violations.extend(check_shallow_views(body, start_line, filepath, func_name))

    return violations


def print_report(all_violations, test_dir):
    """
    打印反模式静态扫描统计与明细报告。
    """
    critical_count = sum(1 for v in all_violations if v["severity"] == "CRITICAL")
    high_count = sum(1 for v in all_violations if v["severity"] == "HIGH")

    print("=" * BANNER_WIDTH)
    print("  ZhiYu 单元测试反模式静态扫描门禁 (Unit Test Anti-Pattern Gatekeeper)")
    print("=" * BANNER_WIDTH)
    print(f"  扫描范围: {test_dir}")
    print(f"  发现反模式违规总数: {len(all_violations)} 处")
    print(f"  - [Critical] 致命空测试/常量断言: {critical_count} 处")
    print(f"  - [High] 浅层断言 / 空 catch 吞异常: {high_count} 处")
    print("-" * BANNER_WIDTH)

    by_type = {}
    for v in all_violations:
        t = v["type"]
        by_type[t] = by_type.get(t, 0) + 1
    for t, cnt in sorted(by_type.items(), key=lambda x: -x[1]):
        print(f"  * {t:25}: {cnt:4} 处")
    print("-" * BANNER_WIDTH)

    for v in all_violations[:MAX_PREVIEW_COUNT]:
        print(f"  [{v['severity']}] {v['file']}:{v['line']} ({v['function']}) -> {v['msg']}")

    print("=" * BANNER_WIDTH)


def main():
    """
    门禁主入口函数。
    """
    parser = argparse.ArgumentParser(description="单元测试质量反模式扫描门禁")
    parser.add_argument("--test-dir", default="Tests/Unit", help="测试目录路径")
    parser.add_argument("--report-only", action="store_true", help="仅报告模式，不触发退出码阻断")
    parser.add_argument("--strict", action="store_true", help="严格模式：浅层视图断言等全量反模式均阻断")
    args = parser.parse_args()

    all_violations = []
    for root, _, files in os.walk(args.test_dir):
        for file in files:
            if file.endswith(".swift"):
                fp = os.path.join(root, file)
                v = scan_file(fp)
                if v:
                    all_violations.extend(v)

    print_report(all_violations, args.test_dir)

    blocking_violations = all_violations if args.strict else [v for v in all_violations if v["severity"] == "CRITICAL"]
    if blocking_violations and not args.report_only:
        print(f"❌ 门禁失败：发现 {len(blocking_violations)} 处致命单元测试反模式违规（无断言/常量断言/命名违规），请消除后重新提交！")
        sys.exit(1)

    print("✅ 门禁通过：未发现致命测试反模式违规（无断言/常量断言/任务与优先级命名已彻底清零）。")
    sys.exit(0)


if __name__ == "__main__":
    main()
