#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-code-magic-strings.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/22.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：检查 Sources/Features/ 和 Sources/Platforms/ 中硬编码的 UserDefaults key、URL
#           以及单字符字面量（花括号/引号/反斜杠等）。
#           硬编码的 forKey 字符串、https?:// URL 应使用 AppConstants.URLs / AppConstants.Keys.Storage 常量；
#           单字符字面量应使用 UFPCore.SystemConstants.Character.* 常量。
#

import sys
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"

# 硬编码 UserDefaults key 模式
UD_KEY_PATTERN = re.compile(r'UserDefaults\.[^)]*forKey:\s*"[^"]+"')
# 硬编码 URL 模式
URL_PATTERN = re.compile(r'"(https?://[^"]+)"')

# UI 组件中的硬编码字符串模式（Text/Label/Button/.navigationTitle 等）
# 匹配：UI组件("字符串字面量" 或 UI组件("字符串字面量",
UI_STRING_PATTERN = re.compile(
    r'\b(?:Text|Label|Button|navigationTitle|Alert|ConfirmationDialog|Toast|Picker|Toggle|Section|TextField|SecureField|TextEditor)\s*\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
)
# 排除的 UI 字符串模式（合理保留）
UI_STRING_EXCLUDE_PATTERNS = [
    re.compile(r'L10n\.'),
    re.compile(r'Localized\.'),
    re.compile(r'\.tr\('),
    re.compile(r'\.trf\('),
    re.compile(r'LocalizedStringKey'),
    re.compile(r'^\s*//'),  # 注释行
    re.compile(r'^\s*\*'),  # 文档注释续行
    re.compile(r'/// '),  # 文档注释
]
# 豁免的 UI 字符串值（空字符串、纯格式占位符等）
UI_STRING_EXEMPT_VALUES = {
    "",  # 空字符串
    "%@",  # 格式占位符
    "%d",
    "%.1f",
    "%.0f",
}

# 排除的 URL 模式（合理保留）
URL_EXCLUDE_PATTERNS = [
    re.compile(r'AppConstants\.URLs\.'),
    re.compile(r'schemas\.openxmlformats\.org'),
    re.compile(r'api\.example\.com'),
    re.compile(r'hasPrefix\("http'),
]

# 应走 SystemConstants.Character 的单字符字面量
# 仅检测明确应该用常量的 API 调用中的单字符字面量，避免字符串插值误报
# key: (字面量正则, 业务语义描述), value: 推荐常量名
SINGLE_CHAR_LITERALS = {
    (r'"\{"', "JSON 对象起始符 / 代码块起始符"): 'SystemConstants.Character.openBrace',
    (r'"\}"', "JSON 对象结束符 / 代码块结束符"): 'SystemConstants.Character.closeBrace',
    (r'"\("', "函数参数列表起始符 / 分组起始符"): 'SystemConstants.Character.openParen',
    (r'"\)"', "函数参数列表结束符 / 分组结束符"): 'SystemConstants.Character.closeParen',
    (r'"\["', "数组下标起始符 / Markdown 链接起始符"): 'SystemConstants.Character.openBracket',
    (r'"\]"', "数组下标结束符 / Markdown 链接结束符"): 'SystemConstants.Character.closeBracket',
    (r'"\\\\"', "转义符 / 路径分隔符"): 'SystemConstants.Character.backslash',
    (r'\\"\\\\"', "字符串定界符"): 'SystemConstants.Character.doubleQuote',
}

# 仅在这些 API 调用上下文中检测单字符字面量（避免字符串插值误报）
SINGLE_CHAR_API_PATTERNS = [
    re.compile(r'replacingOccurrences\(of:\s*'),
    re.compile(r'firstIndex\(of:\s*'),
    re.compile(r'lastIndex\(of:\s*'),
    re.compile(r'\.contains\(\s*"'),
    re.compile(r'hasPrefix\(\s*"'),
    re.compile(r'hasSuffix\(\s*"'),
    re.compile(r'==\s*"[\{\}\(\)\[\]\\\\]"\s*'),
    re.compile(r'!=\s*"[\{\}\(\)\[\]\\\\]"\s*'),
]

# 单字符字面量检测的排除模式（合理保留场景）
SINGLE_CHAR_EXCLUDE_PATTERNS = [
    re.compile(r'SystemConstants\.Character\.'),
    re.compile(r'ProcessorConstants\.MarkdownSyntax\.'),
    re.compile(r'^\s*//'),  # 注释行
    re.compile(r'^\s*\*'),  # 文档注释续行
    re.compile(r'/// '),  # 文档注释
]

CHECK_DIRS = [
    SOURCES_DIR / "Features",
    SOURCES_DIR / "Platforms",
]


