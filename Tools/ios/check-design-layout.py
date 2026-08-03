#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-design-layout.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/16.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：跨平台（iPhone/iPad/Mac Catalyst）SwiftUI 布局质量静态审计引擎。
#           包括触控热区检测、平台适配尺寸检查、Dynamic Type 无障碍标注、
#           魔鬼数字拦截及 iPad/Mac 大屏专项布局验证。
#

import os
import re
import sys

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

# 排除扫描的路径
EXCLUDE_DIRS = ['Tests', '.git', 'env', 'build', 'Frameworks', 'Resources',
                'Localization', 'DesignSystem']

# Apple HIG 最小触控热区高度（pt）
MIN_TOUCH_TARGET_HEIGHT = 44

# iPad/Mac 弹窗菜单建议最小宽度（pt）
MIN_POPOVER_WIDTH_IPAD = 280
MIN_POPOVER_WIDTH_MAC = 320

# 上下文分析窗口大小（前后各扫描的行数）
CONTEXT_WINDOW_LINES = 3

# 工具栏区域在 app 窗口中的预估垂直偏移
TOOLBAR_VERTICAL_OFFSET = 60

# 终端输出分隔线宽度
SEPARATOR_WIDTH = 60

# 交互性 UI 组件关键字（用于区分装饰性元素和触控目标）
INTERACTIVE_KEYWORDS = [
    'Button(', 'NavigationLink', 'onTapGesture', '.contextMenu',
    'Toggle(', 'Picker(', '.menu {', 'contextMenu {',
    'List(', 'Form(', 'Section(',
]

# 纯装饰性元素关键字（豁免触控热区检查）
DECORATIVE_KEYWORDS = [
    'Chip', 'Badge', 'Tag', 'Circle()', 'Rectangle()',
    'Capsule()', '.fill', '.stroke', 'Divider', 'Spacer',
    'RoundedRectangle',
]


# ==============================================================================
# MARK: - 文本分析工具
# ==============================================================================

class LayoutUtil:
    """布局审计所需的启发式检测分析能力。"""

    @staticmethod
    def is_view_file(file_path):
        """判断文件是否为 SwiftUI 视图或表现层文件。"""
        path_lower = file_path.lower()
        return ('/view/' in path_lower or '/views/' in path_lower
                or file_path.endswith('View.swift')
                or file_path.endswith('Components.swift')
                or file_path.endswith('Components.swift'))

    @staticmethod
    def is_interactive_context(line, surrounding_lines):
        """判断当前行及其上下文是否属于交互性 UI 组件。"""
        # 检查当前行
        for kw in INTERACTIVE_KEYWORDS:
            if kw in line:
                return True
        # 检查上下文（前后 3 行）
        context = ' '.join(surrounding_lines)
        for kw in INTERACTIVE_KEYWORDS:
            if kw in context:
                return True
        return False

    @staticmethod
    def is_decorative_context(line):
        """判断当前行是否属于纯装饰性元素。"""
        for kw in DECORATIVE_KEYWORDS:
            if kw in line:
                return True
        return False

    @staticmethod
    def has_platform_condition(file_content):
        """检测文件是否包含平台条件编译。"""
        has_mac = '#if targetEnvironment(macCatalyst)' in file_content
        has_ios = 'os(iOS)' in file_content or 'UIDevice.current.userInterfaceIdiom' in file_content
        return has_mac, has_ios

    @staticmethod
    def uses_popover_or_sheet(file_content):
        """检测文件是否包含 popover 或 sheet 展示。"""
        return ('.popover(' in file_content or '.sheet(' in file_content
                or 'presentationCompactAdaptation' in file_content)


# ==============================================================================
# MARK: - 触控热区审计器 (TouchTargetAuditor)
# ==============================================================================

