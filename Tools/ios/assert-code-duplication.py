#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==============================================================================
#  assert-code-duplication.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/28.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools] 静态合规审计门禁
#  核心职责：集成业界标准工具。优先检测并调用 jscpd 或 PMD-CPD 进行跨语言重复代码扫描，
#            若工具不存在，则优雅降级（Fallback）至本地原生滑动窗口哈希算法。
# ==============================================================================

import os
import sys
import re
import hashlib
import shutil
import subprocess

# 阈值与配置常量
# 判定为重复代码块所需的最小连续雷同代码行数（低于此行数忽略不计，防止误报）
MIN_DUPLICATE_LINES = 10
# 判定为重复代码块中包含的最小不同 Token 种类数量（防止全是括号或空 return 导致误报）
MIN_UNIQUE_TOKENS = 3
# 审计报告中展示的重复代码片段的最大展示行数
SAMPLE_SNIPPET_LINES = 3
# 扫描时需要过滤的非源码目录集合
EXCLUDE_DIRS = {'.git', '.build', 'build', 'Pods', 'DerivedData', '__pycache__', 'env'}
# 目标审计的源文件后缀名集合
TARGET_EXTENSIONS = {'.swift', '.py', '.sh'}


class CodeDuplicationAuditor:
    """
    重复代码审计器：采用滑动窗口算法，剔除注释与空行干扰，识别逻辑一致的重复代码段。
    """

    def __init__(self, root_dir='.'):
        self.root_dir = root_dir
        self.window_map = {}

    def _normalize_line(self, line):
        """
        清洗单行代码：剔除所有空白与单行注释，便于语义级别的精准相似性比对。
        """
        line = re.split(r'//|#', line)[0]
        line = "".join(line.split())
        return line

    def _load_and_clean_file(self, path):
        """
        读取源文件并进行清洗。
        """
        cleaned_lines = []
        in_block_comment = False
        
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            for idx, line in enumerate(f, 1):
                if '/*' in line:
                    in_block_comment = True
                if in_block_comment:
                    if '*/' in line:
                        in_block_comment = False
                    continue
                
                norm = self._normalize_line(line)
                if not norm or norm in ('{', '}', '(', ')', '[', ']'):
                    continue
                    
                cleaned_lines.append((idx, line.rstrip(), norm))
        return cleaned_lines

    def _process_file_windows(self, path, lines_info):
        """
        以滑动窗口方式分析单文件并塞入哈希对应表。
        """
        for i in range(len(lines_info) - MIN_DUPLICATE_LINES + 1):
            window = lines_info[i : i + MIN_DUPLICATE_LINES]
            norm_tuple = tuple(item[2] for item in window)
            
            # 避免对过短且单调的重复块做误报
            if len(set(norm_tuple)) < MIN_UNIQUE_TOKENS:
                continue
                
            window_hash = hashlib.md5("".join(norm_tuple).encode('utf-8')).hexdigest()
            
            if window_hash not in self.window_map:
                self.window_map[window_hash] = []
            self.window_map[window_hash].append((path, window))

    def _filter_overlapping_duplicates(self, occurrences):
        """
        过滤去重同一个文件内相邻重叠的滑动窗口误报。
        """
        unique_occurrences = []
        for filepath, window in occurrences:
            start_line = window[0][0]
            overlap = False
            for u_path, u_window in unique_occurrences:
                u_start = u_window[0][0]
                if filepath == u_path and abs(start_line - u_start) < MIN_DUPLICATE_LINES:
                    overlap = True
                    break
            if not overlap:
                unique_occurrences.append((filepath, window))
        return unique_occurrences

    def audit(self):
        """
        遍历并审计全工程符合扩展名的源码文件（原生滑动窗口算法）。
        """
        for root, dirs, files in os.walk(self.root_dir):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith('.')]
            for f in files:
                ext = os.path.splitext(f)[1]
                if ext not in TARGET_EXTENSIONS:
                    continue
                
                path = os.path.join(root, f)
                lines_info = self._load_and_clean_file(path)
                
                if len(lines_info) < MIN_DUPLICATE_LINES:
                    continue
                
                self._process_file_windows(path, lines_info)

        duplicates = []
        for w_hash, occurrences in self.window_map.items():
            if len(occurrences) <= 1:
                continue
                
            unique_occurrences = self._filter_overlapping_duplicates(occurrences)
            if len(unique_occurrences) > 1:
                duplicates.append(unique_occurrences)
                
        return duplicates


def try_jscpd():
    """
    优先检测并运行 jscpd。
    """
    jscpd_bin = shutil.which("jscpd")
    if not jscpd_bin:
        return False
        
    print("\n[Code Duplication] Detected 'jscpd' in system. Running standard cross-language scan...")
    res = subprocess.run([jscpd_bin, "."], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    print(res.stdout)
    if res.stderr:
        print(res.stderr, file=sys.stderr)
    return True


def try_pmd_cpd():
    """
    降级检测并运行 PMD-CPD。
    """
    pmd_bin = shutil.which("pmd")
    if not pmd_bin:
        return False
        
    print("\n[Code Duplication] Detected 'PMD' in system. Running PMD-CPD scan...")
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("Sources\n")
        file_list_path = f.name
    res = subprocess.run([
        pmd_bin, "cpd",
        "--minimum-tokens", "50",
        "--language", "swift",
        "--file-list", file_list_path,
        "--format", "text"
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    os.unlink(file_list_path)
    print(res.stdout)
    if res.stderr:
        print(res.stderr, file=sys.stderr)
    return True


def run_fallback():
    """
    在无外部工具时，运行原生滑动窗口哈希算法做静默降级检测。
    """
    print("\n⚠️  [Code Duplication] Standard tools ('jscpd' or 'pmd') not found in system.")
    print("   To activate full AST-level scanning, it is highly recommended to run:")
    print("     - Option A (jscpd): npm install -g jscpd")
    print("     - Option B (PMD):   brew install pmd")
    print("   Now falling back to native sliding-window token hash detector...\n")
    
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
    from gatekeeper_reporter import GatekeeperReporter
    
    reporter = GatekeeperReporter("Code Duplication (Fallback)")
    auditor = CodeDuplicationAuditor()
    duplicates_list = auditor.audit()
    
    for group_idx, occurrences in enumerate(duplicates_list, 1):
        locations = []
        for file_path, window in occurrences:
            start = window[0][0]
            end = window[-1][0]
            locations.append(f"{file_path}:L{start}-{end}")
        
        loc_str = " <=> ".join(locations)
        primary_file, primary_window = occurrences[0]
        start_line = primary_window[0][0]
        
        snippet = "\n".join(f"      L{item[0]}: {item[1]}" for item in primary_window[:SAMPLE_SNIPPET_LINES])
        msg = f"Duplicate code block detected: [{loc_str}]. Sample:\n{snippet}\n      ..."
        
        reporter.add_issue(primary_file, start_line, msg, "WARNING")
        
    reporter.report()


def main():
    """主控执行流分配。"""
    if try_jscpd():
        return
        
    if try_pmd_cpd():
        return
        
    run_fallback()


if __name__ == '__main__':
    main()
