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

OVERSIZED_THRESHOLD = 50  # 用例数 > 50 视为超大文件（与 Phase 4 拆分标准一致）
ROUND_PRECISION = 4  # round() 精度
MEDIAN_MIN_CASES = 5  # 中位用例数下限
MEDIAN_MAX_CASES = 20  # 中位用例数上限
RATIO_MIN = 0.5  # 测试源码比下限
RATIO_MAX = 1.5  # 测试源码比上限
BANNER_WIDTH = 60

# SPM 包名集合
SPM_PACKAGE_NAMES = {"UFPCore", "UFPStorage", "UFPDesignSystem", "ZhiYuDomain", "ZhiYuAICore", "ZhiYuFeatures"}

# 功能域枚举（对应 FeatureDomain enum）— 测试子目录名匹配这些名称视为功能域对齐
FEATURE_DOMAINS = {"knowledge", "ai", "insight", "system"}

# 架构层级目录（对应 Sources/ 顶层目录）— 测试子目录名匹配这些名称视为架构层对齐
ARCH_LAYER_DIRS = {"App", "Core", "Domain", "Features", "Infrastructure", "Localization", "Platforms", "Shared"}

# 功能域到 Features 子目录的映射（用于识别 Tests/Unit/Features/<域>/ 结构）
FEATURE_DOMAIN_SUBDIRS = {"Knowledge", "AI", "Insight", "System"}


def count_test_methods(filepath: Path) -> int:
    """统计单个测试文件中的 test 方法数"""
    try:
        content = filepath.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0
    # 匹配 func testXXX( 但不匹配 // func testXXX
    return len(re.findall(r"^\s*func\s+test\w+\s*\(", content, re.MULTILINE))


MOCK_FILE_PATTERNS = {"mock", "helper", "stub", "support", "base", "extension"}

# 按文件名豁免的占位/工具类文件（合理包含 0 用例）
MOCK_FILE_NAME_EXEMPTIONS = {"BaseUITestCase", "KnowledgeBaseUITests", "ZhiYuTests", "RAGEvaluator"}

# 按路径片段豁免的目录（共享测试基础设施）
MOCK_FILE_PATH_EXEMPTIONS = {"Shared", "Support", "Extensions"}


def _is_mock_by_name(filepath: Path) -> bool:
    """通过文件名判断是否为 Mock/Helper/Stub 文件"""
    name_lower = filepath.stem.lower()
    if any(pattern in name_lower for pattern in MOCK_FILE_PATTERNS):
        return True
    if "+" in filepath.stem:
        return True
    return filepath.stem in MOCK_FILE_NAME_EXEMPTIONS


def _is_mock_by_path(filepath: Path) -> bool:
    """通过路径判断是否为共享测试基础设施文件"""
    return any(part in MOCK_FILE_PATH_EXEMPTIONS for part in filepath.parts)


def is_mock_or_helper_file(filepath: Path) -> bool:
    """判断文件是否为 Mock/Helper/Stub/Support/Base/Extension 文件（合理包含 0 用例）"""
    if _is_mock_by_name(filepath):
        return True
    if _is_mock_by_path(filepath):
        return True
    # UI 测试基类
    return filepath.parent.name == "UI" and filepath.stem in MOCK_FILE_NAME_EXEMPTIONS


def scan_test_files(test_dir: Path) -> list[dict]:
    """扫描测试目录下所有 .swift 文件，返回文件路径和用例数

    Mock/Helper/Stub/Support/Base 文件标记为 mock_file，不参与 empty_file_ratio 计算。
    """
    results = []
    for swift_file in test_dir.rglob("*.swift"):
        count = count_test_methods(swift_file)
        is_mock = is_mock_or_helper_file(swift_file)
        rel_path = swift_file.relative_to(test_dir.parent)
        results.append({
            "path": str(rel_path),
            "abs_path": str(swift_file),
            "test_count": count,
            "is_mock_file": is_mock,
        })
    return results


def is_features_subdir_aligned(features_dir: Path) -> bool:
    """检查 Tests/Unit/Features/<域>/ 结构中所有子目录是否匹配功能域"""
    for sub in features_dir.iterdir():
        if sub.is_dir() and sub.name not in FEATURE_DOMAIN_SUBDIRS:
            return False
    return True


def is_subdir_aligned(subdir: str) -> bool:
    """判断单个测试子目录是否对齐（架构层级或功能域）"""
    if subdir in ARCH_LAYER_DIRS:
        return True
    if subdir.lower() in FEATURE_DOMAINS:
        return True
    if subdir == "Features":
        features_dir = TESTS_UNIT_DIR / subdir
        return is_features_subdir_aligned(features_dir)
    return False


def measure_directory_alignment() -> dict:
    """度量 Tests/Unit 子目录的功能域对齐率

    对齐规则（业界实践：按功能域分组，非 1:1 物理路径镜像）：
    1. 架构层级对齐：子目录名匹配 Sources/ 顶层目录（App/Core/Domain/Features/Infrastructure/Localization/Platforms/Shared）
    2. 功能域对齐：子目录名匹配 FeatureDomain 枚举（knowledge/ai/insight/system，大小写不敏感）
    3. Features 子目录对齐：Tests/Unit/Features/<域>/ 结构中 <域> 匹配功能域
    不要求与 Sources 物理路径 1:1 镜像，允许按功能域组织测试。
    """
    test_subdirs = [
        item.name for item in sorted(TESTS_UNIT_DIR.iterdir()) if item.is_dir()
    ]

    aligned = 0
    misaligned = []
    for subdir in test_subdirs:
        if is_subdir_aligned(subdir):
            aligned += 1
        else:
            file_count = len(list((TESTS_UNIT_DIR / subdir).glob("*.swift")))
            misaligned.append({"dir": subdir, "file_count": file_count})

    total = len(test_subdirs)
    rate = aligned / total if total > 0 else 0
    return {
        "metric": "directory_alignment_rate",
        "value": round(rate, ROUND_PRECISION),
        "aligned_dirs": aligned,
        "total_dirs": total,
        "misaligned": misaligned,
        "threshold": THRESHOLDS["directory_alignment_rate"],
        "passed": rate >= THRESHOLDS["directory_alignment_rate"]["min"],
    }


