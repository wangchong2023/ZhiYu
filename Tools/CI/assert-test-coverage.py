#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 作者: Wang Chong
# 功能说明: 智宇 (ZhiYu) 全自动代码覆盖率红线校验熔断工具
#          自动提取 .xcresult，通过 xccov 抽取高维 JSON 报文，
#          按架构分层 (L0-L3) 统计语句覆盖率与分支覆盖率，
#          对全 App 整体及每个模块均强加 85% 双红线（语句 + 分支）。
# 版本: 2.0
# 日期: 2026-08-06
#
# 变更说明 (v2.0):
#   - 从仅校验 Domain 层语句覆盖率扩展为全 App 各层双指标校验
#   - 新增按 Sources/ 顶级目录分类的层级聚合统计
#   - 新增分支覆盖率提取与校验（语句 + 分支双红线）
#   - 校验规则：全 App 整体 + 每个模块的语句覆盖率与分支覆盖率均 ≥ 阈值
#   - 新增 --details / --threshold / --branch-threshold / --json 命令行参数
#
# 调用方式:
#   python3 Tools/CI/assert-test-coverage.py                          # 默认：全层报告 + 85% 双红线
#   python3 Tools/CI/assert-test-coverage.py --details                # 展示每文件覆盖率明细
#   python3 Tools/CI/assert-test-coverage.py --threshold 90           # 自定义语句覆盖率红线
#   python3 Tools/CI/assert-test-coverage.py --branch-threshold 80    # 自定义分支覆盖率红线
#   python3 Tools/CI/assert-test-coverage.py --json                   # JSON 机器可读输出

import os
import sys
import glob
import json
import argparse
import subprocess
from collections import defaultdict

# ── 常量 ──────────────────────────────────────────────────────
PERCENT_MULTIPLIER = 100
DEFAULT_LINE_THRESHOLD = 85.0
DEFAULT_BRANCH_THRESHOLD = 85.0
SEARCH_DIR = "build/DerivedData-ios"
EXCLUDE_SUFFIXES = ["Schema.swift", "Status.swift"]

# 报告表格宽度（字符数）
TABLE_WIDTH = 95
# 函数体行数上限（Gatekeeper 规范）
MAX_FUNCTION_LINES = 50
# 圈复杂度上限（Gatekeeper 规范）
MAX_CYCLOMATIC_COMPLEXITY = 10

# 层级映射：Sources/ 下的顶级目录 → 层级显示名
# 顺序按 L0 → L3 自底向上，与架构分层文档对齐
LAYER_MAP = {
    "Core": "L0 Core",
    "Infrastructure": "L1 Infrastructure",
    "Domain": "L1.5 Domain",
    "Features": "L2 Features",
    "App": "L3 App",
    "Shared": "L3 Shared",
    "Localization": "Shared Localization",
    "Platforms": "L3 Platforms",
}

# 报告展示顺序（L0 → L3）
LAYER_ORDER = [
    "L0 Core",
    "L1 Infrastructure",
    "L1.5 Domain",
    "L2 Features",
    "L3 App",
    "L3 Shared",
    "Shared Localization",
    "L3 Platforms",
]


# ── 日志工具 ──────────────────────────────────────────────────
# JSON 模式下日志输出到 stderr，保证 stdout 为纯净 JSON
_LOG_STREAM = sys.stdout


def _set_log_stream(stream):
    """切换日志输出流（JSON 模式切换到 stderr）"""
    global _LOG_STREAM
    _LOG_STREAM = stream


def log_info(msg):
    print(f"\033[36m[INFO] {msg}\033[0m", file=_LOG_STREAM)


def log_success(msg):
    print(f"\033[32m[SUCCESS] ✓ {msg}\033[0m", file=_LOG_STREAM)


def log_warn(msg):
    print(f"\033[33m[WARN] ! {msg}\033[0m", file=_LOG_STREAM)


def log_error(msg):
    print(f"\033[31m[ERROR] ✗ {msg}\033[0m", file=_LOG_STREAM)


