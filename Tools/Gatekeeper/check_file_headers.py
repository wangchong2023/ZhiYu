#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_file_headers.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/22.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/Gatekeeper] 守卫网关
#  核心职责：检查 Swift 文件的文件头注释规范。
#           包括：系统层级标注、View 文件层级标注正确性、核心职责描述最小长度。
#

import sys
import re
from pathlib import Path
from collections import Counter

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"

# 文件头前 N 行用于检查
HEADER_CHECK_LINES = 20
# 核心职责描述最小字数
MIN_RESPONSIBILITY_LEN = 10
# 模板化描述检测阈值（同一描述出现次数）
TEMPLATE_THRESHOLD = 3

LAYER_PATTERN = re.compile(r'系统层级\s*[：:]\s*\[([^\]]+)\]')
RESPONSIBILITY_PATTERN = re.compile(r'核心职责\s*[：:]\s*(.+)')
# 排除目录（不要求文件头）
EXCLUDE_DIRS = {"Sources/Localization/"}


def check_file(filepath: Path) -> list[str]:
    """检查单个 Swift 文件的文件头规范，返回警告列表。"""
    warnings = []
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
    except Exception:
        return [f"无法读取: {filepath}"]

    first_lines = ''.join(lines[:HEADER_CHECK_LINES])
    rel_path = str(filepath.relative_to(PROJECT_ROOT))

    # 跳过排除目录
    for exclude_dir in EXCLUDE_DIRS:
        if rel_path.startswith(exclude_dir):
            return warnings

    # 检查 1：必须有系统层级
    layer_match = LAYER_PATTERN.search(first_lines)
    if not layer_match:
        warnings.append("缺少 '系统层级' 标注")
        return warnings

    # 检查 2：View 文件不能是 [L2]
    layer = layer_match.group(1)
    if _is_view_file(filepath) and layer == 'L2':
        warnings.append("View 文件标注为 [L2] 业务功能层，应为 [L3] 表现层")

    # 检查 3：核心职责描述不能太短
    resp_match = RESPONSIBILITY_PATTERN.search(first_lines)
    if resp_match:
        desc = resp_match.group(1).strip()
        if len(desc) < MIN_RESPONSIBILITY_LEN:
            warnings.append(f"核心职责描述过短 ({len(desc)} 字): '{desc}'")
    else:
        warnings.append("缺少 '核心职责' 描述")

    return warnings


def _is_view_file(filepath: Path) -> bool:
    """判断是否为 View 文件（路径含 /View/ 或 /Views/ 且为 Swift 文件）。"""
    path_str = str(filepath.relative_to(PROJECT_ROOT))
    return '/View/' in path_str or '/Views/' in path_str


def _check_model_template() -> None:
    """额外检查 Domain/Models/ 下的模板化描述。"""
    domain_models = SOURCES_DIR / "Domain" / "Models"
    if not domain_models.exists():
        return
    counts = Counter()
    for swift_file in domain_models.glob("*.swift"):
        try:
            with open(swift_file, 'r') as f:
                head = ''.join(f.readlines()[:HEADER_CHECK_LINES])
            m = RESPONSIBILITY_PATTERN.search(head)
            if m:
                counts[m.group(1).strip()] += 1
        except Exception:
            pass
    for desc, count in counts.items():
        if count > TEMPLATE_THRESHOLD:
            print(f"⚠️  模板化描述（{count} 个文件共享）: '{desc}'")


def _report(messages: dict, total: int) -> int:
    """打印违规报告。"""
    print(f"❌ FAIL: {len(messages)}/{total} 个文件存在文件头注释问题")
    for rel_path, warnings in messages.items():
        print(f"  {rel_path}:")
        for w in warnings:
            print(f"    - {w}")
    return 1


def main():
    """扫描所有 Swift 文件的文件头注释规范并报告问题。"""
    warnings = {}
    total = 0

    for swift_file in SOURCES_DIR.rglob("*.swift"):
        total += 1
        file_warnings = check_file(swift_file)
        if file_warnings:
            rel_path = swift_file.relative_to(PROJECT_ROOT)
            warnings[rel_path] = file_warnings

    _check_model_template()

    if not warnings:
        print(f"✅ PASS: {total} 个文件的文件头注释规范合格")
        return 0
    return _report(warnings, total)


if __name__ == "__main__":
    sys.exit(main())
