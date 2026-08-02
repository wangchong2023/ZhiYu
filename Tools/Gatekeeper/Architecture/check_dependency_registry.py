#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_dependency_registry.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/02.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/Gatekeeper] 守卫网关
#  核心职责：以 Config/opensource_dependencies.yml 为唯一事实来源 (SSOT)，
#           审计以下三层一致性：
#           1. project.yml.template — 所有 project_yml_path 库是否使用 ${OPENSRC_ROOT} 引入
#           2. Package.swift — adapter 所在 SPM 包是否声明了对应的 GitHub URL 依赖
#           3. 本地磁盘 — project_yml_path 库是否已克隆（OPENSRC_ROOT 环境变量）
#
#  执行：python3 Tools/Gatekeeper/Architecture/check_dependency_registry.py
#  依赖：pyyaml（pip install pyyaml），OPENSRC_ROOT 环境变量（可选，缺失则跳过磁盘检查）
#

import os
import re
import sys
from pathlib import Path

# ==============================================================================
# MARK: - 路径常量
# ==============================================================================

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent.parent
REGISTRY_FILE = PROJECT_DIR / "Config" / "opensource_dependencies.yml"
TEMPLATE_FILE = PROJECT_DIR / "Config" / "project.yml.template"
PACKAGES_DIR = PROJECT_DIR / "Packages"
OPENSRC_ROOT = os.environ.get("OPENSRC_ROOT", "")


# ==============================================================================
# MARK: - 轻量 YAML 解析（不依赖 pyyaml）
# ==============================================================================

def check_key_value(stripped: str, current: dict):
    """解析并提取冒号分隔键值对"""
    if ":" in stripped and not stripped.startswith("-"):
        key, _, val = stripped.partition(":")
        val_clean = val.strip().strip('"')
        if key.strip() and val_clean:
            current[key.strip()] = val_clean


def process_registry_line(line: str, current: dict, in_deps: bool) -> tuple[dict, bool, dict | None]:
    """处理单行 YAML 内容"""
    stripped = line.strip()
    if stripped.startswith("#") or not stripped:
        return current, in_deps, None
    if stripped == "dependencies:":
        return current, True, None
    if not in_deps:
        return current, False, None

    if stripped.startswith("- name:"):
        completed = current if current else None
        new_item = {"name": stripped.split(":", 1)[1].strip()}
        return new_item, True, completed

    check_key_value(stripped, current)
    return current, True, None


def parse_registry(filepath: Path) -> list[dict]:
    """简单解析 opensource_dependencies.yml，提取 dependencies 列表"""
    deps = []
    current: dict = {}
    in_deps = False

    with open(filepath, encoding="utf-8") as f:
        for line in f:
            current, in_deps, completed = process_registry_line(line, current, in_deps)
            if completed:
                deps.append(completed)

    if current:
        deps.append(current)
    return deps


# ==============================================================================
# MARK: - 三层审计
# ==============================================================================

def check_template(deps: list[dict]) -> list[str]:
    """
    审计 1：project.yml.template
    每个 integration=project_yml_path 的库，必须在模板中有 ${OPENSRC_ROOT}/<name> 条目
    """
    violations = []
    if not TEMPLATE_FILE.exists():
        return [f"❌ 未找到 {TEMPLATE_FILE.relative_to(PROJECT_DIR)}"]

    template_content = TEMPLATE_FILE.read_text(encoding="utf-8")

    for dep in deps:
        if dep.get("integration") != "project_yml_path":
            continue
        name = dep["name"]
        expected = f"${{OPENSRC_ROOT}}/{name}"
        if expected not in template_content:
            violations.append(
                f"  ❌ [{name}] 未在 project.yml.template 中以 ${{OPENSRC_ROOT}}/{name} 引入\n"
                f"     应在 packages: 节添加：\n"
                f"       {name.replace('.', '')}:\n"
                f"         path: ${{OPENSRC_ROOT}}/{name}"
            )
    return violations


def check_package_swift(deps: list[dict]) -> list[str]:
    """
    审计 2：SPM Package.swift
    每个有 package_swift_url 字段的库，必须在对应 SPM 包的 Package.swift 中
    以 path: opensrcRoot/名称 的形式声明（而非 url: github.com）
    """
    violations = []

    for dep in deps:
        pkg_url = dep.get("package_swift_url", "")
        if not pkg_url:
            continue  # 无需 Package.swift 声明（如 homebrew / spm_plugin）

        # 从 layer 字段提取目标 SPM 包名，如 "ZhiYuAICore (SPM Package)" → "ZhiYuAICore"
        layer_raw = dep.get("layer", "")
        pkg_name_match = re.match(r"^(\w+)", layer_raw)
        if not pkg_name_match:
            continue
        pkg_name = pkg_name_match.group(1)

        # 跳过 "待迁移" 状态
        if "待迁移" in layer_raw:
            continue

        pkg_swift = PACKAGES_DIR / pkg_name / "Package.swift"
        if not pkg_swift.exists():
            violations.append(
                f"  ⚠️  [{dep['name']}] 目标包 {pkg_name}/Package.swift 不存在，跳过检查"
            )
            continue

        content = pkg_swift.read_text(encoding="utf-8")
        name = dep["name"]

        # 检查：必须有 path: opensrcRoot/name（本地路径），不得有 url: github.com
        has_local_path = f'"opensrcRoot)/{name}"' in content or f"opensrcRoot)/{name}" in content
        has_github_url = pkg_url in content

        if has_github_url:
            violations.append(
                f"  ❌ [{name}] {pkg_name}/Package.swift 仍使用 GitHub URL，违反离线优先原则\n"
                f"     应改为：.package(path: \"\\(opensrcRoot)/{name}\")"
            )
        elif not has_local_path:
            violations.append(
                f"  ❌ [{name}] {pkg_name}/Package.swift 未声明本地路径依赖\n"
                f"     应添加：.package(path: \"\\(opensrcRoot)/{name}\")"
            )

    return violations


