#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对 3 级设计令牌 (3-Tier Layering Tokens) 架构进行 CI 门禁检查。
# 验证内容：
# 1. 验证 Tier 1 (Global Reference)、Tier 2 (Semantic Alias)、Tier 3 (Component Contextual) 架构的完整性。
# 2. 检查 Tier 2 语义 Token 是否严格继承/引用 Tier 1 参考 Token，禁止直接硬编码数值。
# 3. 验证 PlatformContext 与 DesignTokenRegistry 跨平台动态解耦注册器的有效性。
# 4. 扫描 Views/Components 目录，防止越级绕过 Token 注册表硬编码设备分支。
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
LAYERING_FILE = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignSystem+Layering.swift')
PLATFORM_CONTEXT_FILE = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/PlatformContext.swift')
REGISTRY_FILE = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignTokenRegistry.swift')

reporter = GatekeeperReporter("Design Token 3-Tier Layering Check")

def check_layering_structure():
    """检查 3-Tier Layering Token 架构文件的存在性与核心定义"""
    if not os.path.exists(LAYERING_FILE):
        reporter.add_issue(
            filepath=os.path.relpath(LAYERING_FILE, PROJECT_ROOT),
            line_no=1,
            message="缺失 3 级设计令牌架构定义文件 DesignSystem+Layering.swift",
            level="ERROR"
        )
        return

    with open(LAYERING_FILE, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    # 检查 Tier 1, Tier 2, Tier 3 必须同时存在
    for tier_name in ["Tier1", "Tier2", "Tier3"]:
        if not re.search(fr'\benum\s+{tier_name}\b', content):
            reporter.add_issue(
                filepath=os.path.relpath(LAYERING_FILE, PROJECT_ROOT),
                line_no=1,
                message=f"3 级设计令牌架构缺失核心层级定义: {tier_name}",
                level="ERROR"
            )

    # 验证 Tier 2 是否正确继承 Tier 1 (检查是否有 Tier1. 引用)
    if "Tier1." not in content:
        reporter.add_issue(
            filepath=os.path.relpath(LAYERING_FILE, PROJECT_ROOT),
            line_no=1,
            message="Tier 2/3 Token 未正确引用 Tier 1 全局参考 Token，违反 3-Tier 分层规范",
            level="WARNING"
        )

def check_platform_decoupling():
    """检查平台上下文 (PlatformContext) 与 Dynamic Registry 解耦体系"""
    if not os.path.exists(PLATFORM_CONTEXT_FILE):
        reporter.add_issue(
            filepath=os.path.relpath(PLATFORM_CONTEXT_FILE, PROJECT_ROOT),
            line_no=1,
            message="缺失平台上下文动态感知定义文件 PlatformContext.swift",
            level="ERROR"
        )
    else:
        with open(PLATFORM_CONTEXT_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            p_content = f.read()
        if "PlatformDeviceFamily" not in p_content or "PlatformContext" not in p_content:
            reporter.add_issue(
                filepath=os.path.relpath(PLATFORM_CONTEXT_FILE, PROJECT_ROOT),
                line_no=1,
                message="PlatformContext 未包含完整的平台设备家族 (PlatformDeviceFamily) 解耦定义",
                level="ERROR"
            )

    if not os.path.exists(REGISTRY_FILE):
        reporter.add_issue(
            filepath=os.path.relpath(REGISTRY_FILE, PROJECT_ROOT),
            line_no=1,
            message="缺失统一设计令牌解耦注册表 DesignTokenRegistry.swift",
            level="ERROR"
        )
    else:
        with open(REGISTRY_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            r_content = f.read()
        if "DesignTokenRegistry" not in r_content or "resolveSpacing" not in r_content:
            reporter.add_issue(
                filepath=os.path.relpath(REGISTRY_FILE, PROJECT_ROOT),
                line_no=1,
                message="DesignTokenRegistry 缺失动态 Token 解析能力 (resolveSpacing)",
                level="ERROR"
            )

def _scan_single_view_file(fpath):
    """扫描单个 Swift 视图文件"""
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    for i, line in enumerate(lines, 1):
        if ('#if os(' in line or 'UIDevice.current' in line) and any(k in line for k in ['padding', 'frame', 'cornerRadius']):
            reporter.add_issue(
                filepath=os.path.relpath(fpath, PROJECT_ROOT),
                line_no=i,
                message="检测到视图组件中通过硬编码平台分支处理布局参数，建议重构使用 DesignTokenRegistry 动态解耦",
                level="WARNING",
                content=line.strip()
            )

def scan_token_bypasses():
    """扫描 UI 视图组件，防止直接写硬编码 `#if os()` 绕过平台解耦注册表"""
    views_dirs = [
        os.path.join(SOURCES_DIR, 'Features'),
        os.path.join(SOURCES_DIR, 'Shared/UIComponents')
    ]
    exemptions = {'PlatformModifiers.swift', 'AdaptiveSidebarView.swift', 'CrossPlatform.swift', 'DesignTokenRegistry.swift', 'PlatformContext.swift'}

    for v_dir in views_dirs:
        if not os.path.exists(v_dir):
            continue
        for root, _, files in os.walk(v_dir):
            for fname in files:
                if fname.endswith('.swift') and fname not in exemptions:
                    _scan_single_view_file(os.path.join(root, fname))

def main():
    check_layering_structure()
    check_platform_decoupling()
    scan_token_bypasses()
    reporter.report()

if __name__ == '__main__':
    main()
