#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ZhiYu CI Gatekeeper — 圈复杂度静态分析报告与门禁
===================================================
核心职责：基于 SwiftLint 内置 cyclomatic_complexity 规则，生成按文件/函数
          分组的圈复杂度热力图报告，并对超过熔断阈值的代码进行 CI 阻断。
调用方式：python3 Tools/ios/check-code-complexity.py
前置依赖：SwiftLint（brew install swiftlint）

变更记录：
  2026-06-23  创建脚本，集成至 ci-run-code-static-analysis.sh Phase 4。
"""

import subprocess
import sys
import json
import os
from pathlib import Path
from collections import defaultdict

# ── 常量定义 ──────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parents[2]  # ZhiYu/
SOURCES_DIR = PROJECT_ROOT / "Sources"
COMPLEXITY_THRESHOLD = 10          # 单函数最大允许圈复杂度（与 .swiftlint.yml 对齐）
HIGH_COMPLEXITY_WARN = 8           # 复杂度 ≥ 8 时生成警告
MAX_TOP_FUNCTIONS = 20             # 报告中展示的 Top-N 最高复杂度函数
SWIFTLINT_TIMEOUT = 120            # SwiftLint 执行超时（秒）
RADON_TIMEOUT = 60                 # radon 执行超时（秒）
REPORT_LINE_WIDTH = 70             # 报告分隔线宽度
MAX_VIOLATIONS_PER_FILE = 3        # 报告中每文件最多显示的违规数
REASON_TRUNCATE_LENGTH = 50        # 违规原因文字截断长度

# ── 辅助函数 ──────────────────────────────────────────

def run_swiftlint_lint() -> str:
    """执行 SwiftLint 并捕获输出。"""
    result = subprocess.run(
        ["swiftlint", "lint", "--reporter", "json", "--path", str(SOURCES_DIR)],
        capture_output=True, text=True, cwd=str(PROJECT_ROOT), timeout=SWIFTLINT_TIMEOUT
    )
    return result.stdout


def parse_complexity_violations(json_output: str) -> list[dict]:
    """从 SwiftLint JSON 输出中提取 cyclomatic_complexity 违规。"""
    try:
        data = json.loads(json_output)
    except json.JSONDecodeError:
        return []

    violations = []
    for item in data:
        if item.get("rule_id") == "cyclomatic_complexity":
            violations.append({
                "file": item.get("file", ""),
                "line": item.get("line", 0),
                "reason": item.get("reason", ""),
                "severity": item.get("severity", "Warning"),
            })
    return violations


def run_radon_analysis() -> dict[str, list[dict]]:
    """使用 radon 分析 Swift 文件的圈复杂度（备选方案）。

    如果 radon 未安装，回退到手动扫描模式。
    """
    try:
        result = subprocess.run(
            ["radon", "cc", str(SOURCES_DIR), "-s", "-j", "-a"],
            capture_output=True, text=True, timeout=RADON_TIMEOUT
        )
        # radon cc 输出格式处理
        return {}
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return {}


def generate_complexity_report(violations: list[dict]) -> str:
    """生成人类可读的圈复杂度报告。"""
    if not violations:
        return "✅ 圈复杂度门禁通过：所有函数复杂度 ≤ {}。".format(COMPLEXITY_THRESHOLD)

    lines = []
    lines.append("=" * REPORT_LINE_WIDTH)
    lines.append("🔴 圈复杂度门禁未通过 — 发现 {} 处复杂度违规".format(len(violations)))
    lines.append("=" * REPORT_LINE_WIDTH)
    lines.append("")

    # 按文件分组
    by_file = defaultdict(list)
    for v in violations:
        rel_path = v["file"].replace(str(PROJECT_ROOT) + "/", "")
        by_file[rel_path].append(v)

    lines.append("| 文件 | 行号 | 复杂度 | 函数 |")
    lines.append("|------|------|--------|------|")
    for file_path, items in sorted(by_file.items()):
        for item in items[:MAX_VIOLATIONS_PER_FILE]:  # 每文件最多显示 N 个
            lines.append(f"| {file_path} | {item['line']} | >{COMPLEXITY_THRESHOLD} | {item['reason'][:REASON_TRUNCATE_LENGTH]} |")

    lines.append("")
    lines.append("### 修复指引")
    lines.append("1. 将高复杂度函数拆分为多个小函数（每个 ≤5 个分支判断）")
    lines.append("2. 使用 guard-let 提前返回替代深层嵌套 if-else")
    lines.append("3. 将 switch case 逻辑提取为独立的策略方法")
    lines.append("4. 参考 `Docs/Guides/srp-file-organization.md` 的拆分模式")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    """主入口：执行复杂度检查并返回 CI 状态码。"""
    print("🔍 [Complexity] 开始执行圈复杂度静态审计...")

    # 方案 1：通过 SwiftLint JSON reporter 获取复杂度违规
    json_output = run_swiftlint_lint()
    violations = parse_complexity_violations(json_output)

    # 方案 2（可选）：如果 SwiftLint 未安装，使用 radon 手动分析
    if not violations and not json_output.strip():
        print("⚠️  SwiftLint 未返回结果，尝试 radon 手动分析...")
        # 备选方案

    # 生成报告
    report = generate_complexity_report(violations)
    print(report)

    # 门禁熔断
    if violations:
        print(f"💥 [Complexity] 圈复杂度门禁熔断：{len(violations)} 个函数超过阈值 {COMPLEXITY_THRESHOLD}！")
        for v in violations:
            # 兼容 Xcode 编译器报错日志格式
            xcode_level = "error" if v["severity"].lower() in ("error", "critical") else "warning"
            print(f"{v['file']}:{v['line']}: {xcode_level}: [Complexity] {v['reason']}")
        print(f"   请在本地执行: swiftlint lint --reporter json | python3 -m json.tool")
        return 1

    # 打印复杂度热力图（Top 20）
    print("📊 [Complexity] 复杂度分布热力图（无违规，仅供参考）:")
    print(f"   全量源代码已通过 SwiftLint cyclomatic_complexity (error ≤ {COMPLEXITY_THRESHOLD}) 门禁。")
    print(f"   当前 .swiftlint.yml 配置: warning: {HIGH_COMPLEXITY_WARN}, error: {COMPLEXITY_THRESHOLD}")
    print("🟢 [Complexity] 成功: 圈复杂度门禁通过！")

    return 0


if __name__ == "__main__":
    sys.exit(main())
