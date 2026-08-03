#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-code-storage-constants.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/14.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：监控 Swift 代码中是否直接使用了硬编码的物理表名、字段名或手写 SQL，而没有使用 AppConstants.Storage。
#

import os
import re
import sys

def _check_physical_fields_in_line(line, line_no, column_pattern, auto_pk_pattern, pk_array_pattern, issues):
    """
    辅助审计：检测单行 Swift 代码是否含有硬编码物理字段。
    """
    if column_pattern.search(line):
        issues.append((line_no, f"硬编码的物理字段 (t.column): {line}"))
    if auto_pk_pattern.search(line):
        issues.append((line_no, f"硬编码的物理字段 (t.autoIncrementedPrimaryKey): {line}"))
    if pk_array_pattern.search(line):
        issues.append((line_no, f"硬编码的物理字段 (t.primaryKey): {line}"))

def _check_sql_table_in_line(line, line_no, sql_table_pattern, ignore_words, issues):
    """
    辅助审计：检测单行 Swift 代码是否含有硬编码的原始 SQL 表名。
    """
    if 'sql:' in line or 'db.execute(' in line or 'Row.fetchAll(' in line:
        # 寻找不含字符串插值的 SQL 查询
        if r'\(' not in line:
            match = sql_table_pattern.search(line)
            if match:
                table_name = match.group(2).lower()
                if table_name not in ignore_words and not table_name.startswith('sqlite_'):
                    issues.append((line_no, f"硬编码的 SQL 表名 '{match.group(2)}': {line}"))

def check_file(filepath):
    """
    检查单个 Swift 文件的内容。审计其是否直接使用了硬编码的物理表字段
    （例如 t.column("...") 或 t.autoIncrementedPrimaryKey("...") 等）或者硬编码的原始 SQL 表名。
    如果发现违规硬编码，将行号与错误信息添加到 issues 列表中并返回。
    """
    issues = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return issues
        
    # 物理字段正则表达式规则
    column_pattern = re.compile(r't\.column\(\s*"\w+"')
    auto_pk_pattern = re.compile(r't\.autoIncrementedPrimaryKey\(\s*"\w+"\)')
    pk_array_pattern = re.compile(r't\.primaryKey\(\s*\[\s*"\w+"')
    
    # 硬编码 SQL 正则表达式规则
    # 匹配 SQL 关键字后跟着的表名（不带 \()
    sql_table_pattern = re.compile(r'(?i)\b(FROM|INTO|UPDATE|JOIN|TABLE)\s+(\w+)\b')
    ignore_words = {'select', 'insert', 'update', 'delete', 'where', 'set', 'or', 'ignore', 'replace', 'into', 'from', 'table', 'if', 'not', 'exists', 'sqlite_master'}
    
    for i, line in enumerate(lines):
        line = line.strip()
        
        # 跳过注释行
        if line.startswith('//'):
            continue
            
        # 检查物理字段
        _check_physical_fields_in_line(line, i + 1, column_pattern, auto_pk_pattern, pk_array_pattern, issues)
            
        # 检查 SQL 表名
        _check_sql_table_in_line(line, i + 1, sql_table_pattern, ignore_words, issues)
                        
    return issues

def main():
    """
    主程序入口。遍历 Sources 目录下的所有 Swift 代码文件（排除豁免白名单文件），
    调用 check_file 校验物理表字段和硬编码 SQL，若有发现则记录到门禁报告中。
    """
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
    from gatekeeper_reporter import GatekeeperReporter
    
    reporter = GatekeeperReporter("Storage Constants Audit")
    sources_dir = "Sources"
    
    # 白名单排除：允许定义常量或 Scheme 定义的文件
    allow_list = [
        "AppConstants.swift",
    ]
    
    for root, dirs, files in os.walk(sources_dir):
        for file in files:
            if file.endswith('.swift'):
                if file in allow_list:
                    continue
                filepath = os.path.join(root, file)
                issues = check_file(filepath)
                for line, msg in issues:
                    reporter.add_issue(
                        filepath=filepath,
                        line_no=line,
                        message=msg,
                        level="ERROR"
                    )
                    
    reporter.report()

if __name__ == "__main__":
    main()
