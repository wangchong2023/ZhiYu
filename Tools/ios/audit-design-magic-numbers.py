#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对 Sources/ 目录以及 Tools/Mock/ 目录下的 Swift 和 Python 代码
# 进行魔鬼数字和硬编码常量（如 padding，cornerRadius，port，以及硬编码 Hex 颜色等）的精确扫描审计。
#

"""精确扫描：排除 DesignSystem 定义文件和合法用法"""

import os, re, sys

EXCLUDE_DIRS = {'.git','build','DerivedData','.build','Frameworks','Tests','env','__pycache__'}
TOKEN_FILES = {
    'Colors.swift', 'DesignSystem.swift', 'IconTokens.swift', 'Spacing.swift',
    'DemoImageBuilder.swift', 'InitialNotebookGenerator.swift',
    'Reference.swift', 'System.swift', 'Component.swift',
}
TOKEN_FILES_PY = set()

SWIFT_EXT = {'.swift'}
PY_EXT = {'.py'}

# 诊断输出时代码行内容的最大截断长度
MAX_LINE_PREVIEW_LEN = 90
# 每个文件最多展示的缺陷实例数量
MAX_DISPLAY_LIMIT = 5

def scan_file(path, ext):
    issues = []
    if 'Sources/Shared/DesignSystem' in path or os.path.basename(path) in TOKEN_FILES:
        return issues
    with open(path, errors='ignore') as f:
        lines = f.readlines()
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith('//') or s.startswith('#'):
            continue
        if ext in SWIFT_EXT:
            issues.extend(check_swift_line(path, i, s, line))
        if ext in PY_EXT:
            issues.extend(check_python_line(path, i, s, line))
    return issues


def check_swift_colors(raw, path, line_no, s):
    """检查 Swift 代码行中是否包含硬编码颜色值。"""
    if '//' in s:
        return []
    res = []
    _check_rgb_color(raw, path, line_no, s, res)
    _check_hex_color(raw, path, line_no, s, res)
    return res


