#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS)
# 脚本名称: Tools/scripts/assert-quality-gate.py
# 脚本功能: 审计 Tools/{ios,ci,scripts,docs}/ 下所有 CI/CD 脚本的命名规范合规性。
#           命名规范（方案 B）：
#             目录 = 领域（Domain）
#             文件名 = [操作]-[技能]-[内容].[ext]  （3 段，无领域前缀）
#           豁免：ci-common-shared.sh（共享库）
# 规范文档: Docs/Guides/development-standards.md § CI/CD 脚本命名规范
# ==============================================================================

import os
import re
import sys

# ── 领域目录（扫描范围）──────────────────────────────────────────────
DOMAIN_DIRS = {"ios", "ci", "scripts", "docs"}

# ── 允许的操作（Action）──────────────────────────────────────────────
ALLOWED_ACTIONS = {"assert", "audit", "check", "build", "run", "generate"}

# ── 技能白名单 ────────────────────────────────────────────────────────
# iOS 7个：arch / code / design / test / release / pipeline / quality
ALLOWED_SKILLS = {
    "arch", "code", "design", "test",
    "release", "pipeline", "quality",
}

# ── 3 段正则：[action]-[skill]-[content].[ext] ──────────────────────
THREE_PART_PATTERN = re.compile(
    r'^(assert|audit|check|build|run|generate)'
    r'-(arch|code|design|test|release|pipeline|quality)'
    r'-[a-z0-9][a-z0-9-]+'
    r'\.(sh|py)$'
)

# ── 豁免白名单 ────────────────────────────────────────────────────────
SHARED_LIB_PATTERN = re.compile(r'^ci-common-shared\.(sh|py)$')

SCRIPT_EXTENSIONS = {".sh", ".py"}


def check_naming(workspace: str) -> list[str]:
    violations: list[str] = []
    tools_dir = os.path.join(workspace, "Tools")

    for domain in sorted(DOMAIN_DIRS):
        domain_path = os.path.join(tools_dir, domain)
        if not os.path.isdir(domain_path):
            violations.append(f"  [缺少领域目录] Tools/{domain}/ 不存在")
            continue

        for fname in sorted(os.listdir(domain_path)):
            if not any(fname.endswith(ext) for ext in SCRIPT_EXTENSIONS):
                continue
            fpath = os.path.join(domain_path, fname)
            rel = f"Tools/{domain}/{fname}"

            if SHARED_LIB_PATTERN.match(fname):
                continue

            try:
                with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
                    head = "".join(f.readline() for _ in range(15))
                if "NAMING-bypass" in head:
                    continue
            except Exception:
                pass

            if THREE_PART_PATTERN.match(fname):
                continue

            stem = fname.rsplit(".", 1)[0]
            parts = stem.split("-")
            if len(parts) < 3:
                hint = f"（需要 3 段 [操作]-[技能]-[内容]，当前 {len(parts)} 段：'{stem}'）"
            elif parts[0] not in ALLOWED_ACTIONS:
                hint = f"（操作 '{parts[0]}' 不在允许列表 {sorted(ALLOWED_ACTIONS)} 中）"
            elif parts[1] not in ALLOWED_SKILLS:
                hint = f"（技能 '{parts[1]}' 不在允许列表 {sorted(ALLOWED_SKILLS)} 中）"
            else:
                hint = "（格式不符合 [action]-[skill]-[content] 规范）"
            violations.append(f"  {rel} — 命名不合规 {hint}")

    return violations


def main() -> int:
    workspace = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..")
    )
    print("=== ZhiYu CI/CD 脚本命名规范审计（方案B：目录=领域，文件名=3段）===\n")
    violations = check_naming(workspace)

    if not violations:
        print("=== ✓ 审计通过：所有脚本命名合规 ===\n")
        return 0
    else:
        print(f"── 命名格式违规（{len(violations)} 处）──")
        for v in violations:
            print(v)
        print(f"\n=== ❌ 审计失败：{len(violations)} 处违规 ===")
        print("  修复建议：文件名格式 [action]-[skill]-[content].[ext]，放入 Tools/{ios,ci,scripts,docs}/")
        return 1


if __name__ == "__main__":
    sys.exit(main())
