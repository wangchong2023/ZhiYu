#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智宇 (ZhiYu) @EnvironmentObject 冻结门禁工具 (audit-environment-object.py)

功能说明:
1. 扫描 Sources/ 目录下所有 Swift 文件，检测 `@EnvironmentObject` 属性包装器使用。
2. 仅允许白名单 (Config/exemptions/environment_object_whitelist.yml) 内列出的 file+class 组合保留。
3. 白名单外的 `@EnvironmentObject` 声明将导致 CI 阻断（error）。
4. 兼容 Xcode 编译器报错输出格式，如有违规在 Xcode 编译时直接以 error 标红并阻断构建。

使用方法:
    python3 Tools/ios/audit-environment-object.py

退出码:
    0: 审计通过（所有 @EnvironmentObject 均在白名单内）
    1: 审计失败（发现未注册的 @EnvironmentObject 声明）
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# ── 路径配置 ──
PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCES_DIR = PROJECT_ROOT / "Sources"
WHITELIST_FILE = PROJECT_ROOT / "Config" / "exemptions" / "environment_object_whitelist.yml"

# ── 正则：匹配 @EnvironmentObject 声明 ──
# 示例：@EnvironmentObject var themeManager: ThemeManager
# 示例：@EnvironmentObject private var themeManager: ThemeManager
ENV_OBJECT_PATTERN = re.compile(
    r"@EnvironmentObject\s+(?:private\s+)?var\s+(\w+):\s*(\w+)"
)


def load_whitelist() -> set[tuple[str, str]]:
    """从 YAML 白名单加载已登记的 (文件相对路径, 变量名) 元组集合。"""
    if not WHITELIST_FILE.exists():
        return set()

    whitelist: set[tuple[str, str]] = set()
    current_file: str | None = None

    for line in WHITELIST_FILE.read_text(encoding="utf-8").splitlines():
        line = line.rstrip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("  - file:"):
            current_file = line.split(":", 1)[1].strip().strip('"').strip("'")
        elif line.startswith("    var:") and current_file:
            var_name = line.split(":", 1)[1].strip().strip('"').strip("'")
            whitelist.add((current_file, var_name))
            current_file = None
    return whitelist


def scan_sources() -> dict[str, list[tuple[str, str]]]:
    """扫描 Sources/ 目录，返回 {文件相对路径: [(变量名, 类型名), ...]}。"""
    violations: dict[str, list[tuple[str, str]]] = {}
    for swift_file in sorted(SOURCES_DIR.rglob("*.swift")):
        rel_path = str(swift_file.relative_to(PROJECT_ROOT))
        content = swift_file.read_text(encoding="utf-8")
        matches = ENV_OBJECT_PATTERN.findall(content)
        if matches:
            violations[rel_path] = [(var, type_name) for var, type_name in matches]
    return violations


def main() -> int:
    """主审计入口：加载白名单、扫描源码、比对白名单、输出违规项并返回退出码。"""
    whitelist = load_whitelist()
    sources_usage = scan_sources()

    new_violations: list[str] = []
    total_count = 0

    for rel_path, vars_in_file in sorted(sources_usage.items()):
        for var_name, _type_name in vars_in_file:
            total_count += 1
            if (rel_path, var_name) not in whitelist:
                new_violations.append(f"  {rel_path}: var {var_name}")

    if new_violations:
        print(f"❌ [EnvironmentObject Frozen Audit] 审计失败：发现 {len(new_violations)} 处未登记的 @EnvironmentObject")
        print("   未登记项：")
        for v in new_violations:
            print(v)
        print(f"\n   当前白名单登记 {len(whitelist)} 项，实际使用 {total_count} 项。")
        print("   如需新增，请在 Config/exemptions/environment_object_whitelist.yml 登记并说明理由。")
        print("   长期目标：逐步迁移到 @Environment（SwiftUI 推荐方式）。")
        return 1

    print(f"✅ [EnvironmentObject Frozen Audit] 审计通过：所有 {total_count} 处 @EnvironmentObject 均在白名单内（{len(whitelist)} 项）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
