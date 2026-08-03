#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ios-check-code-prompt-governance.py
ZhiYu (智宇) Prompt 治理与安全合规 CI 编译门禁审计脚本

核心职责：
1. 扫描 Sources/ 目录下所有 Swift 文件中的硬编码提示词散落与未注册 System Prompt；
2. 拦截未经 PromptSecurityGuard / ContentModerationEngine 消毒处理的直接 LLM 调用；
3. 一旦发现绕过统一 Prompt 治理的违规代码，输出详细行号及修复建议并以 exit code 1 阻断编译。
"""

import sys
import os
import re


def is_comment_line(line_str):
    """判断当前行是否为注释行"""
    stripped = line_str.strip()
    return stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*")


def check_line_violations(idx, line):
    """检测单行文本中的硬编码 Prompt 及定界符逃逸违规"""
    violations = []
    if re.search(r'generate\(\s*prompt:\s*"(?:You are|Act as|Ignore)', line):
        violations.append((idx, "硬编码内联 System Prompt，必须下沉集中注册至 GlobalPromptRegistry"))

    if "<|im_start|>" in line or "### System:" in line:
        if "PromptSecurityGuard" not in line and "PromptSanitizer" not in line and "GlobalPromptRegistry" not in line:
            violations.append((idx, "定界符 Token 硬编码，必须通过 PromptSecurityGuard 进行沙箱隔离与转义"))

    return violations


def audit_file(file_path):
    """对单个 Swift 文件进行代码行级别的提示词治理与安全审计"""
    if "PromptSecurityGuard.swift" in file_path or "PromptSanitizer.swift" in file_path:
        return []

    violations = []
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    for idx, line in enumerate(lines, 1):
        if is_comment_line(line):
            continue
        violations.extend(check_line_violations(idx, line))

    return violations


def main():
    """主入口：扫描 Sources/ 目录并运行 Prompt 治理门禁检查"""
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    sources_dir = os.path.join(project_root, "Sources")

    total_violations = 0
    print("🔍 [Prompt Audit] 开始 Prompt 治理与安全合规 CI 门禁检查...")

    for root, _, files in os.walk(sources_dir):
        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                file_violations = audit_file(file_path)
                if file_violations:
                    rel_path = os.path.relpath(file_path, project_root)
                    for line_num, msg in file_violations:
                        print(f"{rel_path}:{line_num}: error: [Prompt Audit] {msg}")
                        total_violations += 1

    if total_violations > 0:
        print(f"\n❌ [Prompt Audit] 发现 {total_violations} 处违反 Prompt 治理规范的代码。编译阻断。")
        sys.exit(1)
    else:
        print("✅ [Prompt Audit] 提示词治理与安全合规门禁检查通过。")
        sys.exit(0)


if __name__ == "__main__":
    main()
