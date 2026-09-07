#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-test-structure.py
#  ZhiYu
#
#  Created by Antigravity on 2026/09/07.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/CI] 测试结构度量守卫网关
#  核心职责：量化测试目录与源码目录的对齐度、文件大小分布、SPM 覆盖率等 6 项结构度量指标，CI 门禁自动化拦截结构退化。
#

"""
测试结构度量脚本
量化测试目录与源码目录的对齐度、文件大小分布、SPM 覆盖率等 6 项结构度量指标。
支持 --json 机器可读输出，退出码 0（通过）或 1（不达标）。
"""

import os
import re
import sys
import json
import argparse
from pathlib import Path
from collections import defaultdict

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
TESTS_UNIT_DIR = PROJECT_ROOT / "Tests" / "Unit"
SOURCES_DIR = PROJECT_ROOT / "Sources"
PACKAGES_DIR = PROJECT_ROOT / "Packages"

# 度量阈值
THRESHOLDS = {
    "directory_alignment_rate": {"min": 0.95, "direction": "ge"},
    "median_cases_per_file": {"min": 5, "max": 20, "direction": "range"},
    "oversized_file_ratio": {"max": 0.05, "direction": "le"},
    "empty_file_ratio": {"max": 0.0, "direction": "le"},
    "spm_test_coverage_ratio": {"min": 0.80, "direction": "ge"},
    "test_source_file_ratio": {"min": 0.5, "max": 1.5, "direction": "range"},
}

OVERSIZED_THRESHOLD = 30  # 用例数 > 30 视为超大文件

BANNER_WIDTH = 60


def count_test_methods(filepath: Path) -> int:
    """统计单个测试文件中的 test 方法数"""
    try:
        content = filepath.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0
    # 匹配 func testXXX( 但不匹配 // func testXXX
    return len(re.findall(r"^\s*func\s+test\w+\s*\(", content, re.MULTILINE))


def scan_test_files(test_dir: Path) -> list[dict]:
    """扫描测试目录下所有 .swift 文件，返回文件路径和用例数"""
    results = []
    for swift_file in test_dir.rglob("*.swift"):
        count = count_test_methods(swift_file)
        rel_path = swift_file.relative_to(test_dir.parent)
        results.append({
            "path": str(rel_path),
            "abs_path": str(swift_file),
            "test_count": count,
        })
    return results


def measure_directory_alignment() -> dict:
    """度量 Tests/Unit 子目录与 Sources/ 目录的对齐率"""
    test_subdirs = []
    for item in sorted(TESTS_UNIT_DIR.iterdir()):
        if item.is_dir():
            test_subdirs.append(item.name)

    aligned = 0
    misaligned = []
    for subdir in test_subdirs:
        source_counterpart = SOURCES_DIR / subdir
        if source_counterpart.exists() and source_counterpart.is_dir():
            aligned += 1
        else:
            file_count = len(list((TESTS_UNIT_DIR / subdir).glob("*.swift")))
            misaligned.append({"dir": subdir, "file_count": file_count})

    total = len(test_subdirs)
    rate = aligned / total if total > 0 else 0
    return {
        "metric": "directory_alignment_rate",
        "value": round(rate, 4),
        "aligned_dirs": aligned,
        "total_dirs": total,
        "misaligned": misaligned,
        "threshold": THRESHOLDS["directory_alignment_rate"],
        "passed": rate >= THRESHOLDS["directory_alignment_rate"]["min"],
    }


