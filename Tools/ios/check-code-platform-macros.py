#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-code-platform-macros.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/22.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：检查 Features 与 Domain 层（含 SPM 本地包）禁止使用 #if os() / macCatalyst 平台宏，
#           禁止 Domain 层使用 #if canImport(UIKit/AppKit/WatchKit/WidgetKit/ActivityKit)，
#           并对 Features 层存量 #if canImport(UIKit/AppKit/WatchKit) 实施只减不增文件级基线卡控。
#

from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# 禁止使用 #if os() / macCatalyst 的业务与领域目录（含 SPM 本地包）
OS_FORBIDDEN_DIRS = [
    PROJECT_ROOT / "Sources" / "Features",
    PROJECT_ROOT / "Sources" / "Domain",
    PROJECT_ROOT / "Packages" / "ZhiYuDomain" / "Sources",
    PROJECT_ROOT / "Packages" / "ZhiYuFeatures" / "Sources",
]

# 禁止使用 UI/平台框架 #if canImport(...) 的纯领域目录
DOMAIN_CANIMPORT_FORBIDDEN_DIRS = [
    PROJECT_ROOT / "Sources" / "Domain",
    PROJECT_ROOT / "Packages" / "ZhiYuDomain" / "Sources",
]

# Features 层监控 #if canImport(UIKit/AppKit/WatchKit) 扩张的目录
FEATURES_CANIMPORT_DIRS = [
    PROJECT_ROOT / "Sources" / "Features",
    PROJECT_ROOT / "Packages" / "ZhiYuFeatures" / "Sources",
]

# Features 层存量允许使用 #if canImport(UIKit/AppKit/WatchKit) 的冻结基线（只减不增）
FEATURES_CANIMPORT_BASELINE = {
    "Sources/Features/Knowledge/Graph/View/Components/Graph3DComponents.swift",
    "Sources/Features/Knowledge/Ingest/Coordinator/IngestFileHandler.swift",
    "Sources/Features/Knowledge/Ingest/View/Components/ImportRecordSection.swift",
    "Sources/Features/System/Auth/Strategy/AppAuthGoogleProvider.swift",
    "Sources/Features/System/Auth/Strategy/AppleAuthStrategy.swift",
    "Sources/Features/System/Auth/Strategy/CarrierAuthStrategy.swift",
    "Sources/Features/System/Auth/Strategy/WeChatAuthStrategy.swift",
    "Sources/Features/System/ModelManager/Utility/MobileActionExecutor.swift",
}

# 统一平台宏正则（去注释后匹配，拦截正向/反向/括号/复合条件中的 os() 与 macCatalyst）
OS_MACRO_PATTERN = re.compile(
    r"^\s*#(if|elseif)\b.*(\bos\s*\(|\btargetEnvironment\s*\(\s*macCatalyst\s*\))"
)

# 平台 UI 框架 canImport 正则
UI_CANIMPORT_PATTERN = re.compile(
    r"^\s*#(if|elseif)\b.*\bcanImport\s*\(\s*(UIKit|AppKit|WatchKit|WidgetKit|ActivityKit)\s*\)"
)


def strip_line_comment(line: str) -> str:
    """去除 Swift 单行注释，避免文档/说明注释触发误报。"""
    return line.split("//", 1)[0]


def scan_pattern_in_dirs(
    dirs: list[Path],
    pattern: re.Pattern[str],
    root: Path = PROJECT_ROOT,
) -> list[tuple[str, list[tuple[int, str]]]]:
    """扫描目录列表中命中正则的 Swift 文件与行号。"""
    results: list[tuple[str, list[tuple[int, str]]]] = []
    for check_dir in dirs:
        if not check_dir.exists():
            continue
        for swift_file in sorted(check_dir.rglob("*.swift")):
            hits = _scan_file(swift_file, pattern)
            if hits:
                rel = swift_file.relative_to(root).as_posix()
                results.append((rel, hits))
    return results


def _scan_file(swift_file: Path, pattern: re.Pattern[str]) -> list[tuple[int, str]]:
    """扫描单个 Swift 文件，返回命中的 (行号, 原行文本) 列表。"""
    hits: list[tuple[int, str]] = []
    try:
        content = swift_file.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return hits
    for idx, line in enumerate(content.splitlines(), 1):
        if pattern.search(strip_line_comment(line)):
            hits.append((idx, line.strip()))
    return hits


def _report_os_violations(violations: list[tuple[str, list[tuple[int, str]]]]) -> None:
    """输出 #if os() / macCatalyst 违规详情。"""
    total = sum(len(lines) for _, lines in violations)
    print(f"❌ FAIL: 发现 {total} 处禁止的 #if os() / macCatalyst 平台宏（{len(violations)} 个文件）")
    print("  正确做法：使用 L0 协议 + PlatformRegistrar DI，或运行时 Trait (@Environment(\\.interfaceIdiom))。")
    for rel, lines in violations:
        print(f"  {rel}:")
        for line_no, text in lines:
            print(f"    L{line_no}: {text}")


def _report_canimport_violations(
    domain_hits: list[tuple[str, list[tuple[int, str]]]],
    new_feature_hits: list[tuple[str, list[tuple[int, str]]]],
) -> None:
    """输出 Domain 层禁止或 Features 层新增的 UI canImport 违规详情。"""
    if domain_hits:
        print(f"❌ FAIL: Domain 层禁止使用平台 UI 框架 #if canImport(...)（{len(domain_hits)} 个文件）")
        for rel, lines in domain_hits:
            for line_no, text in lines:
                print(f"  {rel}:{line_no}: {text}")
    if new_feature_hits:
        print(
            f"❌ FAIL: Features 层新增了不在冻结基线内的 #if canImport(UIKit/AppKit/WatchKit)（{len(new_feature_hits)} 个文件）"
        )
        print("  请将平台差异收敛到 CrossPlatform / PlatformModifiers 或 L0 协议。")
        for rel, lines in new_feature_hits:
            for line_no, text in lines:
                print(f"  {rel}:{line_no}: {text}")


def main() -> int:
    """执行 Features/Domain 层（含 SPM 包）平台宏与 canImport 守卫检查。"""
    os_violations = scan_pattern_in_dirs(OS_FORBIDDEN_DIRS, OS_MACRO_PATTERN)
    domain_canimport = scan_pattern_in_dirs(DOMAIN_CANIMPORT_FORBIDDEN_DIRS, UI_CANIMPORT_PATTERN)
    feature_canimport = scan_pattern_in_dirs(FEATURES_CANIMPORT_DIRS, UI_CANIMPORT_PATTERN)
    new_feature_canimport = [
        item for item in feature_canimport if item[0] not in FEATURES_CANIMPORT_BASELINE
    ]

    failed = False
    if os_violations:
        _report_os_violations(os_violations)
        failed = True
    if domain_canimport or new_feature_canimport:
        _report_canimport_violations(domain_canimport, new_feature_canimport)
        failed = True

    if failed:
        return 1

    print(
        f"✅ PASS: Features/Domain 层（含 SPM 包）无 #if os() 平台宏，"
        f"Domain 无 UI canImport，Features canImport 存量受控（{len(feature_canimport)}/{len(FEATURES_CANIMPORT_BASELINE)} 文件）"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
