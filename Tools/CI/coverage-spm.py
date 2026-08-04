#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  coverage-spm.py
#  ZhiYu
#
#  系统层级：[Tools/CI] 持续集成
#  核心职责：本地 SPM 包覆盖率一键测量与报告。
#           1. 对指定 SPM 包（或全部 6 个包）运行 swift test --enable-code-coverage
#           2. 通过 xcrun llvm-cov 提取语句覆盖率（Line）和分支覆盖率（Branch）
#           3. 汇总总体 + 各模块 + 各文件三层粒度
#           4. 对照阈值（语句 ≥90%、分支 ≥90%）判定达标
#           5. 支持 --json 机器可读输出、--details 展示每文件覆盖率
#
#  用法：
#      python3 Tools/CI/coverage-spm.py                    # 测量全部 6 个 SPM 包
#      python3 Tools/CI/coverage-spm.py --pkg UFPCore      # 仅测量 UFPCore
#      python3 Tools/CI/coverage-spm.py --pkg UFPCore,ZhiYuAICore
#      python3 Tools/CI/coverage-spm.py --details          # 展示每文件覆盖率
#      python3 Tools/CI/coverage-spm.py --json             # JSON 机器可读输出
#      python3 Tools/CI/coverage-spm.py --threshold 95     # 自定义语句覆盖率阈值
#      python3 Tools/CI/coverage-spm.py --skip-test        # 跳过测试运行（复用已有 profdata）
#

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from typing import Optional

# ==============================================================================
# MARK: - 常量定义
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PACKAGES_DIR = os.path.join(PROJECT_DIR, "Packages")

ALL_PACKAGES = ["UFPCore", "UFPStorage", "UFPDesignSystem",
                "ZhiYuDomain", "ZhiYuAICore", "ZhiYuFeatures"]

DEFAULT_LINE_THRESHOLD = 90.0
DEFAULT_BRANCH_THRESHOLD = 90.0

# 报告表格宽度与着色阈值
REPORT_WIDTH = 90
NEAR_THRESHOLD_MARGIN = 10.0  # 距阈值 10% 以内标黄色
ERROR_SNIPPET_LEN = 80
TIMEOUT_TEST_SECONDS = 300
TIMEOUT_COV_SECONDS = 60

# llvm-cov report 正则捕获组索引（见 parse_llvm_cov_report）
REGEX_GROUP_FILENAME = 1
REGEX_GROUP_FUNCTIONS_TOTAL = 3
REGEX_GROUP_FUNCTIONS_MISSED = 4
REGEX_GROUP_LINES_TOTAL = 6
REGEX_GROUP_LINES_MISSED = 7
REGEX_GROUP_LINE_RATE = 8
REGEX_GROUP_BRANCH_RATE = 11

# 百分比换算
PERCENT_MULTIPLIER = 100

# llvm-cov report 输出中需忽略的路径正则（基础部分）
# 包级过滤在 parse_llvm_cov_report 中动态构建
IGNORE_REGEX_BASE = r"\.build/|/Tests/|TestMocks|GRDB|Cwl|PartialJSON|SwiftJSONSanitizer|opensrc/"

# ==============================================================================
# MARK: - 数据结构
# ==============================================================================

@dataclass
class FileCoverage:
    """单个文件的覆盖率"""
    filename: str
    line_rate: float          # 语句覆盖率 %
    branch_rate: float        # 分支覆盖率 %（-1 表示未收集）
    functions_total: int
    functions_covered: int
    lines_total: int
    lines_covered: int

@dataclass
class PackageCoverage:
    """单个 SPM 包的覆盖率汇总"""
    name: str
    tested: bool              # 是否成功运行测试
    line_rate: float = 0.0
    branch_rate: float = -1.0
    functions_total: int = 0
    functions_covered: int = 0
    lines_total: int = 0
    lines_covered: int = 0
    files: list = field(default_factory=list)  # list[FileCoverage]
    error: Optional[str] = None
    no_executable_code: bool = False  # 无可执行代码（纯常量/re-export）

# ==============================================================================
# MARK: - 核心逻辑
# ==============================================================================

def run_swift_test_with_coverage(pkg_name: str) -> tuple[bool, Optional[str]]:
    """运行 swift test --enable-code-coverage，返回 (成功, 错误信息)"""
    pkg_path = os.path.join(PACKAGES_DIR, pkg_name)
    if not os.path.isdir(pkg_path):
        return False, f"包目录不存在: {pkg_path}"

    try:
        result = subprocess.run(
            ["swift", "test", "--package-path", pkg_path, "--enable-code-coverage"],
            capture_output=True, text=True, timeout=TIMEOUT_TEST_SECONDS
        )
        if result.returncode != 0:
            return False, f"测试失败 (exit {result.returncode}):\n{result.stderr[-ERROR_SNIPPET_LEN:]}"
        return True, None
    except subprocess.TimeoutExpired:
        return False, f"测试超时（>{TIMEOUT_TEST_SECONDS}s）"
    except FileNotFoundError:
        return False, "swift 命令未找到"

