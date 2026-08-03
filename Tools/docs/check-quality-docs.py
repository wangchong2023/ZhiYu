#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-quality-docs.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/14.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：一站式静态审计项目文档的完整性、死链、大小写敏感一致性、陈旧废弃内容，
#           以及 Python 语法、YAML 配置格式、垃圾文件和残留临时开发脚本。
#

import os
import py_compile
import re
import sys

# 尝试导入 PyYAML 模块以做强类型语法校验，若无则使用 Fallback 简易校验
try:
    import yaml
    HAVE_YAML = True
except ImportError:
    HAVE_YAML = False

# ── 1. 静态配置与关键字定义 ──────────────────────────────────────────
CLEANUP_KEYWORDS = [
    "TODO: 待清理",
    "TODO: 待删除",
    "DEPRECATED_FLAG",
    "OBSOLETE_TEMP"
]

CORE_INDEX_FILES = [
    "AGENTS.md",
    "GEMINI.md"
]

EXCLUDE_DOC_FILES = [
    "Tools/Plugins/README_TEMPLATE.md",
    "Tools/Plugins/PLUGIN_DEVELOPMENT_GUIDE.md"
]

DIRTY_SUFFIXES = (".tmp", ".bak", "xcuserdata")
DIRTY_NAMES = (".DS_Store", "Thumbs.db", ".gitleaks.toml.bak")

DIRTY_PATTERNS = [
    re.compile(r'^check_results.*\.txt$'),
    re.compile(r'^l10n_issues.*\.log$'),
    re.compile(r'^l10n_out\.txt$')
]

ROOT_DIRTY_PY_SCRIPTS = [
    "fix_all.py",
    "fix_filterTags.py",
    "fix_l10n.py",
    "fix_l10n_errors.py",
    "fix_l10n_mismatches.py",
    "fix_magic_constants.py",
    "fix_p1.py",
    "fix_plugin_l10n.py",
    "fix_uicomponents.py",
    "replace_menu.py",
    "update_privacy.py",
    "update_strings.py",
    "update_strings2.py",
    "add_subtitles.py",
    "add_l10n_rag.py"
]

# 链接提取正则
LINK_REGEX = re.compile(r'!?\[.*?\]\((.*?)\)')
REF_LINK_REGEX = re.compile(r'^\[.*?\]:\s*([^\s#]+)')

# 顶层校验限制常量，消除魔鬼数字
MAX_HEADER_LIMIT = 15
EXIT_CODE_ERROR = 1
EXIT_CODE_SUCCESS = 0

def clean_relative_link(base_dir, relative_path):
    """
    清洗链接，返回标准化的相对路径，若为外部绝对路径则直接做物理存在性检测。
    """
    if relative_path.startswith("file://"):
        cleaned_path = relative_path.replace("file://", "")
        if cleaned_path.startswith(base_dir):
            relative_path = os.path.relpath(cleaned_path, base_dir)
        else:
            return cleaned_path, os.path.exists(cleaned_path)
            
    if "#" in relative_path:
        relative_path = relative_path.split("#")[0]
        
    return relative_path, None

def _verify_case_sensitive_path(base_dir, rel_path):
    """
    辅助校验相对路径中每一个目录/文件部分的大小写在物理磁盘上是否完全匹配。
    """
    parts = [p for p in rel_path.replace("\\", "/").split("/") if p]
    current = base_dir

    for part in parts:
        if part == ".":
            continue
        if part == "..":
            current = os.path.dirname(current)
            continue

        if not os.path.exists(current) or not os.path.isdir(current):
            return False

        try:
            children = os.listdir(current)
        except OSError:
            return False

        if part in children:
            current = os.path.join(current, part)
        else:
            return False
    return True

def check_case_sensitive_exists(file_dir, relative_path, workspace):
    """
    在任何文件系统上，严格校验相对路径的大小写是否与磁盘实际物理文件名完全匹配。
    """
    if "superpowers" in relative_path:
        return True

    if relative_path.startswith("file://"):
        rel_path, quick_check = clean_relative_link(workspace, relative_path)
        if quick_check is not None:
            return quick_check
        base_dir = workspace
    elif relative_path.startswith("/"):
        rel_path = relative_path.lstrip("/")
        base_dir = workspace
    else:
        rel_path = relative_path
        base_dir = file_dir

    if "#" in rel_path:
        rel_path = rel_path.split("#")[0]

    if not rel_path:
        return True

    return _verify_case_sensitive_path(base_dir, rel_path)