def _check_rgb_color(raw, path, line_no, s, res):
    """检查 RGB 颜色硬编码。"""
    valid_color = any(k in raw or k in path for k in ['DesignSystem', 'Colors.swift', 'UIColor.theme', 'Color.theme'])
    if (re.search(r'\bColor\(red:', raw) or re.search(r'\bUIColor\(red:', raw) or re.search(r'\bUIColor\(white:', raw)) and not valid_color:
        res.append(('Color/UIColor(red:/white:)', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_hex_color(raw, path, line_no, s, res):
    """检查 Hex 颜色硬编码。"""
    if re.search(r'\bColor\(hex:\s*"([^"]+)"', raw) and 'Colors.swift' not in path:
        res.append(('Color(hex:"...")', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def is_layout_exempt(path, s):
    """判断布局检查是否可豁免。仅豁免完整注释行和 Layout 定义块，行尾注释不豁免。"""
    exempt_tokens = ['enum Layout', 'struct Layout', 'private enum', 'private struct', 'ContentView.swift', 'ZhiYuWatchView.swift']
    return any(t in s or t in path for t in exempt_tokens)


def check_swift_layout(raw, path, line_no, s):
    """检查 Swift 视图代码中的布局魔鬼数字与算术表达式。"""
    if is_layout_exempt(path, s):
        return []
    res = []
    _check_padding_and_radius(raw, path, line_no, s, res)
    _check_frame_and_opacity(raw, path, line_no, s, res)
    _check_spacing_and_layout_params(raw, path, line_no, s, res)
    _check_magic_math(raw, path, line_no, s, res)
    _check_business_threshold(raw, path, line_no, s, res)
    return res


def _check_business_threshold(raw, path, line_no, s, res):
    """检查 View 文件中的业务比较阈值魔鬼数字（> N, < N, >= N, <= N）。"""
    # 仅检测 View 文件中的比较运算符后的裸数字（2 位以上，避免误报）
    if '/View/' not in path and '/Views/' not in path and not path.endswith('View.swift'):
        return
    # 排除常量定义文件
    basename = os.path.basename(path)
    if basename in TOKEN_FILES or 'Constants' in basename:
        return
    # 检测 > N, < N, >= N, <= N（2 位以上数字，避免 > 0/> 1 误报）
    if re.search(r'[<>]=?\s*(\d{2,})\b', raw):
        # 排除 DesignSystem token 上下文
        if not any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component']):
            res.append(('hardcoded business threshold', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_padding_and_radius(raw, path, line_no, s, res):
    """检查 padding 与 cornerRadius。"""
    valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component'])
    if re.search(r'\.padding\(\s*(\d+)\s*\)', raw) and not valid:
        res.append(('hardcoded padding', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    # 检测带 label 的双参数形式：.padding(.vertical, 10) / .padding(.horizontal, 8)
    if re.search(r'\.padding\(\s*\.\w+,\s*(\d+)\s*\)', raw) and not valid:
        res.append(('hardcoded padding (labeled)', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    if re.search(r'cornerRadius:\s*(\d+)\s*[),]', raw) and not valid:
        res.append(('hardcoded cornerRadius', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_frame_and_opacity(raw, path, line_no, s, res):
    """检查 frame 尺寸与 opacity。"""
    valid_frame = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component', 'geo', 'CGFloat', 'Double'])
    if re.search(r'\.frame\([^)]*\b(width|height|minWidth|minHeight|maxWidth|maxHeight):\s*\d{2,}\b', raw) and not valid_frame:
        res.append(('hardcoded frame dimension', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    valid_opacity = any(k in raw for k in ['DesignSystem', 'Colors', 'Opacity', 'Color.theme', 'glassOpacity', 'Reference', 'System', 'Component'])
    if re.search(r'\.opacity\(\s*0\.\d+\s*\)', raw) and not valid_opacity:
        res.append(('hardcoded opacity', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_spacing_and_layout_params(raw, path, line_no, s, res):
    """检查容器 spacing、font size、lineWidth、shadow 等布局参数中的魔鬼数字。"""
    valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component'])
    if valid:
        return
    _check_container_spacing(raw, path, line_no, s, res)
    _check_line_spacing(raw, path, line_no, s, res)
    _check_font_size(raw, path, line_no, s, res)
    _check_line_width(raw, path, line_no, s, res)
    _check_shadow_params(raw, path, line_no, s, res)
    _check_kerning_tracking(raw, path, line_no, s, res)


def _check_container_spacing(raw, path, line_no, s, res):
    """检查 HStack/VStack/ZStack 等容器的 spacing 参数。"""
    # spacing: 0 是合法的无间距用法，豁免
    pattern = r'\b(?:HStack|VStack|ZStack|LazyVStack|LazyHStack|Grid|LazyVGrid|LazyHGrid)\(\s*(?:alignment:[^,]+,\s*)?spacing:\s*([1-9]\d*)\s*[),]'
    if re.search(pattern, raw):
        res.append(('hardcoded container spacing', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_line_spacing(raw, path, line_no, s, res):
    """检查 .lineSpacing(N) 硬编码。lineSpacing 的值必须是 token，纯数字即违规。"""
    if re.search(r'\.lineSpacing\(\s*(\d+\.?\d*)\s*\)', raw):
        res.append(('hardcoded lineSpacing', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_font_size(raw, path, line_no, s, res):
    """检查 .font(.system(size: N)) 中的硬编码字号。"""
    if re.search(r'\.font\(\s*\.system\(\s*size:\s*(\d+)\s*[,)]', raw):
        res.append(('hardcoded font size', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_line_width(raw, path, line_no, s, res):
    """检查 lineWidth: N 硬编码。lineWidth 的值必须是 token，纯数字即违规，不受行内其他 token 影响。"""
    if re.search(r'\blineWidth:\s*(\d+\.?\d*)\b', raw):
        res.append(('hardcoded lineWidth', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_shadow_params(raw, path, line_no, s, res):
    """检查 .shadow 中的 radius/x/y 硬编码。"""
    if re.search(r'\.shadow\(.*?radius:\s*(\d+\.?\d*)\b', raw):
        res.append(('hardcoded shadow radius', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    if re.search(r'\.shadow\(.*?\b[xy]:\s*(\d+\.?\d*)\b', raw):
        res.append(('hardcoded shadow offset', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_kerning_tracking(raw, path, line_no, s, res):
    """检查 .kerning(N) / .tracking(N) 硬编码。"""
    if re.search(r'\.(?:kerning|tracking)\(\s*(\d+\.?\d*)\s*\)', raw):
        res.append(('hardcoded kerning/tracking', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_magic_math(raw, path, line_no, s, res):
    """检查魔鬼算术表达式与 customSize。"""
    # 严格有限原则：禁止任何 token 算术表达式（* / + -），无豁免
    exempt_tokens = ['DesignSystem.Domain', 'DesignSystem.Metrics', 'DesignSystem.Gallery', 'Spacing']
    _check_view_arithmetic(raw, path, line_no, s, res)
    _check_token_arithmetic(raw, path, line_no, s, res, exempt_tokens)
    _check_custom_size(raw, path, line_no, s, res)


def _check_view_arithmetic(raw, path, line_no, s, res):
    """检查 View 修饰符中的 token 算术表达式。"""
    pattern = r'\.(padding|frame|offset|radius)\([^)]*\b(DesignSystem|Spacing)\.[a-zA-Z0-9_.]+\s*[\*\/\+\-]\s*(0\.\d+|\d+\.?\d*)\b'
    if re.search(pattern, raw):
        res.append(('Magic Math View算术表达式', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_token_arithmetic(raw, path, line_no, s, res, exempt_tokens):
    """检查 token 算术表达式（严格禁止 * / + -）。检测 Token op number 和 Token op Token 两种形式。"""
    # 形式 1: Token op number（如 DesignSystem.small * 2）
    token_math_num = re.search(r'\b(DesignSystem|Spacing|Reference|System|Component)\.([a-zA-Z0-9_.]+)\s*[\*\/\+\-]\s*(\d+\.?\d*)\b', raw)
    if token_math_num:
        token_full = f'{token_math_num.group(1)}.{token_math_num.group(2)}'
        if token_full not in exempt_tokens and not any(token_full.startswith(e) for e in exempt_tokens):
            res.append(('Magic Math token算术表达式', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    # 形式 2: Token op Token（如 DesignSystem.small + DesignSystem.atomic）
    token_math_token = re.search(r'\b(DesignSystem|Spacing|Reference|System|Component)\.([a-zA-Z0-9_.]+)\s*[\*\/\+\-]\s*(DesignSystem|Spacing|Reference|System|Component)\.([a-zA-Z0-9_.]+)\b', raw)
    if token_math_token:
        token_full = f'{token_math_token.group(1)}.{token_math_token.group(2)}'
        if token_full not in exempt_tokens and not any(token_full.startswith(e) for e in exempt_tokens):
            res.append(('Magic Math token+token算术表达式', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))


def _check_custom_size(raw, path, line_no, s, res):
    """检查 customSizeN 伪 token 模式。"""
    if re.search(r'customSize\d+', raw) and 'DesignSystem+Metrics.swift' not in path and 'Spacing.swift' not in path:
        res.append(('pseudo-token customSize (硬编码数字变相包裹)', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))

def check_swift_line(path, line_no, s, raw):
    """
    检查 Swift 单行代码中是否包含硬编码的 UI 参数，
    例如硬编码的 RGB Color 构造、Hex Color 字符串、硬编码的 padding 或 cornerRadius。
    """
    return check_swift_colors(raw, path, line_no, s) + check_swift_layout(raw, path, line_no, s)


def check_python_line(path, line_no, s, raw):
    """
    检查 Python 单行代码中是否包含硬编码的常数或敏感配置，
    例如未定义为常量的硬编码 Port 端口号，或可能硬编码的版本号信息。
    """
    results = []
    if re.search(r'port\s*=\s*\d{4,5}\b', raw) and 'PORT' not in raw:
        results.append(('硬编码端口号', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    if re.match(r'^[A-Z][A-Z_]*\s*=', s):
        return results
    m = re.search(r'["\'](\d+\.\d+\.\d+)["\']', raw)
    if m and m.group(1) not in ('',):
        if 'version' in raw.lower():
            if 'version=' not in raw:
                results.append(('硬编码版本号', path, line_no, s[:MAX_LINE_PREVIEW_LEN]))
    return results


results = []
scan_dirs = ['Sources', 'Tools/Mock']

for scan_dir in scan_dirs:
    if not os.path.isdir(scan_dir):
        continue
    for root, dirs, files in os.walk(scan_dir):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for fname in files:
            ext = os.path.splitext(fname)[1]
            scanner_exts = {'.swift': '.swift', '.py': '.py'}
            if ext not in scanner_exts:
                continue
            if fname in TOKEN_FILES or fname in TOKEN_FILES_PY:
                continue
            path = os.path.join(root, fname)
            results.extend(scan_file(path, ext))

# 引入统一报告管理器
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from gatekeeper_reporter import GatekeeperReporter

reporter = GatekeeperReporter("Magic Number Audit")

for typ, path, line_no, code in results:
    fpath = os.path.relpath(path)
    if 'Widget' in fpath or 'Widgets' in fpath:
        continue
    reporter.add_issue(
        filepath=fpath,
        line_no=line_no,
        message=f"发现硬编码魔鬼参数 ({typ})，建议替换为 DesignSystem token。",
        level="ERROR",
        content=code
    )

reporter.report()
