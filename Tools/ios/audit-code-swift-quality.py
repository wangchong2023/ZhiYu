#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-code-swift-quality.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/14.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：自动对 Sources/ 目录下的 Swift 业务代码进行函数长度、注释完备性及禁止引入 swiftlint 禁用指令的卡点审计。
#           卡口规则：
#           1. Swift 文件前 15 行必须含有“系统层级”与“核心职责”的中文说明。
#           2. 若函数有效代码行数 (NBNC) 超过 30 行，必须在其上方配置注释。
#

import os
import re
import sys
from pathlib import Path

# 顶层审计常量约束
SOURCES_DIR = "Sources"
MAX_HEADER_LINES = 15
MIN_NBNC_FOR_COMMENT = 30
MAX_OFFSET_FOR_COMMENT = 3
EXIT_CODE_ERROR = 1
EXIT_CODE_SUCCESS = 0
FUNC_KEYWORD_LEN = 5

# 排除目录与特定路径
EXCLUDE_DIRS = {'.git', 'build', 'DerivedData', '.build', 'Frameworks', 'Tests', 'env'}
EXCLUDE_PATH_KEYWORD = "Localization"

# 匹配 Swift 函数声明的正则
FUNC_PATTERN = re.compile(
    r'\b(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+|override\s+|static\s+|class\s+)*func\s+(\w+)\b'
)

def find_closure_end(content: str, start_index: int) -> int:
    """
    匹配成对的大括号以确定函数体的边界。
    
    :param content: 文件全文内容
    :param start_index: 第一个左大括号的索引位置
    :return: 匹配的右大括号索引位置，找不到则返回 -1
    """
    depth = 1
    i = start_index
    length = len(content)
    while i < length and depth > 0:
        char = content[i]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        i += 1
    return i - 1 if depth == 0 else -1

def check_has_comment(lines: list, func_line_no: int) -> bool:
    """
    自函数行向上回溯检查是否有有效注释，支持跳过 Swift 装饰器属性（以 @ 开头）。
    
    :param lines: 文件各行内容列表
    :param func_line_no: 函数声明行号（1-indexed）
    :return: 是否包含有效注释
    """
    # 允许回溯的行数范围
    for offset in range(1, MAX_OFFSET_FOR_COMMENT + 1):
        prev_idx = func_line_no - offset - 1
        if prev_idx < 0:
            break
        prev_line = lines[prev_idx].strip()
        
        # 匹配单行注释或多行注释结束符
        if prev_line.startswith('//') or prev_line.startswith('///') or prev_line.endswith('*/'):
            return True
            
        # 若碰到非空、且非装饰器的代码，则终止向上检查
        if prev_line and not prev_line.startswith('@'):
            break
    return False

def check_file_header(lines: list) -> bool:
    """
    校验文件头前 15 行是否含有规范描述的中文注释（如“系统层级”与“核心职责”）。
    
    :param lines: 文件各行内容列表
    :return: 文件头是否合规
    """
    has_layer = False
    has_responsibility = False
    limit = min(len(lines), MAX_HEADER_LINES)
    
    for i in range(limit):
        line = lines[i]
        if "系统层级" in line:
            has_layer = True
        if "核心职责" in line:
            has_responsibility = True
            
    return has_layer and has_responsibility

def calculate_nbnc(func_body: str) -> int:
    """
    计算函数体的有效代码行数 (NBNC)，忽略空行与注释行。
    
    :param func_body: 函数体字符串内容
    :return: 有效行数计数 (int)
    """
    body_lines = func_body.split('\n')
    nbnc_count = 0
    for line in body_lines:
        striped = line.strip()
        if not striped:
            continue
        if striped.startswith('//') or striped.startswith('/*') or striped.startswith('*'):
            continue
        nbnc_count += 1
    return nbnc_count

def _verify_function_body(content: str, match, func_start_idx: int, lines: list, func_line_no: int):
    """
    定位并校验单个函数的具体长度与注释状况。
    
    :return: (is_valid, nbnc, has_comment, err_msg)
    """
    func_name = match.group(1)
    brace_start = content.find('{', func_start_idx)
    if brace_start == -1:
        return True, 0, True, ""

    # 检查是否为没有函数体的 Protocol 声明
    next_func_idx = content.find('func ', func_start_idx + FUNC_KEYWORD_LEN)
    if next_func_idx != -1 and brace_start > next_func_idx:
        return True, 0, True, ""

    brace_end = find_closure_end(content, brace_start + 1)
    if brace_end == -1:
        return True, 0, True, ""

    func_body = content[brace_start + 1:brace_end]
    nbnc_count = calculate_nbnc(func_body)
    has_comment = check_has_comment(lines, func_line_no)

    if nbnc_count > MIN_NBNC_FOR_COMMENT and not has_comment:
        err = f"函数 '{func_name}' 长度为 {nbnc_count} 行 (> {MIN_NBNC_FOR_COMMENT} 行)，但缺少上方注释说明"
        return False, nbnc_count, has_comment, err

    return True, nbnc_count, has_comment, ""

