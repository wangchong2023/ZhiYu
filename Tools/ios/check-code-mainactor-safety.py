#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-code-mainactor-safety.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/25.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：静态审计 Swift 源码中不安全的 @MainActor 跨线程访问模式。
#           禁止直接使用 DispatchQueue.main.sync（可能导致主线程死锁）
#           和 MainActor.assumeIsolated（可能在后台线程崩溃）。
#           runOnMainSync() 是唯一合法的跨线程 @MainActor 桥接入口。

import os
import re
import sys

# ── 配置 ──────────────────────────────────────────────

UNSAFE_PATTERNS = [
    (r'DispatchQueue\.main\.sync\b', 'DispatchQueue.main.sync — 使用 runOnMainSync 替代以避免主线程死锁'),
    (r'MainActor\.assumeIsolated\b', 'MainActor.assumeIsolated — 使用 runOnMainSync 替代以避免后台线程崩溃'),
]

ALLOWED_FILES = {
    'Infrastructure/Plugins/JavaScriptPlugin.swift',
}


def _is_swift_file(filename):
    """判断文件是否为 Swift 源代码。"""
    return filename.endswith('.swift')


def _is_allowed(rel_path):
    """判断文件路径是否在豁免列表中。"""
    return any(rel_path.endswith(a) for a in ALLOWED_FILES)


def _scan_file(filepath):
    """
    扫描单个 Swift 文件中的不安全 @MainActor 访问模式。

    :param filepath: Swift 文件绝对路径
    :return: 违规信息列表
    """
    issues = []
    with open(filepath, 'r', encoding='utf-8') as fh:
        lines = fh.readlines()
    for i, line in enumerate(lines, 1):
        for pattern, msg in UNSAFE_PATTERNS:
            if re.search(pattern, line) and 'runOnMainSync' not in line:
                issues.append(f"{os.path.relpath(filepath, os.getcwd())}:{i}: {msg}")
    return issues


def scan_sources():
    """
    扫描 Sources 目录下所有 Swift 文件，检测不安全的 @MainActor 访问模式。

    :return: 违规信息列表
    """
    all_issues = []
    for root, dirs, files in os.walk('Sources'):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for f in files:
            if not _is_swift_file(f):
                continue
            path = os.path.join(root, f)
            if _is_allowed(os.path.relpath(path, os.getcwd())):
                continue
            all_issues.extend(_scan_file(path))
    return all_issues


def main():
    """
    主入口：执行 @MainActor 安全审计并以适当的退出码退出。
    """
    issues = scan_sources()
    if issues:
        print(f"❌ 发现 {len(issues)} 处不安全的 @MainActor 访问：")
        for issue in issues:
            print(f"  {issue}")
        print("\n💡 请使用 UFPCore 中的 runOnMainSync() 替代（import UFPCore 后直接调用）。")
        sys.exit(1)
    else:
        print("✅ @MainActor 访问安全：所有跨线程桥接均通过 runOnMainSync")
        sys.exit(0)


if __name__ == '__main__':
    main()
