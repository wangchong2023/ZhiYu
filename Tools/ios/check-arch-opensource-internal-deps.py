#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-arch-opensource-internal-deps.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/19.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：审计开源库自身的 Package.swift 内部依赖是否已全部本地化。
#           盲区补缺：check-arch-dependency-registry.py 只审计项目自身 Packages/*/Package.swift
#           对开源库的引用方式，不审计开源库自身 Package.swift 内部的二级依赖。
#           本脚本扫描 ${OPENSRC_ROOT}/*/Package.swift，禁止出现 url: "https://..." 远端依赖，
#           所有依赖必须以 path: ../<name> 形式声明，且 <name> 必须在 opensource_dependencies.yml 注册。
#
#  执行：python3 Tools/ios/check-arch-opensource-internal-deps.py
#  依赖：OPENSRC_ROOT 环境变量（必须设置，否则跳过并 WARNING）
#

import os
import re
import sys
from pathlib import Path

# 导入统一门禁报告器
GATEKEEPER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if GATEKEEPER_DIR not in sys.path:
    sys.path.insert(0, GATEKEEPER_DIR)
from gatekeeper_reporter import GatekeeperReporter  # noqa: E402

# ==============================================================================
# MARK: - 路径常量
# ==============================================================================

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
REGISTRY_FILE = PROJECT_DIR / "Config" / "opensource_dependencies.yml"
OPENSRC_ROOT = os.environ.get("OPENSRC_ROOT", "")

# ==============================================================================
# MARK: - 轻量 YAML 解析（复用 check-arch-dependency-registry.py 模式）
# ==============================================================================

def _is_comment_or_blank(stripped: str) -> bool:
    """判断行是否为注释或空行"""
    return stripped.startswith("#") or not stripped


def _parse_kv(stripped: str, current: dict) -> None:
    """解析键值对并写入 current 字典"""
    if ":" in stripped and not stripped.startswith("-"):
        key, _, val = stripped.partition(":")
        val_clean = val.strip().strip('"')
        if key.strip() and val_clean:
            current[key.strip()] = val_clean