def _should_exclude_url(content: str) -> bool:
    """判断 URL 行是否属于合理保留模式（XML 命名空间、placeholder、协议检查等）。"""
    for pat in URL_EXCLUDE_PATTERNS:
        if pat.search(content):
            return True
    return False


def _should_exclude_single_char(content: str) -> bool:
    """判断单字符字面量行是否属于合理保留场景（已用常量、注释等）。"""
    for pat in SINGLE_CHAR_EXCLUDE_PATTERNS:
        if pat.search(content):
            return True
    return False


def _is_in_char_api_context(content: str) -> bool:
    """判断该行是否处于应使用常量的 API 调用上下文中（避免字符串插值误报）。"""
    for pat in SINGLE_CHAR_API_PATTERNS:
        if pat.search(content):
            return True
    return False


def _should_exclude_ui_string(content: str, match_value: str) -> bool:
    """判断 UI 字符串是否属于合理保留场景（已用 L10n、注释、空字符串、字符串插值等）。"""
    if match_value in UI_STRING_EXEMPT_VALUES:
        return True
    # 排除字符串插值（含 \( 的字符串不是纯硬编码）
    if '\\(' in match_value:
        return True
    for pat in UI_STRING_EXCLUDE_PATTERNS:
        if pat.search(content):
            return True
    return False


def _scan_ud_key(line: str, rel_path: Path, line_no: int) -> list:
    """检测 UserDefaults key 硬编码。"""
    if UD_KEY_PATTERN.search(line) and 'AppConstants' not in line:
        return [(rel_path, line_no, line.strip())]
    return []


def _scan_url(line: str, rel_path: Path, line_no: int) -> list:
    """检测 URL 硬编码。"""
    if URL_PATTERN.search(line) and not _should_exclude_url(line):
        return [(rel_path, line_no, line.strip())]
    return []


def _scan_single_char(line: str, rel_path: Path, line_no: int) -> list:
    """检测单字符字面量硬编码。"""
    violations = []
    if not _should_exclude_single_char(line) and _is_in_char_api_context(line):
        for (pattern, semantic), const_name in SINGLE_CHAR_LITERALS.items():
            if re.search(pattern, line):
                violations.append((rel_path, line_no, line.strip(), const_name, semantic))
    return violations


def _scan_ui_string(line: str, rel_path: Path, line_no: int) -> list:
    """检测 UI 硬编码字符串。"""
    violations = []
    for m in UI_STRING_PATTERN.finditer(line):
        match_value = m.group(1)
        if not _should_exclude_ui_string(line, match_value):
            violations.append((rel_path, line_no, line.strip(), match_value))
    return violations


def _scan_line_for_violations(line: str, rel_path: Path, line_no: int) -> tuple[list, list, list, list]:
    """
    扫描单行代码的四类违规：UserDefaults key、URL、单字符字面量、UI 硬编码字符串。

    :param line: 单行代码内容
    :param rel_path: 文件相对路径
    :param line_no: 行号
    :return: (UD 违规列表, URL 违规列表, 单字符违规列表, UI字符串违规列表)
    """
    return (
        _scan_ud_key(line, rel_path, line_no),
        _scan_url(line, rel_path, line_no),
        _scan_single_char(line, rel_path, line_no),
        _scan_ui_string(line, rel_path, line_no),
    )


def _scan_directory(check_dir: Path) -> tuple[list, list, list, list]:
    """
    扫描目录中所有 Swift 文件的硬编码 UserDefaults key、URL、单字符字面量和 UI 硬编码字符串。

    :param check_dir: 扫描目录
    :return: (UD 违规列表, URL 违规列表, 单字符违规列表, UI字符串违规列表)
    """
    all_ud = []
    all_url = []
    all_char = []
    all_ui_string = []
    if not check_dir.exists():
        return all_ud, all_url, all_char, all_ui_string

    for swift_file in check_dir.rglob("*.swift"):
        rel_path = swift_file.relative_to(PROJECT_ROOT)
        try:
            with open(swift_file, 'r') as f:
                lines = f.readlines()
        except Exception:
            continue
        for i, line in enumerate(lines, 1):
            uds, urls, chars, ui_strings = _scan_line_for_violations(line, rel_path, i)
            all_ud.extend(uds)
            all_url.extend(urls)
            all_char.extend(chars)
            all_ui_string.extend(ui_strings)

    return all_ud, all_url, all_char, all_ui_string


def _report_violations(label: str, hint: str, items: list) -> int:
    """
    打印违规报告。

    :param label: 违规类别标签
    :param hint: 修复提示
    :param items: 违规条目列表
    :return: 1（始终返回非零）
    """
    print(f"❌ {label}: {len(items)} 处硬编码")
    print(f"  {hint}")
    for entry in items:
        rel_path, line_no, content = entry[0], entry[1], entry[2]
        print(f"    {rel_path}:L{line_no} → {content}")
    return 1


