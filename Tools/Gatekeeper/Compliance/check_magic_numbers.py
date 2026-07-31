#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对 Sources/ 目录以及 Tools/Mock/ 目录下的 Swift 和 Python 代码
# 进行魔鬼数字和硬编码常量（如 padding，cornerRadius，port，以及硬编码 Hex 颜色等）的精确扫描审计。
#

"""精确扫描：排除 DesignSystem 定义文件和合法用法"""

import os, re, sys

EXCLUDE_DIRS = {'.git','build','DerivedData','.build','Frameworks','Tests','env','__pycache__'}
TOKEN_FILES = {'Colors.swift','DesignSystem.swift','IconTokens.swift','Spacing.swift'}
TOKEN_FILES_PY = set()

SWIFT_EXT = {'.swift'}
PY_EXT = {'.py'}

# 诊断输出时代码行内容的最大截断长度
MAX_LINE_PREVIEW_LEN = 90
# 每个文件最多展示的缺陷实例数量
MAX_DISPLAY_LIMIT = 5

def scan_file(path, ext):
    issues = []
    with open(path, errors='ignore') as f:
        lines = f.readlines()
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith('//') or s.startswith('#'):
            continue
        if ext in SWIFT_EXT:
            issues.extend(check_swift_line(path, i, s, line))
        if ext in PY_EXT:
            issues.extend(check_python_line(path, i, s, line))
    return issues


def check_swift_colors(raw, path, line_no, s):
    results = []
    if re.search(r'Color\(red:', raw) and 'DesignSystem' not in raw:
        results.append(('Color(red:)', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    if re.search(r'Color\(hex:\s*"([^"]+)"', raw):
        results.append(('Color(hex:"...")', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    return results

def check_swift_layout(raw, path, line_no, s):
    results = []
    if re.search(r'\.padding\(\s*(\d+)\s*\)', raw) and 'DesignSystem' not in raw:
        results.append(('hardcoded padding', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    if re.search(r'cornerRadius:\s*(\d+)\s*[),]', raw) and 'DesignSystem' not in raw and 'Spacing' not in raw:
        results.append(('hardcoded cornerRadius', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    if re.search(r'customSize\d+', raw) and 'DesignSystem+Metrics.swift' not in path and 'Spacing.swift' not in path:
        results.append(('pseudo-token customSize (硬编码数字变相包裹)', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    return results

def check_swift_line(path, line_no, s, raw):
    """
    检查 Swift 单行代码中是否包含硬编码的 UI 参数，
    例如硬编码的 RGB Color 构造、Hex Color 字符串、硬编码的 padding 或 cornerRadius。
    """
    return check_swift_colors(raw, path, line_no, s) + check_swift_layout(raw, path, line_no, s)


def check_python_line(path, line_no, s, raw):
    """
    检查 Python 单行代码中是否包含硬编码的常数或敏感配置，
    例如未定义为常量的硬编码 Port 端口号，或可能硬编码的版本号信息。
    """
    results = []
    if re.search(r'port\s*=\s*\d{4,5}\b', raw) and 'PORT' not in raw:
        results.append(('硬编码端口号', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    if re.match(r'^[A-Z][A-Z_]*\s*=', s):
        return results
    m = re.search(r'["\'](\d+\.\d+\.\d+)["\']', raw)
    if m and m.group(1) not in ('',):
        if 'version' in raw.lower():
            if 'version=' not in raw:
                results.append(('硬编码版本号', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    return results


results = []
scan_dirs = ['Sources', 'Tools/Mock']

for scan_dir in scan_dirs:
    if not os.path.isdir(scan_dir):
        continue
    for root, dirs, files in os.walk(scan_dir):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for fname in files:
            ext = os.path.splitext(fname)[1]
            scanner_exts = {'.swift': '.swift', '.py': '.py'}
            if ext not in scanner_exts:
                continue
            if fname in TOKEN_FILES or fname in TOKEN_FILES_PY:
                continue
            path = os.path.join(root, fname)
            results.extend(scan_file(path, ext))

# 引入统一报告管理器
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from gatekeeper_reporter import GatekeeperReporter

reporter = GatekeeperReporter("Magic Number Audit")

for typ, path, line_no, code in results:
    fpath = os.path.relpath(path)
    if 'Widget' in fpath or 'Widgets' in fpath:
        continue
    reporter.add_issue(
        filepath=fpath,
        line_no=line_no,
        message=f"发现硬编码魔鬼参数 ({typ})，建议替换为 DesignSystem token。",
        level="ERROR",
        content=code
    )

reporter.report()
