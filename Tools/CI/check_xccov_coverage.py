#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_xccov_coverage.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/25.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/CI] 持续集成
#  核心职责：从 xccov 生成的 SonarQube Generic Coverage XML 直接解析语句覆盖率与
#           分支覆盖率（不依赖 SonarQube server），按模块统计并对照 Quality Gate
#           阈值（语句 ≥95%、分支 ≥90%）判定是否达标。
#           适用场景：SonarQube Community Edition 不支持 Swift 语言分析，无法导入
#           Swift 覆盖率数据，因此用本脚本在 CI 中直接从 xccov 报告做本地门禁。
#

import argparse
import os
import re
import sys
from collections import defaultdict

# ==============================================================================
# MARK: - 常量定义
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

PERCENT_MULTIPLIER = 100.0

LINE_COVERAGE_THRESHOLD = 95.0
BRANCH_COVERAGE_THRESHOLD = 90.0

COLOR_RED = "\033[31m"
COLOR_GREEN = "\033[32m"
COLOR_YELLOW = "\033[33m"
COLOR_CYAN = "\033[36m"
COLOR_BOLD = "\033[1m"
COLOR_RESET = "\033[0m"

REPORT_LINE_WIDTH = 80
TABLE_SEPARATOR_WIDTH = 70

DEFAULT_COVERAGE_XML = "build/coverage/sonarqube-generic-coverage.xml"

REGEX_GROUP_COVERED_FLAG = 1
REGEX_GROUP_BRANCHES_TOTAL = 2
REGEX_GROUP_BRANCHES_COVERED = 3
MIN_PATH_PARTS_FOR_MODULE = 3

MODULE_CATEGORIES = [
    ("App", "Sources/App"),
    ("Core", "Sources/Core"),
    ("Infrastructure", "Sources/Infrastructure"),
    ("Domain", "Sources/Domain"),
    ("Features/非View", "Sources/Features (非View)"),
    ("Features/View", "Sources/Features/View"),
    ("Shared", "Sources/Shared"),
    ("Platforms", "Sources/Platforms"),
    ("Localization", "Sources/Localization"),
]

FILE_PATTERN = re.compile(
    r'<file path="([^"]+)">(.*?)</file>', re.DOTALL
)
LINE_PATTERN = re.compile(
    r'<lineToCover lineNumber="\d+" covered="(true|false)"'
    r'(?: branchesToCover="(\d+)" coveredBranches="(\d+)")?'
)


# ==============================================================================
# MARK: - 日志函数
# ==============================================================================

def log_info(msg: str):
    print(f"{COLOR_CYAN}[INFO]{COLOR_RESET} {msg}")


def log_success(msg: str):
    print(f"{COLOR_GREEN}[PASS]{COLOR_RESET} {msg}")


def log_error(msg: str):
    print(f"{COLOR_RED}[FAIL]{COLOR_RESET} {msg}")


def log_warn(msg: str):
    print(f"{COLOR_YELLOW}[WARN]{COLOR_RESET} {msg}")


# ==============================================================================
# MARK: - 路径分类
# ==============================================================================

def categorize_file(path: str, project_root: str) -> str:
    """将文件路径分类到对应模块

    返回模块标签字符串；不属于 Sources/ 的返回空字符串（忽略）。
    """
    prefix = project_root + "/"
    if path.startswith(prefix):
        path = path[len(prefix):]

    if not path.startswith("Sources/"):
        return ""

    parts = path.split("/")
    if len(parts) < MIN_PATH_PARTS_FOR_MODULE:
        return "Sources/其他"

    top = parts[1]
    if top == "Features":
        if "View" in parts[2:]:
            return "Features/View"
        return "Features/非View"
    if top in ("App", "Core", "Infrastructure", "Domain", "Shared",
               "Platforms", "Localization"):
        return top
    return "Sources/其他"


# ==============================================================================
# MARK: - XML 解析
# ==============================================================================

