#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-cross-platform-isolation.py
#  ZhiYu
#
#  Created by Antigravity on 2026/11/25.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：三平台物理隔离、Watch 轻量化依赖及 macOS 弹窗防塌缩 CI 门禁审计。
#

"""三平台隔离与 macOS 桌面布局规范门禁审计脚本。"""

import os
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]
TEMPLATE_PATH = PROJECT_DIR / "Config" / "project.yml.template"
FEATURES_DIR = PROJECT_DIR / "Sources" / "Features"

# WatchAppTemplate 禁止引入的非表端重量级依赖
FORBIDDEN_WATCH_PACKAGES = ("ZhiYuAICore", "ZhiYuFeatures", "ZIPFoundation", "AppAuth")

# 判定 .sheet() 已具备桌面端尺寸保护的关键词
SHEET_SIZE_MARKERS = (
    "appDesktopSheetSize",
    "appAdaptiveSheet",
    "minWidth",
    "desktopSheetMinWidth",
    "applySettingsPresentationSizing",
    "macSettingsWindowWidth",
    "macProfileWindowWidth",
)

# 已知豁免：纯系统分享表或内部自带尺寸的弹窗调用（仅允许减少，禁止新增）
MAX_LEGACY_UNSIZED_SHEETS = 2
# 检测 .sheet() 尺寸修饰符时的向下扫描行数窗口
SHEET_LOOKAHEAD_LINES = 20


def extract_yaml_section(content: str, section_header: str) -> str:
    """提取 project.yml.template 中指定缩进模板区块的文本内容。"""
    pattern = rf"^  {re.escape(section_header)}:\n(.*?)(?=^  \S|\Z)"
    match = re.search(pattern, content, flags=re.MULTILINE | re.DOTALL)
    return match.group(1) if match else ""


def check_target_physical_isolation(content: str) -> list[str]:
    """校验 iOS / macOS Target 之间的平台目录物理排除规则。"""
    errors: list[str] = []
    ios_block = extract_yaml_section(content, "IOSApplicationTemplate")
    mac_block = extract_yaml_section(content, "MacApplicationTemplate")

    for required in ("Platforms/macOS/**", "Platforms/watchOS/**"):
        if required not in ios_block:
            errors.append(f"IOSApplicationTemplate 缺少排除规则: {required}")

    for required in ("Platforms/iOS/**", "Platforms/watchOS/**"):
        if required not in mac_block:
            errors.append(f"MacApplicationTemplate 缺少排除规则: {required}")

    return errors


def check_watch_lightweight_dependencies(content: str) -> list[str]:
    """校验 WatchAppTemplate 不得引入重量级非表端依赖。"""
    errors: list[str] = []
    watch_block = extract_yaml_section(content, "WatchAppTemplate")
    for pkg in FORBIDDEN_WATCH_PACKAGES:
        if re.search(rf"package:\s*{re.escape(pkg)}\b", watch_block):
            errors.append(f"WatchAppTemplate 禁止引入非表端依赖: {pkg}")
    return errors


def check_macos_sheet_sizing() -> list[str]:
    """扫描 Features 层 .sheet() 调用，阻断未配桌面尺寸的新增弹窗。"""
    unsized: list[str] = []
    for swift_file in sorted(FEATURES_DIR.rglob("*.swift")):
        lines = swift_file.read_text(encoding="utf-8", errors="ignore").splitlines()
        rel = swift_file.relative_to(PROJECT_DIR)
        for idx, line in enumerate(lines, start=1):
            stripped = line.lstrip()
            if stripped.startswith("//") or not re.search(r"\.sheet\s*\(", line):
                continue
            window = "\n".join(lines[idx - 1 : min(len(lines), idx + SHEET_LOOKAHEAD_LINES)])
            if not any(marker in window for marker in SHEET_SIZE_MARKERS):
                unsized.append(f"{rel}:{idx}")

    if len(unsized) <= MAX_LEGACY_UNSIZED_SHEETS:
        return []
    return [
        f"发现 {len(unsized)} 处未声明 macOS 桌面尺寸的 .sheet()（上限 {MAX_LEGACY_UNSIZED_SHEETS}）："
        + ", ".join(unsized)
    ]


def check_infrastructure_zero_platform_macros() -> list[str]:
    """确保 Sources/Infrastructure/ 保持 0 处 #if os() 平台宏（平台差异应走 canImport 或 Platforms/）。"""
    infra_root = PROJECT_DIR / "Sources" / "Infrastructure"
    if not infra_root.is_dir():
        return []
    hits: list[str] = []
    macro_pattern = re.compile(r"#if\s+os\(")
    for swift_file in sorted(infra_root.rglob("*.swift")):
        rel = swift_file.relative_to(PROJECT_DIR)
        for idx, line in enumerate(swift_file.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1):
            code_part = line.split("//", 1)[0]
            if macro_pattern.search(code_part):
                hits.append(f"{rel}:{idx}")
    if not hits:
        return []
    return [f"Sources/Infrastructure/ 禁止出现 #if os()（共 {len(hits)} 处）：" + ", ".join(hits)]


def check_no_misplaced_platform_files() -> list[str]:
    """确保 Sources/Core 与 Sources/App/Environment 不再出现平台专属实现文件（应归位 Sources/Platforms/）。"""
    errors: list[str] = []
    guarded_dirs = [
        PROJECT_DIR / "Sources" / "Core",
        PROJECT_DIR / "Sources" / "App" / "Environment",
    ]
    platform_file_re = re.compile(r"^(?:iOS|Mac|Watch).+\.swift$")
    allowed_names = {"WatchSyncProtocol.swift"}
    for root in guarded_dirs:
        if not root.is_dir():
            continue
        for swift_file in sorted(root.rglob("*.swift")):
            if swift_file.name in allowed_names:
                continue
            if platform_file_re.match(swift_file.name):
                rel = swift_file.relative_to(PROJECT_DIR)
                errors.append(f"平台专属文件错位（请归位至 Sources/Platforms/）: {rel}")
    return errors


def main() -> int:
    """主入口：执行三平台隔离与桌面弹窗门禁审计。"""
    os.chdir(PROJECT_DIR)
    if not TEMPLATE_PATH.is_file():
        print(f"❌ 缺少项目模板文件: {TEMPLATE_PATH}")
        return 1

    template_text = TEMPLATE_PATH.read_text(encoding="utf-8")
    errors = []
    errors.extend(check_target_physical_isolation(template_text))
    errors.extend(check_watch_lightweight_dependencies(template_text))
    errors.extend(check_macos_sheet_sizing())
    errors.extend(check_infrastructure_zero_platform_macros())
    errors.extend(check_no_misplaced_platform_files())

    if errors:
        print("❌ [Cross-Platform Isolation Audit] 发现以下跨平台隔离/弹窗规范违规：")
        for err in errors:
            print(f"   • {err}")
        return 1

    print("✅ [Cross-Platform Isolation Audit] 三平台物理隔离、Watch 轻量化依赖与 macOS 弹窗尺寸规范全部通过。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