def _report_char_violations(items: list) -> int:
    """
    打印单字符字面量违规报告（含业务语义化修复指引）。

    修复策略（两层常量体系）：
    - L0 层 UFPCore.SystemConstants.Character.* = 通用基础字符（无业务语义，直接可用）
    - 业务层桥接 = 赋予业务语义，使代码自文档化

    示例（JSON 解析场景）：
        // L0 通用基础（UFPCore 已提供）
        SystemConstants.Character.openBrace  // 通用 "{" 字符

        // 业务层桥接（在业务常量文件定义 1 次，赋予 JSON 语义）
        enum JSONSyntax {
            /// JSON 对象起始符
            static let objectStart: String = SystemConstants.Character.openBrace
            /// JSON 对象结束符
            static let objectEnd: String = SystemConstants.Character.closeBrace
        }

        // 使用点引用业务桥接常量（语义明确）
        text.firstIndex(of: Character(JSONSyntax.objectStart))

    :param items: 违规条目列表 (rel_path, line_no, content, const_name, semantic)
    :return: 1（始终返回非零）
    """
    print(f"❌ 单字符字面量: {len(items)} 处硬编码")
    print("  修复指引（两层常量体系）：")
    print("    L0 通用层: UFPCore.SystemConstants.Character.*（通用基础字符，无业务语义）")
    print("    业务桥接层: 在业务常量文件桥接 1 次，赋予业务语义，使代码自文档化")
    print("    示例:")
    print("      enum JSONSyntax {")
    print("          /// JSON 对象起始符")
    print("          static let objectStart = SystemConstants.Character.openBrace")
    print("      }")
    print("      text.firstIndex(of: Character(JSONSyntax.objectStart))")
    for rel_path, line_no, content, const_name, semantic in items:
        print(f"    {rel_path}:L{line_no}")
        print(f"      业务语义: {semantic}")
        print(f"      L0 基础: {const_name}")
        print(f"      代码: {content}")
    return 1


def _aggregate_violations() -> tuple[list, list, list, list]:
    """聚合所有扫描目录的违规条目。"""
    all_ud = []
    all_url = []
    all_char = []
    all_ui_string = []
    for check_dir in CHECK_DIRS:
        uds, urls, chars, ui_strings = _scan_directory(check_dir)
        all_ud.extend(uds)
        all_url.extend(urls)
        all_char.extend(chars)
        all_ui_string.extend(ui_strings)
    return all_ud, all_url, all_char, all_ui_string


def _report_url_violations(all_url: list, exit_code: int) -> int:
    """报告 URL 违规并更新退出码。"""
    if all_url:
        ec = _report_violations(
            "URL",
            "应使用 AppConstants.URLs.* 常量",
            all_url)
        return exit_code or ec
    return exit_code


def _report_char_violations_and_update(all_char: list, exit_code: int) -> int:
    """报告单字符违规并更新退出码。"""
    if all_char:
        ec = _report_char_violations(all_char)
        return exit_code or ec
    return exit_code


def _report_ui_string_violations(all_ui_string: list, exit_code: int) -> int:
    """报告 UI 字符串违规并更新退出码。"""
    if all_ui_string:
        ec = _report_violations(
            "UI 硬编码字符串",
            "应使用 L10n.模块.属性 强类型访问",
            all_ui_string)
        return exit_code or ec
    return exit_code


def _report_all_violations(all_ud: list, all_url: list, all_char: list, all_ui_string: list) -> int:
    """报告四类违规并返回退出码。"""
    if not all_ud and not all_url and not all_char and not all_ui_string:
        print("✅ PASS: 无硬编码 UserDefaults key、URL、单字符字面量或 UI 硬编码字符串")
        return 0

    exit_code = 0
    if all_ud:
        exit_code = _report_violations(
            "UserDefaults key",
            "应使用 AppConstants.Keys.Storage.* 常量",
            all_ud)
    exit_code = _report_url_violations(all_url, exit_code)
    exit_code = _report_char_violations_and_update(all_char, exit_code)
    exit_code = _report_ui_string_violations(all_ui_string, exit_code)
    return exit_code


def main():
    """扫描业务层硬编码 UserDefaults key、URL、单字符字面量和 UI 硬编码字符串，验证是否已用常量替代。"""
    all_ud, all_url, all_char, all_ui_string = _aggregate_violations()
    return _report_all_violations(all_ud, all_url, all_char, all_ui_string)


if __name__ == "__main__":
    sys.exit(main())