def parse_coverage_xml(xml_path: str, project_root: str) -> dict:
    """解析 SonarQube Generic Coverage XML，返回按模块聚合的覆盖率统计

    返回结构:
    {
        "modules": {
            "App": {"lines": int, "covered": int, "branches": int, "covered_branches": int},
            ...
        },
        "totals": {"lines": int, "covered": int, "branches": int, "covered_branches": int},
        "files_parsed": int,
        "files_ignored": int,
    }
    """
    if not os.path.isfile(xml_path):
        log_error(f"覆盖率报告不存在: {xml_path}")
        return {}

    with open(xml_path, encoding="utf-8") as f:
        content = f.read()

    modules = defaultdict(
        lambda: {"lines": 0, "covered": 0, "branches": 0, "covered_branches": 0}
    )
    totals = {"lines": 0, "covered": 0, "branches": 0, "covered_branches": 0}
    files_parsed = 0
    files_ignored = 0

    for file_match in FILE_PATTERN.finditer(content):
        path = file_match.group(REGEX_GROUP_COVERED_FLAG)
        body = file_match.group(REGEX_GROUP_BRANCHES_TOTAL)
        category = categorize_file(path, project_root)
        if not category:
            files_ignored += 1
            continue
        files_parsed += 1
        _accumulate_file_coverage(body, modules, category, totals)

    return {
        "modules": dict(modules),
        "totals": totals,
        "files_parsed": files_parsed,
        "files_ignored": files_ignored,
    }


def _accumulate_file_coverage(
    body: str,
    modules: defaultdict,
    category: str,
    totals: dict,
):
    """累加单个文件的覆盖率数据到模块和总计统计中"""
    for line_match in LINE_PATTERN.finditer(body):
        covered = line_match.group(REGEX_GROUP_COVERED_FLAG) == "true"
        modules[category]["lines"] += 1
        totals["lines"] += 1
        if covered:
            modules[category]["covered"] += 1
            totals["covered"] += 1
        branches_str = line_match.group(REGEX_GROUP_BRANCHES_TOTAL)
        if branches_str:
            branches = int(branches_str)
            covered_branches = int(
                line_match.group(REGEX_GROUP_BRANCHES_COVERED)
            )
            modules[category]["branches"] += branches
            totals["branches"] += branches
            modules[category]["covered_branches"] += covered_branches
            totals["covered_branches"] += covered_branches


# ==============================================================================
# MARK: - 报告格式化
# ==============================================================================

def _format_pct(numerator: int, denominator: int) -> str:
    """格式化百分比"""
    if denominator == 0:
        return "N/A"
    return f"{numerator / denominator * PERCENT_MULTIPLIER:.2f}%"


def _coverage_status(numerator: int, denominator: int, threshold: float) -> str:
    """判断覆盖率是否达标，返回带颜色的状态标记"""
    if denominator == 0:
        return f"{COLOR_YELLOW}⚠ 无数据{COLOR_RESET}"
    pct = numerator / denominator * PERCENT_MULTIPLIER
    if pct >= threshold:
        return f"{COLOR_GREEN}✓ 达标{COLOR_RESET}"
    return f"{COLOR_RED}✗ 未达标{COLOR_RESET}"


def print_report(stats: dict, line_threshold: float, branch_threshold: float):
    """打印覆盖率报告"""
    modules = stats["modules"]
    totals = stats["totals"]

    print(f"\n{'=' * REPORT_LINE_WIDTH}")
    print(f"{COLOR_BOLD}  ZhiYu xccov 覆盖率报告 — 本地门禁（不依赖 SonarQube）{COLOR_RESET}")
    print(f"{'=' * REPORT_LINE_WIDTH}")
    print(f"\n  已解析文件: {stats['files_parsed']}  |  已忽略文件: {stats['files_ignored']}")

    header = f"  {'模块':<20} {'语句覆盖率':>12} {'分支覆盖率':>12} {'行数':>8} {'分支数':>8} {'状态'}"
    print(f"\n{header}")
    print(f"  {'-' * TABLE_SEPARATOR_WIDTH}")

    for label, _ in MODULE_CATEGORIES:
        s = modules.get(label)
        if not s or s["lines"] == 0:
            print(f"  {label:<20} {COLOR_YELLOW}{'无数据':>12}{COLOR_RESET} {'':>12} {'':>8} {'':>8}")
            continue
        line_pct = _format_pct(s["covered"], s["lines"])
        branch_pct = _format_pct(s["covered_branches"], s["branches"])
        line_status = _coverage_status(s["covered"], s["lines"], line_threshold)
        print(f"  {label:<20} {line_pct:>12} {branch_pct:>12} {s['lines']:>8} {s['branches']:>8} {line_status}")

    print(f"  {'-' * TABLE_SEPARATOR_WIDTH}")
    line_pct = _format_pct(totals["covered"], totals["lines"])
    branch_pct = _format_pct(totals["covered_branches"], totals["branches"])
    line_status = _coverage_status(totals["covered"], totals["lines"], line_threshold)
    branch_status = _coverage_status(
        totals["covered_branches"], totals["branches"], branch_threshold
    )
    print(f"  {'总计':<20} {COLOR_BOLD}{line_pct:>12}{COLOR_RESET} {COLOR_BOLD}{branch_pct:>12}{COLOR_RESET} {totals['lines']:>8} {totals['branches']:>8}")

    print(f"\n  门禁阈值: 语句覆盖率 ≥ {line_threshold}%  |  分支覆盖率 ≥ {branch_threshold}%")
    print(f"  语句覆盖率: {line_status}")
    print(f"  分支覆盖率: {branch_status}")


