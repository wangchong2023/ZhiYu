#!/usr/bin/env python3
"""
CI-2 门禁：@EnvironmentObject 冻结审计

策略：白名单注册制 + 禁止新增。
- 现有 51 处 @EnvironmentObject 登记在白名单中（Config/exemptions/environment_object_whitelist.yml）。
- 白名单外新增 @EnvironmentObject 即 CI 阻断。
- 目标：推动后续 P4-P6 阶段逐步迁移到 @Environment（SwiftUI 推荐）。

触发场景：CI/CD 流水线 + pre-push 钩子。
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
