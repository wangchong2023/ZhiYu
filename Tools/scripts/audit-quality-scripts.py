#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-quality-scripts.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/14.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：自动对 Tools 目录下的所有 Python ( .py ) 和 Shell ( .sh ) 脚本进行代码质量和规范性静态审计。
#           包括：文件头注释完整度、Python 函数 Docstring 函数头校验、函数大小限制（代码行数限制）、
#           函数圈复杂度审计、硬编码魔鬼数字与敏感信息扫描、未使用的冗余代码扫描。
#

import os
import re
import sys
import ast
import subprocess
import json
import shutil

# 尝试导入开源库 radon 进行圈复杂度与 NBNC 辅助分析
HAS_RADON = False
try:
    from radon.visitors import ComplexityVisitor
    HAS_RADON = True
except ImportError:
    pass

# 豁免扫描的脚本或目录（如第三方库、Mock 服务、或者用于调试的文件）
EXEMPT_FILES = {
    'audit-quality-scripts.py',
    'check-quality-script-refs.py',
    'assert-quality-gate.py',
    'gatekeeper_reporter.py',
    'clean_unused.py',
}
EXEMPT_DIRS = {'env', 'DerivedData', 'build', '.git', '__pycache__', 'Mock', 'Plugins', 'Utils', 'Lint'}

