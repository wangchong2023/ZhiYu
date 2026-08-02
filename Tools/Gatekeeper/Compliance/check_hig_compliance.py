#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_hig_compliance.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/12.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/Gatekeeper] 守卫网关
#  核心职责：执行人机交互指南 (HIG) 合规性静态分析。
#           扫描 Swift 源代码中违规的固定字号、空 Accessibility Hint、UUID 动画触发器及硬编码系统颜色。
#

import os
import re
import sys

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

# 项目根目录，相对于 Tools/Gatekeeper/Compliance 目录的上一级 (退3层)
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")

# 排除扫描的文件夹
EXCLUDE_DIRS = {'.git', 'build', 'DerivedData', '.build', 'Frameworks', 'Tests', 'env', '__pycache__'}

# 排除扫描的特定文件（例如定义字体的 Typography.swift，定义图标/样式的 DesignSystem 文件）
EXCLUDE_FILES = {
    'Typography.swift',
    'Colors.swift',
    'DesignSystem.swift',
    'DesignSystem+Icons.swift',
    'IconTokens.swift',
    'Spacing.swift'
}

# 排除扫描的特定子目录路径片段（例如设计系统目录在定义底层颜色/字体时必然会有固定字号或硬编码颜色）
EXCLUDE_PATH_FRAGMENTS = [
    "Sources/Shared/DesignSystem",
    "Sources/Platforms/iOS/Widgets",
]

# HIG 推荐最低无障碍系统字号
MIN_RECOMMENDED_FONT_SIZE = 11.0

# 匹配 SwiftUI / UIKit 的系统字号调用，例如 .system(size: 14) 或 systemFont(ofSize: 12)
FONT_SIZE_PATTERNS = [
    re.compile(r'\.system\(\s*size:\s*([0-9\.]+)'),
    re.compile(r'systemFont\(\s*ofSize:\s*([0-9\.]+)'),
    re.compile(r'\.systemFont\(\s*ofSize:\s*([0-9\.]+)'),
]

# 匹配空或仅包含空格的无障碍提示，例如 .accessibilityHint("")
EMPTY_ACC_HINT_PATTERN = re.compile(r'\.accessibilityHint\(\s*"\s*"\s*\)')

# 匹配以 UUID() 作为动画触发值的模式，例如 .animation(.default, value: UUID())
UUID_ANIMATION_PATTERN = re.compile(r'value:\s*UUID\(\)')

# 匹配硬编码系统颜色的模式，例如 .foregroundColor(.red) 或 Color.blue
HARDCODED_COLOR_PATTERNS = [
    re.compile(r'\.foregroundColor\(\s*\.(red|blue|green|yellow|orange|pink|purple|gray|black|white|cyan|mint|indigo|teal|brown)\)'),
    re.compile(r'\bColor\.(red|blue|green|yellow|orange|pink|purple|gray|black|white|cyan|mint|indigo|teal|brown)\b'),
    re.compile(r'\bUIColor\.(red|blue|green|yellow|orange|pink|purple|gray|black|white|cyan|mint|indigo|teal|brown)\b')
]

# ==============================================================================
# MARK: - 核心扫描逻辑
# ==============================================================================

def should_skip_file(file_path):
    """
    判断是否需要跳过当前 Swift 文件的审计。
    
    参数:
        file_path (str): 文件的绝对路径
        
    返回:
        bool: True 表示跳过，False 表示需要审计
    """
    # 检查文件名是否在白名单排除列表中
    file_name = os.path.basename(file_path)
    if file_name in EXCLUDE_FILES:
        return True
        
    # 检查路径是否包含排除片段
    rel_path = os.path.relpath(file_path, PROJECT_DIR)
    for frag in EXCLUDE_PATH_FRAGMENTS:
        if frag in rel_path:
            return True
            
    return False


def _check_font_size(clean_line, is_exempt, issues):
    """
    辅助审计：检查字号是否为固定硬编码字号，是否低于 HIG 最低可读阈值。
    """
    for pattern in FONT_SIZE_PATTERNS:
        match = pattern.search(clean_line)
        if match:
            try:
                size_val = float(match.group(1))
                if size_val < MIN_RECOMMENDED_FONT_SIZE:
                    if not is_exempt:
                        issues.append({
                            "type": "error",
                            "message": f"字号硬编码 {size_val}pt 低于 HIG 推荐的最低可读字号 11pt。请使用 Typography 语义样式，或在行尾添加 '// Dynamic Type' 进行豁免。"
                        })
                else:
                    if not is_exempt:
                        issues.append({
                            "type": "warning",
                            "message": f"检测到硬编码字号 {size_val}pt。建议使用 Typography 语义字体样式以适配无障碍放大，或在行尾添加 '// Dynamic Type' 忽略此警告。"
                        })
            except ValueError:
                pass


def _check_empty_accessibility_hint(clean_line, issues):
    """
    辅助审计：检查是否使用空的 accessibilityHint。
    """
    if EMPTY_ACC_HINT_PATTERN.search(clean_line):
        issues.append({
            "type": "error",
            "message": "检测到空的 accessibilityHint 描述。空 hint 会干扰旁白 (VoiceOver) 的朗读，请传入有实际意义的本地化字符串，或直接省略该修饰器。"
        })


def _check_uuid_animation(clean_line, issues):
    """
    辅助审计：检查是否使用 UUID() 作为动画触发值。
    """
    if UUID_ANIMATION_PATTERN.search(clean_line):
        issues.append({
            "type": "error",
            "message": "检测到使用 UUID() 作为动画的 trigger value。这会导致每次 View 重绘时都触发无意义的动画，严重影响 UI 帧率。请使用稳定的 @State 绑定状态值。"
        })


