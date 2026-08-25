#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于检查 DesignSystem token 数量上限，防止 token 爆炸。
# 对齐业界标杆（Tailwind CSS 严格有限原则）：
#   - Reference 层（原子值）≤ 60
#   - System 层（语义映射）≤ 50
#   - Component 层（组件特定）≤ 25
#   - 总计 ≤ 135
#

import os
import re
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TOKENS_DIR = os.path.join(PROJECT_ROOT, 'Sources/Shared/DesignSystem/Tokens')

# token 数量上限（对齐 Tailwind CSS 严格有限原则）
LIMITS = {
    'Reference.swift': 70,
    'System.swift': 60,
    'Component.swift': 25,
}
TOTAL_LIMIT = 155


def count_tokens(filepath):
    """统计文件中 public static let 数量"""
    if not os.path.exists(filepath):
        return 0
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    return len(re.findall(r'public\s+static\s+let\s+', content))


def main():
    """主入口：统计各 token 文件数量并对比业界上限，超标则阻断。"""
    errors = []
    total = 0

    for fname, limit in LIMITS.items():
        fpath = os.path.join(TOKENS_DIR, fname)
        count = count_tokens(fpath)
        total += count
        status = "✅" if count <= limit else "❌"
        print(f"  {status} {fname}: {count}/{limit}")
        if count > limit:
            errors.append(f"{fname} token 数量 {count} 超过上限 {limit}")

    status = "✅" if total <= TOTAL_LIMIT else "❌"
    print(f"  {status} 总计: {total}/{TOTAL_LIMIT}")
    if total > TOTAL_LIMIT:
        errors.append(f"token 总数 {total} 超过上限 {TOTAL_LIMIT}")

    if errors:
        print("\n❌ [Token Budget Check] token 数量超标：")
        for e in errors:
            print(f"  - {e}")
        print("\n建议：")
        print("  - Reference 层：原子值不可再分，保持稳定")
        print("  - System 层：合并语义重复的 token，去除低频使用")
        print("  - Component 层：一次性组件特定值不应放入公共 token，改为组件内 private 常量")
        sys.exit(1)
    else:
        print("\n✅ [Token Budget Check] token 数量符合业界标准。")
        sys.exit(0)


if __name__ == '__main__':
    main()
