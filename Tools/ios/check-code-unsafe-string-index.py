#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-code-unsafe-string-index.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/21.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/scripts/Sanity] 卫生守卫
#  核心职责：扫描 Swift 源码中不安全的 String.Index offsetBy: 调用，强制使用 limitedBy 保护。
#
import re
import os
import sys

ROOT = "Sources"

# 匹配 .index(xxx, offsetBy: N) 但没有 limitedBy 的模式
# 目标: "offsetBy:" 后面没有 "limitedBy:"
UNSAFE_PATTERN = re.compile(r'\.index\([^)]*offsetBy:\s*\d+[^)]*\)(?!.*limitedBy)')

def scan_file(filepath):
    issues = []
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    for i, line in enumerate(lines, 1):
        # 跳过注释行
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
            continue
        matches = UNSAFE_PATTERN.findall(line)
        for m in matches:
            # 确认没有 limitedBy
            if "limitedBy" not in m:
                issues.append((i, m.strip()))
    return issues

def main():
    all_issues = {}
    for root, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for f in files:
            if f.endswith('.swift'):
                path = os.path.join(root, f)
                issues = scan_file(path)
                if issues:
                    all_issues[path] = issues

    if all_issues:
        print("❌ Unsafe String.Index offsetBy: calls found (use limitedBy:):")
        for path, issues in sorted(all_issues.items()):
            print(f"\n📂 {path}")
            for line_no, code in issues:
                print(f"  L{line_no}: {code}")
        sys.exit(1)
    else:
        print("✅ All String.Index offsetBy: calls are safe (use limitedBy:)")
        sys.exit(0)

if __name__ == "__main__":
    main()