# ==============================================================================
# MARK: - 门禁判定
# ==============================================================================

def check_gate(stats: dict, line_threshold: float, branch_threshold: float) -> bool:
    """检查覆盖率是否满足门禁阈值"""
    totals = stats["totals"]
    if totals["lines"] == 0:
        log_error("无覆盖率数据，无法判定门禁")
        return False

    line_pct = totals["covered"] / totals["lines"] * PERCENT_MULTIPLIER
    branch_pct = (
        totals["covered_branches"] / totals["branches"] * PERCENT_MULTIPLIER
        if totals["branches"] > 0
        else 0.0
    )

    passed = True
    if line_pct < line_threshold:
        log_error(
            f"语句覆盖率 {line_pct:.2f}% < {line_threshold}% 阈值"
        )
        passed = False
    else:
        log_success(
            f"语句覆盖率 {line_pct:.2f}% ≥ {line_threshold}% 阈值"
        )

    if totals["branches"] > 0:
        if branch_pct < branch_threshold:
            log_error(
                f"分支覆盖率 {branch_pct:.2f}% < {branch_threshold}% 阈值"
            )
            passed = False
        else:
            log_success(
                f"分支覆盖率 {branch_pct:.2f}% ≥ {branch_threshold}% 阈值"
            )

    return passed


# ==============================================================================
# MARK: - 主流程
# ==============================================================================

def main():
    """主程序：解析 xccov 覆盖率 XML，生成报告并判定门禁"""
    parser = argparse.ArgumentParser(
        description="ZhiYu xccov 本地覆盖率门禁检查（不依赖 SonarQube server）",
        epilog="示例: python3 Tools/CI/check_xccov_coverage.py --xml build/coverage/sonarqube-generic-coverage.xml",
    )
    parser.add_argument(
        "--xml",
        default=os.path.join(PROJECT_DIR, DEFAULT_COVERAGE_XML),
        help=f"SonarQube Generic Coverage XML 路径 (默认: {DEFAULT_COVERAGE_XML})",
    )
    parser.add_argument(
        "--line-threshold",
        type=float,
        default=LINE_COVERAGE_THRESHOLD,
        help=f"语句覆盖率阈值 (默认: {LINE_COVERAGE_THRESHOLD}%%)",
    )
    parser.add_argument(
        "--branch-threshold",
        type=float,
        default=BRANCH_COVERAGE_THRESHOLD,
        help=f"分支覆盖率阈值 (默认: {BRANCH_COVERAGE_THRESHOLD}%%)",
    )
    parser.add_argument(
        "--report-only",
        action="store_true",
        help="仅生成报告，不执行门禁判定（始终返回 0）",
    )
    args = parser.parse_args()

    xml_path = os.path.abspath(args.xml)
    log_info(f"覆盖率报告: {xml_path}")
    log_info(f"门禁阈值: 语句 ≥ {args.line_threshold}%  |  分支 ≥ {args.branch_threshold}%")

    stats = parse_coverage_xml(xml_path, PROJECT_DIR)
    if not stats:
        return 1

    print_report(stats, args.line_threshold, args.branch_threshold)

    print(f"\n{'=' * REPORT_LINE_WIDTH}")
    if args.report_only:
        log_info("仅报告模式，跳过门禁判定")
        return 0

    passed = check_gate(stats, args.line_threshold, args.branch_threshold)
    if passed:
        log_success("覆盖率门禁通过")
        return 0
    log_error("覆盖率门禁未通过")
    return 1


if __name__ == "__main__":
    sys.exit(main())