# ── xcresult 定位与解析 ──────────────────────────────────────
def find_latest_xcresult(search_dir):
    """寻找最新的 .xcresult 测试结果集包"""
    pattern = os.path.join(search_dir, "**/*.xcresult")
    results = glob.glob(pattern, recursive=True)
    if not results:
        return None
    # 按最后修改时间排序，取得最新产生的测试记录
    results.sort(key=os.path.getmtime, reverse=True)
    return results[0]


def recursive_find_files(node):
    """递归遍历 JSON 结构以适应 Xcode 不同版本 xccov 报文结构，收集所有文件覆盖率节点"""
    files = []
    if isinstance(node, dict):
        if "path" in node and ("coveredLines" in node or "executableLines" in node):
            files.append(node)
        for key, value in node.items():
            files.extend(recursive_find_files(value))
    elif isinstance(node, list):
        for item in node:
            files.extend(recursive_find_files(item))
    return files


def extract_raw_report_json(latest_result):
    """使用 xccov 工具提取最新的单元测试覆盖率 JSON 报文"""
    try:
        cmd = ["xcrun", "xccov", "view", "--report", "--json", latest_result]
        log_info(f"执行底层覆盖率转储: {' '.join(cmd)}")
        process = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        return process.stdout
    except subprocess.CalledProcessError as e:
        log_error(f"xccov 调用失败。错误详情:\n{e.stderr}")
        sys.exit(1)


# ── 层级分类 ──────────────────────────────────────────────────
def classify_layer(path):
    """根据文件路径返回层级显示名，非 Sources/ 下返回 None"""
    norm = path.replace("\\", "/")
    if "/Sources/" not in norm:
        return None
    idx = norm.find("/Sources/")
    after = norm[idx + len("/Sources/"):]
    top = after.split("/")[0]
    return LAYER_MAP.get(top, f"Other ({top})")


def filter_domain_files(all_files):
    """从所有文件覆盖率节点中，精准过滤并提取核心 Domain 层的 Swift 文件"""
    domain_files = []
    for f in all_files:
        path = f.get("path", "")
        if "Sources/Domain" in path or "Sources/Domain" in path.replace("\\", "/"):
            filename = os.path.basename(path)
            if any(filename.endswith(suffix) for suffix in EXCLUDE_SUFFIXES):
                continue
            domain_files.append(f)
    return domain_files


# ── 分支覆盖率提取 ────────────────────────────────────────────
def extract_branch_metrics(file_node):
    """
    从文件节点提取分支覆盖数据。
    xccov JSON 报文中分支数据可能以两种形式存在：
      1. 顶层 branchCoverage (0-1 浮点) + branches 数组
      2. 仅 branches 数组，需自行计算
    返回 (covered_branches, total_branches)；无分支数据返回 (0, 0)。
    """
    branches = file_node.get("branches")
    if branches and isinstance(branches, list):
        total = 0
        covered = 0
        for b in branches:
            if not isinstance(b, dict):
                continue
            # branchCount: 该分支点的分支总数；taken: 已执行的分支数
            branch_count = b.get("branchCount", 0)
            taken = b.get("taken", 0)
            if branch_count > 0:
                total += branch_count
                covered += min(taken, branch_count)
        return covered, total

    # 降级：尝试从 branchCoverage 浮点 + executableLines 反推（不精确，仅告警用）
    return 0, 0


# ── 聚合统计 ──────────────────────────────────────────────────
def aggregate_by_layer(all_files):
    """
    按架构层级聚合覆盖率数据。
    返回 {layer: {line_covered, line_executable, branch_covered, branch_total, files, has_branch}}。
    """
    layer_stats = defaultdict(lambda: {
        "line_covered": 0,
        "line_executable": 0,
        "branch_covered": 0,
        "branch_total": 0,
        "files": 0,
        "has_branch": False,
    })
    for f in all_files:
        path = f.get("path", "")
        line_covered = f.get("coveredLines", 0)
        line_executable = f.get("executableLines", 0)
        branch_covered, branch_total = extract_branch_metrics(f)

        layer = classify_layer(path)
        if layer is None:
            continue
        layer_stats[layer]["line_covered"] += line_covered
        layer_stats[layer]["line_executable"] += line_executable
        layer_stats[layer]["branch_covered"] += branch_covered
        layer_stats[layer]["branch_total"] += branch_total
        layer_stats[layer]["files"] += 1
        if branch_total > 0:
            layer_stats[layer]["has_branch"] = True
    return layer_stats


