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
#           单字符字面量（花括号/引号/反斜杠等）、switch case 字符串、命名参数字符串、
#           以及硬编码 SwiftUI 系统颜色（.red/.blue/.cyan 等）。
#           硬编码的 forKey 字符串、https?:// URL 应使用 AppConstants.URLs / AppConstants.Keys.Storage 常量；
#           单字符字面量应使用 UFPCore.SystemConstants.Character.* 常量；
#           switch case 字符串应使用枚举或 FeatureConstants.* 常量；
#           命名参数字符串（label:/title:/name:/key: 等）应使用 L10n 或常量；
#           SwiftUI 系统颜色应使用 Color.theme.* 或 DesignSystem.Colors.* 令牌。
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

# ── 新增检测 1：switch case 硬编码字符串 ──
# 匹配：case "xxx": （字符串字面量作为 switch 匹配键，应改用枚举或常量）
SWITCH_CASE_STRING_PATTERN = re.compile(r'\bcase\s+"([^"\\]*(?:\\.[^"\\]*)*)"\s*:')
# 排除模式（合理保留场景）
SWITCH_CASE_EXCLUDE_PATTERNS = [
    re.compile(r'FeatureConstants\.'),
    re.compile(r'SystemConstants\.'),
    re.compile(r'ProcessorConstants\.'),
    re.compile(r'PlatformConstants\.'),
    re.compile(r'AppConstants\.'),
    re.compile(r'^\s*//'),  # 注释行
    re.compile(r'^\s*\*'),  # 文档注释续行
    re.compile(r'/// '),  # 文档注释
]
# 豁免值（空字符串、格式占位符等）
SWITCH_CASE_EXEMPT_VALUES = {
    "",
}

# ── 新增检测 2：命名参数硬编码字符串 ──
# 匹配：参数名: "xxx" （命名参数传字符串字面量，应改用 L10n 或常量）
# 覆盖常见参数名：label/title/name/key/icon/color/text/tag/id/type/section/category/group
NAMED_ARG_STRING_PATTERN = re.compile(
    r'\b(?:label|title|name|key|icon|text|tag|type|section|category|group|placeholder|description|message|hint|tooltip|accessibilityLabel|accessibilityHint|accessibilityValue)\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
)
# 排除模式
NAMED_ARG_EXCLUDE_PATTERNS = [
    re.compile(r'L10n\.'),
    re.compile(r'Localized\.'),
    re.compile(r'\.tr\('),
    re.compile(r'\.trf\('),
    re.compile(r'LocalizedStringKey'),
    re.compile(r'FeatureConstants\.'),
    re.compile(r'SystemConstants\.'),
    re.compile(r'ProcessorConstants\.'),
    re.compile(r'PlatformConstants\.'),
    re.compile(r'AppConstants\.'),
    re.compile(r'DesignSystem\.'),
    re.compile(r'^\s*//'),  # 注释行
    re.compile(r'^\s*\*'),  # 文档注释续行
    re.compile(r'/// '),  # 文档注释
]
# 豁免值
NAMED_ARG_EXEMPT_VALUES = {
    "",
    "%@",
    "%d",
    "%.1f",
    "%.0f",
}

# ── 新增检测 3：硬编码 SwiftUI 系统颜色 ──
# 匹配：.red / .blue / .cyan 等（SwiftUI 系统色，应改用 Color.theme.* 或 DesignSystem.Colors.*）
# 注意：排除 .clear（透明色，合理使用）和 Color.xxx（显式类型调用，部分场景合理）
SWIFTUI_COLOR_PATTERN = re.compile(
    r'\.\b(red|orange|yellow|green|blue|purple|pink|gray|teal|cyan|indigo|mint|brown)\b'
)
# 排除模式（合理保留场景）
SWIFTUI_COLOR_EXCLUDE_PATTERNS = [
    re.compile(r'Color\.theme\.'),
    re.compile(r'DesignSystem\.Colors\.'),
    re.compile(r'DesignSystem\.'),
    re.compile(r'Colors\.'),
    re.compile(r'^\s*//'),  # 注释行
    re.compile(r'^\s*\*'),  # 文档注释续行
    re.compile(r'/// '),  # 文档注释
    re.compile(r'Color\.\b(red|orange|yellow|green|blue|purple|pink|gray|teal|cyan|indigo|mint|brown)\b'),  # Color.red 显式调用（部分场景合理）
    re.compile(r'MockColorName\.\b(red|orange|yellow|green|blue|purple|pink|gray|teal|cyan|indigo|mint|brown)\b'),  # MockColorName 字符串常量
    re.compile(r'\.theme\.\b(red|orange|yellow|green|blue|purple|pink|gray|teal|cyan|indigo|mint|brown)\b'),  # .theme.xxx 已是令牌
    re.compile(r'WidgetConstants\.Color\.\b(red|orange|yellow|green|blue|purple|pink|gray|teal|cyan|indigo|mint|brown)\b'),  # Widget 专用颜色令牌
    re.compile(r'static let \w+:.*=\s*\.\b(red|orange|yellow|green|blue|purple|pink|gray|teal|cyan|indigo|mint|brown)\b'),  # 颜色令牌定义行
]
# 豁免：.clear 不是系统颜色
SWIFTUI_COLOR_EXEMPT = {"clear"}

