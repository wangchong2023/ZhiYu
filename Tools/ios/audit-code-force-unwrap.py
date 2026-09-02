#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-code-force-unwrap.py
#  ZhiYu
#
#  系统层级：[Tools/ios] 代码安全门禁
#  核心职责：检测 Sources/ 目录下生产代码中的强制解包 (!) 和强制类型转换 (as!)，
#           防止运行时崩溃风险。使用白名单排除已知安全的模式。
#

import re
import sys
from pathlib import Path

SOURCES_DIR = Path("Sources")
EXCLUDE_DIRS = {'.git', 'build', 'DerivedData', '.build', 'Tests', 'Localization', 'env'}

# 匹配模式
FORCE_UNWRAP_PATTERN = re.compile(r'!\s*$|!\s*[.\(,\)]|!\s*//|!\s*$')
FORCE_CAST_PATTERN = re.compile(r'\bas!\s')

# 常量定义
MAX_SNIPPET_LENGTH = 100
MAX_ISSUES_DISPLAY = 50

# 白名单：已知安全或架构性使用的文件
WHITELIST_FILES = {
    'AppStore.swift',
    'AppEnvironment.swift',
    'DatabaseManager.swift',
}


def is_in_comment(line: str, pos: int) -> bool:
    """判断位置是否在注释中（简化版）。"""
    stripped = line[:pos].strip()
    return stripped.startswith('//')


def is_valid_force_unwrap(line: str, pos: int) -> bool:
    """判定指定位置的感叹号是否为真正的强制解包。"""
    if is_in_comment(line, pos):
        return False
    after = line[pos + 1:].lstrip()
    if after.startswith('='):
        return False
    before = line[:pos].rstrip()
    if before.endswith((' ', '(', ',', 'let', 'var', 'if', 'while', 'guard', 'return', '||', '&&')):
        return False
    if 'var ' in line[pos:] or 'let ' in line[pos:]:
        return False
    return bool(re.search(r'[)\w]\s*!$', before) or re.search(r'[)\w]\s*!\s*[.\(,]', line[pos:]))


def check_line_patterns(line: str, line_no: int) -> list:
    """检查单行中的强制解包和类型转换违规。"""
    line_issues = []
    stripped = line.strip()

    for match in FORCE_CAST_PATTERN.finditer(line):
        if not is_in_comment(line, match.start()):
            line_issues.append((line_no, "强制类型转换 as!", stripped))

    for match in re.finditer(r'(?<!\w)!(?!=)', line):
        pos = match.start()
        if is_valid_force_unwrap(line, pos):
            line_issues.append((line_no, "强制解包 !", stripped))

    return line_issues


def check_file(filepath: Path) -> list:
    """检查单个文件中的强制解包和强制转换。"""
    issues = []
    try:
        content = filepath.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return issues

    lines = content.split('\n')
    in_block_comment = False

    for line_no, line in enumerate(lines, 1):
        stripped = line.strip()

        if '/*' in stripped:
            in_block_comment = True
        if in_block_comment:
            if '*/' in stripped:
                in_block_comment = False
            continue

        if stripped.startswith('//'):
            continue

        issues.extend(check_line_patterns(line, line_no))

    return issues


def collect_all_unwrap_issues():
    """收集所有 Swift 文件中的强制解包违规项。"""
    all_issues = []
    for fp in sorted(SOURCES_DIR.rglob("*.swift")):
        if any(part in fp.parts for part in EXCLUDE_DIRS):
            continue
        if fp.name in WHITELIST_FILES:
            continue

        issues = check_file(fp)
        for line_no, issue_type, snippet in issues:
            all_issues.append(f"  {fp}:{line_no}: [{issue_type}] {snippet[:MAX_SNIPPET_LENGTH]}")
    return all_issues


def main():
    """主执行函数：执行 Swift 强制解包安全审计。"""
    print("====== Force Unwrap Audit (Gatekeeper) ======")
    if not SOURCES_DIR.exists():
        print(f"❌ 找不到目录: {SOURCES_DIR}")
        sys.exit(1)

    all_issues = collect_all_unwrap_issues()

    if all_issues:
        print(f"\n❌ [Force Unwrap] 发现 {len(all_issues)} 处强制解包/强制转换，阻断流水线:")
        for issue in all_issues[:MAX_ISSUES_DISPLAY]:
            print(issue)
        if len(all_issues) > MAX_ISSUES_DISPLAY:
            print(f"  ... 及另外 {len(all_issues) - MAX_ISSUES_DISPLAY} 处")
        print(f"\n建议：使用 guard let / if let 安全解包，或使用 as? + ?? 替代 as!。")
        sys.exit(1)

    print(f"\n✅ [Force Unwrap] 未发现强制解包/强制转换。")
    sys.exit(0)


if __name__ == '__main__':
    main()
