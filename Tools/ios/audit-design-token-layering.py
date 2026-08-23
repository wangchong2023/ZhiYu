#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对 3 层设计令牌架构 (Reference→System→Component) 进行 CI 门禁检查。
# 验证内容：
# 1. 验证 Reference/System/Component 3 个文件的存在性与核心定义
# 2. 检查依赖方向：Component→System→Reference，严禁反向
# 3. 扫描视图代码，禁止直接引用 Reference 层（必须通过 System/Component）
# 4. 检查旧架构残留（Tier1/Tier2/Tier3/DesignTokenRegistry/PlatformContext）
#

import os
import re
import sys

# 引入统一报告管理器
SYS_GATEKEEPER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.append(SYS_GATEKEEPER_DIR)
from gatekeeper_reporter import GatekeeperReporter

PROJECT_ROOT = os.path.abspath(os.path.join(SYS_GATEKEEPER_DIR, '..'))
SOURCES_DIR = os.path.join(PROJECT_ROOT, 'Sources')
TOKENS_DIR = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/Tokens')

REFERENCE_FILE = os.path.join(TOKENS_DIR, 'Reference.swift')
SYSTEM_FILE = os.path.join(TOKENS_DIR, 'System.swift')
COMPONENT_FILE = os.path.join(TOKENS_DIR, 'Component.swift')

# 旧架构文件（应已删除）
LEGACY_FILES = [
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignSystem+Layering.swift'),
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/PlatformContext.swift'),
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignTokenRegistry.swift'),
]

reporter = GatekeeperReporter("Design Token 3-Tier Layering Check")


def check_layering_structure():
    """检查 3 层架构文件的存在性与核心定义"""
    files_to_check = [
        (REFERENCE_FILE, 'Reference'),
        (SYSTEM_FILE, 'System'),
        (COMPONENT_FILE, 'Component'),
    ]
    for fpath, enum_name in files_to_check:
        if not os.path.exists(fpath):
            reporter.add_issue(
                filepath=os.path.relpath(fpath, PROJECT_ROOT),
                line_no=1,
                message=f"缺失 3 层架构定义文件: {os.path.basename(fpath)}",
                level="ERROR"
            )
            continue
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        # 检查 enum 定义存在
        if enum_name == 'Reference':
            if not re.search(r'\benum\s+Reference\b', content):
                reporter.add_issue(
                    filepath=os.path.relpath(fpath, PROJECT_ROOT),
                    line_no=1,
                    message="Reference.swift 缺失 enum Reference 定义",
                    level="ERROR"
                )
        else:
            # System/Component 是多个 enum（SystemSpacing/SystemOpacity 等）
            if enum_name == 'System':
                required = ['SystemSpacing', 'SystemOpacity', 'SystemRadius', 'SystemStroke', 'SystemFontSize']
            else:
                required = ['ComponentSpacing']
            for req in required:
                if not re.search(r'\benum\s+{}\b'.format(req), content):
                    reporter.add_issue(
                        filepath=os.path.relpath(fpath, PROJECT_ROOT),
                        line_no=1,
                        message=f"{os.path.basename(fpath)} 缺失 enum {req} 定义",
                        level="ERROR"
                    )


