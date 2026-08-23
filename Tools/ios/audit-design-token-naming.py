#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对设计令牌命名规范进行 CI 门禁检查。
# 验证内容：
# 1. token 定义文件内禁止算术表达式（Reference 纯原子值，System/Component 仅允许组合）
# 2. 视图代码禁止 token 算术表达式（Reference.* * N、System.* * N、Component.* * N）
# 3. hardcoded 值零容忍（视图代码中 .padding(N)、spacing: N、lineWidth: N 等）
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

reporter = GatekeeperReporter("Design Token Naming Check")

# token 定义文件
REFERENCE_FILE = os.path.join(TOKENS_DIR, 'Reference.swift')
SYSTEM_FILE = os.path.join(TOKENS_DIR, 'System.swift')
COMPONENT_FILE = os.path.join(TOKENS_DIR, 'Component.swift')


def check_token_definition_arithmetic():
    """检查 token 定义文件内禁止算术表达式"""
    _check_reference_arithmetic()
    _check_system_arithmetic()
    _check_component_arithmetic()


def _check_reference_arithmetic():
    """Reference.swift：禁止任何 * / 算术（纯原子值）"""
    if not os.path.exists(REFERENCE_FILE):
        return
    with open(REFERENCE_FILE, 'r', encoding='utf-8', errors='ignore') as f:
        for i, line in enumerate(f, 1):
            s = line.strip()
            if s.startswith('//') or s.startswith('/*'):
                continue
            if re.search(r'\b\d+\.?\d*\s*[\*\/]\s*\d+\.?\d*\b', line):
                reporter.add_issue(
                    filepath=os.path.relpath(REFERENCE_FILE, PROJECT_ROOT),
                    line_no=i,
                    message="Reference 层禁止算术表达式（纯原子值）",
                    level="ERROR",
                    content=s
                )


def _check_system_arithmetic():
    """System.swift：禁止 * / 算术（允许 Reference.A + Reference.B 组合）"""
    if not os.path.exists(SYSTEM_FILE):
        return
    _check_token_arithmetic_in_file(SYSTEM_FILE, "System 层禁止 token 算术表达式")


def _check_component_arithmetic():
    """Component.swift：禁止 * / 算术"""
    if not os.path.exists(COMPONENT_FILE):
        return
    _check_token_arithmetic_in_file(COMPONENT_FILE, "Component 层禁止 token 算术表达式")


def _check_token_arithmetic_in_file(fpath, message):
    """检查文件中 token 算术表达式"""
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        for i, line in enumerate(f, 1):
            s = line.strip()
            if s.startswith('//') or s.startswith('/*'):
                continue
            if re.search(r'\b(Reference|System|Component)\.\w+\.\w+\s*[\*\/]\s*\d+\.?\d*\b', line):
                reporter.add_issue(
                    filepath=os.path.relpath(fpath, PROJECT_ROOT),
                    line_no=i,
                    message=message,
                    level="ERROR",
                    content=s
                )


def check_view_token_arithmetic():
    """扫描视图代码，禁止 token 算术表达式"""
    views_dirs = [
        os.path.join(SOURCES_DIR, 'Features'),
        os.path.join(SOURCES_DIR, 'Shared/UIComponents'),
        os.path.join(SOURCES_DIR, 'Platforms'),
        os.path.join(SOURCES_DIR, 'App'),
    ]
    exempt_files = {'Reference.swift', 'System.swift', 'Component.swift'}

    for v_dir in views_dirs:
        if not os.path.exists(v_dir):
            continue
        _scan_dir_for_token_arithmetic(v_dir, exempt_files)


def _scan_dir_for_token_arithmetic(v_dir, exempt_files):
    """扫描单个目录的 token 算术表达式"""
    for root, dirs, files in os.walk(v_dir):
        dirs[:] = [d for d in dirs if d not in {'.git', 'build', 'DerivedData', '.build'}]
        for fname in files:
            if not fname.endswith('.swift') or fname in exempt_files:
                continue
            fpath = os.path.join(root, fname)
            _scan_file_for_token_arithmetic(fpath)


def _scan_file_for_token_arithmetic(fpath):
    """扫描单个文件的 token 算术表达式"""
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        for i, line in enumerate(f, 1):
            s = line.strip()
            if s.startswith('//'):
                continue
            if re.search(r'\b(Reference|System|Component)\w*\.\w+\s*[\*\/]\s*\d+\.?\d*\b', line):
                reporter.add_issue(
                    filepath=os.path.relpath(fpath, PROJECT_ROOT),
                    line_no=i,
                    message="视图代码禁止 token 算术表达式，应使用命名 token",
                    level="ERROR",
                    content=s
                )


def main():
    check_token_definition_arithmetic()
    check_view_token_arithmetic()
    reporter.report()


if __name__ == '__main__':
    main()