class TouchTargetAuditor:
    """检测可能低于 HIG 44pt 标准的触控热区。"""

    # 匹配 .frame(height: XX) 模式，XX < 44
    FRAME_HEIGHT_PATTERN = re.compile(
        r'\.frame\s*\([^)]*height\s*:\s*(\d+(?:\.\d+)?)\s*[,)]'
    )

    def __init__(self, min_height=MIN_TOUCH_TARGET_HEIGHT):
        self.min_height = min_height

    def audit_file(self, file_path):
        """
        审计单个文件中的触控热区大小。

        :return: 异常列表 [(line_no, message, severity)]
        """
        issues = []
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            line_no = i + 1

            # 跳过注释行
            stripped = line.strip()
            if stripped.startswith('//') or stripped.startswith('/*'):
                continue

            # 跳过已标注豁免的行
            if '// Decorative' in line or '// HIG Exempt' in line:
                continue

            # 检测 frame height
            for match in self.FRAME_HEIGHT_PATTERN.finditer(line):
                height = float(match.group(1))
                if height < self.min_height:
                    # 获取上下文（前后 CONTEXT_WINDOW_LINES 行）
                    start = max(0, i - CONTEXT_WINDOW_LINES)
                    end = min(len(lines), i + CONTEXT_WINDOW_LINES + 1)
                    surrounding = [lines[j] for j in range(start, end) if j != i]

                    # 只在交互性上下文中报告
                    if LayoutUtil.is_interactive_context(line, surrounding):
                        if not LayoutUtil.is_decorative_context(line):
                            issues.append((
                                line_no,
                                f"Touch target height {height:.0f}pt < {self.min_height}pt HIG minimum. "
                                f"Add '// Decorative' if this is a non-interactive element.",
                                "WARNING"
                            ))

        return issues


# ==============================================================================
# MARK: - 平台适配尺寸审计器 (PlatformSizeAuditor)
# ==============================================================================

class PlatformSizeAuditor:
    """检测 iPad/Mac 大屏上偏小的固定尺寸弹窗和菜单。"""

    # 匹配 .frame(width: XX) 硬编码数字
    FRAME_WIDTH_PATTERN = re.compile(
        r'\.frame\s*\([^)]*width\s*:\s*(\d+(?:\.\d+)?)\s*[,)]'
    )

    # 匹配 menuWidth / popoverWidth 等常量赋值
    CONSTANT_WIDTH_PATTERN = re.compile(
        r'(?:menuWidth|popoverWidth|sheetWidth|contentWidth)\s*[=:]\s*(\d+(?:\.\d+)?)'
    )

    def __init__(self):
        self.min_ipad = MIN_POPOVER_WIDTH_IPAD
        self.min_mac = MIN_POPOVER_WIDTH_MAC

    def _check_constant_width(self, width_val, line_no, has_mac, has_ios, content):
        """检查硬编码的固定宽度常量是否在 iPad/Mac 上适配。"""
        issues = []
        if has_mac and width_val < self.min_mac:
            issues.append((
                line_no,
                f"Popover/menu width {width_val:.0f}pt may be too narrow on Mac Catalyst "
                f"(suggest ≥ {self.min_mac}pt).",
                "WARNING"
            ))
        elif has_ios and width_val < self.min_ipad:
            if 'UIDevice.current.userInterfaceIdiom' not in content:
                issues.append((
                    line_no,
                    f"Popover/menu width {width_val:.0f}pt may be too narrow on iPad "
                    f"(suggest ≥ {self.min_ipad}pt for iPad, or add iPad conditional).",
                    "ERROR"
                ))
        return issues

    def _check_frame_width(self, line, line_no, has_mac):
        """检查硬编码 frame width 是否偏小。"""
        issues = []
        for match in self.FRAME_WIDTH_PATTERN.finditer(line):
            width_val = float(match.group(1))
            if width_val < self.min_ipad and 'DesignSystem' not in line:
                if any(kw in line for kw in ['iconSize', 'IconSize', 'badge', 'dot', 'border']):
                    continue
                if has_mac and width_val < self.min_mac:
                    issues.append((
                        line_no,
                        f"Fixed width {width_val:.0f}pt in popover/sheet file — "
                        f"consider DesignSystem token with platform adaptation.",
                        "ERROR"
                    ))
        return issues

    def audit_file(self, file_path):
        """审计弹窗/菜单宽度是否在 iPad/Mac 上偏小。"""
        issues = []
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        lines = content.split('\n')

        if not LayoutUtil.uses_popover_or_sheet(content):
            return issues

        has_mac, has_ios = LayoutUtil.has_platform_condition(content)

        for i, line in enumerate(lines):
            line_no = i + 1
            if line.strip().startswith('//'):
                continue

            for match in self.CONSTANT_WIDTH_PATTERN.finditer(line):
                issues.extend(self._check_constant_width(
                    float(match.group(1)), line_no, has_mac, has_ios, content))

            issues.extend(self._check_frame_width(line, line_no, has_mac))

        return issues


