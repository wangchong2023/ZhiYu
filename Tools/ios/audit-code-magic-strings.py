#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-code-magic-strings.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/22.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：检查 Sources/Features/ 和 Sources/Platforms/ 中硬编码的 UserDefaults key 和 URL。
#           硬编码的 forKey 字符串和 https?:// URL 应使用 AppConstants.URLs / AppConstants.Keys.Storage 常量。
#

import sys
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"

# 硬编码 UserDefaults key 模式
UD_KEY_PATTERN = re.compile(r'UserDefaults\.[^)]*forKey:\s*"[^"]+"')
# 硬编码 URL 模式
URL_PATTERN = re.compile(r'"(https?://[^"]+)"')

# 排除的 URL 模式（合理保留）
URL_EXCLUDE_PATTERNS = [
    re.compile(r'AppConstants\.URLs\.'),
    re.compile(r'schemas\.openxmlformats\.org'),
    re.compile(r'api\.example\.com'),
    re.compile(r'hasPrefix\("http'),
]

CHECK_DIRS = [
    SOURCES_DIR / "Features",
    SOURCES_DIR / "Platforms",
]


def _should_exclude_url(content: str) -> bool:
    """判断 URL 行是否属于合理保留模式（XML 命名空间、placeholder、协议检查等）。"""
    for pat in URL_EXCLUDE_PATTERNS:
        if pat.search(content):
            return True
    return False


def _scan_directory(check_dir: Path) -> tuple[list, list]:
    """
    扫描目录中所有 Swift 文件的硬编码 UserDefaults key 和 URL。
    
    :param check_dir: 扫描目录
    :return: (UD 违规列表, URL 违规列表)
    """
    ud_violations = []
    url_violations = []
    if not check_dir.exists():
        return ud_violations, url_violations
    for swift_file in check_dir.rglob("*.swift"):
        rel_path = swift_file.relative_to(PROJECT_ROOT)
        try:
            with open(swift_file, 'r') as f:
                lines = f.readlines()
        except Exception:
            continue
        for i, line in enumerate(lines, 1):
            if UD_KEY_PATTERN.search(line) and 'AppConstants' not in line:
                ud_violations.append((rel_path, i, line.strip()))
            if URL_PATTERN.search(line) and not _should_exclude_url(line):
                url_violations.append((rel_path, i, line.strip()))
    return ud_violations, url_violations


def _report_violations(label: str, hint: str, items: list) -> int:
    """
    打印违规报告。
    
    :param label: 违规类别标签
    :param hint: 修复提示
    :param items: 违规条目列表
    :return: 1（始终返回非零）
    """
    print(f"❌ {label}: {len(items)} 处硬编码")
    print(f"  {hint}")
    for rel_path, line_no, content in items:
        print(f"    {rel_path}:L{line_no} → {content}")
    return 1


def main():
    """扫描业务层硬编码 UserDefaults key 和 URL，验证是否已用 AppConstants 常量替代。"""
    all_ud = []
    all_url = []
    for check_dir in CHECK_DIRS:
        uds, urls = _scan_directory(check_dir)
        all_ud.extend(uds)
        all_url.extend(urls)

    if not all_ud and not all_url:
        print("✅ PASS: 无硬编码 UserDefaults key 或 URL")
        return 0

    exit_code = 0
    if all_ud:
        exit_code = _report_violations(
            "UserDefaults key",
            "应使用 AppConstants.Keys.Storage.* 常量",
            all_ud)
    if all_url:
        ec = _report_violations(
            "URL",
            "应使用 AppConstants.URLs.* 常量",
            all_url)
        exit_code = exit_code or ec
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
