#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-arch-opensource-adapters.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/02.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：审计开源库是否通过适配层（Adapter Layer）封装调用。
#           原则：所有外部开源库只允许在指定适配层中直接 import，业务逻辑层必须通过适配层间接调用。
#           渐进策略：设置 MAX_GRDB_VIOLATIONS 阈值，防止新增违规（已有违规随重构逐步清除）。
#

import os
import re
import sys
from pathlib import Path

# 导入统一门禁报告器
GATEKEEPER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if GATEKEEPER_DIR not in sys.path:
    sys.path.insert(0, GATEKEEPER_DIR)
from gatekeeper_reporter import GatekeeperReporter

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")

# 开源库注册表：每个库的允许引用白名单（只有这些路径可以直接 import）
# Key = import 名称, Value = list of allowed path prefixes (相对于 Sources/)
# GRDB 已 100% 物理隔离至 Packages/UFPStorage SPM 包中（GRDBReexport.swift 唯一重导出），Sources/ 层零残留
MAX_GRDB_VIOLATIONS = 0  # 严格封锁：违规必须为 0，Sources/ 层严禁任何直接 import GRDB

OPEN_SOURCE_REGISTRY = {
    "GRDB": {
        # GRDB 已全量隔离至 UFPStorage SPM 包，Sources/ 层不允许任何直接 import
        "allowed_prefixes": [],
        "adapter_class": "UFPStorage SPM 包内的 GRDBReexport / SQLiteStore",
        "severity": "ERROR",
    },
    "Lottie": {
        "allowed_prefixes": [
            "Shared/UIComponents/Feedback/AppLottieView",  # 唯一适配器
        ],
        "adapter_class": "AppLottieView",
        "severity": "ERROR",
    },
    "ZIPFoundation": {
        "allowed_prefixes": [
            "Platforms/iOS/Services/ZIPFoundationArchiver",  # 唯一适配层
            "Platforms/macOS/MacFileArchiver",              # macOS 系统命令实现，内部无 ZIPFoundation import
        ],
        "adapter_class": "ZIPFoundationArchiver / MacFileArchiver",
        "severity": "ERROR",
    },
    "SwiftJSONSanitizer": {
        "allowed_prefixes": [
            "Infrastructure/Processors/Synthesis/JSONRepairProcessor",
        ],
        "adapter_class": "JSONRepairProcessor",
        "severity": "ERROR",
    },
    "PartialJSON": {
        "allowed_prefixes": [
            "Infrastructure/Processors/Synthesis/JSONRepairProcessor",
        ],
        "adapter_class": "JSONRepairProcessor",
        "severity": "ERROR",
    },
    "MarkdownUI": {
        "allowed_prefixes": [
            "Shared/UIComponents/",
            "Features/",  # MarkdownUI 为 UI 渲染库，Feature View 层可直接使用
        ],
        "adapter_class": "MarkdownRendererView",
        "severity": "WARNING",
    },
}

EXCLUDE_DIRS = {'.git', 'build', 'DerivedData', '.build', 'Frameworks', '__pycache__'}

# ==============================================================================
# MARK: - 审计逻辑
# ==============================================================================

def get_swift_files(directory: str):
    """递归获取所有 Swift 文件（排除测试与脚本目录）"""
    results = []
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for f in files:
            if f.endswith(".swift"):
                results.append(os.path.join(root, f))
    return results


def is_allowed(rel_path: str, allowed_prefixes: list) -> bool:
    """检查文件路径是否符合允许的白名单前缀"""
    normalized = rel_path.replace("\\", "/")
    return any(normalized.startswith(prefix) for prefix in allowed_prefixes)


