#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-cross-package-symbol-collisions.py
#  ZhiYu
#
#  Created by Antigravity on 2026/11/26.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：审计 Sources 与 Packages 跨包顶层类型同名冲突、非 Shim 重名文件与白名单僵尸路径。
#
"""CI 门禁 #29: 跨包同名类型冲突与白名单健康审计。

检查三项高风险退化:
1. Sources/ 与 Packages/*/Sources/ 之间严禁出现同名非私有顶层类型声明（防止影分身与同名遮蔽）。
2. Sources/ 与 Packages/*/Sources/ 之间严禁新增非 Shim 转发的同名 Swift 文件。
3. 核心豁免白名单 (Config/exemptions/*_whitelist.yml) 严禁残留指向不存在文件的僵尸路径。
"""

import os
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
TOP_TYPE_RE = re.compile(
    r"^(?:(?:public|internal|open|final|indirect|nonisolated|@[\w\(\)\.]+)\s+)*"
    r"(struct|class|actor|enum|protocol)\s+(\w+)\b",
    re.MULTILINE,
)
PRIVATE_PREFIX_RE = re.compile(r"^\s*(?:private|fileprivate)\b")
WHITELIST_FILE_RE = re.compile(r'^\s*-?\s*file:\s*"?([^"#\n]+?)"?\s*$')

ALLOWED_DUPLICATE_FILENAMES = {
    "Logger.swift",
}

EXEMPTION_WHITELISTS = [
    "Config/exemptions/singleton_whitelist.yml",
    "Config/exemptions/inject_deprecated_whitelist.yml",
    "Config/exemptions/environment_object_whitelist.yml",
    "Config/exemptions/userdefaults_standard_whitelist.yml",
]


def _iter_swift_files(base_rel: str) -> list[tuple[str, Path]]:
    """遍历指定根目录下的生产 Swift 源码文件（自动排除 Tests 与 .build）。"""
    results: list[tuple[str, Path]] = []
    base_path = ROOT_DIR / base_rel
    if not base_path.exists():
        return results
    for dirpath, dirnames, filenames in os.walk(base_path):
        dirnames[:] = [
            d for d in dirnames if d not in (".build", ".git", "DerivedData", "Tests")
        ]
        for fname in filenames:
            if fname.endswith(".swift"):
                full_path = Path(dirpath) / fname
                rel_path = full_path.relative_to(ROOT_DIR).as_posix()
                results.append((rel_path, full_path))
    return sorted(results)


def _extract_public_top_types(file_path: Path) -> list[tuple[str, str]]:
    """提取文件内非 private/fileprivate 的顶层类型声明。"""
    content = file_path.read_text(encoding="utf-8", errors="ignore")
    results: list[tuple[str, str]] = []
    for line in content.splitlines():
        if not line or line[0].isspace() or PRIVATE_PREFIX_RE.match(line):
            continue
        match = TOP_TYPE_RE.match(line)
        if match:
            results.append((match.group(1), match.group(2)))
    return results


def _is_shim_file(file_path: Path) -> bool:
    """判断文件是否为仅包含 import 与 typealias 的薄壳兼容垫片。"""
    content = file_path.read_text(encoding="utf-8", errors="ignore")
    code_lines = [
        line.strip()
        for line in content.splitlines()
        if line.strip() and not line.strip().startswith("//")
    ]
    non_imports = [
        line
        for line in code_lines
        if not line.startswith("import ") and not line.startswith("@_exported")
    ]
    if not non_imports:
        return True
    return all(
        line.startswith("public typealias ") or line.startswith("typealias ")
        for line in non_imports
    )


def check_symbol_collisions(
    src_files: list[tuple[str, Path]], pkg_files: list[tuple[str, Path]]
) -> list[str]:
    """检测 Sources 与 Packages 之间的非私有顶层类型同名冲突。"""
    src_types: dict[str, list[str]] = defaultdict(list)
    pkg_types: dict[str, list[str]] = defaultdict(list)

    for rel, path in src_files:
        for kind, name in _extract_public_top_types(path):
            src_types[name].append(f"[{kind}] {rel}")

    for rel, path in pkg_files:
        for kind, name in _extract_public_top_types(path):
            pkg_types[name].append(f"[{kind}] {rel}")

    violations: list[str] = []
    for name in sorted(set(src_types) & set(pkg_types)):
        violations.append(
            f"跨包顶层类型同名冲突 `{name}`: Sources={src_types[name]} vs Packages={pkg_types[name]}"
        )
    return violations


def check_duplicate_filenames(
    src_files: list[tuple[str, Path]], pkg_files: list[tuple[str, Path]]
) -> list[str]:
    """检测 Sources 与 Packages 之间非 Shim 的同名 Swift 文件。"""
    pkg_by_name: dict[str, list[str]] = defaultdict(list)
    for rel, _ in pkg_files:
        if rel.endswith("/Package.swift") or rel == "Package.swift":
            continue
        pkg_by_name[Path(rel).name].append(rel)

    violations: list[str] = []
    for rel, path in src_files:
        fname = Path(rel).name
        if fname in ALLOWED_DUPLICATE_FILENAMES or fname not in pkg_by_name:
            continue
        if not _is_shim_file(path):
            violations.append(
                f"跨包非 Shim 同名文件 `{fname}`: {rel} <-> {pkg_by_name[fname]}"
            )
    return violations


def check_zombie_whitelist_entries() -> list[str]:
    """检测核心豁免白名单中指向不存在文件的僵尸条目。"""
    violations: list[str] = []
    for rel_wl in EXEMPTION_WHITELISTS:
        wl_path = ROOT_DIR / rel_wl
        if not wl_path.exists():
            continue
        for lineno, line in enumerate(
            wl_path.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1
        ):
            match = WHITELIST_FILE_RE.match(line)
            if not match:
                continue
            target_rel = match.group(1).strip()
            if not (ROOT_DIR / target_rel).exists():
                violations.append(
                    f"僵尸白名单路径 {rel_wl}:{lineno} -> `{target_rel}` 文件不存在"
                )
    return violations


def main() -> int:
    """运行跨包同名类型冲突与白名单健康审计。"""
    print("🔍 [CI-29] 正在执行跨包同名类型冲突、非 Shim 重名文件与白名单僵尸路径审计...")
    src_files = _iter_swift_files("Sources")
    pkg_files = [
        item for item in _iter_swift_files("Packages") if "/Sources/" in item[0]
    ]

    violations = (
        check_symbol_collisions(src_files, pkg_files)
        + check_duplicate_filenames(src_files, pkg_files)
        + check_zombie_whitelist_entries()
    )

    if violations:
        print(f"❌ 发现 {len(violations)} 项跨包冲突或白名单僵尸条目:")
        for item in violations:
            print(f"   • {item}")
        return 1

    print(
        f"✅ 跨包同名冲突审计通过: 扫描 Sources {len(src_files)} 文件 / "
        f"Packages {len(pkg_files)} 文件，0 顶层类型冲突、0 非 Shim 重名、0 白名单僵尸路径。"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