def measure_cases_distribution(test_files: list[dict]) -> dict:
    """度量每文件用例数分布"""
    counts = sorted([f["test_count"] for f in test_files])
    total = len(counts)
    if total == 0:
        return {
            "median_cases_per_file": {
                "metric": "median_cases_per_file",
                "value": 0,
                "threshold": THRESHOLDS["median_cases_per_file"],
                "passed": False,
            },
            "oversized_file_ratio": {
                "metric": "oversized_file_ratio",
                "value": 0,
                "oversized_count": 0,
                "total_files": 0,
                "threshold": THRESHOLDS["oversized_file_ratio"],
                "passed": True,
            },
            "empty_file_ratio": {
                "metric": "empty_file_ratio",
                "value": 0,
                "empty_count": 0,
                "total_files": 0,
                "threshold": THRESHOLDS["empty_file_ratio"],
                "passed": True,
            },
        }

    median = counts[total // 2] if total % 2 == 1 else (counts[total // 2 - 1] + counts[total // 2]) / 2
    oversized = sum(1 for c in counts if c > OVERSIZED_THRESHOLD)
    empty = sum(1 for c in counts if c == 0)

    return {
        "median_cases_per_file": {
            "metric": "median_cases_per_file",
            "value": median,
            "threshold": THRESHOLDS["median_cases_per_file"],
            "passed": 5 <= median <= 20,
        },
        "oversized_file_ratio": {
            "metric": "oversized_file_ratio",
            "value": round(oversized / total, 4),
            "oversized_count": oversized,
            "total_files": total,
            "threshold": THRESHOLDS["oversized_file_ratio"],
            "passed": oversized / total <= THRESHOLDS["oversized_file_ratio"]["max"],
        },
        "empty_file_ratio": {
            "metric": "empty_file_ratio",
            "value": round(empty / total, 4),
            "empty_count": empty,
            "total_files": total,
            "threshold": THRESHOLDS["empty_file_ratio"],
            "passed": empty == 0,
        },
    }


def measure_spm_coverage() -> dict:
    """度量 SPM 包测试覆盖率"""
    spm_test_cases = 0
    for pkg_dir in PACKAGES_DIR.iterdir():
        if not pkg_dir.is_dir():
            continue
        tests_dir = pkg_dir / "Tests"
        if tests_dir.exists():
            for swift_file in tests_dir.rglob("*.swift"):
                spm_test_cases += count_test_methods(swift_file)

    # 统计主 App 中测试 SPM 代码的文件（通过 @testable import SPM 包名判断）
    spm_imports = {"UFPCore", "UFPStorage", "UFPDesignSystem", "ZhiYuDomain", "ZhiYuAICore", "ZhiYuFeatures"}
    main_app_spm_cases = 0
    for swift_file in TESTS_UNIT_DIR.rglob("*.swift"):
        try:
            content = swift_file.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for pkg in spm_imports:
            if f"@testable import {pkg}" in content:
                main_app_spm_cases += count_test_methods(swift_file)
                break

    total = spm_test_cases + main_app_spm_cases
    ratio = spm_test_cases / total if total > 0 else 0
    return {
        "metric": "spm_test_coverage_ratio",
        "value": round(ratio, 4),
        "spm_test_cases": spm_test_cases,
        "main_app_spm_cases": main_app_spm_cases,
        "threshold": THRESHOLDS["spm_test_coverage_ratio"],
        "passed": ratio >= THRESHOLDS["spm_test_coverage_ratio"]["min"],
    }


def measure_test_source_ratio(test_files: list[dict]) -> dict:
    """度量测试文件与源码文件比"""
    source_count = sum(1 for _ in SOURCES_DIR.rglob("*.swift"))
    test_count = len(test_files)
    ratio = test_count / source_count if source_count > 0 else 0
    return {
        "metric": "test_source_file_ratio",
        "value": round(ratio, 4),
        "test_files": test_count,
        "source_files": source_count,
        "threshold": THRESHOLDS["test_source_file_ratio"],
        "passed": 0.5 <= ratio <= 1.5,
    }


def main():
    parser = argparse.ArgumentParser(description="测试结构度量脚本")
    parser.add_argument("--json", action="store_true", help="输出 JSON 格式")
    parser.add_argument("--verbose", action="store_true", help="显示详细信息")
    args = parser.parse_args()

    test_files = scan_test_files(TESTS_UNIT_DIR)

    results = {
        "directory_alignment": measure_directory_alignment(),
        "cases_distribution": measure_cases_distribution(test_files),
        "spm_coverage": measure_spm_coverage(),
        "test_source_ratio": measure_test_source_ratio(test_files),
    }

    all_passed = all(
        results[k].get("passed", True) for k in results
        if isinstance(results[k], dict) and "passed" in results[k]
    )
    # 展开 cases_distribution
    for k, v in results["cases_distribution"].items():
        results[k] = v
    del results["cases_distribution"]

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print("=" * BANNER_WIDTH)
        print("测试结构度量报告")
        print("=" * BANNER_WIDTH)
        for key, val in results.items():
            if isinstance(val, dict) and "metric" in val:
                status = "✅" if val.get("passed") else "❌"
                print(f"\n{status} {val['metric']}: {val['value']}")
                if args.verbose:
                    for k2, v2 in val.items():
                        if k2 not in ("metric", "value", "passed", "threshold"):
                            print(f"    {k2}: {v2}")
        print("\n" + "=" * BANNER_WIDTH)
        print(f"总体: {'✅ 全部达标' if all_passed else '❌ 存在不达标项'}")
        print("=" * BANNER_WIDTH)

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
