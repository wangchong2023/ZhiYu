#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-arch-opensource-placement.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/02.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：物理归位审计——验证开源库适配器必须在对应的 SPM Package 物理目录中，
#           而非停留在 App Target 的 Sources/ 逻辑目录（逻辑隔离 ≠ 物理隔离）。
#           物理归位后，编译器才能真正阻断跨层越权调用。
#
#  审计规则：
#    1. 适配器文件必须存在于指定的 SPM 包路径内
#    2. 适配器文件不得同时存在于 Sources/ App Target 目录内（旧文件残留检测）
#    3. 对应 SPM 包的 Package.swift 必须声明了开源库依赖（依赖完整性校验）
#

import os
import re
import sys

GATEKEEPER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if GATEKEEPER_DIR not in sys.path:
    sys.path.insert(0, GATEKEEPER_DIR)
from gatekeeper_reporter import GatekeeperReporter

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")
PACKAGES_DIR = os.path.join(PROJECT_DIR, "Packages")

# ==============================================================================
# MARK: - 物理归位规则注册表
#
# 每条规则描述一个适配器的期望物理位置：
#   adapter_file    : 适配器文件名
#   expected_package: 期望所在的 SPM 包目录名（在 Packages/ 下）
#   expected_subpath: 在 SPM 包内的相对路径
#   forbidden_paths : 不允许存在该文件的路径前缀（相对 Sources/）
#   package_must_declare: Package.swift 中必须声明的依赖包名（字符串匹配）
#   severity        : ERROR=必须通过，WARNING=已知例外提醒
# ==============================================================================

PHYSICAL_PLACEMENT_RULES = [
    {
        "adapter_file": "JSONRepairProcessor.swift",
        "expected_package": "ZhiYuAICore",
        "expected_subpath": "Sources/ZhiYuAICore/Adapters/JSONRepairProcessor.swift",
        "forbidden_paths": ["Infrastructure/Processors/Synthesis/JSONRepairProcessor.swift"],
        "package_must_declare": ["SwiftJSONSanitizer", "PartialJSON"],
        "description": "JSON 双层自愈适配器 → 必须在 ZhiYuAICore SPM 包",
        "severity": "ERROR",
    },
    {
        "adapter_file": "AppLottieView.swift",
        "expected_package": "UFPDesignSystem",
        "expected_subpath": "Sources/UFPDesignSystem/Adapters/AppLottieView.swift",
        "forbidden_paths": ["Shared/UIComponents/Feedback/AppLottieView.swift"],
        "package_must_declare": ["Lottie"],
        "description": "Lottie 动画封装适配器 → 必须在 UFPDesignSystem SPM 包",
        "severity": "ERROR",
    },
    {
        "adapter_file": "MarkdownRendererView.swift",
        "expected_package": "UFPDesignSystem",
        "expected_subpath": "Sources/UFPDesignSystem/Adapters/MarkdownRendererView.swift",
        "forbidden_paths": ["Shared/UIComponents/", "Features/"],
        "package_must_declare": ["swift-markdown-ui"],
        "description": "Markdown 渲染封装适配器 → 必须在 UFPDesignSystem SPM 包",
        "severity": "ERROR",
    },
    {
        "adapter_file": "iOSFileArchiver.swift",
        "expected_package": None,  # 平台适配器允许在 App Target 的 Platforms/ 目录
        "expected_subpath": None,
        "forbidden_paths": ["Features/", "Domain/", "Core/Base/"],
        "package_must_declare": [],
        "description": "ZIP 文件压缩平台适配器 → 允许在 Platforms/iOS/Services/（平台层例外）",
        "severity": "WARNING",
    },
]


# ==============================================================================
# MARK: - 审计逻辑
# ==============================================================================

def check_file_in_package(package_name: str, subpath: str) -> bool:
    """检查文件是否存在于 SPM 包的正确物理位置"""
    full_path = os.path.join(PACKAGES_DIR, package_name, subpath)
    return os.path.isfile(full_path)


def check_file_not_in_sources(forbidden_paths: list) -> list:
    """检查文件是否仍残留在被禁止的 Sources/ 路径（旧文件检测）"""
    violations = []
    for forbidden in forbidden_paths:
        full_path = os.path.join(SOURCES_DIR, forbidden)
        if os.path.isfile(full_path):
            violations.append(full_path)
    return violations


def check_package_declares_deps(package_name: str, required_deps: list) -> list:
    """验证 Package.swift 是否声明了必要的开源依赖"""
    if not required_deps:
        return []
    pkg_swift = os.path.join(PACKAGES_DIR, package_name, "Package.swift")
    if not os.path.isfile(pkg_swift):
        return required_deps  # Package.swift 不存在，全部缺失
    with open(pkg_swift, encoding="utf-8") as f:
        content = f.read()
    return [dep for dep in required_deps if dep not in content]


# ==============================================================================
# MARK: - 报告输出
# ==============================================================================

def audit_rule(rule: dict) -> tuple[list[str], str, str, str]:
    """处理单个物理归位规则的主审计逻辑"""
    issues = []
    adapter = rule["adapter_file"]
    pkg = rule["expected_package"]
    subpath = rule["expected_subpath"]
    severity = rule["severity"]
    desc = rule["description"]

    if pkg and subpath and not check_file_in_package(pkg, subpath):
        issues.append(f"❌ 未找到物理归位文件：Packages/{pkg}/{subpath}")

    residues = check_file_not_in_sources(rule["forbidden_paths"])
    for r in residues:
        rel = os.path.relpath(r, PROJECT_DIR)
        issues.append(f"⚠️  旧文件残留：{rel}")

    if pkg and rule["package_must_declare"]:
        missing_deps = check_package_declares_deps(pkg, rule["package_must_declare"])
        for dep in missing_deps:
            issues.append(f"❌ Package.swift 缺少依赖声明：Packages/{pkg}/Package.swift 未声明 {dep}")

    return issues, adapter, desc, severity


def main():
    """扫描并审计开源适配层文件在 SPM 包中的物理分布与残留检查"""
    errors = []
    warnings = []

    print("\n🔍 [Physical Adapter Placement Audit] 开始物理归位审计...\n")

    for rule in PHYSICAL_PLACEMENT_RULES:
        issues, adapter, desc, severity = audit_rule(rule)
        if issues:
            print(f"{'❌' if severity == 'ERROR' else '⚠️ '} {adapter}  ({desc})")
            for issue in issues:
                print(f"   {issue}")
            if severity == "ERROR":
                errors.extend(issues)
            else:
                warnings.extend(issues)
        else:
            print(f"✅ {adapter}  →  物理归位已完成，SPM 依赖声明完整")

    if not errors and not warnings:
        print("\n✅ [Physical Placement Audit] 所有开源库适配层 100% 物理归位包物理隔离。")
    elif not errors:
        print(f"\n⚠️  [Physical Placement Audit] 发现 {len(warnings)} 项残留（警告不阻断构建）。")
    else:
        print(f"\n❌ [Physical Placement Audit] 发现 {len(errors)} 项严重错误，阻断构建！")
        sys.exit(1)


if __name__ == "__main__":
    main()
