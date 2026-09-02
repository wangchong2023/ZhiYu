#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-code-file-size.py
#  ZhiYu
#
#  系统层级：[Tools/ios] 代码质量门禁
#  核心职责：检测 Sources/ 目录下过大的 Swift 文件，防止 SRP 违规的 God File 出现。
#           阈值：500 行为 WARNING，800 行为 ERROR（阻断流水线）。
#

import sys
from pathlib import Path

SOURCES_DIR = Path("Sources")
EXCLUDE_DIRS = {'.git', 'build', 'DerivedData', '.build', 'Tests', 'Localization', 'env'}

WARNING_THRESHOLD = 500
ERROR_THRESHOLD = 800


def count_swift_lines(filepath: Path) -> int:
    """统计 Swift 文件的有效代码行数（排除空行和纯注释行）。"""
    count = 0
    in_block_comment = False
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                stripped = line.strip()
                if '/*' in stripped:
                    in_block_comment = True
                if in_block_comment:
                    if '*/' in stripped:
                        in_block_comment = False
                    continue
                if not stripped or stripped.startswith('//'):
                    continue
                count += 1
    except Exception:
        return 0
    return count


def collect_size_issues():
    """遍历收集所有超过阈值的 Swift 文件。"""
    errors = []
    warnings = []
    for fp in sorted(SOURCES_DIR.rglob("*.swift")):
        if any(part in fp.parts for part in EXCLUDE_DIRS):
            continue
        if fp.name == "FeatureConstants.swift":
            continue
        line_count = count_swift_lines(fp)
        if line_count >= ERROR_THRESHOLD:
            errors.append(f"  ❌ {fp} — {line_count} 行 (>= {ERROR_THRESHOLD} 行阈值)")
        elif line_count >= WARNING_THRESHOLD:
            warnings.append(f"  ⚠️  {fp} — {line_count} 行 (>= {WARNING_THRESHOLD} 行阈值)")
    return errors, warnings


def main():
    """主执行函数：执行 Swift 文件大小 SRP 审计。"""
    print("====== File Size Audit (Gatekeeper) ======")
    if not SOURCES_DIR.exists():
        print(f"❌ 找不到目录: {SOURCES_DIR}")
        sys.exit(1)

    errors, warnings = collect_size_issues()

    if warnings:
        print(f"\n⚠️  [File Size] 发现 {len(warnings)} 个文件超过 {WARNING_THRESHOLD} 行:")
        for w in warnings:
            print(w)

    if errors:
        print(f"\n❌ [File Size] 发现 {len(errors)} 个文件超过 {ERROR_THRESHOLD} 行，阻断流水线:")
        for e in errors:
            print(e)
        print(f"\n建议：将大文件按 SRP 拆分为多个职责单一的文件。")
        sys.exit(1)

    print(f"\n✅ [File Size] 所有 Swift 文件大小合规。")
    sys.exit(0)


if __name__ == '__main__':
    main()
