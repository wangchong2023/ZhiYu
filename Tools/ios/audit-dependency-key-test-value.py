#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智宇 (ZhiYu) DependencyKey testValue 完整性审计工具 (audit-dependency-key-test-value.py)

功能说明:
1. 扫描 Sources/ 目录下所有 Swift 文件，检测所有 `DependencyKey` 枚举。
2. 验证每个 DependencyKey 是否同时定义了 `liveValue`、`testValue` 和 `previewValue`。
3. 缺少 `testValue` 的 DependencyKey 会导致测试环境 `reportIssue`（test failure），
   即使 `ServiceContainer` 已注册 liveValue。
4. 缺少 `previewValue` 的 DependencyKey 在 SwiftUI Preview 中会 fallback 到 liveValue，
   可能导致 Preview 崩溃。

使用方法:
    python3 Tools/ios/audit-dependency-key-test-value.py

退出码:
    0: 审计通过（所有 DependencyKey 均定义了 testValue）
    1: 审计失败（发现缺少 testValue 的 DependencyKey）
"""

import os
import sys
import re
import glob

# ==================== 配置常量 ====================
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")

# 匹配 DependencyKey 枚举定义
# 例如: `enum FooKey: DependencyKey {` 或 `public enum FooKey: DependencyKey {`
DEP_KEY_PATTERN = re.compile(
    r'(?:public\s+)?(?:enum|struct)\s+(\w+Key)\s*:\s*DependencyKey\b'
)

# 匹配 testValue 属性定义（支持 static var 和 static let）
TEST_VALUE_PATTERN = re.compile(r'\bstatic\s+(?:var|let)\s+testValue\b')

# 匹配 previewValue 属性定义
PREVIEW_VALUE_PATTERN = re.compile(r'\bstatic\s+(?:var|let)\s+previewValue\b')

# 匹配 liveValue 属性定义
LIVE_VALUE_PATTERN = re.compile(r'\bstatic\s+(?:var|let)\s+liveValue\b')

# DependencyKey 枚举体最大扫描行数（防止无限扫描）
MAX_KEY_BODY_LINES = 200

# 控制台分隔线宽度
SEPARATOR_WIDTH = 70

# 表格分隔线宽度
TABLE_SEPARATOR_WIDTH = 120


def find_swift_files():
    """查找 Sources/ 目录下所有 Swift 文件"""
    patterns = [
        os.path.join(SOURCES_DIR, "**", "*.swift"),
    ]
    files = set()
    for pattern in patterns:
        for f in glob.glob(pattern, recursive=True):
            files.add(f)
    return sorted(files)


def _find_key_body_end(lines, start_index):
    """
    从 start_index 开始查找枚举体的结束行（匹配大括号配对）。
    返回结束行号（1-indexed），未找到则返回 start_index + 1。
    """
    brace_depth = 0
    found_open = False
    end_line = start_index + 1

    for j in range(start_index, min(start_index + MAX_KEY_BODY_LINES, len(lines))):
        for char in lines[j]:
            if char == '{':
                brace_depth += 1
                found_open = True
            elif char == '}':
                brace_depth -= 1
                if found_open and brace_depth == 0:
                    end_line = j + 1  # 1-indexed
                    return end_line
        if found_open and brace_depth == 0:
            break

    return end_line


def extract_dependency_keys(content):
    """
    提取文件中所有 DependencyKey 枚举及其定义体范围。
    返回列表: [(key_name, start_line, end_line), ...]
    """
    results = []
    lines = content.split('\n')

    for i, line in enumerate(lines):
        # 跳过注释行（// 或 ///）
        stripped = line.lstrip()
        if stripped.startswith('//') or stripped.startswith('///'):
            continue
        match = DEP_KEY_PATTERN.search(line)
        if not match:
            continue

        key_name = match.group(1)
        start_line = i + 1  # 1-indexed
        end_line = _find_key_body_end(lines, i)
        results.append((key_name, start_line, end_line))

    return results


def check_key_body(content, start_line, end_line):
    """
    检查 DependencyKey 体内是否包含 liveValue/testValue/previewValue。
    返回: (has_live, has_test, has_preview)
    """
    lines = content.split('\n')
    body = '\n'.join(lines[start_line - 1:end_line])

    has_live = bool(LIVE_VALUE_PATTERN.search(body))
    has_test = bool(TEST_VALUE_PATTERN.search(body))
    has_preview = bool(PREVIEW_VALUE_PATTERN.search(body))

    return has_live, has_test, has_preview


def audit_file(file_path):
    """
    审计单个文件中的 DependencyKey。
    返回违规列表: [(key_name, file_path, line, missing_props), ...]
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"warning: 无法读取文件 {file_path}: {e}", file=sys.stderr)
        return []

    violations = []
    rel_path = os.path.relpath(file_path, PROJECT_DIR)

    keys = extract_dependency_keys(content)
    for key_name, start_line, end_line in keys:
        has_live, has_test, has_preview = check_key_body(content, start_line, end_line)

        missing = []
        if not has_test:
            missing.append("testValue")
        if not has_preview:
            missing.append("previewValue")

        if missing:
            violations.append((key_name, rel_path, start_line, missing))

    return violations