def _check_hardcoded_colors(clean_line, issues):
    """
    辅助审计：检查是否使用了硬编码系统颜色。
    """
    for pattern in HARDCODED_COLOR_PATTERNS:
        match = pattern.search(clean_line)
        if match:
            issues.append({
                "type": "warning",
                "message": f"检测到硬编码系统颜色 '{match.group(0)}'。为保证深色模式/自定义主题的完美适配，建议使用 Color.theme 语义 Token。"
            })
            break


def check_swift_line(line_content, line_no, file_path):
    """
    对 Swift 源代码的单行进行 HIG 规则匹配。
    
    参数:
        line_content (str): 未去掉两端空格的原始行内容
        line_no (int): 当前行号 (1-indexed)
        file_path (str): 文件路径，用于打印警告/错误信息
        
    返回:
        list: 包含发现的错误或警告信息的字典列表
    """
    issues = []
    
    # 1. 过滤和识别注释豁免
    is_exempt = '// Dynamic Type' in line_content
    
    # 移除行内普通注释以防误判，但要保留代码前部
    clean_line = line_content
    if '//' in clean_line:
        # 如果不是 '// Dynamic Type'，就把注释部分切掉
        clean_line = clean_line.split('//')[0]
            
    clean_line = clean_line.strip()
    if not clean_line:
        return issues

    # 2. 规则检测: 固定字号与字号下限
    _check_font_size(clean_line, is_exempt, issues)

    # 3. 规则检测: 空 accessibilityHint 检查
    _check_empty_accessibility_hint(clean_line, issues)

    # 4. 规则检测: UUID() 作为动画触发器检查
    _check_uuid_animation(clean_line, issues)

    # 5. 规则检测: 硬编码系统颜色检查
    _check_hardcoded_colors(clean_line, issues)

    return issues


def _check_file_form_theme(file_path, content, warnings_list):
    """检查 Swift 视图中使用的 Form 是否配置了 .scrollContentBackground(.hidden) 与 DesignSystem 主题染色"""
    if "Form {" in content:
        if ".scrollContentBackground(.hidden)" not in content and "scrollContentBackground" not in content:
            warnings_list.append({
                "line": 1,
                "message": "检测到视图中使用原生 Form 但未配置 .scrollContentBackground(.hidden)，可能导致深色模式背景呈现退化灰色。建议配置 DesignSystem 沉浸式背景。"
            })
        if "Color.app" not in content and ".tint(" not in content and "Color.theme" not in content:
            warnings_list.append({
                "line": 1,
                "message": "检测到视图中使用原生 Form 但未指定 DesignSystem 主题色 (.tint(Color.appAccent) 或 Color.appBackground)，可能导致系统默认蓝色/灰色退化。"
            })


def _audit_file_hig(file_path):
    """
    审计单个 Swift 文件并返回包含的 (errors, warnings) 计数。
    """
    errors = 0
    warnings = 0
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            full_content = f.read()
            f.seek(0)
            lines = f.readlines()
    except Exception as e:
        # 文件读取失败时，输出编译错误阻断
        print(f"{file_path}:1: error: [HIG Compliance] 无法读取文件进行静态审计: {str(e)}", file=sys.stderr)
        return 1, 0

    file_warnings = []
    _check_file_form_theme(file_path, full_content, file_warnings)
    for fw in file_warnings:
        log_msg = f"{file_path}:{fw['line']}: warning: [HIG Compliance] {fw['message']}"
        print(log_msg)
        warnings += 1

    for index, line in enumerate(lines, 1):
        line_issues = check_swift_line(line, index, file_path)
        for issue in line_issues:
            # 格式化输出为符合 Xcode 诊断格式的报错/警告行
            log_type = issue["type"]
            log_msg = f"{file_path}:{index}: {log_type}: [HIG Compliance] {issue['message']}"
            
            if log_type == "error":
                print(log_msg, file=sys.stderr)
                errors += 1
            else:
                print(log_msg)
                warnings += 1
    return errors, warnings


def scan_files():
    """
    遍历 Sources 目录下的 Swift 文件，执行逐行审计，并输出 Xcode 兼容的错误与警告格式。
    
    返回:
        tuple: (error_count, warning_count)
    """
    total_errors = 0
    total_warnings = 0
    scanned_files_count = 0

    print("🔍 [HIG Compliance] 开始执行 HIG 视觉与无障碍合规性静态审计...")

    if not os.path.exists(SOURCES_DIR):
        print(f"⚠️ [HIG Compliance] 未发现 Sources 目录，跳过审计: {SOURCES_DIR}")
        return 0, 0

    for root, dirs, files in os.walk(SOURCES_DIR):
        # 排除无需扫描的目录
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        
        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                
                if should_skip_file(file_path):
                    continue
                    
                scanned_files_count += 1
                
                f_errors, f_warnings = _audit_file_hig(file_path)
                total_errors += f_errors
                total_warnings += f_warnings

    print(f"📊 [HIG Compliance] 审计完成。共扫描了 {scanned_files_count} 个 Swift 文件。")
    print(f"📊 [HIG Compliance] 结果汇总: {total_errors} 个错误，{total_warnings} 个警告。")
    
    return total_errors, total_warnings



# ==============================================================================
# MARK: - 程序主入口
# ==============================================================================

def main():
    """
    主程序，执行扫描并根据错误数熔断退出。
    """
    errors, warnings = scan_files()
    if errors > 0:
        print(f"🔴 [HIG Compliance] 失败: 发现 {errors} 处 HIG 合规错误。构建已熔断阻断！", file=sys.stderr)
        sys.exit(1)
    else:
        print("🟢 [HIG Compliance] 成功: 代码库 HIG 静态审计通过（允许存在警告）。")
        sys.exit(0)


if __name__ == "__main__":
    main()