def parse_registry(filepath: Path) -> list[dict]:
    """简单解析 opensource_dependencies.yml，提取 dependencies 列表"""
    deps: list[dict] = []
    current: dict = {}
    in_deps = False

    with open(filepath, encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if _is_comment_or_blank(stripped):
                continue
            if stripped == "dependencies:":
                in_deps = True
                continue
            if not in_deps:
                continue

            if stripped.startswith("- name:"):
                if current:
                    deps.append(current)
                current = {"name": stripped.split(":", 1)[1].strip()}
                continue

            _parse_kv(stripped, current)

    if current:
        deps.append(current)
    return deps


# ==============================================================================
# MARK: - Package.swift 依赖声明提取
# ==============================================================================

# 匹配 .package(url: "https://..." ...) 远端依赖声明
REMOTE_URL_PATTERN = re.compile(
    r'\.package\(\s*url:\s*"((?:https?://github\.com|https?://[^"]+)/(?:[^"]+))"\s*,'
)

# 匹配 .package(path: "../<name>") 本地路径依赖声明
LOCAL_PATH_PATTERN = re.compile(
    r'\.package\(\s*path:\s*"\.\./([A-Za-z0-9_\.\-]+)"\s*\)'
)


def extract_package_deps(package_swift_content: str) -> tuple[list[tuple[int, str]], list[tuple[int, str]]]:
    """
    从 Package.swift 内容中提取远端 URL 依赖和本地路径依赖。

    返回:
        (remote_deps, local_deps)
        remote_deps: [(line_no, url), ...]
        local_deps: [(line_no, name), ...]
    """
    remote_deps = []
    local_deps = []
    lines = package_swift_content.split("\n")

    for idx, line in enumerate(lines, 1):
        # 跳过注释行
        stripped = line.split("//")[0].strip()
        if not stripped:
            continue

        # 检测远端 URL 依赖
        url_match = REMOTE_URL_PATTERN.search(stripped)
        if url_match:
            remote_deps.append((idx, url_match.group(1)))

        # 检测本地路径依赖
        path_match = LOCAL_PATH_PATTERN.search(stripped)
        if path_match:
            local_deps.append((idx, path_match.group(1)))

    return remote_deps, local_deps


# ==============================================================================
# MARK: - 审计核心逻辑
# ==============================================================================

def _audit_remote_deps(
    package_swift: Path,
    remote_deps: list[tuple[int, str]],
    reporter: GatekeeperReporter,
) -> int:
    """审计远端 URL 依赖（违规）"""
    count = 0
    for line_no, url in remote_deps:
        reporter.add_issue(
            str(package_swift),
            line_no,
            f"开源库内部依赖仍使用远端 URL: {url}，违反离线优先原则。"
            f"应改为 .package(path: \"../<本地目录名>\")",
            level="ERROR",
            content=url,
        )
        count += 1
    return count


def _audit_local_deps(
    package_swift: Path,
    local_deps: list[tuple[int, str]],
    registered_names: set[str],
    reporter: GatekeeperReporter,
) -> int:
    """审计本地路径依赖是否已注册"""
    count = 0
    for line_no, dep_name in local_deps:
        if dep_name not in registered_names:
            reporter.add_issue(
                str(package_swift),
                line_no,
                f"本地路径依赖 ../{dep_name} 未在 opensource_dependencies.yml 注册。"
                f"请在注册表中新增该库条目",
                level="ERROR",
                content=dep_name,
            )
            count += 1
    return count


def _audit_single_package(
    lib_dir: Path,
    registered_names: set[str],
    reporter: GatekeeperReporter,
) -> int:
    """审计单个开源库的 Package.swift"""
    package_swift = lib_dir / "Package.swift"
    if not package_swift.exists():
        return 0

    try:
        content = package_swift.read_text(encoding="utf-8")
    except Exception as e:
        reporter.add_issue(
            str(package_swift),
            1,
            f"无法读取 Package.swift: {e}",
            level="ERROR",
        )
        return 1

    remote_deps, local_deps = extract_package_deps(content)
    violations = _audit_remote_deps(package_swift, remote_deps, reporter)
    violations += _audit_local_deps(package_swift, local_deps, registered_names, reporter)
    return violations


def audit_opensrc_internal_deps(
    opensrc_root: Path,
    registered_names: set[str],
    reporter: GatekeeperReporter,
) -> int:
    """
    扫描 ${OPENSRC_ROOT}/*/Package.swift，审计：
    1. 禁止出现 url: "https://..." 远端依赖（必须改为 path: ../<name>）
    2. 本地路径依赖的 <name> 必须在 opensource_dependencies.yml 注册

    返回:
        int: 发现的违规总数
    """
    violations = 0
    scanned_count = 0

    for lib_dir in sorted(opensrc_root.iterdir()):
        if not lib_dir.is_dir() or lib_dir.name.startswith("."):
            continue
        if not (lib_dir / "Package.swift").exists():
            continue

        scanned_count += 1
        violations += _audit_single_package(lib_dir, registered_names, reporter)

    print(f"   扫描开源库 Package.swift 数量：{scanned_count}")
    return violations


# ==============================================================================
# MARK: - 主流程
# ==============================================================================

DIVIDER_WIDTH = 50


def main() -> int:
    """执行开源库内部依赖本地化审计入口"""
    print("\n" + "━" * DIVIDER_WIDTH)
    print("🔍 [OpenSource Internal Deps Audit] 开源库内部依赖本地化审计...")
    print(f"   SSOT: {REGISTRY_FILE.relative_to(PROJECT_DIR)}")
    print(f"   OPENSRC_ROOT: {OPENSRC_ROOT or '（未设置）'}")
    print("━" * DIVIDER_WIDTH)

    if not OPENSRC_ROOT:
        print("⚠️  OPENSRC_ROOT 未设置，跳过开源库内部依赖审计。")
        print("   请 source Config/.env.local 后重试。")
        return 0

    opensrc_root = Path(OPENSRC_ROOT)
    if not opensrc_root.exists():
        print(f"❌ OPENSRC_ROOT 路径不存在：{OPENSRC_ROOT}")
        return 1

    if not REGISTRY_FILE.exists():
        print(f"❌ 未找到注册表文件：{REGISTRY_FILE}")
        return 1

    # 解析注册表，获取已注册库名集合
    deps = parse_registry(REGISTRY_FILE)
    registered_names = {d["name"] for d in deps if d.get("name")}
    print(f"   注册库总数：{len(registered_names)}")
    print("─" * DIVIDER_WIDTH)

    reporter = GatekeeperReporter("OpenSourceInternalDepsAudit")

    violations = audit_opensrc_internal_deps(opensrc_root, registered_names, reporter)

    print("─" * DIVIDER_WIDTH)
    if violations > 0:
        print(f"❌ [OpenSource Internal Deps Audit] 发现 {violations} 处违规，构建阻断！")
        print("   修复指南：")
        print("   1. 远端 URL 依赖 → 克隆对应库到 ${OPENSRC_ROOT}，改为 .package(path: \"../<name>\")")
        print("   2. 未注册的本地路径依赖 → 在 Config/opensource_dependencies.yml 新增条目")
        reporter.report()
        return 1
    else:
        print("✅ [OpenSource Internal Deps Audit] 审计通过：所有开源库内部依赖均已本地化且已注册。")
        return 0


if __name__ == "__main__":
    sys.exit(main())
