#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  scan-plugin-marketplace.py
#  ZhiYu
#
#  系统层级：[Tools/CI] 守卫网关
#  核心职责：扫描插件市场目录（Plugins/Marketplace/）下所有 .zyplugin 包，
#           复用 check-code-plugin-validation.py 的校验逻辑，实现 CI 自动化安全扫描。
#           发现任何校验失败的插件将熔断 CI 流程。
#

import os
import sys
import glob
from pathlib import Path

# 项目根目录（Tools/CI/ → 退 2 层）
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
MARKETPLACE_DIR = PROJECT_DIR / "Plugins" / "Marketplace"
VALIDATOR_SCRIPT = PROJECT_DIR / "Tools" / "ios" / "check-code-plugin-validation.py"


def scan_marketplace():
    """扫描插件市场目录，对每个 .zyplugin 执行校验"""
    print("🔌 [Plugin Marketplace Scanner] 开始扫描插件市场目录...\n")

    if not MARKETPLACE_DIR.exists():
        print(f"ℹ️  插件市场目录不存在: {MARKETPLACE_DIR.relative_to(PROJECT_DIR)}")
        print("   跳过扫描（无插件需校验）")
        return 0

    # 查找所有 .zyplugin 包
    plugin_paths = sorted(
        glob.glob(str(MARKETPLACE_DIR / "**" / "*.zyplugin"), recursive=True)
    )

    if not plugin_paths:
        print(f"ℹ️  插件市场目录无 .zyplugin 包: {MARKETPLACE_DIR.relative_to(PROJECT_DIR)}")
        print("   跳过扫描（无插件需校验）")
        return 0

    print(f"📦 发现 {len(plugin_paths)} 个插件包，开始逐个校验...\n")

    total_passed = 0
    total_failed = 0
    failed_plugins = []

    for plugin_path in plugin_paths:
        rel_path = Path(plugin_path).relative_to(PROJECT_DIR)
        print(f"{'─' * 60}")
        print(f"🔍 校验: {rel_path}")

        # 调用校验脚本
        import subprocess
        result = subprocess.run(
            [sys.executable, str(VALIDATOR_SCRIPT), plugin_path],
            capture_output=False,
        )

        if result.returncode == 0:
            total_passed += 1
            print(f"✅ 通过: {rel_path}\n")
        else:
            total_failed += 1
            failed_plugins.append(str(rel_path))
            print(f"❌ 失败: {rel_path}\n")

    # 汇总报告
    print("=" * 60)
    print("📊 [Plugin Marketplace Scanner] 扫描结果汇总")
    print("=" * 60)
    print(f"  总插件数: {len(plugin_paths)}")
    print(f"  通过: {total_passed}")
    print(f"  失败: {total_failed}")

    if total_failed > 0:
        print(f"\n❌ 失败插件清单:")
        for p in failed_plugins:
            print(f"  • {p}")
        print(f"\n❌ [Plugin Marketplace Scanner] {total_failed} 个插件校验失败，熔断 CI！")
        return 1

    print(f"\n✅ [Plugin Marketplace Scanner] 全部 {total_passed} 个插件校验通过。")
    return 0


if __name__ == "__main__":
    sys.exit(scan_marketplace())