def find_binary_and_profdata(pkg_name: str) -> tuple[Optional[str], Optional[str]]:
    """定位 SPM 包的测试二进制和 profdata 文件"""
    build_dir = os.path.join(PACKAGES_DIR, pkg_name, ".build", "arm64-apple-macosx", "debug")
    profdata = os.path.join(build_dir, "codecov", "default.profdata")

    # 测试二进制路径：{pkg}PackageTests.xctest/Contents/MacOS/{pkg}PackageTests
    binary = os.path.join(build_dir, f"{pkg_name}PackageTests.xctest",
                          "Contents", "MacOS", f"{pkg_name}PackageTests")

    if os.path.isfile(binary) and os.path.isfile(profdata):
        return binary, profdata
    return None, None

def parse_llvm_cov_report(binary: str, profdata: str, pkg_name: str) -> tuple[list[FileCoverage], FileCoverage]:
    """解析 llvm-cov report 输出，返回 (文件列表, 汇总行)

    动态构建忽略正则：过滤掉其他 SPM 包的源码，只统计当前包
    """
    # 基础忽略 + 其他包源码（保留当前包）
    other_packages = [p for p in ALL_PACKAGES if p != pkg_name]
    ignore_regex = IGNORE_REGEX_BASE + "|" + "|".join(f"/{p}/" for p in other_packages)

    cmd = [
        "xcrun", "llvm-cov", "report", binary,
        "-instr-profile", profdata,
        "-ignore-filename-regex", ignore_regex,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT_COV_SECONDS)
        if result.returncode != 0:
            return [], FileCoverage("ERROR", 0, -1, 0, 0, 0, 0)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return [], FileCoverage("ERROR", 0, -1, 0, 0, 0, 0)

    files = []
    total = FileCoverage("TOTAL", 0, -1, 0, 0, 0, 0)

    for line in result.stdout.splitlines():
        # 匹配表格行：Filename  Regions  Missed  Cover  Functions  Missed  Executed  Lines  Missed  Cover  Branches  Missed  Cover
        m = re.match(
            r"^(\S.*?)\s+\d+\s+\d+\s+([\d.]+)%\s+(\d+)\s+(\d+)\s+([\d.]+)%\s+(\d+)\s+(\d+)\s+([\d.]+)%\s+(\d+)\s+(\d+)\s+([\d.-]+)%?\s*$",
            line
        )
        if not m:
            continue

        filename = m.group(REGEX_GROUP_FILENAME)
        line_rate = float(m.group(REGEX_GROUP_LINE_RATE))
        functions_total = int(m.group(REGEX_GROUP_FUNCTIONS_TOTAL))
        functions_covered = int(m.group(REGEX_GROUP_FUNCTIONS_TOTAL)) - int(m.group(REGEX_GROUP_FUNCTIONS_MISSED))
        lines_total = int(m.group(REGEX_GROUP_LINES_TOTAL))
        lines_covered = int(m.group(REGEX_GROUP_LINES_TOTAL)) - int(m.group(REGEX_GROUP_LINES_MISSED))

        # 分支覆盖率（llvm-cov 默认不收集时为 0/0，显示 "-"）
        branch_str = m.group(REGEX_GROUP_BRANCH_RATE)
        branch_rate = float(branch_str) if branch_str not in ("-", "") else -1.0

        fc = FileCoverage(filename, line_rate, branch_rate,
                          functions_total, functions_covered,
                          lines_total, lines_covered)

        if filename == "TOTAL":
            total = fc
        else:
            files.append(fc)

    return files, total

def measure_package(pkg_name: str, skip_test: bool) -> PackageCoverage:
    """测量单个 SPM 包的覆盖率"""
    pc = PackageCoverage(name=pkg_name, tested=False)

    if not skip_test:
        ok, err = run_swift_test_with_coverage(pkg_name)
        if not ok:
            pc.error = err
            return pc
        pc.tested = True
    else:
        pc.tested = True  # 假设已有 profdata

    binary, profdata = find_binary_and_profdata(pkg_name)
    if not binary or not profdata:
        pc.error = "未找到测试二进制或 profdata（请先运行测试）"
        return pc

    files, total = parse_llvm_cov_report(binary, profdata, pkg_name)
    pc.files = files
    pc.line_rate = total.line_rate
    pc.branch_rate = total.branch_rate
    pc.functions_total = total.functions_total
    pc.functions_covered = total.functions_covered
    pc.lines_total = total.lines_total
    pc.lines_covered = total.lines_covered

    # 无可执行代码的包（纯常量/re-export）标记为 N/A，不参与达标判定
    if pc.lines_total == 0 and pc.functions_total == 0:
        pc.no_executable_code = True

    return pc

