#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-code-business-magic-numbers.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/05.
#  Copyright © 2026 WangChong. All rights reserved.
#
# 系统层级：[Tools/ios] 守卫网关
# 核心职责：补全 AGENTS.md 红线 #4「彻底去魔鬼化数字/字符/字符串」的业务层守门。
#          现有 audit-design-magic-numbers.py 仅检测 UI 设计令牌（padding/frame/color），
#          本脚本专扫 Domain/Infrastructure/Core 业务逻辑层的：
#            1. 业务阈值魔鬼数字（比较运算符/prefix/参数默认值/赋值中的裸数字）
#            2. 硬编码 Prompt 字符串（多行字符串字面量或含英文指令性词汇的单行字符串）
#            3. 硬编码 SQL/正则字面量（直接出现在代码中的复杂正则或 SQL 片段）
#
# 豁免机制：统一走 ExemptionRegistry（Config/exemptions/manual_whitelist.yml）
#          在 business_magic_exempt 分类下登记，每项含 file/line/reason/expiry_check
#          不支持行注释豁免（// magic_exempt），所有豁免必须显式登记在 whitelist
#
# 用法：python3 Tools/ios/audit-code-business-magic-numbers.py [--strict]
#       --strict: 将违规视为构建失败（CI 模式）
#

import argparse
import re
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Set, Tuple, Optional

# ── 扫描范围：业务逻辑层（排除 UI 层，UI 层由 audit-design-magic-numbers.py 负责）──
SCAN_DIRS = [
    "Sources/Domain",
    "Sources/Infrastructure",
    "Sources/Core",
]

# ── 排除目录 ──
EXCLUDE_DIRS = {".git", "build", "DerivedData", ".build", "Frameworks", "__pycache__"}

# ── 常量定义文件白名单（这些文件本身就是常量集，不审计）──
CONSTANT_FILES = {
    "AppConstants.swift",
    "SearchConstants.swift",
    "DomainConstants.swift",
    "GraphConstants.swift",
    "PromptConstants.swift",
    "InferenceDefaults.swift",
    "IngestPipelineConstants.swift",
    "RAGEvalConstants.swift",
    "SyncConstants.swift",
    "DeviceConstants.swift",
    "KnowledgePageLimits.swift",
    "BackupConstants.swift",
    "UndoConstants.swift",
}

# ── 合法数字（边界值，不视为魔鬼数字）──
# 0/1/-1/0.0/1.0/-1.0 是常见的边界值；2 是常见的二元/三元状态值
# 注意：HTTP 状态码、位运算移位、IP 段等协议常量不在此列，
#       必须在功能代码中抽取为强类型常量/枚举（如 HTTPStatusCode.ok、BitShift.octet1）。
#       这是 AGENTS.md 红线 #4「彻底去魔鬼化」的硬性要求，不通过文件白名单豁免。
BENIGN_NUMBERS = {"0", "1", "-1", "0.0", "1.0", "-1.0", "2", "-2"}

# ── 正则复杂度阈值：特殊字符数 >= 此值即判定为硬编码正则 ──
REGEX_SPECIAL_CHARS_THRESHOLD = 3

# ── 多行字符串分隔符 ──
MULTILINE_STRING_DELIM = '"""'

# ── Prompt 指令性关键词（出现即判定为硬编码 Prompt）──
# 含英文和中文指令性词汇，覆盖常见 Prompt 开头模式
PROMPT_KEYWORDS = [
    # 英文指令词
    "You are",
    "Summarize",
    "Generate",
    "Please",
    "Analyze",
    "Extract",
    "Translate",
    "Rewrite",
    "Based on",
    "followed by",
    "Your task",
    "As an expert",
    "Act as",
    # 中文指令词
    "你是一位",
    "你是一个",
    "请分析",
    "请基于",
    "请总结",
    "请生成",
    "请提取",
    "请翻译",
    "请重写",
    "请按照",
    "请用",
    "请从",
    "任务是",
    "角色是",
]

# ── 诊断输出时代码行内容的最大截断长度 ──
MAX_LINE_PREVIEW_LEN = 120

# ── 豁免分类名（在 manual_whitelist.yml 中登记）──
EXEMPT_CATEGORY = "business_magic_exempt"