def _run_git_diff(rel_path) -> str:
    """运行 git diff 获取当前文件修改内容"""
    import subprocess
    try:
        result = subprocess.run(
            ["git", "diff", "HEAD", "--", str(rel_path)],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass
    return ""

def _parse_diff_for_swiftlint(diff_output: str, filepath: Path) -> list:
    """解析 git diff 结果，找出新增的 swiftlint:disable 并报告行号"""
    errors = []
    current_new_line = 0
    for diff_line in diff_output.split('\n'):
        if diff_line.startswith('@@'):
            match = re.search(r'\+(\d+)', diff_line)
            if match:
                current_new_line = int(match.group(1))
            continue
        
        if diff_line.startswith('+') and not diff_line.startswith('+++'):
            if "swiftlint:disable" in diff_line:
                errors.append(f"{filepath}:{current_new_line}: error: [Comments Guard] 严禁在新增或修改的代码中引入 swiftlint:disable 禁用指令。请移除该禁用，并重构相关源码以使其合规。")
            current_new_line += 1
        elif not diff_line.startswith('-') and not diff_line.startswith('---'):
            current_new_line += 1
    return errors

def check_added_swiftlint_disable(filepath: Path) -> list:
    """
    检查指定 Swift 文件最近一次提交或修改中是否新引入了 swiftlint:disable 指令。
    
    :param filepath: 目标文件路径
    :return: 错误消息列表
    """
    try:
        rel_path = filepath.relative_to(Path.cwd())
    except Exception:
        rel_path = filepath

    diff_out = _run_git_diff(rel_path)
    if not diff_out:
        return []
    return _parse_diff_for_swiftlint(diff_out, filepath)

def audit_file(filepath: Path) -> list:
    """
    审计单个 Swift 文件是否符合规则。
    
    :param filepath: Swift 文件路径
    :return: 错误消息列表
    """
    errors = []
    try:
        content = filepath.read_text(encoding='utf-8')
    except Exception as e:
        errors.append(f"{filepath}:1: error: [Comments Guard] 读取文件失败: {e}")
        return errors

    lines = content.split('\n')
    
    # 1. 检查文件头
    if not check_file_header(lines):
        errors.append(f"{filepath}:1: error: [Comments Guard] 文件头部前 {MAX_HEADER_LINES} 行缺少 '系统层级' 或 '核心职责' 中文标识注释")

    # 2. 检查内部函数
    for match in FUNC_PATTERN.finditer(content):
        func_start_idx = match.start()
        
        # 计算行号
        char_count = 0
        func_line_no = 1
        for idx, line in enumerate(lines, 1):
            char_count += len(line) + 1
            if char_count > func_start_idx:
                func_line_no = idx
                break

        is_valid, _, _, err_msg = _verify_function_body(content, match, func_start_idx, lines, func_line_no)
        if not is_valid:
            errors.append(f"{filepath}:{func_line_no}: error: [Comments Guard] {err_msg}")

    # 3. 严禁新引入 swiftlint:disable 禁用指令
    errors.extend(check_added_swiftlint_disable(filepath))

    return errors

def main():
    """主程序入口"""
    print("====== Swift Comments & Length Audit (Gatekeeper) ======")
    root_path = Path(SOURCES_DIR)
    if not root_path.exists():
        print(f"❌ 找不到目录: {SOURCES_DIR}")
        sys.exit(EXIT_CODE_ERROR)

    all_errors = []
    for fp in root_path.rglob("*.swift"):
        # 排除指定目录和本地化相关文件
        if any(part in fp.parts for part in EXCLUDE_DIRS):
            continue
        if EXCLUDE_PATH_KEYWORD in fp.parts:
            continue

        errors = audit_file(fp)
        all_errors.extend(errors)

    if all_errors:
        print(f"\n❌ [Swift Comments Guard] 发现 {len(all_errors)} 个合规缺陷:\n", file=sys.stderr)
        for err in all_errors:
            print(err, file=sys.stderr)
        print("\n[Swift Comments Guard] Build blocked. 请修复上述 Swift 业务代码注释缺陷后重新编译。", file=sys.stderr)
        sys.exit(EXIT_CODE_ERROR)
    else:
        print("\n✅ [Swift Comments Guard] 所有 Swift 业务代码注释与文件头通过校验！")
        sys.exit(EXIT_CODE_SUCCESS)

if __name__ == '__main__':
    main()
