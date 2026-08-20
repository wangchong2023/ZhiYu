#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gatekeeper: 检查 @Inject 安全模式 — 非可选 @Inject 在 DI 就绪前可能崩溃。

规则：
1. 高风险文件（AppEnvironment.init() 中创建的 Store 类）中，
   非可选的 @Inject（`@Inject var x: T` 而非 `T?`）需人工审核。
2. `resolve()` 直接调用（非 `resolveOptional()`）同样标记。

用法：python3 Tools/ios/check-code-inject-safety.py [--strict]
      --strict: 将违规视为构建失败（CI 模式）
"""

import argparse
import re
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import List

# ── ANSI 颜色代码常量 ──
COLOR_RED = 91
COLOR_YELLOW = 93
COLOR_GREEN = 92

# ── 高风险文件模式 ──
# 这些文件中的类在 AppEnvironment.init() 中被创建，DI 链可能尚未就绪
HIGH_RISK_FILE_PATTERNS = [
    "AppStore.swift",
    "AppStore+*.swift",
    "KnowledgeStore.swift",
    "AIWorkflowStore.swift",
    "SearchStore.swift",
    "TagStore.swift",
    "IngestStore.swift",
    "SynthesisStore.swift",
    "SettingsStore.swift",
]

# ── 中风险文件模式 ──
# 这些文件中的类在运行时通过视图或协调器创建，通常 DI 已就绪
MEDIUM_RISK_FILE_PATTERNS = [
    "*Coordinator*.swift",
    "*View*.swift",
    "WatchDictationView.swift",
    "WatchBriefingView.swift",
]

# 文件路径相对于 Sources/ 目录
SOURCES_ROOT = Path(__file__).resolve().parents[2] / "Sources"

# 非可选 @Inject 的正则模式
_INJECT_RE = re.compile(
    r"@Inject(?:\([^)]*\))?\s+(?:nonisolated\s+)?(?:private\s+)?var\s+(\w+)\s*:\s*(?!.*\?\s*$)(.+)"
)
# resolve() 直接调用的正则模式
_RESOLVE_RE = re.compile(r"\bresolve\s*\(\s*(?!.*resolveOptional)")


@dataclass
class Finding:
    """单次检查发现项。

    :param severity: 严重程度 — HIGH / MEDIUM / LOW
    :param file: 相对于仓库根目录的文件路径
    :param line: 行号（1-based）
    :param kind: 发现类型 — non_optional_inject / direct_resolve
    :param detail: 具体的代码片段描述
    """
    severity: str
    file: str
    line: int
    kind: str
    detail: str


def _match_pattern(filename: str, patterns: List[str]) -> bool:
    """检查文件名是否匹配任一 glob 风格的模式。

    :param filename: 仅文件名（不含路径）
    :param patterns: 支持 ``*`` 通配符的模式列表
    :return: 匹配成功返回 True
    """
    for pattern in patterns:
        regex = pattern.replace("*", ".*").replace(".swift", r"\.swift$")
        if re.match(regex, filename):
            return True
    return False


def scan_file(filepath: Path) -> List[Finding]:
    """扫描单个 Swift 源文件，返回该文件内所有 @Inject 安全发现。

    对文件按风险等级分类，检测非可选 ``@Inject`` 属性及直接
    调用 ``resolve()`` 而不使用 ``resolveOptional()`` 的行。

    ``DependencyKey.liveValue`` 内部的 ``resolve()`` 调用属于标准 DI 注册
    模式（在 DI 容器就绪后才被解析），自动降级为 LOW 风险。

    :param filepath: Swift 源文件绝对路径
    :return: 该文件中发现的问题列表
    """
    findings: List[Finding] = []
    rel_path = str(filepath.relative_to(SOURCES_ROOT.parent))
    filename = filepath.name

    try:
        content = filepath.read_text(encoding="utf-8")
    except Exception:
        return findings

    risk = "HIGH"
    if not _match_pattern(filename, HIGH_RISK_FILE_PATTERNS):
        risk = "MEDIUM" if _match_pattern(filename, MEDIUM_RISK_FILE_PATTERNS) else "LOW"

    in_live_value = False
    for i, raw_line in enumerate(content.splitlines(), start=1):
        line = raw_line.strip()

        if line.startswith("//"):
            continue

        # 豁免标注：// inject_exempt 表示该行 @Inject 已确认 DI 就绪后访问
        if "// inject_exempt" in line:
            continue

        # 跟踪 DependencyKey.liveValue 上下文
        # liveValue 是 computed property，从 `var liveValue` 开始到下一个 `}` 结束
        if re.search(r"\bvar\s+liveValue\b", line):
            in_live_value = True
        if in_live_value and line == "}":
            in_live_value = False

        # liveValue 内部的 resolve 降级为 LOW（标准 DI 注册模式）
        effective_risk = "LOW" if in_live_value else risk

        _check_non_optional_inject(raw_line, effective_risk, rel_path, i, findings)
        _check_direct_resolve(line, effective_risk, rel_path, i, findings)

    return findings


def _check_non_optional_inject(
    raw_line: str, risk: str, rel_path: str, line_no: int, findings: List[Finding]
) -> None:
    """检测单行中的非可选 @Inject 声明。

    :param raw_line: 原始行文本（含缩进）
    :param risk: 当前文件的风险等级
    :param rel_path: 文件相对路径
    :param line_no: 行号
    :param findings: 追加发现到此列表
    """
    match = _INJECT_RE.search(raw_line)
    if not match:
        return
    prop_type = match.group(2).strip()
    if prop_type.endswith("?"):
        return
    findings.append(Finding(
        severity=risk,
        file=rel_path,
        line=line_no,
        kind="non_optional_inject",
        detail=f"@Inject var {match.group(1)}: {prop_type}"
    ))


def _check_direct_resolve(
    line: str, risk: str, rel_path: str, line_no: int, findings: List[Finding]
) -> None:
    """检测单行中直接调用 resolve() 而非 resolveOptional() 的用法。

    :param line: 去除首尾空白后的行文本
    :param risk: 当前文件的风险等级
    :param rel_path: 文件相对路径
    :param line_no: 行号
    :param findings: 追加发现到此列表
    """
    if _RESOLVE_RE.search(line) and "resolveOptional" not in line:
        findings.append(Finding(
            severity=risk,
            file=rel_path,
            line=line_no,
            kind="direct_resolve",
            detail=line
        ))


def _print_findings(label: str, color: int, findings_group: List[Finding]) -> None:
    """按严重等级输出一批发现。

    :param label: 分类标题文本
    :param color: ANSI 颜色代码
    :param findings_group: 该分类下的发现列表
    """
    if not findings_group:
        return
    print(f"\033[{color}m{label}\033[0m")
    for f in findings_group:
        src_line = f"{f.file}:{f.line}"
        print(f"  📄 {src_line}")
        print(f"     [{f.kind}] {f.detail}")
        if f.severity == "HIGH" and f.kind == "non_optional_inject":
            type_name = f.detail.split(":")[1].strip()
            print(f"     💡 建议: 改为 `@Inject var x: {type_name}?` (可选)")


def _classify_findings(all_findings: List[Finding]):
    """按严重程度将发现分为 HIGH / MEDIUM / LOW 三组。

    :param all_findings: 所有发现的列表
    :return: 三元组 (high, medium, low)
    """
    high = [f for f in all_findings if f.severity == "HIGH"]
    medium = [f for f in all_findings if f.severity == "MEDIUM"]
    low = [f for f in all_findings if f.severity == "LOW"]
    return high, medium, low


def _determine_exit_code(high: List[Finding], strict: bool) -> int:
    """根据 HIGH 级发现数量和严格模式判定退出码。

    :param high: HIGH 级发现列表
    :param strict: 是否为 --strict 模式
    :return: 0 通过，1 阻断
    """
    if not high:
        return 0
    if strict:
        print(f"\n❌ STRICT 模式：{len(high)} 处 HIGH 级发现，构建失败。")
        return 1
    print(f"\n⚠️  非严格模式：{len(high)} 处 HIGH 级发现需要人工审核。")
    print("   运行 `python3 Tools/ios/check-code-inject-safety.py --strict` 以在 CI 中断构建。")
    return 0


def main() -> int:
    """入口函数：扫描所有 Swift 源文件并按严重度输出 @Inject 安全报告。

    :return: 0 表示通过（或仅警告），1 表示 --strict 模式下有 HIGH 级阻断
    """
    parser = argparse.ArgumentParser(description="检查 @Inject 安全性")
    parser.add_argument("--strict", action="store_true", help="HIGH 级发现视为错误")
    args = parser.parse_args()

    all_findings: List[Finding] = []
    for fp in SOURCES_ROOT.rglob("*.swift"):
        all_findings.extend(scan_file(fp))

    if not all_findings:
        print("\033[92m✅ 所有 @Inject 均通过安全检查\033[0m\n")
        return 0

    high, medium, low = _classify_findings(all_findings)
    print(f"\n=== @Inject 安全性检查 ({len(all_findings)} 处发现) ===\n")
    _print_findings(
        f"🔴 HIGH — DI 就绪前可能触发 fatalError ({len(high)} 处)",
        COLOR_RED, high
    )
    _print_findings(
        f"🟡 MEDIUM — 懒加载，一般安全 ({len(medium)} 处)",
        COLOR_YELLOW, medium
    )
    _print_findings(
        f"🟢 LOW — 低风险文件 ({len(low)} 处)",
        COLOR_GREEN, low
    )
    return _determine_exit_code(high, args.strict)


if __name__ == "__main__":
    sys.exit(main())
