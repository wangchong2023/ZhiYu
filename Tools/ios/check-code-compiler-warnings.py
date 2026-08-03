#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ios-check-code-compiler-warnings.py
ZhiYu (智宇) 全平台编译告警 (Zero Warning Policy) CI 门禁审计脚本

核心职责：
1. 解析 xcodebuild 构建日志文件或控制台标准输出；
2. 扫描 Xcode 项目工程结构告警（如 malformed project / duplicate group）、Swift 编译器 Warning 及废弃 API 告警；
3. 一旦检测到编译告警，输出具体告警信息及行号，并返回 exit code 1 阻断 CI 流水线。
"""

import sys
import os
import glob
import re

MAX_PRINTED_VIOLATIONS = 10

IGNORE_PATTERNS = [
    # 忽略外部三方库 opensrc 内的第三方警告（如预编译二进制或第三方 Package 依赖内部告警）
    r"opensrc/swift/",
    r"SourcePackages/checkouts/",
]

WARNING_PATTERNS = [
    r"warning:\s+The file reference for",
    r"warning:\s+malformed project",
    r"warning:\s+.*is deprecated",
    r"warning:\s+cannot find",
    r":\d+:\d+:\s+warning:",
]


def is_ignored(log_line):
    """判断当前日志行是否应该被忽略"""
    for pat in IGNORE_PATTERNS:
        if re.search(pat, log_line):
            return True
    return False


def check_log_file(file_path):
    """扫描指定编译日志文件中的警告行"""
    violations = []
    if not os.path.exists(file_path):
        return violations

    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        for idx, line in enumerate(f, start=1):
            if is_ignored(line):
                continue
            for pat in WARNING_PATTERNS:
                if re.search(pat, line, re.IGNORECASE):
                    violations.append((idx, line.strip()))
                    break
    return violations


def main():
    """入口函数：检索 build/*.log 编译日志文件并执行 0 告警审计"""
    print("==================================================")
    print("🔍 [Zero Warning Audit] 开始进行编译告警清零 CI 审计...")
    print("==================================================")

    log_dir = "build"
    log_files = glob.glob(os.path.join(log_dir, "*.log"))

    if not log_files:
        print("ℹ️ 未发现 build/*.log 编译日志，零告警审计跳过。")
        sys.exit(0)

    all_violations = {}
    total_count = 0

    for log_path in log_files:
        violations = check_log_file(log_path)
        if violations:
            all_violations[log_path] = violations
            total_count += len(violations)

    if total_count > 0:
        print(f"\n❌ [Zero Warning Audit] 发现 {total_count} 条未清理的编译告警 (Violation!):\n")
        for log_path, items in all_violations.items():
            print(f"📄 日志文件: {log_path}")
            for line_no, content in items[:MAX_PRINTED_VIOLATIONS]:
                print(f"  └─ 行 {line_no}: {content}")
            if len(items) > MAX_PRINTED_VIOLATIONS:
                print(f"  └─ ... 以及其余 {len(items) - MAX_PRINTED_VIOLATIONS} 条告警")
            print()
        print("⚠️ 提示: 请修复相关 project.yml 结构或代码中的 Warning 后重新构建。")
        sys.exit(1)
    else:
        print("✅ [Zero Warning Audit] 零告警 CI 门禁检查通过！三端编译无任何 Warning！\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
