#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  analyze_coverage_gaps.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/31.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/CI] 质量工具
#  核心职责：全工程代码覆盖率与分支缺口系统性分析工具，定位拉低覆盖率的核心文件与代码块。
#

import os
import sys
import glob
import re
import subprocess
from collections import defaultdict

PERCENT_MULTIPLIER = 100
DEFAULT_SEARCH_DIR = "build/DerivedData-ios"
MAX_TOP_DISPLAY_COUNT = 20
DIVIDER_LINE_WIDTH = 100
SAMPLE_LINES_COUNT = 10
INDEX_COLUMN = 1
INDEX_COUNT1 = 2
INDEX_COUNT2 = 3
DEFAULT_BRANCH_PATHS = 2


def find_latest_xcresult(search_dir=DEFAULT_SEARCH_DIR):
    """
    定位 DerivedData 中最新的测试结果包 xcresult。

    :param search_dir: 搜索目录
    :return: 最新的 xcresult 绝对路径或 None
    """
    pattern = os.path.join(search_dir, "**/*.xcresult")
    results = glob.glob(pattern, recursive=True)
    if not results:
        return None
    results.sort(key=os.path.getmtime, reverse=True)
    return results[0]


def _process_branch_line(raw_line, stats):
    """
    处理分支元组行并更新分支统计。

    :param raw_line: 原始文本行
    :param stats: 统计字典
    :return: 是否处理了分支元组
    """
    m_tuple = re.match(r"^\s*\((\d+),\s+(\d+),\s+(\d+)\)\s*$", raw_line)
    if not m_tuple:
        return False
    col = int(m_tuple.group(INDEX_COLUMN))
    c1 = int(m_tuple.group(INDEX_COUNT1))
    c2 = int(m_tuple.group(INDEX_COUNT2))
    stats['branch_total'] += DEFAULT_BRANCH_PATHS
    if c1 > 0:
        stats['branch_covered'] += 1
    if c2 > 0:
        stats['branch_covered'] += 1
    if c1 == 0 or c2 == 0:
        stats['uncovered_branches'].append((col, c1, c2))
    return True


def _process_executable_line(raw_line, stats):
    """
    处理可执行行（覆盖/未覆盖/分支块开始）。

    :param raw_line: 原始文本行
    :param stats: 统计字典
    :return: 是否进入了分支块
    """
    m_bstart = re.match(r"^\s+(\d+):\s+(\d+)\s+\[\s*$", raw_line)
    if m_bstart:
        line_num = int(m_bstart.group(1))
        exec_c = int(m_bstart.group(2))
        stats['executable'] += 1
        if exec_c > 0:
            stats['covered'] += 1
        else:
            stats['uncovered_lines'].append(line_num)
        return True

    m_uncov = re.match(r"^\s+(\d+):\s+0\s*$", raw_line)
    if m_uncov:
        line_num = int(m_uncov.group(1))
        stats['executable'] += 1
        stats['uncovered_lines'].append(line_num)
        return False

    m_cov = re.match(r"^\s+(\d+):\s+([1-9]\d*)\s*$", raw_line)
    if m_cov:
        stats['executable'] += 1
        stats['covered'] += 1
    return False


def _init_file_stat():
    """
    初始化单个源文件的覆盖率数据结构。

    :return: 空统计字典
    """
    return {
        'executable': 0,
        'covered': 0,
        'branch_total': 0,
        'branch_covered': 0,
        'uncovered_lines': [],
        'uncovered_branches': []
    }


def analyze_gaps(xcresult_path):
    """
    从指定 xcresult 提取所有源文件的覆盖率与分支统计。

    :param xcresult_path: 测试结果包路径
    :return: 文件覆盖率统计字典映射
    """
    cmd = ["xcrun", "xccov", "view", "--archive", xcresult_path]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)

    file_stats = {}
    current_file = None
    in_branch = False

    for raw_line in res.stdout.splitlines():
        if raw_line.endswith(":") and not re.match(r"^\s+\d+:", raw_line):
            current_file = raw_line[:-1].strip()
            in_branch = False
            if "Sources/" in current_file:
                file_stats[current_file] = _init_file_stat()
            else:
                current_file = None
            continue

        if not current_file or current_file not in file_stats:
            continue

        stats = file_stats[current_file]
        if in_branch:
            if _process_branch_line(raw_line, stats):
                continue
            if raw_line.strip() == "]":
                in_branch = False
                continue

        in_branch = _process_executable_line(raw_line, stats)

    return file_stats