def parse_markdown_links(file_path):
    """
    解析 Markdown 文件，返回包含的所有本地路径链接及行号。
    """
    links = []
    cleanup_issues = []
    
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        for idx, line in enumerate(f, 1):
            for keyword in CLEANUP_KEYWORDS:
                if keyword in line:
                    cleanup_issues.append((idx, keyword))

            for match in LINK_REGEX.findall(line):
                links.append((idx, match))
                
            ref_match = REF_LINK_REGEX.match(line.strip())
            if ref_match:
                links.append((idx, ref_match.group(1)))
                
    return links, cleanup_issues

def find_all_markdown_files(workspace):
    """
    遍历获取项目下的所有 Markdown 文件。排除隐藏目录及缓存依赖项。
    """
    md_files = []
    for root, _, files in os.walk(workspace):
        parts = root.split(os.sep)
        if any(p.startswith(".") and p != "." and p != ".." for p in parts):
            continue
            
        # 排除构建目录、派生数据目录、隐藏缓存目录、Node依赖目录以及外部发布的插件仓（zhiyu-releases）
        if any(p in root for p in ["build", "DerivedData", ".cache", "node_modules", "zhiyu-releases"]):
            continue
            
        for file in files:
            if file.endswith(".md"):
                md_files.append(os.path.join(root, file))
    return md_files

def audit_single_file(workspace, file_path):
    """
    审计单个文件的死链接和清理标识。
    """
    rel_file_path = os.path.relpath(file_path, workspace)
    normalized_rel_path = rel_file_path.replace("\\", "/")
    if any(ex in normalized_rel_path for ex in EXCLUDE_DOC_FILES):
        return False

    links, cleanup_issues = parse_markdown_links(file_path)
    file_has_error = False

    if cleanup_issues:
        print(f"❌ 废弃清理检查失败: 文件 [{rel_file_path}] 中包含需清理的陈旧标识:")
        for line_no, kw in cleanup_issues:
            print(f"  - 第 {line_no} 行: 发现残留关键字 '{kw}'")
        file_has_error = True

    for line_no, link in links:
        if link.startswith(("http://", "https://", "mailto:")) or link.startswith("#"):
            continue

        file_dir = os.path.dirname(file_path)
        is_valid = check_case_sensitive_exists(file_dir, link, workspace)
        if not is_valid:
            print(f"❌ 链接死链或大小写不匹配: 文件 [{rel_file_path}] 第 {line_no} 行:")
            print(f"  - 引用链接: '{link}'")
            print(f"  - 原因: 文件不存在，或磁盘物理大小写与引用不匹配")
            file_has_error = True

    return file_has_error

def audit_core_indices(workspace):
    """
    校验核心索引文件引用的文件存在性。
    """
    index_has_error = False
    for index_file in CORE_INDEX_FILES:
        index_path = os.path.join(workspace, index_file)
        if not os.path.exists(index_path):
            continue
        
        links, _ = parse_markdown_links(index_path)
        for line_no, link in links:
            if link.endswith(".md") and not link.startswith(("http://", "https://")):
                is_valid = check_case_sensitive_exists(workspace, link, workspace)
                if not is_valid:
                    print(f"❌ 索引引用缺失: [{index_file}] 第 {line_no} 行引用的核心文档不存在:")
                    print(f"  - 核心文档路径: '{link}'")
                    index_has_error = True
    return index_has_error

def check_python_files(workspace):
    """
    扫描 Tools 目录下所有 Python 文件，通过 py_compile 执行语法安全分析。
    """
    print("===> 开始校验 Python 脚本语法...")
    has_error = False
    py_files = []
    
    for root, _, files in os.walk(os.path.join(workspace, "Tools")):
        for file in files:
            if file.endswith(".py"):
                py_files.append(os.path.join(root, file))
                
    print(f"  发现 {len(py_files)} 个 Python 脚本文件。")
    
    for py_file in py_files:
        rel_path = os.path.relpath(py_file, workspace)
        try:
            py_compile.compile(py_file, doraise=True)
        except py_compile.PyCompileError as e:
            print(f"❌ Python 语法编译失败: [{rel_path}]")
            print(f"  - 详情: {e.msg}")
            has_error = True
            
    return not has_error