def check_direct_imports(sources_dir: str) -> list:
    """扫描所有 Swift 文件，检测违规的开源库直接 import"""
    violations = []
    import_pattern = re.compile(r'^(?:@preconcurrency\s+)?import\s+(\w+)', re.MULTILINE)

    swift_files = get_swift_files(sources_dir)
    for filepath in swift_files:
        rel_path = os.path.relpath(filepath, sources_dir)

        try:
            with open(filepath, encoding='utf-8') as f:
                content = f.read()
        except Exception:
            continue

        imported_modules = import_pattern.findall(content)
        for module in imported_modules:
            if module not in OPEN_SOURCE_REGISTRY:
                continue

            spec = OPEN_SOURCE_REGISTRY[module]
            if not is_allowed(rel_path, spec["allowed_prefixes"]):
                violations.append({
                    "file": rel_path,
                    "module": module,
                    "adapter": spec["adapter_class"],
                    "severity": spec["severity"],
                })

    return violations


# ==============================================================================
# MARK: - 报告输出
# ==============================================================================

def report_grdb_baseline(grdb_errors: list[dict]):
    """处理并输出 GRDB 渐进迁移阈值审计报告"""
    count = len(grdb_errors)
    if count > MAX_GRDB_VIOLATIONS:
        print(f"\n❌ [GRDB 渐进阈值] 直接 import GRDB 的文件数 {count} 超过阈值 {MAX_GRDB_VIOLATIONS}！")
        print(f"   新增了 {count - MAX_GRDB_VIOLATIONS} 处违规，构建阻断！")
        sys.exit(1)
    elif count == MAX_GRDB_VIOLATIONS:
        print(f"\n⚠️  [GRDB 渐进阈值] 直接 import GRDB 的文件数：{count}/{MAX_GRDB_VIOLATIONS}（已达基线上限）")
        for v in grdb_errors:
            if any(v["file"].startswith(p) for p in ["App/", "Core/"]):
                print(f"      ⚠️  {v['file']}（优先迁移）")
    else:
        print(f"\n✅ [GRDB 渐进阈值] 直接 import GRDB 的文件数：{count}/{MAX_GRDB_VIOLATIONS}（已减少）")


def process_violations_report(errors: list[dict], warnings: list[dict]):
    """处理并打印非 GRDB 错误与警告报告，使用 Xcode 标准 <file>:<line>: error: 规则格式化输出"""
    if warnings:
        print(f"\n⚠️  [Open-Source Adapter Audit] {len(warnings)} 处警告：")
        for v in warnings:
            line_no = v.get("line", 1)
            print(f"{v['file']}:{line_no}: warning: [Open-Source Adapter Audit] import {v['module']} → 通过 [{v['adapter']}] 间接调用")

    other_errors = [v for v in errors if v["module"] != "GRDB"]
    if other_errors:
        print(f"\n❌ [Open-Source Adapter Audit] 发现 {len(other_errors)} 处违规：\n")
        for v in other_errors:
            line_no = v.get("line", 1)
            print(f"{v['file']}:{line_no}: error: [Open-Source Adapter Audit] 违规 import {v['module']}，必须通过 [{v['adapter']}] 间接调用")
        sys.exit(1)
    return other_errors


def print_audit_result(errors: list[dict], warnings: list[dict], other_errors: list[dict]):
    """处理并输出最终结果"""
    if not errors and not warnings:
        print("\n✅ [Open-Source Adapter Audit] 审计通过：所有开源库均通过适配层封装调用。")
    elif not other_errors:
        print("\n✅ [Open-Source Adapter Audit] 审计通过（GRDB 渐进迁移中，其余库完全合规）。")


def main():
    """主逻辑：扫描 Sources/ 层开源库直接 import 情况并校验适配器封装规则"""
    reporter = GatekeeperReporter("Open-Source Adapter Audit")
    violations = check_direct_imports(SOURCES_DIR)

    for v in violations:
        lvl = v["severity"]
        msg = f"违规 import {v['module']}，必须通过 [{v['adapter']}] 间接调用"
        reporter.add_issue(v["file"], v.get("line", 1), msg, level=lvl)

    reporter.report()


if __name__ == "__main__":
    main()