def _print_tables(module_stats, file_list):
    """
    格式化打印模块与文件缺口榜单。

    :param module_stats: 模块聚合统计
    :param file_list: 文件统计列表
    """
    div = "=" * DIVIDER_LINE_WIDTH
    subdiv = "-" * DIVIDER_LINE_WIDTH
    print(f"\n{div}\n📊 各模块覆盖率汇总与缺口分析\n{div}")
    print(f"{'模块名':<20} {'文件数':<8} {'语句覆盖率':<12} {'未覆盖行数':<12} {'分支覆盖率':<12} {'未覆盖分支数':<12}\n{subdiv}")
    for mod, d in sorted(module_stats.items(), key=lambda x: x[1]['exec'] - x[1]['cov'], reverse=True):
        l_pct = d['cov'] / d['exec'] * PERCENT_MULTIPLIER if d['exec'] > 0 else 0
        b_pct = d['b_cov'] / d['b_tot'] * PERCENT_MULTIPLIER if d['b_tot'] > 0 else 0
        uncov_l = d['exec'] - d['cov']
        uncov_b = d['b_tot'] - d['b_cov']
        print(f"{mod:<20} {d['files']:<8} {l_pct:>6.2f}%      {uncov_l:>8}      {b_pct:>6.2f}%      {uncov_b:>8}")

    print(f"\n{div}\n🔴 未覆盖语句行数 TOP {MAX_TOP_DISPLAY_COUNT} 文件 (拉低语句覆盖率)\n{div}")
    print(f"{'文件路径':<60} {'语句覆盖率':<12} {'未覆盖行数/总行数':<18} {'分支覆盖率':<12}\n{subdiv}")
    for f in sorted(file_list, key=lambda x: x['uncovered_lines'], reverse=True)[:MAX_TOP_DISPLAY_COUNT]:
        print(f"{f['path']:<60} {f['line_cov']:>6.2f}%      {f['uncovered_lines']:>5}/{f['exec']:<5}       {f['branch_cov']:>6.2f}%")


def main():
    """主入口函数：扫描最新测试结果并输出缺口分析。"""
    xcresult = find_latest_xcresult()
    if not xcresult:
        print("❌ 未找到 xcresult 测试结果包")
        sys.exit(1)

    stats = analyze_gaps(xcresult)
    module_stats = defaultdict(lambda: {'exec': 0, 'cov': 0, 'b_tot': 0, 'b_cov': 0, 'files': 0})
    file_list = []

    for path, data in stats.items():
        if data['executable'] == 0:
            continue
        line_cov = data['covered'] / data['executable'] * PERCENT_MULTIPLIER if data['executable'] > 0 else 0
        branch_cov = data['branch_covered'] / data['branch_total'] * PERCENT_MULTIPLIER if data['branch_total'] > 0 else 0
        uncovered_lines_count = data['executable'] - data['covered']
        uncovered_branch_count = data['branch_total'] - data['branch_covered']

        rel_path = path.split("Sources/")[-1]
        top_mod = rel_path.split("/")[0]

        module_stats[top_mod]['exec'] += data['executable']
        module_stats[top_mod]['cov'] += data['covered']
        module_stats[top_mod]['b_tot'] += data['branch_total']
        module_stats[top_mod]['b_cov'] += data['branch_covered']
        module_stats[top_mod]['files'] += 1

        file_list.append({
            'path': rel_path,
            'module': top_mod,
            'exec': data['executable'],
            'cov': data['covered'],
            'uncovered_lines': uncovered_lines_count,
            'line_cov': line_cov,
            'branch_tot': data['branch_total'],
            'branch_cov_count': data['branch_covered'],
            'uncovered_branches': uncovered_branch_count,
            'branch_cov': branch_cov,
        })

    _print_tables(module_stats, file_list)


if __name__ == "__main__":
    main()
