#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_absolute_paths.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/02.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/Gatekeeper] 守卫网关
#  核心职责：扫描项目中所有源文件，禁止硬编码绝对物理路径（如 /Users/xxx/...）。
#           绝对路径会导致项目在其他开发者机器或 CI 环境中无法构建。
#           正确做法：project.yml 使用 $(OPENSRC_ROOT) 环境变量，
#           Package.swift 使用 GitHub URL 或相对路径，
#           Python/Shell 脚本使用 __file__ 计算路径。
#

import os
import re
import sys

# ==============================================================================
# MARK: - 配置区
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# 检测绝对路径的正则（匹配 /Users/ 或 /home/ 开头的路径）
ABSOLUTE_PATH_PATTERN = re.compile(r'(?:^|["\'\s=:(])(/(?:Users|home)/\S+)', re.MULTILINE)

# 扫描的文件扩展名
SCAN_EXTENSIONS = {".swift", ".py", ".sh", ".yml", ".yaml", ".json", ".md"}

# 完全跳过的目录（生成物/缓存/工具配置）
SKIP_DIRS = {
    ".git", ".build", "DerivedData", "build",
    ".claude", ".gemini",           # IDE 工具配置，非项目代码
    "scratch",                       # 临时脚本
    ".VSCodeCounter",                # VSCode 代码统计工具生成的报告（构建产物）
}

# 完全跳过的文件（已知合理包含绝对路径的文件）
SKIP_FILES = {
    ".env.local",           # 本地环境配置，gitignore
    "Config/.env.local",    # 本地环境配置，gitignore
    ".env.example",         # 模板，占位符路径
    "CONTRIBUTING.md",      # 可能包含示例路径说明
    "project.yml",          # 由 bootstrap.sh 从 Config/project.yml.template 生成的文件，包含展开后的路径
}

# 允许的绝对路径模式（白名单正则，匹配则跳过该行）
ALLOWED_PATTERNS = [
    r"#.*example.*path",            # 注释中的示例路径
    r"#.*placeholder",              # 注释中的占位符
    r"export OPENSRC_ROOT=",        # .env 模板赋值行
    r"OPENSRC_ROOT=/path/to",       # 模板中的占位路径
    r"/Users/yourname",             # 文档示例路径
    r"/Users/test/",                # 测试脚本中的虚构路径（非真实机器）
    r"^\s*#",                       # 纯注释行（Python/Shell）
    r"^\s*//",                      # 纯注释行（Swift）
    r"debug\.yaml",                 # SPM 构建产物
]


# ==============================================================================
# MARK: - 扫描逻辑
# ==============================================================================

def should_skip_path(path: str) -> bool:
    parts = path.replace(PROJECT_DIR, "").split(os.sep)
    return any(part in SKIP_DIRS for part in parts)


def should_skip_file(filename: str) -> bool:
    return os.path.basename(filename) in SKIP_FILES


def is_allowed_line(line: str) -> bool:
    return any(re.search(p, line, re.IGNORECASE) for p in ALLOWED_PATTERNS)


def scan_file(filepath: str) -> list[dict]:
    violations = []
    try:
        with open(filepath, encoding="utf-8", errors="ignore") as f:
            for lineno, line in enumerate(f, 1):
                if is_allowed_line(line):
                    continue
                matches = ABSOLUTE_PATH_PATTERN.findall(line)
                for match in matches:
                    rel_file = os.path.relpath(filepath, PROJECT_DIR)
                    violations.append({
                        "file": rel_file,
                        "line": lineno,
                        "content": line.rstrip(),
                        "path": match,
                    })
    except (PermissionError, IsADirectoryError):
        pass
    return violations


def scan_project() -> list[dict]:
    all_violations = []
    for root, dirs, files in os.walk(PROJECT_DIR):
        # 过滤跳过目录
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        if should_skip_path(root):
            continue
        for filename in files:
            ext = os.path.splitext(filename)[1]
            if ext not in SCAN_EXTENSIONS:
                continue
            filepath = os.path.join(root, filename)
            if should_skip_file(filepath):
                continue
            violations = scan_file(filepath)
            all_violations.extend(violations)
    return all_violations


MAX_SNIPPET_LENGTH = 100


# ==============================================================================
# MARK: - 主流程
# ==============================================================================

def main():
    """扫描项目根目录下代码与配置中是否存在硬编码绝对路径"""
    print("\n🔍 [Absolute Path Audit] 扫描硬编码绝对路径...\n")

    violations = scan_project()

    if not violations:
        print("✅ [Absolute Path Audit] 未发现硬编码绝对路径，审计通过。")
        return 0

    print(f"❌ 发现 {len(violations)} 处硬编码绝对路径：\n")
    for v in violations:
        print(f"  {v['file']}:{v['line']}")
        print(f"    路径：{v['path']}")
        print(f"    内容：{v['content'][:MAX_SNIPPET_LENGTH]}")
        print()

    print(
        "❌ [Absolute Path Audit] 审计失败，构建阻断！\n"
        "   修复方式：\n"
        "   • project.yml → 使用 $(OPENSRC_ROOT)/库名 替代绝对路径\n"
        "   • Package.swift → 使用 GitHub URL 或相对路径\n"
        "   • Python/Shell 脚本 → 使用 os.path.dirname(__file__) 计算路径\n"
        "   • 无法修复的误报 → 在 check_absolute_paths.py 的 ALLOWED_PATTERNS 中添加白名单"
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
