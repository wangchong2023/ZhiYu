#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智宇 (ZhiYu) UserDefaults.standard 冻结门禁工具 (audit-userdefaults-standard.py)

功能说明:
1. 扫描 Sources/ 目录下所有 Swift 文件，检测 `UserDefaults.standard` 直接调用。
2. 仅允许白名单 (Config/exemptions/userdefaults_standard_whitelist.yml) 内列出的 file+line 组合保留。
3. 白名单外的 `UserDefaults.standard` 调用将导致 CI 阻断（error）。
4. 兼容 Xcode 编译器报错输出格式，如有违规在 Xcode 编译时直接以 error 标红并阻断构建。

使用方法:
    python3 Tools/ios/audit-userdefaults-standard.py

退出码:
    0: 审计通过（所有 UserDefaults.standard 均在白名单内）
    1: 审计失败（发现未注册的 UserDefaults.standard 调用）
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# ── 路径配置 ──
PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCES_DIR = PROJECT_ROOT / "Sources"
WHITELIST_FILE = PROJECT_ROOT / "Config" / "exemptions" / "userdefaults_standard_whitelist.yml"

# ── 正则：匹配 UserDefaults.standard 调用 ──
USERDEFAULTS_PATTERN = re.compile(r"UserDefaults\.standard")

# ── 豁免文件（协议定义和适配器本身）──
EXEMPT_FILES = {
    "Sources/Core/Base/Protocols/KeyStoreProtocol.swift",
    "Sources/Core/Base/Services/UserDefaultsKeyStore.swift",
}


def load_whitelist() -> set[tuple[str, int]]:
    """从 YAML 白名单加载已登记的 (文件相对路径, 行号) 元组集合。"""
    if not WHITELIST_FILE.exists():
        return set()

    whitelist: set[tuple[str, int]] = set()
    current_file: str | None = None

    for line in WHITELIST_FILE.read_text(encoding="utf-8").splitlines():
        line = line.rstrip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("  - file:"):
            current_file = line.split(":", 1)[1].strip().strip('"').strip("'")
        elif line.startswith("    line:") and current_file:
            line_num = int(line.split(":", 1)[1].strip())
            whitelist.add((current_file, line_num))
    return whitelist


def scan_sources() -> list[tuple[str, int, str]]:
    """扫描 Sources/ 目录，返回 [(文件相对路径, 行号, 行内容), ...]。"""
    violations: list[tuple[str, int, str]] = []
    for swift_file in sorted(SOURCES_DIR.rglob("*.swift")):
        rel_path = str(swift_file.relative_to(PROJECT_ROOT))
        if rel_path in EXEMPT_FILES:
            continue
        for line_num, line in enumerate(swift_file.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.strip()
            # 跳过注释行
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            if USERDEFAULTS_PATTERN.search(line):
                violations.append((rel_path, line_num, stripped))
    return violations


def main() -> int:
    """主审计入口：加载白名单、扫描源码、比对白名单、输出违规项并返回退出码。"""
    whitelist = load_whitelist()
    sources_usage = scan_sources()

    new_violations: list[str] = []
    total_count = len(sources_usage)

    for rel_path, line_num, line_content in sources_usage:
        if (rel_path, line_num) not in whitelist:
            new_violations.append(f"  {rel_path}:{line_num}: {line_content}")

    if new_violations:
        print(f"❌ [UserDefaults.standard Frozen Audit] 审计失败：发现 {len(new_violations)} 处未登记的 UserDefaults.standard")
        print("   未登记项：")
        for v in new_violations:
            print(v)
        print(f"\n   当前白名单登记 {len(whitelist)} 项，实际使用 {total_count} 项。")
        print("   如需新增，请在 Config/exemptions/userdefaults_standard_whitelist.yml 登记并说明理由。")
        print("   长期目标：逐步迁移到 KeyStoreProtocol（DI 注入）。")
        return 1

    print(f"✅ [UserDefaults.standard Frozen Audit] 审计通过：所有 {total_count} 处 UserDefaults.standard 均在白名单内（{len(whitelist)} 项）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