def audit_single_yaml_file(workspace, yml_file):
    """
    审计单个 YAML 文件的合法性。
    """
    rel_path = os.path.relpath(yml_file, workspace)
    
    if HAVE_YAML:
        try:
            with open(yml_file, "r", encoding="utf-8") as f:
                yaml.safe_load(f)
        except yaml.YAMLError as e:
            print(f"❌ YAML 语法解析失败: [{rel_path}]")
            print(f"  - 解析器报错: {e}")
            return True
    else:
        try:
            with open(yml_file, "r", encoding="utf-8") as f:
                for line_idx, line in enumerate(f, 1):
                    if "\t" in line:
                        print(f"❌ YAML 规范校验失败: [{rel_path}] 第 {line_idx} 行包含制表符 (Tab)，YAML 只允许空格缩进！")
                        return True
        except Exception as e:
            print(f"❌ 配置文件读取失败: [{rel_path}] - {e}")
            return True
            
    return False

def check_yaml_files(workspace):
    """
    校验项目下的 project.yml 及 .woodpecker*.yml 配置文件的格式规范。
    """
    print("===> 开始校验 YAML/YML 配置文件结构...")
    has_error = False
    yaml_targets = []
    
    for file in os.listdir(workspace):
        if file.endswith((".yml", ".yaml")) and file != "project.yml":
            yaml_targets.append(os.path.join(workspace, file))
            
    proj_yml = os.path.join(workspace, "project.yml")
    if os.path.exists(proj_yml):
        yaml_targets.append(proj_yml)
        
    print(f"  发现 {len(yaml_targets)} 个配置文件需要校验。")
    
    for yml_file in yaml_targets:
        if audit_single_yaml_file(workspace, yml_file):
            has_error = True
                
    return not has_error

def _audit_single_file_garbage(root, file, workspace):
    """
    辅助函数：审计单个文件是否属于垃圾文件或残留开发脚本。
    """
    if file in DIRTY_NAMES:
        return "操作系统/编辑器垃圾文件"
        
    if file.endswith(DIRTY_SUFFIXES):
        return "临时缓存/本地私有配置"
        
    for pattern in DIRTY_PATTERNS:
        if pattern.match(file):
            return "开发分析过程残留临时文件"
    
    if root == workspace and file in ROOT_DIRTY_PY_SCRIPTS:
        return "根目录下残留的临时开发重构脚本（请移入 Tools/ 目录或删除）"
        
    return None

def check_garbage_files(workspace):
    """
    遍历整个项目，扫描是否残存违规的临时文件、OS/IDE垃圾文件及无用开发脚本。
    """
    print("===> 开始扫描项目垃圾文件及残留临时配置...")
    has_error = False
    garbage_found = []

    for root, _, files in os.walk(workspace):
        if any(p in root for p in ["build", "DerivedData", ".cache", "node_modules", ".git"]):
            continue
            
        for file in files:
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, workspace)
            reason = _audit_single_file_garbage(root, file, workspace)
            if reason:
                garbage_found.append((rel_path, reason))

    if garbage_found:
        print("❌ 发现未受控的垃圾文件/临时残留脚本 (请在本地执行清理后再提交):")
        for path, reason in garbage_found:
            print(f"  - [{path}] : {reason}")
        has_error = True
    else:
        print("  ✓ 未发现垃圾文件及临时残留。")

    return not has_error

def main():
    """
    主程序入口。合流并依次运行 Markdown 文档死链、核心索引有效性、
    Python 语法、YAML 配置格式、以及全局垃圾文件的扫描审计。
    """
    workspace = os.getcwd()
    print("=== 开始文档与配置健康度集成审计 ===")
    print(f"工作空间: {workspace}")

    # 1. 审计文档
    md_files = find_all_markdown_files(workspace)
    print(f"共发现 {len(md_files)} 个 Markdown 文件进行审计。")
    md_ok = True
    for file_path in md_files:
        if audit_single_file(workspace, file_path):
            md_ok = False

    if audit_core_indices(workspace):
        md_ok = False

    # 2. 审计配置与临时代码
    py_ok = check_python_files(workspace)
    yaml_ok = check_yaml_files(workspace)
    garbage_ok = check_garbage_files(workspace)

    if not md_ok or not py_ok or not yaml_ok or not garbage_ok:
        print("=== ❌ 审计结束: 部分文档或配置检查未通过 ===")
        sys.exit(EXIT_CODE_ERROR)
    else:
        print("=== ✓ 审计成功: 所有文档与配置文件校验通过 ===")
        sys.exit(EXIT_CODE_SUCCESS)

if __name__ == "__main__":
    main()
