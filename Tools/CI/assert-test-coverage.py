#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 作者: Wang Chong
# 功能说明: 智宇 (ZhiYu) 全自动代码覆盖率红线校验熔断工具
#          自动提取 .xcresult，通过 xccov 抽取高维 JSON 报文，
#          计算核心领域层 (Sources/Domain) 的汇总覆盖率，强加 85% 的红线限制。
# 版本: 1.0
# 日期: 2026-05-18

import os
import sys
import glob
import json
import subprocess

def log_info(msg):
    print(f"\033[36m[INFO] {msg}\033[0m")

def log_success(msg):
    print(f"\033[32m[SUCCESS] ✓ {msg}\033[0m")

def log_error(msg):
    print(f"\033[31m[ERROR] ✗ {msg}\033[0m")

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

PERCENT_MULTIPLIER = 100
DEFAULT_COVERAGE_THRESHOLD = 85.0
SEARCH_DIR = "build/DerivedData-ios"
EXCLUDE_SUFFIXES = ["Schema.swift", "Status.swift"]

def _extract_raw_report_json(latest_result: str) -> str:
    """
    使用 xccov 工具提取最新的单元测试覆盖率 JSON 报文。
    """
    try:
        cmd = ["xcrun", "xccov", "view", "--report", "--json", latest_result]
        log_info(f"执行底层覆盖率转储: {' '.join(cmd)}")
        process = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return process.stdout
    except subprocess.CalledProcessError as e:
        log_error(f"xccov 调用失败。错误详情:\n{e.stderr}")
        sys.exit(1)

def _filter_domain_files(all_files: list) -> list:
    """
    从所有文件覆盖率节点中，精准过滤并提取核心 Domain 层的 Swift 文件。
    """
    domain_files = []
    for f in all_files:
        path = f.get("path", "")
        if "Sources/Domain" in path or "Sources/Domain" in path.replace("\\", "/"):
            filename = os.path.basename(path)
            if any(filename.endswith(suffix) for suffix in EXCLUDE_SUFFIXES):
                continue
            domain_files.append(f)
    return domain_files

def _calculate_metrics(domain_files: list) -> tuple[int, int]:
    """
    计算 Domain 层的覆盖行数与总可执行行数。
    """
    total_covered = 0
    total_executable = 0
    print("\n------------------ 领域层 (Domain) 覆盖率明细 ------------------")
    for f in sorted(domain_files, key=lambda x: x.get("lineCoverage", 0)):
        name = os.path.basename(f.get("path", ""))
        covered = f.get("coveredLines", 0)
        executable = f.get("executableLines", 0)
        pct = f.get("lineCoverage", 0.0) * PERCENT_MULTIPLIER
        print(f" ◌ {name:<35} | 覆盖行: {covered:<4} / 可执行行: {executable:<4} | 比例: {pct:.2f}%")
        total_covered += covered
        total_executable += executable
    print("----------------------------------------------------------------\n")
    return total_covered, total_executable

def _print_detail_and_check(total_covered: int, total_executable: int):
    """
    计算比例并验证是否通过覆盖率红线门禁。
    """
    if total_executable == 0:
        log_success("领域层可执行代码行为 0，免于拦截校验。")
        sys.exit(0)
        
    domain_pct = (total_covered / total_executable) * PERCENT_MULTIPLIER
    log_info(f"◉ 最终统计 ──► 领域层 (Domain) 汇总覆盖率: {domain_pct:.2f}% (红线指标: {DEFAULT_COVERAGE_THRESHOLD:.2f}%)")
    
    if domain_pct < DEFAULT_COVERAGE_THRESHOLD:
        log_error(f"代码覆盖率低于红线要求 ({domain_pct:.2f}% < {DEFAULT_COVERAGE_THRESHOLD:.2f}%)！强行熔断拦截并阻断流水线！")
        sys.exit(1)
    else:
        log_success(f"代码覆盖率校验通过 ({domain_pct:.2f}% >= {DEFAULT_COVERAGE_THRESHOLD:.2f}%)！流水线正常通关。")
        sys.exit(0)

def main():
    """
    主程序，分析 Xcode 测试覆盖率结果并根据红线指标做出熔断阻断。
    """
    log_info("启动代码覆盖率熔断校验程序...")
    
    if not os.path.exists(SEARCH_DIR):
        log_error(f"未找到 Xcode 派生数据目录: {SEARCH_DIR}。请先执行自动化跑测。")
        sys.exit(1)
        
    latest_result = find_latest_xcresult(SEARCH_DIR)
    if not latest_result:
        log_error("在 build/DerivedData 中未搜索到任何有效的 .xcresult 结果包")
        sys.exit(1)
        
    log_info(f"定位最新测试结果集: {latest_result}")
    raw_json = _extract_raw_report_json(latest_result)
    
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError:
        log_error("JSON 报文格式损坏，解析失败")
        sys.exit(1)
        
    all_files = recursive_find_files(data)
    log_info(f"全栈扫描完毕。共捕获到 {len(all_files)} 个源文件节点的覆盖率信息。")
    
    domain_files = _filter_domain_files(all_files)
    if not domain_files:
        log_success("未在工程中检索到属于 Domain (领域层) 的源文件节点或当前测试 target 未覆盖该模块，默认通关。")
        sys.exit(0)
        
    total_covered, total_executable = _calculate_metrics(domain_files)
    _print_detail_and_check(total_covered, total_executable)

if __name__ == "__main__":
    main()