def compute_overall(packages: list) -> dict:
    """计算所有包的加权总体覆盖率（排除无可测代码的包和出错的包）"""
    measurable = [p for p in packages if p.error is None and not p.no_executable_code]
    total_lines = sum(p.lines_total for p in measurable)
    covered_lines = sum(p.lines_covered for p in measurable)
    total_funcs = sum(p.functions_total for p in measurable)
    covered_funcs = sum(p.functions_covered for p in measurable)

    line_rate = (covered_lines / total_lines * PERCENT_MULTIPLIER) if total_lines > 0 else 0.0
    func_rate = (covered_funcs / total_funcs * PERCENT_MULTIPLIER) if total_funcs > 0 else 0.0

    return {
        "line_rate": round(line_rate, 2),
        "function_rate": round(func_rate, 2),
        "lines_total": total_lines,
        "lines_covered": covered_lines,
        "functions_total": total_funcs,
        "functions_covered": covered_funcs,
    }

# ==============================================================================
# MARK: - 报告输出
# ==============================================================================

def colorize_rate(rate: float, threshold: float) -> str:
    """根据阈值着色：达标绿色、接近黄色、未达标红色"""
    if rate < 0:
        return "  -  "  # 未收集
    if rate >= threshold:
        return f"\033[32m{rate:6.2f}%\033[0m"
    if rate >= threshold - NEAR_THRESHOLD_MARGIN:
        return f"\033[33m{rate:6.2f}%\033[0m"
    return f"\033[31m{rate:6.2f}%\033[0m"

def _print_report_header(line_threshold: float, branch_threshold: float):
    """打印报告头部（标题 + 阈值 + 表头）"""
    print("=" * REPORT_WIDTH)
    print("📊 SPM 包覆盖率报告 (llvm-cov)")
    print("=" * REPORT_WIDTH)
    print(f"语句覆盖率阈值: ≥{line_threshold:.0f}%   分支覆盖率阈值: ≥{branch_threshold:.0f}%")
    print("（注：分支覆盖率需编译时启用 -profile-coverage-mapping，默认未收集显示 '-'）")
    print("-" * REPORT_WIDTH)
    print(f"{'包名':<20} {'语句覆盖':>10} {'分支覆盖':>10} {'函数':>10} {'行数':>12} {'状态':>8}")
    print("-" * REPORT_WIDTH)

def _print_package_row(pc: PackageCoverage, line_threshold: float,
                       branch_threshold: float, show_details: bool) -> bool:
    """打印单个包的覆盖率行，返回是否达标（出错/未达标返回 False）"""
    if pc.error:
        print(f"{pc.name:<20} {'ERROR':>10} {'-':>10} {'-':>10} {'-':>12} {'❌ 失败':>8}")
        print(f"  └─ {pc.error[:ERROR_SNIPPET_LEN]}")
        return False

    if pc.no_executable_code:
        print(f"{pc.name:<20} {'N/A':>10} {'-':>10} {'-':>10} {'0/0':>12} {'⏭️ 无可测代码':>8}")
        return True  # N/A 不算失败

    status = "✅" if pc.line_rate >= line_threshold else "⚠️"
    print(f"{pc.name:<20} {colorize_rate(pc.line_rate, line_threshold):>16} "
          f"{colorize_rate(pc.branch_rate, branch_threshold):>16} "
          f"{pc.functions_covered}/{pc.functions_total:<6} "
          f"{pc.lines_covered}/{pc.lines_total:<8} {status:>8}")

    if show_details and pc.files:
        for fc in pc.files:
            short_name = fc.filename.split("/")[-1]
            print(f"  {short_name:<30} 语句={colorize_rate(fc.line_rate, line_threshold):>16} "
                  f"函数={fc.functions_covered}/{fc.functions_total}")

    return pc.line_rate >= line_threshold

def _print_report_footer(packages: list, overall: dict,
                          line_threshold: float, branch_threshold: float,
                          all_pass: bool):
    """打印报告尾部（总体行 + 达标判定）"""
    print("-" * REPORT_WIDTH)
    print(f"{'总体（加权）':<20} {colorize_rate(overall['line_rate'], line_threshold):>16} "
          f"{'-':>16} "
          f"{overall['functions_covered']}/{overall['functions_total']:<6} "
          f"{overall['lines_covered']}/{overall['lines_total']:<8}")
    print("=" * REPORT_WIDTH)

    if all_pass:
        print("✅ 所有可测包语句覆盖率达标")
    else:
        failed = [p.name for p in packages
                  if p.error is None and not p.no_executable_code
                  and p.line_rate < line_threshold]
        errored = [p.name for p in packages if p.error]
        if failed:
            print(f"⚠️  语句覆盖率未达标: {', '.join(failed)}")
        if errored:
            print(f"❌ 测试失败: {', '.join(errored)}")
    print()