def check_local_clones(deps: list[dict]) -> list[str]:
    """
    审计 3：本地磁盘克隆状态
    每个 integration=project_yml_path 的库必须存在于 OPENSRC_ROOT/<name>
    """
    violations = []

    if not OPENSRC_ROOT:
        return ["  ⚠️  OPENSRC_ROOT 未设置，跳过本地磁盘克隆检查（请 source Config/.env.local 后重试）"]

    opensrc = Path(OPENSRC_ROOT)
    if not opensrc.exists():
        return [f"  ❌ OPENSRC_ROOT 路径不存在：{OPENSRC_ROOT}"]

    for dep in deps:
        if dep.get("integration") not in ("project_yml_path",):
            continue  # homebrew / spm_plugin 无需本地克隆
        name = dep["name"]
        local_path = opensrc / name
        if not local_path.exists():
            git_url = dep.get("git_url", "（未知）")
            violations.append(
                f"  ❌ [{name}] 未克隆到 {local_path}\n"
                f"     克隆命令：git clone {git_url} {local_path}"
            )

    return violations


def check_registry_completeness(deps: list[dict]) -> list[str]:
    """
    审计 4：注册表自身完整性
    每个条目必须包含 name, git_url, integration, status
    """
    violations = []
    required_fields = ["name", "git_url", "integration", "status"]
    for dep in deps:
        for field in required_fields:
            if not dep.get(field):
                violations.append(
                    f"  ❌ [{dep.get('name', '?')}] 注册表条目缺少必填字段：{field}"
                )
    return violations


# ==============================================================================
# MARK: - 常量定义
# ==============================================================================

DIVIDER_WIDTH = 50


# ==============================================================================
# MARK: - 主流程
# ==============================================================================

def run_audits(active_deps: list[dict]) -> tuple[list[str], int]:
    """运行 4 大一致性审计规则"""
    all_violations: list[str] = []
    passed = 0

    print("【1/4】project.yml.template 一致性")
    v1 = check_template(active_deps)
    if v1:
        all_violations.extend(v1)
        print("\n".join(v1))
    else:
        print("  ✅ 所有 project_yml_path 库均已在模板中以 ${OPENSRC_ROOT} 引入")
        passed += 1

    print("\n【2/4】SPM Package.swift 本地路径声明")
    v2 = check_package_swift(active_deps)
    if v2:
        all_violations.extend(v2)
        print("\n".join(v2))
    else:
        print("  ✅ 所有需声明的库均已在对应 Package.swift 中以 (opensrcRoot)/名称 本地路径引入")
        passed += 1

    print("\n【3/4】本地磁盘克隆状态（OPENSRC_ROOT）")
    v3 = check_local_clones(active_deps)
    if v3:
        errors = [x for x in v3 if x.strip().startswith("❌")]
        print("\n".join(v3))
        if errors:
            all_violations.extend(errors)
        else:
            passed += 1
    else:
        print("  ✅ 所有库均已克隆到 OPENSRC_ROOT")
        passed += 1

    print("\n【4/4】注册表字段完整性")
    v4 = check_registry_completeness(active_deps)
    if v4:
        all_violations.extend(v4)
        print("\n".join(v4))
    else:
        print("  ✅ 所有注册表条目字段完整")
        passed += 1

    return all_violations, passed


def main() -> int:
    """执行开源依赖注册表 (SSOT) 三层一致性与完整性校验入口"""
    print("\n🔍 [Dependency Registry Audit] 开源依赖注册表一致性审计...\n")
    print(f"   SSOT: {REGISTRY_FILE.relative_to(PROJECT_DIR)}")
    print(f"   OPENSRC_ROOT: {OPENSRC_ROOT or '（未设置）'}\n")

    if not REGISTRY_FILE.exists():
        print(f"❌ 未找到注册表文件：{REGISTRY_FILE}")
        return 1

    deps = parse_registry(REGISTRY_FILE)
    active_deps = [d for d in deps if d.get("status") == "active"]
    print(f"   注册库总数：{len(deps)}，活跃：{len(active_deps)}\n")

    all_violations, _ = run_audits(active_deps)

    print(f"\n{'━' * DIVIDER_WIDTH}")
    if all_violations:
        true_errors = [x for x in all_violations if "❌" in x]
        print(f"❌ [Dependency Registry Audit] {len(true_errors)} 处违规，构建阻断！")
        return 1
    else:
        print("✅ [Dependency Registry Audit] 4/4 审计全部通过，依赖注册表一致性完整。")
        return 0


if __name__ == "__main__":
    sys.exit(main())