# ── ExemptionRegistry 行级豁免 ──
EXEMPT_CATEGORY = "magic_string_exempt"

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


def _should_exclude_switch_case(content: str, match_value: str) -> bool:
    """判断 switch case 字符串是否属于合理保留场景。"""
    if match_value in SWITCH_CASE_EXEMPT_VALUES:
        return True
    if '\\(' in match_value:
        return True
    for pat in SWITCH_CASE_EXCLUDE_PATTERNS:
        if pat.search(content):
            return True
    return False


def _should_exclude_named_arg(content: str, match_value: str) -> bool:
    """判断命名参数字符串是否属于合理保留场景。"""
    if match_value in NAMED_ARG_EXEMPT_VALUES:
        return True
    if '\\(' in match_value:
        return True
    for pat in NAMED_ARG_EXCLUDE_PATTERNS:
        if pat.search(content):
            return True
    return False


def _should_exclude_swiftui_color(content: str) -> bool:
    """判断 SwiftUI 系统颜色是否属于合理保留场景。"""
    for pat in SWIFTUI_COLOR_EXCLUDE_PATTERNS:
        if pat.search(content):
            return True
    return False


def load_exemptions() -> tuple[set, list]:
    """从 ExemptionRegistry 加载 magic_string_exempt 分类的行级豁免。

    豁免项结构：
        - file: 相对于仓库根的文件路径
        - line: 行号（1-based）
        - reason: 豁免理由
        - expiry_check: 是否参与过期检测

    :return: (豁免集合 {(file, line)}, 全部豁免项列表)
    """
    exempt_keys: set = set()
    exempt_items: list = []

    try:
        import sys as _sys
        _sys.path.insert(0, str(PROJECT_ROOT / "Tools" / "CI"))
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


def _scan_switch_case_string(line: str, rel_path: Path, line_no: int) -> list:
    """检测 switch case 硬编码字符串。"""
    violations = []
    for m in SWITCH_CASE_STRING_PATTERN.finditer(line):
        match_value = m.group(1)
        if not _should_exclude_switch_case(line, match_value):
            violations.append((rel_path, line_no, line.strip(), match_value))
    return violations


def _scan_named_arg_string(line: str, rel_path: Path, line_no: int) -> list:
    """检测命名参数硬编码字符串。"""
    violations = []
    for m in NAMED_ARG_STRING_PATTERN.finditer(line):
        match_value = m.group(1)
        if not _should_exclude_named_arg(line, match_value):
            violations.append((rel_path, line_no, line.strip(), match_value))
    return violations


def _scan_swiftui_color(line: str, rel_path: Path, line_no: int) -> list:
    """检测硬编码 SwiftUI 系统颜色。"""
    violations = []
    if _should_exclude_swiftui_color(line):
        return violations
    for m in SWIFTUI_COLOR_PATTERN.finditer(line):
        color_name = m.group(1)
        if color_name not in SWIFTUI_COLOR_EXEMPT:
            violations.append((rel_path, line_no, line.strip(), color_name))
    return violations


def _scan_line_for_violations(line: str, rel_path: Path, line_no: int) -> tuple[list, list, list, list, list, list, list]:
    """
    扫描单行代码的七类违规：UserDefaults key、URL、单字符字面量、UI 硬编码字符串、
    switch case 字符串、命名参数字符串、硬编码 SwiftUI 系统颜色。

    :param line: 单行代码内容
    :param rel_path: 文件相对路径
    :param line_no: 行号
    :return: (UD, URL, 单字符, UI字符串, switch case, 命名参数, SwiftUI颜色) 违规列表
    """
    return (
        _scan_ud_key(line, rel_path, line_no),
        _scan_url(line, rel_path, line_no),
        _scan_single_char(line, rel_path, line_no),
        _scan_ui_string(line, rel_path, line_no),
        _scan_switch_case_string(line, rel_path, line_no),
        _scan_named_arg_string(line, rel_path, line_no),
        _scan_swiftui_color(line, rel_path, line_no),
    )