def calculate_pct(covered, total):
    """计算覆盖率百分比"""
    if total == 0:
        return 0.0
    return (covered / total) * PERCENT_MULTIPLIER


# ── 报告打印 ──────────────────────────────────────────────────
def print_layer_report(layer_stats, show_details=False, all_files=None):
    """打印全 App 各层覆盖率报告表（语句 + 分支双指标）"""
    print("\n" + "=" * TABLE_WIDTH)
    print(
        f"{'层级':<25} {'文件数':>6} "
        f"{'语句覆盖':>10} {'分支覆盖':>10} "
        f"{'覆盖行':>8} {'可执行行':>10}"
    )
    print("=" * TABLE_WIDTH)

    total_line_covered = 0
    total_line_executable = 0
    total_branch_covered = 0
    total_branch_total = 0
    any_branch = False

    for layer in LAYER_ORDER:
        s = layer_stats.get(layer)
        if not s:
            continue
        line_pct = calculate_pct(s["line_covered"], s["line_executable"])
        if s["has_branch"]:
            branch_pct = calculate_pct(s["branch_covered"], s["branch_total"])
            branch_str = f"{branch_pct:>9.2f}%"
            any_branch = True
        else:
            branch_str = f"{'N/A':>10}"
        print(
            f"{layer:<25} {s['files']:>6} "
            f"{line_pct:>9.2f}% {branch_str} "
            f"{s['line_covered']:>8} {s['line_executable']:>10}"
        )
        total_line_covered += s["line_covered"]
        total_line_executable += s["line_executable"]
        total_branch_covered += s["branch_covered"]
        total_branch_total += s["branch_total"]

    print("-" * TABLE_WIDTH)
    total_line_pct = calculate_pct(total_line_covered, total_line_executable)
    total_branch_pct = calculate_pct(total_branch_covered, total_branch_total)
    branch_str = f"{total_branch_pct:>9.2f}%" if any_branch else f"{'N/A':>10}"
    print(
        f"{'全 App 合计':<25} {'':>6} "
        f"{total_line_pct:>9.2f}% {branch_str} "
        f"{total_line_covered:>8} {total_line_executable:>10}"
    )
    print("=" * TABLE_WIDTH + "\n")

    if show_details and all_files:
        print_domain_detail(all_files)

    return total_line_covered, total_line_executable, total_branch_covered, total_branch_total


def print_domain_detail(all_files):
    """打印 Domain 层每文件覆盖率明细"""
    domain_files = filter_domain_files(all_files)
    if not domain_files:
        return
    print("------------------ 领域层 (Domain) 覆盖率明细 ------------------")
    for f in sorted(domain_files, key=lambda x: x.get("lineCoverage", 0)):
        name = os.path.basename(f.get("path", ""))
        covered = f.get("coveredLines", 0)
        executable = f.get("executableLines", 0)
        pct = f.get("lineCoverage", 0.0) * PERCENT_MULTIPLIER
        print(f" ◌ {name:<35} | 覆盖行: {covered:<4} / 可执行行: {executable:<4} | 比例: {pct:.2f}%")
    print("----------------------------------------------------------------\n")


# ── 红线校验 ──────────────────────────────────────────────────
def check_redline(name, line_covered, line_executable,
                  branch_covered, branch_total, has_branch,
                  line_threshold, branch_threshold):
    """
    校验单个单元（整体或模块）的双红线。
    返回 (passed: bool, failures: [str])。
    """
    failures = []

    # 语句覆盖率校验
    if line_executable == 0:
        # 可执行行为 0，免于校验
        pass
    else:
        line_pct = calculate_pct(line_covered, line_executable)
        if line_pct < line_threshold:
            failures.append(
                f"{name} 语句覆盖率 {line_pct:.2f}% < {line_threshold:.2f}%"
            )

    # 分支覆盖率校验
    if has_branch and branch_total > 0:
        branch_pct = calculate_pct(branch_covered, branch_total)
        if branch_pct < branch_threshold:
            failures.append(
                f"{name} 分支覆盖率 {branch_pct:.2f}% < {branch_threshold:.2f}%"
            )
    elif not has_branch:
        # 该模块无分支数据（可能 Xcode 版本未提供），跳过分支校验
        pass

    return len(failures) == 0, failures