def _compute_median(counts: list[int]) -> float:
    """计算中位数"""
    total = len(counts)
    if total == 0:
        return 0
    if total % 2 == 1:
        return counts[total // 2]
    return (counts[total // 2 - 1] + counts[total // 2]) / 2


def _build_distribution_metric(median: float, oversized: int, empty: int, total: int) -> dict:
    """构建用例分布度量结果"""
    return {
        "median_cases_per_file": {
            "metric": "median_cases_per_file",
            "value": median,
            "threshold": THRESHOLDS["median_cases_per_file"],
            "passed": MEDIAN_MIN_CASES <= median <= MEDIAN_MAX_CASES,
        },
        "oversized_file_ratio": {
            "metric": "oversized_file_ratio",
            "value": round(oversized / total, ROUND_PRECISION) if total > 0 else 0,
            "oversized_count": oversized,
            "total_files": total,
            "threshold": THRESHOLDS["oversized_file_ratio"],
            "passed": (oversized / total if total > 0 else 0) <= THRESHOLDS["oversized_file_ratio"]["max"],
        },
        "empty_file_ratio": {
            "metric": "empty_file_ratio",
            "value": round(empty / total, ROUND_PRECISION) if total > 0 else 0,
            "empty_count": empty,
            "total_files": total,
            "threshold": THRESHOLDS["empty_file_ratio"],
            "passed": empty == 0,
        },
    }


def _empty_distribution() -> dict:
    """返回空分布结果（无测试文件时）"""
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


def measure_cases_distribution(test_files: list[dict]) -> dict:
    """度量每文件用例数分布

    Mock/Helper/Stub/Support/Base 文件不参与 empty_file_ratio 计算（合理包含 0 用例），
    但参与 oversized_file_ratio 和 median 计算。
    """
    all_counts = sorted([f["test_count"] for f in test_files])
    total = len(all_counts)
    if total == 0:
        return _empty_distribution()

    median = _compute_median(all_counts)
    oversized = sum(1 for c in all_counts if c > OVERSIZED_THRESHOLD)
    # 空文件只统计非 Mock 文件
    non_mock_counts = [f for f in test_files if not f.get("is_mock_file", False)]
    non_mock_total = len(non_mock_counts)
    empty = sum(1 for f in non_mock_counts if f["test_count"] == 0)

    return _build_distribution_metric(median, oversized, empty, non_mock_total or total)


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
    main_app_spm_cases = 0
    for swift_file in TESTS_UNIT_DIR.rglob("*.swift"):
        try:
            content = swift_file.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for pkg in SPM_PACKAGE_NAMES:
            if f"@testable import {pkg}" in content:
                main_app_spm_cases += count_test_methods(swift_file)
                break

    total = spm_test_cases + main_app_spm_cases
    ratio = spm_test_cases / total if total > 0 else 0
    return {
        "metric": "spm_test_coverage_ratio",
        "value": round(ratio, ROUND_PRECISION),
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
        "value": round(ratio, ROUND_PRECISION),
        "test_files": test_count,
        "source_files": source_count,
        "threshold": THRESHOLDS["test_source_file_ratio"],
        "passed": RATIO_MIN <= ratio <= RATIO_MAX,
    }


def _collect_all_metrics(test_files: list[dict]) -> dict:
    """收集全部度量指标并展开 cases_distribution"""
    results = {
        "directory_alignment": measure_directory_alignment(),
        "cases_distribution": measure_cases_distribution(test_files),
        "spm_coverage": measure_spm_coverage(),
        "test_source_ratio": measure_test_source_ratio(test_files),
    }
    # 展开 cases_distribution
    for k, v in results["cases_distribution"].items():
        results[k] = v
    del results["cases_distribution"]
    return results


def _check_all_passed(results: dict) -> bool:
    """检查所有指标是否达标"""
    return all(
        results[k].get("passed", True) for k in results
        if isinstance(results[k], dict) and "passed" in results[k]
    )


def _print_text_report(results: dict, verbose: bool, all_passed: bool) -> None:
    """打印文本格式报告"""
    print("=" * BANNER_WIDTH)
    print("测试结构度量报告")
    print("=" * BANNER_WIDTH)
    for key, val in results.items():
        if isinstance(val, dict) and "metric" in val:
            status = "✅" if val.get("passed") else "❌"
            print(f"\n{status} {val['metric']}: {val['value']}")
            if verbose:
                for k2, v2 in val.items():
                    if k2 not in ("metric", "value", "passed", "threshold"):
                        print(f"    {k2}: {v2}")
    print("\n" + "=" * BANNER_WIDTH)
    print(f"总体: {'✅ 全部达标' if all_passed else '❌ 存在不达标项'}")
    print("=" * BANNER_WIDTH)


def main():
    """主入口：解析参数、收集度量指标、输出报告并返回退出码"""
    parser = argparse.ArgumentParser(description="测试结构度量脚本")
    parser.add_argument("--json", action="store_true", help="输出 JSON 格式")
    parser.add_argument("--verbose", action="store_true", help="显示详细信息")
    args = parser.parse_args()

    test_files = scan_test_files(TESTS_UNIT_DIR)
    results = _collect_all_metrics(test_files)
    all_passed = _check_all_passed(results)

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        _print_text_report(results, args.verbose, all_passed)

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