# ==============================================================================
# MARK: - 紧凑间距审计器 (CompactSpacingAuditor)
# ==============================================================================

class CompactSpacingAuditor:
    """检测可能导致触控困难的过小垂直间距（≤2pt）。"""

    COMPACT_PADDING_PATTERN = re.compile(
        r'\.padding\s*\(\s*\.vertical\s*,\s*([0-2])\s*\)'
    )

    # 合理使用小间距的场景
    LEGITIMATE_COMPACT_CONTEXTS = [
        'Chip', 'Badge', 'Tag', 'Capsule', '.caption', '.caption2',
        'font(.system(size:', 'foregroundStyle', '.clipShape',
        'RoundedRectangle', 'Circle()', '.overlay', '.background(',
    ]

    def audit_file(self, file_path):
        """
        审计过小垂直间距。

        :return: 异常列表 [(line_no, message, severity)]
        """
        issues = []
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            line_no = i + 1

            if line.strip().startswith('//'):
                continue

            for match in self.COMPACT_PADDING_PATTERN.finditer(line):
                padding_val = int(match.group(1))

                # 检查是否为装饰性元素（Chip/Badge 等）
                is_decorative = any(ctx in line for ctx in self.LEGITIMATE_COMPACT_CONTEXTS)
                if is_decorative:
                    continue

                # 检查上下文是否包含交互性组件
                start = max(0, i - CONTEXT_WINDOW_LINES)
                end = min(len(lines), i + CONTEXT_WINDOW_LINES + 1)
                surrounding = [lines[j] for j in range(start, end) if j != i]
                if LayoutUtil.is_interactive_context(line, surrounding):
                    issues.append((
                        line_no,
                        f"Vertical padding {padding_val}pt in interactive row context — "
                        f"may reduce touch target below 44pt HIG minimum. "
                        f"Chip/Badge elements are exempt.",
                        "WARNING"
                    ))

        return issues


# ==============================================================================
# MARK: - Dynamic Type 无障碍审计器 (DynamicTypeAuditor)
# ==============================================================================

class DynamicTypeAuditor:
    """检测可能影响 Dynamic Type 无障碍适配的硬编码字号。"""

    HARDCODED_FONT_PATTERN = re.compile(
        r'\.font\s*\(\s*\.system\s*\(\s*size\s*:\s*(\d+(?:\.\d+)?)'
    )

    # 合理使用硬编码字号的场景
    LEGITIMATE_FONT_CONTEXTS = [
        '// Dynamic Type',
        'IconSize', 'iconSize', 'badge',
    ]

    def audit_file(self, file_path):
        """
        审计硬编码字号。

        :return: 异常列表 [(line_no, message, severity)]
        """
        issues = []
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            line_no = i + 1

            if line.strip().startswith('//'):
                continue

            for match in self.HARDCODED_FONT_PATTERN.finditer(line):
                size = float(match.group(1))

                # 已标注 Dynamic Type 豁免
                if '// Dynamic Type' in line:
                    continue

                # 合理的装饰性字号
                if any(ctx in line for ctx in self.LEGITIMATE_FONT_CONTEXTS):
                    continue

                issues.append((
                    line_no,
                    f"Hardcoded font size {size:.0f}pt without '// Dynamic Type' annotation — "
                    f"may break Dynamic Type accessibility. Add '// Dynamic Type' if size is intentional.",
                    "ERROR"
                ))

        return issues