def _scan_directory(check_dir: Path) -> tuple[list, list, list, list, list, list, list]:
    """
    扫描目录中所有 Swift 文件的七类硬编码违规。

    :param check_dir: 扫描目录
    :return: (UD, URL, 单字符, UI字符串, switch case, 命名参数, SwiftUI颜色) 违规列表
    """
    all_ud = []
    all_url = []
    all_char = []
    all_ui_string = []
    all_switch_case = []
    all_named_arg = []
    all_swiftui_color = []
    if not check_dir.exists():
        return all_ud, all_url, all_char, all_ui_string, all_switch_case, all_named_arg, all_swiftui_color

    for swift_file in check_dir.rglob("*.swift"):
        rel_path = swift_file.relative_to(PROJECT_ROOT)
        try:
            with open(swift_file, 'r') as f:
                lines = f.readlines()
        except Exception:
            continue
        for i, line in enumerate(lines, 1):
            uds, urls, chars, ui_strings, switch_cases, named_args, swiftui_colors = _scan_line_for_violations(line, rel_path, i)
            all_ud.extend(uds)
            all_url.extend(urls)
            all_char.extend(chars)
            all_ui_string.extend(ui_strings)
            all_switch_case.extend(switch_cases)
            all_named_arg.extend(named_args)
            all_swiftui_color.extend(swiftui_colors)

    return all_ud, all_url, all_char, all_ui_string, all_switch_case, all_named_arg, all_swiftui_color


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


def _aggregate_violations() -> tuple[list, list, list, list, list, list, list]:
    """聚合所有扫描目录的违规条目。"""
    all_ud = []
    all_url = []
    all_char = []
    all_ui_string = []
    all_switch_case = []
    all_named_arg = []
    all_swiftui_color = []
    for check_dir in CHECK_DIRS:
        uds, urls, chars, ui_strings, switch_cases, named_args, swiftui_colors = _scan_directory(check_dir)
        all_ud.extend(uds)
        all_url.extend(urls)
        all_char.extend(chars)
        all_ui_string.extend(ui_strings)
        all_switch_case.extend(switch_cases)
        all_named_arg.extend(named_args)
        all_swiftui_color.extend(swiftui_colors)
    return all_ud, all_url, all_char, all_ui_string, all_switch_case, all_named_arg, all_swiftui_color


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


def _apply_exemptions(items: list, exempt_keys: set) -> list:
    """过滤掉已豁免的违规项。

    :param items: 违规项列表，每项前 2 个元素为 (rel_path, line_no)
    :param exempt_keys: 豁免集合 {(file_str, line_no)}
    :return: 过滤后的违规项列表
    """
    if not exempt_keys:
        return items
    filtered = []
    for item in items:
        rel_path = item[0]
        line_no = item[1]
        file_str = str(rel_path)
        if (file_str, line_no) not in exempt_keys:
            filtered.append(item)
    return filtered


def _report_all_violations(
    all_ud: list, all_url: list, all_char: list, all_ui_string: list,
    all_switch_case: list, all_named_arg: list, all_swiftui_color: list,
    exempt_keys: set,
) -> int:
    """报告七类违规并返回退出码。"""
    # 应用豁免过滤
    all_ud = _apply_exemptions(all_ud, exempt_keys)
    all_url = _apply_exemptions(all_url, exempt_keys)
    all_char = _apply_exemptions(all_char, exempt_keys)
    all_ui_string = _apply_exemptions(all_ui_string, exempt_keys)
    all_switch_case = _apply_exemptions(all_switch_case, exempt_keys)
    all_named_arg = _apply_exemptions(all_named_arg, exempt_keys)
    all_swiftui_color = _apply_exemptions(all_swiftui_color, exempt_keys)

    if not any([all_ud, all_url, all_char, all_ui_string, all_switch_case, all_named_arg, all_swiftui_color]):
        print("✅ PASS: 无硬编码 UserDefaults key、URL、单字符字面量、UI 字符串、switch case 字符串、命名参数字符串或 SwiftUI 系统颜色")
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

    if all_switch_case:
        ec = _report_violations(
            "switch case 硬编码字符串",
            "应使用枚举或 FeatureConstants.* 常量替代字符串匹配键",
            all_switch_case)
        exit_code = exit_code or ec

    if all_named_arg:
        ec = _report_violations(
            "命名参数硬编码字符串",
            "应使用 L10n.模块.属性 或常量替代 label:/title:/name: 等参数中的字符串字面量",
            all_named_arg)
        exit_code = exit_code or ec

    if all_swiftui_color:
        ec = _report_violations(
            "硬编码 SwiftUI 系统颜色",
            "应使用 Color.theme.* 或 DesignSystem.Colors.* 令牌替代 .red/.blue/.cyan 等系统色",
            all_swiftui_color)
        exit_code = exit_code or ec

    return exit_code


def main():
    """扫描业务层七类硬编码违规，验证是否已用常量替代。"""
    all_ud, all_url, all_char, all_ui_string, all_switch_case, all_named_arg, all_swiftui_color = _aggregate_violations()
    exempt_keys, _ = load_exemptions()
    return _report_all_violations(
        all_ud, all_url, all_char, all_ui_string,
        all_switch_case, all_named_arg, all_swiftui_color,
        exempt_keys,
    )


if __name__ == "__main__":
    sys.exit(main())