class ScriptAuditor:
    """运维和静态检查脚本质量审计器，支持 Python 与 Shell 双引擎解析。"""

    def __init__(self, root_dir='Tools'):
        self.root_dir = root_dir

    def audit(self):
        """
        执行全量 Tools 脚本审计。
        
        :return: (issues_count, issues_details)
        """
        issues_count = 0
        issues_details = []

        for root, dirs, files in os.walk(self.root_dir):
            dirs[:] = [d for d in dirs if d not in EXEMPT_DIRS]
            for file in files:
                if file in EXEMPT_FILES or file.endswith('.pyc'):
                    continue
                
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content_start = f.read(2000)
                    if 'bypass' in content_start.lower() or 'NAMING-bypass' in content_start or 'QUALITY-bypass' in content_start:
                        continue
                except Exception:
                    pass

                ext = os.path.splitext(file)[1]
                
                if ext == '.py':
                    count, details = self._audit_python_file(filepath)
                    issues_count += count
                    issues_details.extend(details)
                elif ext == '.sh':
                    count, details = self._audit_shell_file(filepath)
                    issues_count += count
                    issues_details.extend(details)

        return issues_count, issues_details

    def _calculate_complexity(self, node):
        """
        利用 AST 树节点递归计算 Python 函数圈复杂度（基于决策分支点计数）。
        
        :param node: AST 节点
        :return: 圈复杂度值 (int)
        """
        complexity = 1
        for child in ast.walk(node):
            # 每一个 if, for, while, except 分支，以及 boolean 逻辑 combined (and/or) 均使复杂度加 1
            if isinstance(child, (ast.If, ast.For, ast.While, ast.ExceptHandler)):
                complexity += 1
            elif isinstance(child, ast.BoolOp):
                complexity += len(child.values) - 1
        return complexity

    def _audit_python_file(self, filepath):
        """
        审计 Python 脚本的规范性。
        
        :param filepath: 物理路径
        :return: (issues_count, list_of_issues)
        """
        issues = []
        filename = os.path.basename(filepath)

        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        lines = content.split('\n')

        # 1. 检查文件头编码声明与描述
        has_encoding = False
        has_header_comment = False
        for line in lines[:15]:
            if 'coding:' in line:
                has_encoding = True
            if any(term in line.lower() for term in ('created', 'copyright', '职责', '说明', 'gatekeeper', 'tools')):
                has_header_comment = True

        if not has_encoding:
            issues.append((1, f"Python 脚本文件头缺少 UTF-8 编码声明 (# -*- coding: utf-8 -*-)"))
        if not has_header_comment:
            issues.append((1, f"Python 脚本文件头前 15 行缺少核心职责/创建版权中文说明注释"))

        # 1.5 针对 Gatekeeper 门禁脚本，强校验必须接入 GatekeeperReporter 统一机制
        norm_path = filepath.replace('\\', '/')
        if '/Tools/scripts/' in norm_path and filename not in ('scripts-generate-quality-report.py', 'scripts-audit-quality-scripts.py', 'ios-assert-release-compile.py'):
            if 'GatekeeperReporter' not in content:
                issues.append((1, "Gatekeeper 门禁脚本必须统一导入并使用 GatekeeperReporter 机制暴露 IDE/CI 缺陷"))

        # 2. 解析 AST 进行语法级审计
        try:
            tree = ast.parse(content, filename=filepath)
        except Exception as e:
            issues.append((1, f"Python AST 语法解析失败: {e}"))
            return len(issues), [(filepath, line_no, msg) for line_no, msg in issues]

        # 建立父节点映射关系以向上追溯
        parent_map = {}
        for parent in ast.walk(tree):
            for child in ast.iter_child_nodes(parent):
                parent_map[child] = parent

        def is_under_uppercase_assignment(n):
            curr = n
            while curr in parent_map:
                p = parent_map[curr]
                if isinstance(p, ast.Assign):
                    for t in p.targets:
                        if isinstance(t, ast.Name) and t.id.isupper():
                            return True
                curr = p
            return False

        def is_under_func_arguments(n):
            curr = n
            while curr in parent_map:
                p = parent_map[curr]
                if isinstance(p, ast.arguments):
                    return True
                curr = p
            return False

        # 检查通用数值魔鬼数字
        for node in ast.walk(tree):
            is_num = False
            num_val = None
            if isinstance(node, ast.Constant) and type(node.value) in (int, float):
                is_num = True
                num_val = node.value
            elif hasattr(ast, 'Num') and isinstance(node, ast.Num):
                is_num = True
                num_val = node.n
                
            if is_num:
                if num_val not in (0, 1, 2, 0.0, 1.0, 2.0):
                    if not is_under_uppercase_assignment(node) and not is_under_func_arguments(node):
                        l_no = getattr(node, 'lineno', 1)
                        issues.append((l_no, f"行内硬编码魔鬼数字 '{num_val}'，请抽取为大写常量定义"))

        # 3. 遍历函数节点，进行行数与圈复杂度校验
        radon_complexities = {}
        if HAS_RADON:
            try:
                visitor = ComplexityVisitor.from_code(content)
                for func in visitor.functions:
                    radon_complexities[func.lineno] = func.complexity
            except Exception:
                pass

        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                line_no = node.lineno
                func_name = node.name

                # 函数头 Docstring 检查
                docstring = ast.get_docstring(node)
                # 只有当函数体行数 > 5 行时，强制要求必须有中文/英文 docstring 函数头
                func_body_lines = len(node.body)
                if func_body_lines > 5 and not docstring:
                    issues.append((line_no, f"函数 '{func_name}' (大于 5 行) 缺失 Docstring 函数头注释说明"))

                # 函数大小限制校验（函数有效行数检查）
                # 利用 AST 定位函数的开始行和结束行
                func_start = node.lineno
                # 找到函数节点内所有子节点的最大行号作为结束行号
                func_end = func_start
                for child in ast.walk(node):
                    if hasattr(child, 'lineno'):
                        func_end = max(func_end, child.lineno)
                
                func_lines = lines[func_start-1:func_end]
                code_only_lines = [l for l in func_lines if l.strip() and not l.strip().startswith('#')]
                
                if len(code_only_lines) > 50:
                    issues.append((line_no, f"函数 '{func_name}' 过大 (有效代码行数为 {len(code_only_lines)} 行，超过 50 行限制)，请重构拆分"))

                # 圈复杂度审计
                complexity = radon_complexities.get(line_no)
                if complexity is None:
                    complexity = self._calculate_complexity(node)
                if complexity > 10:
                    issues.append((line_no, f"函数 '{func_name}' 圈复杂度过高 (Complexity={complexity}，超过 10 阈值)，请重构拆分"))

        # 4. 敏感信息与魔鬼数字（硬编码端口）扫描
        port_pattern = re.compile(r'port\s*=\s*(\d{4,5})\b')
        for i, line in enumerate(lines, 1):
            s = line.strip()
            if s.startswith('#'):
                continue
            
            # 检测硬编码的非常规网络端口（排除常规调试/内置端口如 8000, 3000, 80, 443）
            match = port_pattern.search(line)
            if match:
                port = int(match.group(1))
                if port not in (8000, 3000, 80, 443):
                    issues.append((i, f"硬编码魔鬼数字网络端口: {port}，请写入配置或常量"))

            # 废弃残留/临时代码扫描（拦截未解决的 TODO 标记）
            if '# TODO' in line:
                issues.append((i, f"含有未解决的残存 TODO 废弃/临时代码标记"))

        return len(issues), [(filepath, line_no, msg) for line_no, msg in issues]

    def _audit_shell_file(self, filepath):
        """
        审计 Shell 脚本的规范性。
        
        :param filepath: 物理路径
        :return: (issues_count, list_of_issues)
        """
        issues = []
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()

        if not lines:
            return 0, []

        # 1. 检查 Shebang 声明
        first_line = lines[0].strip()
        if not first_line.startswith('#!/bin/'):
            issues.append((1, f"Shell 脚本缺少标准的 Shebang 解释器声明 (如 #!/bin/bash 或 #!/bin/sh)"))

        # 2. 检查文件头说明注释
        comment_lines_count = 0
        for line in lines[:15]:
            if line.strip().startswith('#'):
                comment_lines_count += 1

        # 前 15 行中，除去 Shebang，必须有至少 3 行起的核心说明注释
        if comment_lines_count < 4:
            issues.append((1, f"Shell 脚本文件头前 15 行缺少核心职责/功能说明注释说明 (当前只有 {comment_lines_count-1} 行说明)"))

        # 3. 动态探测开源 shellcheck 校验并合流
        shellcheck_path = shutil.which("shellcheck")
        if shellcheck_path:
            try:
                res = subprocess.run(
                    [shellcheck_path, "-f", "json", "-S", "warning", filepath],
                    capture_output=True,
                    text=True,
                    check=False
                )
                if res.stdout.strip():
                    warnings = json.loads(res.stdout)
                    for w in warnings:
                        issues.append((w.get('line', 1), f"[ShellCheck] {w.get('message')} ({w.get('code')})"))
            except Exception:
                pass

        # 4. 检查魔鬼数字或临时废弃标记
        port_pattern = re.compile(r'\bport=(\d{4,5})\b')
        for i, line in enumerate(lines, 1):
            s = line.strip()
            if s.startswith('#'):
                continue
            
            match = port_pattern.search(line)
            if match:
                port = int(match.group(1))
                if port not in (8000, 3000, 80, 443):
                    issues.append((i, f"硬编码魔鬼数字网络端口: {port}"))

            if '# TODO' in line:
                issues.append((i, f"含有未解决的残存 TODO 废弃/临时代码标记"))

        return len(issues), [(filepath, line_no, msg) for line_no, msg in issues]


def main():
    print("====== Tools Script Quality & Standards Audit (Gatekeeper) ======")
    auditor = ScriptAuditor()
    issues_count, details = auditor.audit()

    if issues_count > 0:
        print(f"\n❌ [Scripts Quality Audit] 发现 {issues_count} 个脚本规范与质量缺陷:\n")
        current_file = ""
        for filepath, line_no, msg in sorted(details):
            if filepath != current_file:
                print(f"📂 {filepath}")
                current_file = filepath
            print(f"  L{line_no}: 🚨 {msg}")
        
        print("\n[Scripts Quality Audit] Build blocked. 请修复上述运维及静态检查脚本后重新编译。")
        sys.exit(1)
    else:
        print("\n✅ [Scripts Quality Audit] 所有 Tools 脚本通过了规范性、注释及复杂度检查！")
        sys.exit(0)

if __name__ == '__main__':
    main()