def run_redline_checks(layer_stats, total_stats,
                       line_threshold, branch_threshold):
    """
    运行全 App 整体 + 每个模块的双红线校验。
    返回 (all_passed: bool, all_failures: [str])。
    """
    all_failures = []

    # 1. 全 App 整体校验
    total_line_covered, total_line_executable, \
        total_branch_covered, total_branch_total, total_has_branch = total_stats
    passed, failures = check_redline(
        "全 App 整体",
        total_line_covered, total_line_executable,
        total_branch_covered, total_branch_total, total_has_branch,
        line_threshold, branch_threshold,
    )
    if not passed:
        all_failures.extend(failures)

    # 2. 每个模块校验
    for layer in LAYER_ORDER:
        s = layer_stats.get(layer)
        if not s:
            continue
        # 可执行行为 0 的模块跳过（未覆盖该模块）
        if s["line_executable"] == 0:
            continue
        passed, failures = check_redline(
            layer,
            s["line_covered"], s["line_executable"],
            s["branch_covered"], s["branch_total"], s["has_branch"],
            line_threshold, branch_threshold,
        )
        if not passed:
            all_failures.extend(failures)

    return len(all_failures) == 0, all_failures


def print_redline_result(all_passed, all_failures, line_threshold, branch_threshold):
    """打印红线校验最终结果"""
    log_info(
        f"◉ 红线指标 ──► 语句覆盖率 ≥ {line_threshold:.2f}% | "
        f"分支覆盖率 ≥ {branch_threshold:.2f}%"
    )

    if all_passed:
        log_success(
            f"代码覆盖率校验全部通过！全 App 整体及各模块语句/分支覆盖率均达标。"
            f"流水线正常通关。"
        )
        return 0
    else:
        log_error(
            f"代码覆盖率红线校验失败！以下 {len(all_failures)} 项未达标，"
            f"强行熔断拦截并阻断流水线！"
        )
        for i, f in enumerate(all_failures, 1):
            print(f"  {i}. {f}")
        return 1


# ── JSON 报告 ────────────────────────────────────────────────
def _build_coverage_json(covered, total, percent, threshold, has_data):
    """构建单个覆盖率指标的 JSON 结构"""
    return {
        "covered": covered,
        "total": total,
        "percent": percent,
        "threshold": threshold,
        "passed": (percent >= threshold) if has_data else True,
        "available": has_data,
    }


def _build_layer_json(layer, stats, line_threshold, branch_threshold):
    """构建单个层级的 JSON 结构"""
    line_pct = calculate_pct(stats["line_covered"], stats["line_executable"])
    branch_pct = calculate_pct(stats["branch_covered"], stats["branch_total"]) if stats["has_branch"] else None
    return {
        "layer": layer,
        "files": stats["files"],
        "lineCoverage": _build_coverage_json(
            stats["line_covered"], stats["line_executable"],
            line_pct, line_threshold, True,
        ),
        "branchCoverage": _build_coverage_json(
            stats["branch_covered"], stats["branch_total"],
            branch_pct, branch_threshold, stats["has_branch"],
        ),
    }


def print_json_report(layer_stats, total_stats,
                      line_threshold, branch_threshold):
    """JSON 机器可读输出"""
    total_line_covered, total_line_executable, \
        total_branch_covered, total_branch_total, total_has_branch = total_stats

    layers = [
        _build_layer_json(layer, layer_stats[layer], line_threshold, branch_threshold)
        for layer in LAYER_ORDER
        if layer_stats.get(layer)
    ]

    total_line_pct = calculate_pct(total_line_covered, total_line_executable)
    total_branch_pct = calculate_pct(total_branch_covered, total_branch_total) if total_has_branch else None

    report = {
        "total": {
            "lineCoverage": _build_coverage_json(
                total_line_covered, total_line_executable,
                total_line_pct, line_threshold, True,
            ),
            "branchCoverage": _build_coverage_json(
                total_branch_covered, total_branch_total,
                total_branch_pct, branch_threshold, total_has_branch,
            ),
        },
        "layers": layers,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))