PROJECT_ROOT = Path(__file__).resolve().parents[2]


@dataclass
class Finding:
    """单次检查发现项。

    :param kind: 发现类型 — magic_number / hardcoded_prompt / hardcoded_regex
    :param file: 相对于仓库根目录的文件路径
    :param line: 行号（1-based）
    :param detail: 具体的代码片段描述
    :param content: 违规行原文（截断）
    """
    kind: str
    file: str
    line: int
    detail: str
    content: str


def _is_enum_raw_value_line(line: str) -> bool:
    """判断该行是否为枚举 rawValue 赋值行（如 ``case fail = "fail"`` 或 ``case retry = 3``）。

    :param line: 原始代码行
    :return: 是枚举 rawValue 行返回 True
    """
    stripped = line.strip()
    return bool(re.match(r"^case\s+\w+\s*=\s*", stripped))


def _is_single_value_constant(line: str) -> bool:
    """判断该行是否为「单值常量定义」（右侧只有一个数字字面量）。

    单值常量定义（如 ``static let rrfK: Double = 60``）已有语义名称，
    其中的数字是合法的，不应视为魔鬼数字。

    复合表达式常量定义（如 ``private let maxResponseSize = 5 * 1024 * 1024``）
    不在此列——其中的 ``1024`` 是字节换算常量，应抽为 ``BytesPerKB``。

    :param line: 原始代码行
    :return: 是单值常量定义返回 True
    """
    stripped = line.strip()
    # 匹配 `[access] [static] let/var xxx[: Type] = <single_number>`
    # 右侧只允许：单个数字（可带负号/小数点），不能有运算符 * / + - 等
    pattern = (
        r"^(?:public\s+|private\s+|internal\s+|fileprivate\s+)?"
        r"(?:static\s+)?(let|var)\s+\w+(?:\s*:\s*\w+)?\s*=\s*"
        r"(-?\d+\.?\d*)\s*$"
    )
    return bool(re.match(pattern, stripped))


def _extract_numbers_from_line(line: str) -> List[str]:
    """从代码行中提取所有数字字面量（排除注释部分）。

    检测模式：
    1. 比较运算符后的数字：``> 0.7`` / ``<= 200`` / ``== 0.5``
    2. prefix/maxLength/maxCount 等函数参数中的数字：``prefix(200)`` / ``limit: 3000``
    3. 赋值语句中的数字：``let timeout = 3000`` / ``progress = 0.75``
    4. 函数默认参数中的数字：``timeout: TimeInterval = 30``
    5. 复合表达式常量定义中的数字：``private let x = 5 * 1024 * 1024``
       （单值常量 ``static let x = 60`` 跳过，已有语义名）

    :param line: 原始代码行
    :return: 提取出的数字字符串列表（去重）
    """
    # 去除行尾注释（粗略处理，避免注释中的数字被误判）
    code_part = line.split("//")[0]

    # 单值常量定义整体跳过（static let xxx = 60 已有语义名）
    if _is_single_value_constant(code_part):
        return []

    numbers = set()

    # 模式 1: 比较运算符后的数字 — < 0.7 / >= 200 / == 0.5 / != 0
    # 注意：排除赋值 =（单独的 = 不是比较运算符）
    for m in re.finditer(r"[<>!]=?\s*(\-?\d+\.?\d*)\b|==\s*(\-?\d+\.?\d*)\b", code_part):
        num = m.group(1) or m.group(2)
        if num:
            numbers.add(num)

    # 模式 2: prefix(\d+) / suffix(\d+) / maxLen(\d+) 等函数参数
    for m in re.finditer(r"\b(?:prefix|suffix|maxLength|minLength|maxCount|minCount|maxRetries|limit|timeout|delay|interval|batchSize|chunkSize|windowSize|topN|topK)\s*\(?\s*(\-?\d+\.?\d*)\b", code_part):
        numbers.add(m.group(1))

    # 模式 3: 赋值语句中的数字 — let/var xxx = 3000 / progress = 0.75
    # 排除 == 比较运算符（已在模式 1 处理）
    # 注意：单值常量定义已在上文跳过，这里会处理复合表达式（5 * 1024 * 1024）
    for m in re.finditer(r"(?<![=<>!])=\s*(\-?\d+\.?\d*)\b", code_part):
        numbers.add(m.group(1))

    # 模式 4: 函数默认参数 — timeout: TimeInterval = 30 / limit: Int = 200
    for m in re.finditer(r":\s*\w+\s*=\s*(\-?\d+\.?\d*)\b", code_part):
        numbers.add(m.group(1))

    # 模式 5: 复合表达式中的裸数字 — 5 * 1024 * 1024 / 1 << 24 / value & 0xFF
    # 检测乘法/除法/位运算/移位运算中的数字（这些通常是换算常量或位掩码，应抽为命名常量）
    # 排除已被模式 1-4 覆盖的比较/赋值场景
    for m in re.finditer(r"[*\/%<>]\s*(\-?\d+\.?\d*)\b", code_part):
        numbers.add(m.group(1))

    return list(numbers)