def print_text_report(packages: list, overall: dict,
                      line_threshold: float, branch_threshold: float,
                      show_details: bool):
    """打印文本格式覆盖率报告"""
    _print_report_header(line_threshold, branch_threshold)
    all_pass = True
    for pc in packages:
        if not _print_package_row(pc, line_threshold, branch_threshold, show_details):
            if pc.error is None and not pc.no_executable_code:
                all_pass = False
    _print_report_footer(packages, overall, line_threshold, branch_threshold, all_pass)

def print_json_report(packages: list, overall: dict):
    """打印 JSON 格式覆盖率报告"""
    output = {
        "overall": overall,
        "packages": [asdict(p) for p in packages],
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))

# ==============================================================================
# MARK: - 主入口
# ==============================================================================

def _build_arg_parser() -> argparse.ArgumentParser:
    """构建命令行参数解析器"""
    parser = argparse.ArgumentParser(
        description="SPM 包覆盖率一键测量与报告",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python3 Tools/CI/coverage-spm.py                    # 测量全部 6 个 SPM 包
  python3 Tools/CI/coverage-spm.py --pkg UFPCore      # 仅测量 UFPCore
  python3 Tools/CI/coverage-spm.py --pkg UFPCore,ZhiYuAICore
  python3 Tools/CI/coverage-spm.py --details          # 展示每文件覆盖率
  python3 Tools/CI/coverage-spm.py --json             # JSON 机器可读输出
  python3 Tools/CI/coverage-spm.py --skip-test        # 跳过测试（复用已有 profdata）
        """
    )
    parser.add_argument("--pkg", type=str, default="",
                        help="指定包名（逗号分隔），默认全部 6 个包")
    parser.add_argument("--details", action="store_true",
                        help="展示每文件覆盖率")
    parser.add_argument("--json", action="store_true",
                        help="JSON 机器可读输出")
    parser.add_argument("--skip-test", action="store_true",
                        help="跳过测试运行（复用已有 profdata）")
    parser.add_argument("--threshold", type=float, default=DEFAULT_LINE_THRESHOLD,
                        help=f"语句覆盖率阈值（默认 {DEFAULT_LINE_THRESHOLD}%%）")
    parser.add_argument("--branch-threshold", type=float, default=DEFAULT_BRANCH_THRESHOLD,
                        help=f"分支覆盖率阈值（默认 {DEFAULT_BRANCH_THRESHOLD}%%）")
    return parser

def _resolve_package_list(args) -> list:
    """解析并校验包列表，无效包名时退出进程"""
    if not args.pkg:
        return ALL_PACKAGES
    pkg_list = [p.strip() for p in args.pkg.split(",") if p.strip()]
    invalid = [p for p in pkg_list if p not in ALL_PACKAGES]
    if invalid:
        print(f"❌ 未知包名: {', '.join(invalid)}", file=sys.stderr)
        print(f"   可用包: {', '.join(ALL_PACKAGES)}", file=sys.stderr)
        sys.exit(2)
    return pkg_list

def _measure_all_packages(pkg_list: list, skip_test: bool) -> list:
    """测量所有指定包的覆盖率"""
    packages = []
    for pkg in pkg_list:
        print(f"🧪 测量 {pkg} ...", file=sys.stderr)
        pc = measure_package(pkg, skip_test)
        packages.append(pc)
    return packages

def _determine_exit_code(packages: list, threshold: float) -> int:
    """根据测量结果决定退出码（0=达标，1=未达标或出错）"""
    measurable_failed = [p.name for p in packages
                         if p.error is None and not p.no_executable_code
                         and p.line_rate < threshold]
    errored = [p.name for p in packages if p.error]
    return 0 if len(measurable_failed) == 0 and len(errored) == 0 else 1

def main():
    """主入口：解析参数 → 测量包 → 输出报告 → 返回退出码"""
    args = _build_arg_parser().parse_args()
    pkg_list = _resolve_package_list(args)
    packages = _measure_all_packages(pkg_list, args.skip_test)
    overall = compute_overall(packages)

    if args.json:
        print_json_report(packages, overall)
    else:
        print_text_report(packages, overall, args.threshold, args.branch_threshold, args.details)

    sys.exit(_determine_exit_code(packages, args.threshold))

if __name__ == "__main__":
    main()