# ==============================================================================
# MARK: - 报告输出与执行入口 (main)
# ==============================================================================

def format_issues(file_path, issues, output_lines):
    """格式化单个文件的审计结果。"""
    if not issues:
        return False

    output_lines.append(f"\n📂 {file_path}")
    has_critical = False
    for line_no, msg, severity in issues:
        icon = "🚨" if severity in ("ERROR", "CRITICAL") else "⚠️" if severity == "WARNING" else "ℹ️"
        if severity in ("ERROR", "CRITICAL"):
            has_critical = True
        output_lines.append(f"  L{line_no}: {icon} [{severity}] {msg}")
    return has_critical


def _audit_view_file(file_path, touch_auditor, platform_auditor, spacing_auditor):
    """对视图文件执行触控热区、平台适配、紧凑间距审计。"""
    issues = []
    issues.extend(touch_auditor.audit_file(file_path))
    issues.extend(platform_auditor.audit_file(file_path))
    issues.extend(spacing_auditor.audit_file(file_path))
    return issues


def _audit_single_file(file_path, auditors):
    """对单个 Swift 文件执行完整审计，返回发现的问题列表。"""
    touch_auditor, platform_auditor, spacing_auditor, font_auditor = auditors

    if 'ViewFactory' in os.path.basename(file_path) or 'ViewProvider' in os.path.basename(file_path):
        return []

    issues = []
    if LayoutUtil.is_view_file(file_path):
        issues.extend(_audit_view_file(file_path, touch_auditor, platform_auditor, spacing_auditor))
    issues.extend(font_auditor.audit_file(file_path))
    return issues


def audit_all():
    """执行全量布局审计。"""
    touch_auditor = TouchTargetAuditor()
    platform_auditor = PlatformSizeAuditor()
    spacing_auditor = CompactSpacingAuditor()
    font_auditor = DynamicTypeAuditor()
    auditors = (touch_auditor, platform_auditor, spacing_auditor, font_auditor)

    all_issues = {}
    total_issues = 0

    for root, dirs, files in os.walk('Sources'):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith('.')]
        for f in files:
            if not f.endswith('.swift'):
                continue
            file_path = os.path.join(root, f)
            issues = _audit_single_file(file_path, auditors)
            if issues:
                all_issues[file_path] = issues
                total_issues += len(issues)

    return all_issues, total_issues


def main():
    """布局守卫网关的执行总入口。"""

    print("\n🔍 [Layout Audit] Scanning SwiftUI layout anti-patterns...")
    print(f"   Touch target: ≥ {MIN_TOUCH_TARGET_HEIGHT}pt (HIG)")
    print(f"   Popover width: ≥ {MIN_POPOVER_WIDTH_IPAD}pt (iPad) / ≥ {MIN_POPOVER_WIDTH_MAC}pt (Mac)")
    print()

    all_issues, total_issues = audit_all()

    if not all_issues:
        print("✅ [Layout Audit] All layout checks passed.")
        sys.exit(0)

    output_lines = []
    has_critical = False

    for file_path, issues in sorted(all_issues.items()):
        critical = format_issues(file_path, issues, output_lines)
        if critical:
            has_critical = True

    for line in output_lines:
        print(line)

    print(f"\n{'─' * SEPARATOR_WIDTH}")
    print(f"📊 [Layout Audit] Summary: {total_issues} issue(s) in {len(all_issues)} file(s)")

    if has_critical:
        print("\n🚨 [Layout Audit] CRITICAL layout violations detected. Build blocked.")
        sys.exit(1)

    print("\n⚠️ [Layout Audit] Warnings found. Review recommended before merge.")
    sys.exit(0)


if __name__ == '__main__':
    main()