def _is_hardcoded_prompt(line: str, in_multiline: bool) -> bool:
    """判断该行是否包含硬编码 Prompt 字符串。

    检测规则：
    1. 多行字符串字面量 (三引号) 内的内容，若含指令性词汇则视为 Prompt
    2. 单行字符串中含 Prompt 指令性关键词

    :param line: 原始代码行
    :param in_multiline: 是否处于多行字符串字面量内部
    :return: 是硬编码 Prompt 返回 True
    """
    # 单行或双引号字符串中检测 Prompt 关键词
    # 提取所有双引号字符串（长度 >= 20，避免短字符串误报）
    for m in re.finditer(r'"([^"]{20,})"', line):
        content = m.group(1)
        for keyword in PROMPT_KEYWORDS:
            if keyword.lower() in content.lower():
                return True

    # 多行字符串内部：检测是否含指令性词汇
    if in_multiline:
        for keyword in PROMPT_KEYWORDS:
            if keyword in line:
                return True

    return False


def _is_hardcoded_regex(line: str) -> bool:
    """判断该行是否包含硬编码复杂正则字面量。

    检测规则：NSRegularExpression 或 .firstMatch(in:) 等场景中的正则字符串
    含至少 3 个特殊字符（[]().*+?^$|\\）的字符串视为复杂正则。

    :param line: 原始代码行
    :return: 是硬编码正则返回 True
    """
    # 检测 NSRegularExpression(pattern: "...") 或 pattern: "..." 字符串
    regex_pattern_match = re.search(r'(?:NSRegularExpression\(pattern:\s*|pattern:\s*)["\']([^"\']{8,})["\']', line)
    if regex_pattern_match:
        pattern = regex_pattern_match.group(1)
        # 统计正则特殊字符数量
        special_chars = sum(1 for c in pattern if c in "[]().*+?^$|\\{}")
        if special_chars >= REGEX_SPECIAL_CHARS_THRESHOLD:
            return True
    return False


def _check_prompt_in_line(line: str, was_in_multiline: bool, rel_path: str, line_no: int, stripped: str) -> Optional[Finding]:
    """检测单行中的硬编码 Prompt（多行字符串内部）。

    :return: 发现违规返回 Finding，否则 None
    """
    if _is_hardcoded_prompt(line, was_in_multiline):
        return Finding(
            kind="hardcoded_prompt",
            file=rel_path,
            line=line_no,
            detail="硬编码 Prompt 字符串，应迁移到 L10n.Prompt.* 或 PromptTemplates 常量",
            content=stripped[:MAX_LINE_PREVIEW_LEN]
        )
    return None


def _check_regex_in_line(line: str, rel_path: str, line_no: int, stripped: str) -> Optional[Finding]:
    """检测单行中的硬编码复杂正则。

    :return: 发现违规返回 Finding，否则 None
    """
    if _is_hardcoded_regex(line):
        return Finding(
            kind="hardcoded_regex",
            file=rel_path,
            line=line_no,
            detail="硬编码复杂正则字面量，应抽取为强类型常量",
            content=stripped[:MAX_LINE_PREVIEW_LEN]
        )
    return None


