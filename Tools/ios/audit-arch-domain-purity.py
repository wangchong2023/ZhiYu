#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智宇 (ZhiYu) 领域层 (Domain Layer) 平台纯净化静态分析工具
功能说明: 
1. 物理扫描 Sources/Domain 目录下的所有 Swift 源代码。
2. 强制拦截任何违规导入平台特有依赖库（如 UIKit, AppKit, ActivityKit, WatchKit）的行为。
3. 强制拦截在领域层直接使用 #if os 等条件编译宏进行平台分支的行为。
4. 兼容 Xcode 编译器报错输出格式，如有违规在 Xcode 编译时直接以 error 标红并阻断构建。
"""

import os
import sys
import re

# ==================== 配置常量 ====================
# 项目根目录，相对于 Tools/ios 目录的上一级 (退2层)
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOMAIN_DIR = os.path.join(PROJECT_DIR, "Sources", "Domain")

# 严禁在 L1.5 领域层导入的平台相关包列表
FORBIDDEN_IMPORTS = ["UIKit", "AppKit", "ActivityKit", "WatchKit"]

# 拦截平台条件编译宏的正则表达式
OS_MACRO_PATTERNS = [
    re.compile(r"#if\s+os\s*\("),
    re.compile(r"#if\s+!os\s*\("),
    re.compile(r"#elseif\s+os\s*\(")
]

def check_file_purity(file_path):
    """
    检查单个 Swift 文件的平台纯净化。
    
    参数:
        file_path (str): Swift 文件的绝对路径。
        
    返回:
        list: 包含错误详情字典的列表。如果合规，返回空列表。
    """
    errors = []
    
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        # 如果读取失败，也视为一次严重阻断错误
        errors.append({
            "line": 1,
            "message": f"无法读取文件进行纯净性审计: {str(e)}"
        })
        return errors

    lines = content.split("\n")
    for index, line in enumerate(lines, 1):
        # 移除单行注释，避免把注释里的文字误判为违规
        clean_line = re.sub(r'//.*', '', line).strip()
        
        # 1. 检查禁止的平台导入 (import X)
        if clean_line.startswith("import "):
            imported_package = clean_line.split()[1].replace(";", "")
            # 处理带 @preconcurrency 的情况，提取干净的包名
            imported_package = imported_package.split(".")[-1]
            if imported_package in FORBIDDEN_IMPORTS:
                errors.append({
                    "line": index,
                    "message": f"违规导入平台相关依赖包 '{imported_package}'。L1.5 领域层必须保持绝对的平台无关性。"
                })
        
        # 2. 检查 #if os 宏的使用
        for pattern in OS_MACRO_PATTERNS:
            if pattern.search(clean_line):
                errors.append({
                    "line": index,
                    "message": "禁止在领域层直接使用 #if os 进行平台特化分支。平台相关能力必须定义为协议，并由外层下沉实现注入。"
                })
                break

    return errors

def main():
    """
    主入口程序。执行全量扫描并输出报告。
    """
    print("🔍 [Domain Purity] 开始执行领域层平台纯净化静态审计...")
    
    if not os.path.exists(DOMAIN_DIR):
        print(f"⚠️ [Domain Purity] 未发现 Domain 目录，跳过审计: {DOMAIN_DIR}")
        sys.exit(0)

    total_files = 0
    violations_count = 0

    for root, _, files in os.walk(DOMAIN_DIR):
        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                total_files += 1
                
                # 执行纯净性静态校验
                file_errors = check_file_purity(file_path)
                
                if file_errors:
                    for err in file_errors:
                        # 格式化输出为 Xcode 兼容的编译器错误标准，使构建能当场阻断并显示红牌
                        print(f"{file_path}:{err['line']}: error: [Domain Purity Violation] {err['message']}", file=sys.stderr)
                        violations_count += 1

    print(f"📊 [Domain Purity] 审计完成。共扫描了 {total_files} 个 Swift 文件。")
    
    if violations_count > 0:
        print(f"🔴 [Domain Purity] 失败: 发现 {violations_count} 处领域层不纯净性违规。构建已熔断阻断！", file=sys.stderr)
        sys.exit(1)
    else:
        print("🟢 [Domain Purity] 成功: 领域层 100% 物理通过平台纯净化静态审计！")
        sys.exit(0)

if __name__ == "__main__":
    main()