def _scan_all_files(files):
    """
    扫描所有 Swift 文件，分类收集 testValue 违规和 previewValue 警告。
    返回: (test_value_violations, preview_warnings, keys_found)
    """
    all_violations = []
    preview_warnings = []
    keys_found = 0

    for file_path in files:
        violations = audit_file(file_path)
        # 统计所有 Key（包括合规的）
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
            keys = extract_dependency_keys(content)
            keys_found += len(keys)
        except Exception:
            pass

        for v in violations:
            key_name, rel_path, line, missing = v
            if "testValue" in missing:
                all_violations.append(v)
            else:
                # 仅缺 previewValue 的为 warning
                preview_warnings.append(v)

    return all_violations, preview_warnings, keys_found


def _print_violation_table(title, violations):
    """
    打印违规表格（序号/Key 名称/文件/行号/缺少属性）。
    """
    print("=" * SEPARATOR_WIDTH)
    print(title)
    print("=" * SEPARATOR_WIDTH)
    print()
    print(f"{'序号':<4} {'Key 名称':<30} {'文件':<55} {'行号':<6} {'缺少'}")
    print("-" * TABLE_SEPARATOR_WIDTH)

    for idx, (key_name, rel_path, line, missing) in enumerate(violations, 1):
        missing_str = ", ".join(missing)
        print(f"{idx:<4} {key_name:<30} {rel_path:<55} {line:<6} {missing_str}")
    print()


def main():
    """
    审计入口：扫描 Sources/ 下所有 Swift 文件，检测 DependencyKey 的
    testValue/previewValue 完整性。testValue 缺失为硬阻断，previewValue 缺失为警告。
    """
    print("=" * SEPARATOR_WIDTH)
    print("智宇 DependencyKey testValue 完整性审计")
    print("=" * SEPARATOR_WIDTH)
    print()

    files = find_swift_files()
    if not files:
        print("⚠️  未找到 Swift 文件", file=sys.stderr)
        sys.exit(1)

    print(f"扫描目录: {SOURCES_DIR}")
    print(f"Swift 文件数: {len(files)}")
    print()

    all_violations, preview_warnings, keys_found = _scan_all_files(files)

    print(f"DependencyKey 总数: {keys_found}")
    print(f"缺少 testValue 的 Key 数: {len(all_violations)} (硬阻断)")
    print(f"缺少 previewValue 的 Key 数: {len(preview_warnings)} (警告)")
    print()

    if all_violations:
        _print_violation_table(
            "❌ 审计失败 — 以下 DependencyKey 缺少 testValue（硬阻断）:",
            all_violations
        )
        print("修复指南:")
        print("  1. 为每个缺少 testValue 的 Key 添加:")
        print("     static var testValue: Type {")
        print("         ServiceContainer.shared.resolveOptional(Type.self) ?? NoOpType()")
        print("     }")
        print("  2. 协议类型需新建 NoOp 实现类（参考 NoOpChatService 模式）")
        print("  3. 具体类型用 resolveOptional ?? Type() 模式")
        print()
        sys.exit(1)

    if preview_warnings:
        _print_violation_table(
            "⚠️  警告 — 以下 DependencyKey 缺少 previewValue（不影响 CI 阻断）:",
            preview_warnings
        )
        print("修复建议:")
        print("  为每个缺少 previewValue 的 Key 添加:")
        print("     static var previewValue: Type { NoOpType() }")
        print()
        sys.exit(0)
    else:
        print("=" * SEPARATOR_WIDTH)
        print("✅ 审计通过 — 所有 DependencyKey 均已定义 testValue/previewValue")
        print("=" * SEPARATOR_WIDTH)
        sys.exit(0)


if __name__ == "__main__":
    main()