def _check_magic_numbers_in_line(line: str, rel_path: str, line_no: int, stripped: str) -> List[Finding]:
    """检测单行中的业务魔鬼数字。

    :return: 发现的违规列表（可能多个）
    """
    results: List[Finding] = []
    numbers = _extract_numbers_from_line(line)
    for num in numbers:
        if num in BENIGN_NUMBERS:
            continue
        results.append(Finding(
            kind="magic_number",
            file=rel_path,
            line=line_no,
            detail=f"业务魔鬼数字 `{num}`，应抽取为强类型常量",
            content=stripped[:MAX_LINE_PREVIEW_LEN]
        ))
    return results


def _process_line(line: str, stripped: str, in_multiline: bool, rel_path: str, line_no: int) -> Tuple[List[Finding], bool]:
    """处理单行代码，返回该行的发现列表和更新后的多行字符串状态。

    :param in_multiline: 进入该行前的多行字符串状态
    :return: (发现列表, 离开该行后的多行字符串状态)
    """
    findings: List[Finding] = []

    # 多行字符串状态跟踪：统计该行 """ 数量，奇数则切换状态
    delim_count = line.count(MULTILINE_STRING_DELIM)
    was_in_multiline = in_multiline
    if delim_count % 2 == 1:
        in_multiline = not in_multiline

    # 多行字符串内部：只检测 Prompt，跳过数字
    if was_in_multiline or in_multiline:
        prompt_finding = _check_prompt_in_line(line, was_in_multiline, rel_path, line_no, stripped)
        if prompt_finding:
            findings.append(prompt_finding)
        return findings, in_multiline

    # 跳过枚举 rawValue 行
    if _is_enum_raw_value_line(line):
        return findings, in_multiline

    # 检测硬编码正则
    regex_finding = _check_regex_in_line(line, rel_path, line_no, stripped)
    if regex_finding:
        findings.append(regex_finding)

    # 检测业务魔鬼数字
    findings.extend(_check_magic_numbers_in_line(line, rel_path, line_no, stripped))

    return findings, in_multiline


def scan_file(filepath: Path) -> List[Finding]:
    """扫描单个 Swift 源文件，返回该文件内所有业务层魔鬼数字/字符串发现。

    :param filepath: Swift 源文件绝对路径
    :return: 该文件中发现的问题列表
    """
    findings: List[Finding] = []
    rel_path = str(filepath.relative_to(PROJECT_ROOT))

    # 常量定义文件跳过
    if filepath.name in CONSTANT_FILES:
        return findings

    try:
        content = filepath.read_text(encoding="utf-8")
    except Exception:
        return findings

    lines = content.splitlines()
    in_multiline = False

    for i, raw_line in enumerate(lines, start=1):
        line = raw_line.rstrip()

        # 跳过纯注释行
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("*"):
            continue

        line_findings, in_multiline = _process_line(line, stripped, in_multiline, rel_path, i)
        findings.extend(line_findings)

    return findings


def load_exemptions() -> Tuple[Set[Tuple[str, int]], List[dict]]:
    """从 ExemptionRegistry 加载 business_magic_exempt 分类的行级豁免。

    豁免项结构：
        - file: 相对于仓库根的文件路径（如 Sources/Domain/RAG/RAGEvaluationService.swift）
        - line: 行号（1-based）
        - reason: 豁免理由
        - expiry_check: 是否参与过期检测

    :return: (豁免集合 {(file, line)}, 全部豁免项列表)
    """
    exempt_keys: Set[Tuple[str, int]] = set()
    exempt_items: List[dict] = []

    try:
        sys.path.insert(0, str(PROJECT_ROOT / "Tools" / "CI"))
        from exemption_registry import ExemptionRegistry  # noqa: E402
        registry = ExemptionRegistry()
        registry.load()
        items = registry.whitelist_data.get(EXEMPT_CATEGORY, [])
        if not isinstance(items, list):
            return exempt_keys, exempt_items
        for item in items:
            if not isinstance(item, dict):
                continue
            file = item.get("file")
            line = item.get("line")
            if file and line is not None:
                exempt_keys.add((file, int(line)))
                exempt_items.append(item)
    except Exception as e:
        print(f"⚠️ 豁免加载失败：{e}", file=sys.stderr)

    return exempt_keys, exempt_items