# ── 主程序 ────────────────────────────────────────────────────
def _parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description="智宇 (ZhiYu) 全自动代码覆盖率红线校验熔断工具"
    )
    parser.add_argument(
        "--details",
        action="store_true",
        help="展示 Domain 层每文件覆盖率明细",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_LINE_THRESHOLD,
        help=f"语句覆盖率红线（默认 {DEFAULT_LINE_THRESHOLD}%%）",
    )
    parser.add_argument(
        "--branch-threshold",
        type=float,
        default=DEFAULT_BRANCH_THRESHOLD,
        help=f"分支覆盖率红线（默认 {DEFAULT_BRANCH_THRESHOLD}%%）",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="JSON 机器可读输出（不打印表格，不熔断）",
    )
    return parser.parse_args()


def _load_coverage_data():
    """定位并解析最新 xcresult 的覆盖率 JSON 报文"""
    if not os.path.exists(SEARCH_DIR):
        log_error(f"未找到 Xcode 派生数据目录: {SEARCH_DIR}。请先执行自动化跑测。")
        sys.exit(1)

    latest_result = find_latest_xcresult(SEARCH_DIR)
    if not latest_result:
        log_error("在 build/DerivedData 中未搜索到任何有效的 .xcresult 结果包")
        sys.exit(1)

    log_info(f"定位最新测试结果集: {latest_result}")
    raw_json = extract_raw_report_json(latest_result)

    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError:
        log_error("JSON 报文格式损坏，解析失败")
        sys.exit(1)

    all_files = recursive_find_files(data)
    log_info(f"全栈扫描完毕。共捕获到 {len(all_files)} 个源文件节点的覆盖率信息。")
    return all_files


def _aggregate_total_stats(layer_stats):
    """从分层统计聚合全 App 整体统计"""
    total_line_covered = sum(s["line_covered"] for s in layer_stats.values())
    total_line_executable = sum(s["line_executable"] for s in layer_stats.values())
    total_branch_covered = sum(s["branch_covered"] for s in layer_stats.values())
    total_branch_total = sum(s["branch_total"] for s in layer_stats.values())
    total_has_branch = any(s["has_branch"] for s in layer_stats.values())
    return (
        total_line_covered, total_line_executable,
        total_branch_covered, total_branch_total, total_has_branch,
    )


def main():
    """主程序入口：解析参数 → 加载覆盖率 → 聚合统计 → 报告/熔断"""
    args = _parse_args()

    # JSON 模式日志转到 stderr，保证 stdout 为纯净 JSON
    if args.json:
        _set_log_stream(sys.stderr)

    log_info("启动代码覆盖率熔断校验程序...")

    all_files = _load_coverage_data()

    layer_stats = aggregate_by_layer(all_files)
    total_stats = _aggregate_total_stats(layer_stats)
    # total_stats 结构: (line_covered, line_executable, branch_covered, branch_total, has_branch)
    _, _, _, _, total_has_branch = total_stats

    if not total_has_branch:
        log_warn(
            "当前 xcresult 未包含分支覆盖率数据（可能 Xcode 版本未提供），"
            "将仅校验语句覆盖率。建议确认 xcodebuild 已启用分支覆盖率采集。"
        )

    if args.json:
        print_json_report(layer_stats, total_stats,
                          args.threshold, args.branch_threshold)
        sys.exit(0)

    print_layer_report(layer_stats, show_details=args.details, all_files=all_files)

    all_passed, all_failures = run_redline_checks(
        layer_stats, total_stats, args.threshold, args.branch_threshold
    )
    exit_code = print_redline_result(
        all_passed, all_failures, args.threshold, args.branch_threshold
    )
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
