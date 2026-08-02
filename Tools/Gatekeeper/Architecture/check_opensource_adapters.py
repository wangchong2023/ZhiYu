#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_opensource_adapters.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/02.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/Gatekeeper] 守卫网关
#  核心职责：审计开源库是否通过适配层（Adapter Layer）封装调用。
#           原则：所有外部开源库只允许在指定适配层中直接 import，业务逻辑层必须通过适配层间接调用。
#           渐进策略：设置 MAX_GRDB_VIOLATIONS 阈值，防止新增违规（已有违规随重构逐步清除）。
#

import os
import re
import sys
from pathlib import Path

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")

# 开源库注册表：每个库的允许引用白名单（只有这些路径可以直接 import）
# Key = import 名称, Value = list of allowed path prefixes (相对于 Sources/)
# 渐进阈值：GRDB 当前还在 Sources/ 内过渡（待迁移至 UFPStorage SPM）
# 對违规文件数设定上限，防止新增违规（随重构进度逐步收紧）
MAX_GRDB_VIOLATIONS = 33  # 当前基线: 33 个文件，每清除一批后降低此值

OPEN_SOURCE_REGISTRY = {
    "GRDB": {
        # 仅允许在存储适配层内使用，严禁在 App/、Features/、Core/Base/、Domain/ 层直接 import
        # 长期目标：将所有 GRDB 使用迁移至 UFPStorage SPM 包，清空此白名单
        "allowed_prefixes": [
            "Infrastructure/Storage/",           # 过渡期允许（待迁移 UFPStorage SPM）
            "Infrastructure/Models/",             # 过渡期允许（GRDB Row 映射模型）
            "Platforms/iOS/Widgets/",             # Widget 平台例外，独立扩展必须直接访问 DB
        ],
        "adapter_class": "UFPStorage SPM 包内的 SQLiteStore / Repository 适配层",
        "severity": "ERROR",  # 严格封锁：违规必须处理，配合 MAX_GRDB_VIOLATIONS 阈值渐进清理
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

def main():
    violations = check_direct_imports(SOURCES_DIR)

    errors = [v for v in violations if v["severity"] == "ERROR"]
    warnings = [v for v in violations if v["severity"] == "WARNING"]

    if warnings:
        print(f"\n⚠️  [Open-Source Adapter Audit] {len(warnings)} 处警告：")
        for v in warnings:
            print(f"   {v['file']}: import {v['module']}")
            print(f"      → 建议通过适配层 [{v['adapter']}] 间接调用")

    # GRDB 渐进阈值控制：允许当前存量，阻断新增
    grdb_errors = [v for v in errors if v["module"] == "GRDB"]
    other_errors = [v for v in errors if v["module"] != "GRDB"]

    if other_errors:
        print(f"\n❌ [Open-Source Adapter Audit] 发现 {len(other_errors)} 处违规：\n")
        for v in other_errors:
            print(f"   {v['file']}")
            print(f"      import {v['module']}")
            print(f"      ❌ 违规：此文件不在允许的白名单中")
            print(f"      🔧 修复：通过适配层 [{v['adapter']}] 间接调用")
            print()
        sys.exit(1)

    if grdb_errors:
        count = len(grdb_errors)
        if count > MAX_GRDB_VIOLATIONS:
            print(f"\n❌ [GRDB 渐进阈值] 直接 import GRDB 的文件数 {count} 超过阈值 {MAX_GRDB_VIOLATIONS}！")
            print(f"   新增了 {count - MAX_GRDB_VIOLATIONS} 处违规，构建阻断！")
            print(f"   请将新代码通过 UFPStorage SPM 包的适配层调用，不得在 App/、Features/、Core/ 层直接 import GRDB")
            sys.exit(1)
        elif count == MAX_GRDB_VIOLATIONS:
            print(f"\n⚠️  [GRDB 渐进阈值] 直接 import GRDB 的文件数：{count}/{MAX_GRDB_VIOLATIONS}（已达基线上限）")
            print(f"   请在每次清理迁移后降低 MAX_GRDB_VIOLATIONS 的值")
            print(f"   文件清单：App/、Core/ 层违规应优先迁移")
            for v in grdb_errors:
                if any(v["file"].startswith(p) for p in ["App/", "Core/"]):
                    print(f"      ⚠️  {v['file']}（优先迁移）")
        else:
            print(f"\n✅ [GRDB 渐进阈值] 直接 import GRDB 的文件数：{count}/{MAX_GRDB_VIOLATIONS}（已减少）")
            print(f"   🎉 请将 MAX_GRDB_VIOLATIONS 从 {MAX_GRDB_VIOLATIONS} 降低至 {count}")

    if not errors and not warnings:
        print(f"\n✅ [Open-Source Adapter Audit] 审计通过：所有开源库均通过适配层封装调用。")
    elif not other_errors:
        print(f"\n✅ [Open-Source Adapter Audit] 审计通过（GRDB 渐进迁移中，其余库完全合规）。")


if __name__ == "__main__":
    main()