def check_stale_exemptions(exempt_items: List[dict], findings: List[Finding]) -> List[dict]:
    """反向校验：检测豁免项是否已过期（即对应行已无违规）。

    :param exempt_items: 全部豁免项列表
    :param findings: 本次审计的全部发现
    :return: 过期豁免项列表
    """
    finding_keys = {(f.file, f.line) for f in findings}
    stale = []
    for item in exempt_items:
        if not item.get("expiry_check", False):
            continue
        file = item.get("file")
        line = item.get("line")
        if file and line is not None and (file, int(line)) not in finding_keys:
            stale.append(item)
    return stale


def scan_all() -> List[Finding]:
    """扫描所有业务逻辑层目录，返回全部发现项。

    :return: 全部审计发现列表
    """
    all_findings: List[Finding] = []
    for scan_dir in SCAN_DIRS:
        root = PROJECT_ROOT / scan_dir
        if not root.exists():
            continue
        for filepath in root.rglob("*.swift"):
            # 排除目录
            if any(part in EXCLUDE_DIRS for part in filepath.parts):
                continue
            all_findings.extend(scan_file(filepath))
    return all_findings


KIND_LABELS = {
    "magic_number": "业务魔鬼数字",
    "hardcoded_prompt": "硬编码 Prompt 字符串",
    "hardcoded_regex": "硬编码复杂正则",
}


def _print_findings_report(findings: List[Finding]) -> None:
    """打印违规发现报告（按类型分组）。"""
    by_kind: Dict[str, List[Finding]] = {}
    for f in findings:
        by_kind.setdefault(f.kind, []).append(f)

    print(f"❌ [Business Magic Numbers] 审计完成：发现 {len(findings)} 处违规")
    print()
    for kind, label in KIND_LABELS.items():
        items = by_kind.get(kind, [])
        if not items:
            continue
        print(f"── {label}（{len(items)} 处）──")
        for f in items:
            print(f"  {f.file}:{f.line}: {f.detail}")
            print(f"    → {f.content}")
        print()


def _print_fix_guidance() -> None:
    """打印修复指引。"""
    print("修复指引：")
    print("  1. 魔鬼数字 → 抽取到对应模块的 *Constants.swift 文件（如 RAGEvalConstants / IngestPipelineConstants）")
    print("  2. 硬编码 Prompt → 迁移到 L10n.Prompt.* 或 PromptTemplates 常量")
    print("  3. 硬编码正则 → 抽取为强类型常量或 Regex 枚举")
    print(f"  4. 确需豁免的行，在 Config/exemptions/manual_whitelist.yml 的 `{EXEMPT_CATEGORY}` 分类下登记 file/line/reason")
    print()


def _print_stale_exemptions(stale_exemptions: List[dict]) -> None:
    """打印过期豁免警告。"""
    print(f"⚠️ [Business Magic Numbers] 发现 {len(stale_exemptions)} 个过期豁免（对应行已无违规，建议移除）：")
    for item in stale_exemptions:
        print(f"  {item.get('file')}:{item.get('line')} — {item.get('reason', '')}")
    print()


def main() -> int:
    """审计入口：扫描业务层魔鬼数字/字符串并输出报告。

    :return: 0 表示通过，1 表示有违规（--strict 模式）
    """
    parser = argparse.ArgumentParser(description="业务层魔鬼数字/字符串审计")
    parser.add_argument("--strict", action="store_true", help="违规视为构建失败（CI 模式）")
    args = parser.parse_args()

    # 加载豁免
    exempt_keys, exempt_items = load_exemptions()

    # 扫描
    all_findings = scan_all()

    # 应用豁免：过滤掉已豁免的发现
    findings = [f for f in all_findings if (f.file, f.line) not in exempt_keys]

    # 反向校验过期豁免
    stale_exemptions = check_stale_exemptions(exempt_items, all_findings)

    if not findings and not stale_exemptions:
        print("✅ [Business Magic Numbers] 审计通过：业务层无魔鬼数字/硬编码 Prompt。")
        return 0

    exit_code = 0

    if findings:
        _print_findings_report(findings)
        _print_fix_guidance()
        if args.strict:
            exit_code = 1

    if stale_exemptions:
        _print_stale_exemptions(stale_exemptions)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