def check_dependency_direction():
    """检查依赖方向：Component→System→Reference，严禁反向"""
    # Reference.swift：禁止引用 System/Component
    if os.path.exists(REFERENCE_FILE):
        with open(REFERENCE_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if re.search(r'\bSystem(?:Spacing|Opacity|Radius|Stroke|FontSize)\b', content):
            reporter.add_issue(
                filepath=os.path.relpath(REFERENCE_FILE, PROJECT_ROOT),
                line_no=1,
                message="Reference 层禁止引用 System 层（违反依赖方向）",
                level="ERROR"
            )
        if re.search(r'\bComponentSpacing\b', content):
            reporter.add_issue(
                filepath=os.path.relpath(REFERENCE_FILE, PROJECT_ROOT),
                line_no=1,
                message="Reference 层禁止引用 Component 层（违反依赖方向）",
                level="ERROR"
            )

    # System.swift：禁止引用 Component
    if os.path.exists(SYSTEM_FILE):
        with open(SYSTEM_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if re.search(r'\bComponentSpacing\b', content):
            reporter.add_issue(
                filepath=os.path.relpath(SYSTEM_FILE, PROJECT_ROOT),
                line_no=1,
                message="System 层禁止引用 Component 层（违反依赖方向）",
                level="ERROR"
            )
        # System 必须引用 Reference
        if 'Reference.' not in content:
            reporter.add_issue(
                filepath=os.path.relpath(SYSTEM_FILE, PROJECT_ROOT),
                line_no=1,
                message="System 层必须引用 Reference 层（依赖方向检查）",
                level="WARNING"
            )

    # Component.swift：必须引用 System
    if os.path.exists(COMPONENT_FILE):
        with open(COMPONENT_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if 'SystemSpacing.' not in content:
            reporter.add_issue(
                filepath=os.path.relpath(COMPONENT_FILE, PROJECT_ROOT),
                line_no=1,
                message="Component 层应引用 System 层（依赖方向检查）",
                level="WARNING"
            )


def check_legacy_residue():
    """检查旧架构残留"""
    _check_legacy_files_exist()
    _check_legacy_symbol_references()


def _check_legacy_files_exist():
    """检查旧架构文件应已删除"""
    for legacy_file in LEGACY_FILES:
        if os.path.exists(legacy_file):
            reporter.add_issue(
                filepath=os.path.relpath(legacy_file, PROJECT_ROOT),
                line_no=1,
                message=f"旧架构文件应已删除: {os.path.basename(legacy_file)}",
                level="ERROR"
            )


def _check_legacy_symbol_references():
    """扫描所有 Sources 文件，禁止引用旧架构符号"""
    legacy_patterns = [
        r'\bDesignSystem\.Tier[123]\b',
        r'\bDesignTokenRegistry\.shared\b',
        r'\bPlatformContext\.current\b',
        r'\bSemanticSpacingToken\b',
        r'\bSemanticRadiusToken\b',
    ]
    combined = '|'.join(legacy_patterns)
    for root, dirs, files in os.walk(SOURCES_DIR):
        dirs[:] = [d for d in dirs if d not in {'.git', 'build', 'DerivedData', '.build'}]
        for fname in files:
            if not fname.endswith('.swift'):
                continue
            fpath = os.path.join(root, fname)
            if any(fpath == lf for lf in LEGACY_FILES):
                continue
            _scan_file_for_legacy_symbols(fpath, combined)


def _scan_file_for_legacy_symbols(fpath, combined_pattern):
    """扫描单个文件的旧架构符号引用"""
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        for i, line in enumerate(f, 1):
            if re.search(combined_pattern, line):
                reporter.add_issue(
                    filepath=os.path.relpath(fpath, PROJECT_ROOT),
                    line_no=i,
                    message="检测到旧架构符号引用，应迁移到新 3 层架构",
                    level="ERROR",
                    content=line.strip()
                )


def scan_view_token_bypasses():
    """扫描视图代码，禁止直接引用 Reference 层"""
    views_dirs = [
        os.path.join(SOURCES_DIR, 'Features'),
        os.path.join(SOURCES_DIR, 'Shared/UIComponents'),
        os.path.join(SOURCES_DIR, 'Platforms'),
    ]
    exempt_files = {'Reference.swift', 'System.swift', 'Component.swift', 'Colors.swift', 'Typography.swift', 'DesignSystem.swift'}

    for v_dir in views_dirs:
        if not os.path.exists(v_dir):
            continue
        _scan_dir_for_reference_bypasses(v_dir, exempt_files)


def _scan_dir_for_reference_bypasses(v_dir, exempt_files):
    """扫描单个目录的 Reference 层越级引用"""
    for root, dirs, files in os.walk(v_dir):
        dirs[:] = [d for d in dirs if d not in {'.git', 'build', 'DerivedData', '.build'}]
        for fname in files:
            if not fname.endswith('.swift') or fname in exempt_files:
                continue
            fpath = os.path.join(root, fname)
            _scan_file_for_reference_bypass(fpath)


def _scan_file_for_reference_bypass(fpath):
    """扫描单个文件的 Reference 层越级引用"""
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        for i, line in enumerate(f, 1):
            if re.search(r'\bReference\.(Spacing|Opacity|Radius|Stroke|FontSize)\.', line):
                reporter.add_issue(
                    filepath=os.path.relpath(fpath, PROJECT_ROOT),
                    line_no=i,
                    message="视图代码禁止直接引用 Reference 层，应使用 System/Component 层",
                    level="WARNING",
                    content=line.strip()
                )


def main():
    check_layering_structure()
    check_dependency_direction()
    check_legacy_residue()
    scan_view_token_bypasses()
    reporter.report()


if __name__ == '__main__':
    main()
