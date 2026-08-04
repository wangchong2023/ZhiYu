#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-quality-root-hygiene.py
#  ZhiYu
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：根目录卫生检查 — 拦截明确的垃圾文件，其余交由 .gitignore 管理。
#           不维护硬编码白名单，避免每次新增工具目录都需要更新脚本。

import os
import sys

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# ── 只拦截这些明确的垃圾 ──────────────────────────────────────────
TEMP_EXTENSIONS = {".tmp", ".swp", ".swo", ".bak", ".orig", ".rej"}

# 扫描排除：这些目录永远不进入
SKIP_DIRS = {".git", "build", "DerivedData", ".build", "Frameworks", "env", "__pycache__",
             ".claude", ".codegraph", ".remember", ".superpowers", ".VSCodeCounter",
             ".woodpecker", ".workbuddy"}

# 终端打印分割线长度
DIVIDER_LENGTH = 60


def load_gitignore_patterns(root_dir: str) -> set[str]:
    """从 .gitignore 读取应被忽略的根目录条目."""
    gitignore_path = os.path.join(root_dir, ".gitignore")
    if not os.path.exists(gitignore_path):
        return set()
    patterns = set()
    with open(gitignore_path) as f:
        for line in f:
            line = line.strip()
            # 跳过注释和空行
            if not line or line.startswith("#"):
                continue
            # 提取根目录级别的条目（以 / 结尾的目录, 或不含 / 的简单文件名）
            if line.endswith("/"):
                patterns.add(line[:-1])
            elif "/" not in line and "*" not in line and not line.startswith("."):
                patterns.add(line)
            elif line.startswith("./"):
                patterns.add(line[2:])
    return patterns


def _check_directory_files(filenames: list[str], rel_dir: str, issues: list[str]):
    """校验目录下的各文件是否属于垃圾或临时文件。"""
    for filename in filenames:
        # 编辑器临时文件
        _, ext = os.path.splitext(filename)
        if ext.lower() in TEMP_EXTENSIONS or filename.endswith("~"):
            filepath = os.path.join(rel_dir, filename) if rel_dir != "." else filename
            issues.append(f"[TEMP_FILE] {filepath}")

        # .DS_Store 在根目录可接受，子目录下应删除
        if filename == ".DS_Store" and rel_dir != ".":
            issues.append(f"[TEMP_FILE] {os.path.join(rel_dir, filename)}")


def find_temp_files(root_dir: str) -> list[str]:
    """递归扫描临时文件（不含 .DS_Store — macOS 正常行为）."""
    issues = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        rel_dir = os.path.relpath(dirpath, root_dir)

        # __pycache__ 检查
        if os.path.basename(dirpath) == "__pycache__":
            issues.append(f"[TEMP_DIR] Python 缓存目录应清理: {rel_dir}/")
            continue

        _check_directory_files(filenames, rel_dir, issues)

    return issues



def check_root_unknown_items(root_dir: str) -> list[str]:
    """检查根目录下既不在 .gitignore 中也不在 SKIP_DIRS 中的非标准条目（仅报告，不阻断）."""
    gitignored = load_gitignore_patterns(root_dir)

    # 根目录已知的合法条目（不依赖硬编码白名单，而是从实际存在 + gitignore + 常识推断）
    known_hidden = {d for d in os.listdir(root_dir)
                    if d.startswith(".") and os.path.isdir(os.path.join(root_dir, d))}
    known_files = {".gitignore", ".swiftlint.yml", ".woodpecker.yml", ".gitlab-ci.yml",
                   ".jscpd.json", "project.yml", "LICENSE", "README.md",
                   "AGENTS.md", "CLAUDE.md", "GEMINI.md",
                   "ZhiYu.code-workspace",
                   # CI/构建配置
                   ".periphery.yml", ".slather.yml", "sonar-project.properties",
                   "Makefile",
                   # 环境配置
                   ".envrc"}
    known_dirs = {"build", "Docs", "Sources", "Tests", "Tools", "Frameworks", "env",
                  "fastlane", "ZhiYu.xcodeproj",
                  # 项目结构
                  "Config", "Packages"}

    all_known = known_hidden | known_files | known_dirs | gitignored
    try:
        items = set(os.listdir(root_dir))
    except OSError as e:
        return [f"[ERROR] {e}"]

    unknown = items - all_known
    warnings = []
    for item in sorted(unknown):
        item_path = os.path.join(root_dir, item)
        item_type = "目录" if os.path.isdir(item_path) else "文件"
        warnings.append(
            f"[ROOT_UNKNOWN] {item_type} '{item}' 不在已知列表中 — "
            f"如为构建产物请加入 .gitignore，如为项目文件请告知维护者"
        )
    return warnings


def main() -> int:
    """
    主程序入口。依次执行垃圾临时文件扫描和根目录未知条目扫描。
    如果发现任何明确的临时/垃圾残留文件，将以 1 退出，否则以 0 成功退出。
    """
    print("=" * DIVIDER_LENGTH)
    print("🧹 根目录卫生检查 (Root Hygiene Check)")
    print("=" * DIVIDER_LENGTH)

    exit_code = 0

    # 1. 垃圾文件扫描（阻断级）
    print("\n📁 扫描临时/垃圾文件...")
    temp_issues = find_temp_files(PROJECT_DIR)
    if temp_issues:
        for issue in temp_issues:
            print(f"  ❌ {issue}")
        exit_code = 1
    else:
        print("  ✅ 未发现临时文件")

    # 2. 根目录未知条目（警告级，不阻断）
    print("\n📂 检查根目录未知条目...")
    unknown = check_root_unknown_items(PROJECT_DIR)
    if unknown:
        for issue in unknown:
            print(f"  ⚠️  {issue}")
        # 不设 exit_code=1 — 根目录新条目是正常开发行为，由开发者自行判断
    else:
        print("  ✅ 所有根目录条目均已识别")

    # ──
    print("\n" + "=" * DIVIDER_LENGTH)
    if exit_code == 1:
        print("❌ 发现垃圾文件，请清理后重新提交。")
    else:
        print("✅ 根目录卫生检查通过！")
    print("=" * DIVIDER_LENGTH)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
