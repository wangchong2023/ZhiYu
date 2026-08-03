#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-code-dead-code.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/24.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] CI 质量门禁
#  核心职责：集成 Periphery 检测未使用的类型/方法/属性，仅报告真正死代码（排除跨模块公开 API）。
#           重点检测：开源适配器物理迁移后旧文件残留（逻辑隔离 → 物理隔离的关键保障）。
#
"""死代码检测门禁：集成 Periphery，检测未使用的类型/方法/属性。

仅报告真正未使用的声明（排除 "declared public, but not used outside" 这类跨 target API）。
退出码: 0=通过, 非0=发现死代码
"""

import subprocess
import sys
import re
from pathlib import Path

# ── 常量 ──
MAX_DISPLAY_LINES = 30
# 渐进式阈值：超过此数量则阻断构建，随清理进度逐步收紧
MAX_ALLOWED_DEAD_CODE = 50

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"

# 基线：忽略已存在的无害模式
IGNORE_PATTERNS = [
    r"is declared public, but not used outside",      # 跨模块公开 API
    r"protocol .* conformance is redundant",           # 协议冗余声明
    r"retained, but never used",                       # 保留字段
]

# ── 物理迁移残留检测规则 ──
# 适配器物理迁移到 SPM 包后，Sources/ 中不应再存在旧文件
MIGRATION_RESIDUE_RULES = [
    {
        "old_path": "Infrastructure/Processors/Synthesis/JSONRepairProcessor.swift",
        "hint": "JSONRepairProcessor 应已迁移至 Packages/ZhiYuAICore/Sources/ZhiYuAICore/Adapters/",
    },
    {
        "old_path": "Shared/UIComponents/Feedback/AppLottieView.swift",
        "hint": "AppLottieView 应已迁移至 Packages/UFPDesignSystem/Sources/UFPDesignSystem/Adapters/",
    },
    {
        "old_path": "Shared/UIComponents/Markdown/MarkdownRendererView.swift",
        "hint": "MarkdownRendererView 应在 Packages/UFPDesignSystem/Sources/UFPDesignSystem/Adapters/ 中创建",
    },
]

def _check_migration_residues() -> list[str]:
    """检测物理迁移后旧适配文件是否仍残留在 Sources/ 中。"""
    residues = []
    for rule in MIGRATION_RESIDUE_RULES:
        old_full = SOURCES_DIR / rule["old_path"]
        if old_full.exists():
            residues.append(f"⚠️  迁移残留：Sources/{rule['old_path']}\n   → {rule['hint']}")
    return residues


def _run_periphery() -> str:
    """运行 Periphery 扫描，优先使用 .periphery.yml 配置文件。"""
    periphery_yml = PROJECT_ROOT / ".periphery.yml"
    if periphery_yml.exists():
        # 使用项目根目录的 .periphery.yml 配置
        cmd = ["periphery", "scan", "--quiet"]
    else:
        cmd = [
            "periphery", "scan",
            "--project", str(PROJECT_ROOT / "ZhiYu.xcodeproj"),
            "--schemes", "ZhiYu",
            "--targets", "ZhiYu",
            "--quiet",
            "--disable-update-check",
        ]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(PROJECT_ROOT))
    return result.stdout + result.stderr


def _filter_findings(raw_output: str) -> list[str]:
    """过滤 Periphery 输出，只保留真正未使用的声明。"""
    findings = []
    for line in raw_output.splitlines():
        if "warning:" not in line:
            continue
        if any(re.search(p, line) for p in IGNORE_PATTERNS):
            continue
        findings.append(line.strip())
    return findings


def main():
    """主入口。"""
    # ── 第一步：物理迁移残留快速检测（无需编译）──
    print("🔍 [第一步] 检测物理迁移残留文件...")
    residues = _check_migration_residues()
    if residues:
        print()
        for r in residues:
            print(f"  {r}")
        print()
        print("❌ 发现物理迁移残留文件！请完成适配器物理迁移后删除旧文件。")
        return 1
    else:
        print("✅ 无物理迁移残留文件。")

    # ── 第二步：Periphery 死代码全量扫描 ──
    print("\n🔍 [第二步] 运行 Periphery 死代码扫描（首次需编译约 2-5 分钟）...")
    raw = _run_periphery()

    findings = _filter_findings(raw)
    total_all = len(raw.splitlines())

    if not findings:
        print(f"✅ 死代码检测通过（扫描 {total_all} 项，0 项需处理）")
        return 0

    print(f"\n📋 发现 {len(findings)} 处死代码（总警告 {total_all}，已过滤跨模块 API）:")
    for f in findings[:MAX_DISPLAY_LINES]:
        print(f"  {f}")
    if len(findings) > MAX_DISPLAY_LINES:
        print(f"  ... 及其他 {len(findings) - MAX_DISPLAY_LINES} 条")

    print()
    if len(findings) > MAX_ALLOWED_DEAD_CODE:
        print(
            f"❌ 死代码数量 {len(findings)} 超过阈值 {MAX_ALLOWED_DEAD_CODE}，构建阻断！\n"
            f"   提示：在确认误报处添加 // periphery:ignore，或清理未使用代码。"
        )
        return 1
    else:
        print(
            f"⚠️  死代码 {len(findings)} 处（未超阈值 {MAX_ALLOWED_DEAD_CODE}），构建继续。\n"
            f"   建议逐步清理并收紧 MAX_ALLOWED_DEAD_CODE。"
        )
        return 0


if __name__ == "__main__":
    sys.exit(main())
