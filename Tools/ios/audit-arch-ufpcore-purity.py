#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智宇 (ZhiYu) UFPCore 纯净化静态分析工具
功能说明:
1. 物理扫描业务层 (Sources/Core, Sources/Infrastructure, Sources/Domain,
   Sources/Features, Sources/App, Sources/Shared, Sources/Platforms) 下所有 Swift 源代码。
2. 强制拦截"应迁移未迁移"到 UFPCore 的通用基础能力（与业务无关的函数/常量/枚举/工具类/扩展）。
3. 采用"白名单注册制 + 模式检测"双轨策略：
   - 白名单注册制：manual_whitelist.yml 的 `ufpcore_pure_exempt` 分类登记豁免项
     （file + reason + expiry_check），已迁移到 UFPCore 的符号通过 `import UFPCore` 合规。
   - 模式检测：检测已知应迁移的通用模式（裸换算常量、重复通用工具函数、
     通用扩展方法、通用工具类/结构体）。
4. 兼容 Xcode 编译器报错输出格式，如有违规在 Xcode 编译时直接以 error 标红并阻断构建。

检测四类违规:
  A. 通用工具函数/方法：与业务无关的纯算法（字节换算/字数统计/IP 解析等）
  B. 通用常量/枚举：HTTP 状态码/字节换算/时间换算等协议级常量
  C. 通用工具类/结构体：与业务无关的工具类型（SSRFGuard/VectorMath 等）
  D. 通用扩展方法：Date 格式化/String 掩码/Character CJK 判定等
"""

import os
import re
import sys
from pathlib import Path

# ==================== 配置常量 ====================
# 项目根目录（Tools/ios/ → 退 2 层）
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent

# 业务层扫描目录（排除 UFPCore 包本身）
BUSINESS_SCAN_DIRS = [
    PROJECT_DIR / "Sources" / "Core",
    PROJECT_DIR / "Sources" / "Infrastructure",
    PROJECT_DIR / "Sources" / "Domain",
    PROJECT_DIR / "Sources" / "Features",
    PROJECT_DIR / "Sources" / "App",
    PROJECT_DIR / "Sources" / "Shared",
    PROJECT_DIR / "Sources" / "Platforms",
]

# UFPCore 包目录（用于收集已迁移符号，判定"已迁移=合规"）
UFPCORE_DIR = PROJECT_DIR / "Packages" / "UFPCore" / "Sources" / "UFPCore"

# 手动白名单文件
MANUAL_WHITELIST_PATH = PROJECT_DIR / "Config" / "exemptions" / "manual_whitelist.yml"

# 兼容层判定阈值：文件非空非注释行数上限（超过则视为实质实现文件）
COMPAT_LAYER_MAX_LINES = 30

# ==================== 已迁移到 UFPCore 的符号集 ====================
# 这些符号在业务层通过 `import UFPCore` 引用视为合规；
# 若业务层重新定义同名符号（非 typealias 转发），视为违规。

# 已迁移的通用工具类/结构体/枚举（类型名）
MIGRATED_TYPES = {
    "SSRFGuard",
    "VectorMath",
    "ByteFormatter",
    "MainActorBridge",
    "ZipUtility",
    "TextAnalyzer",
    "AppErrorFactory",
    "SystemConstants",
    "NetworkConstants",
}

# 已迁移的通用扩展方法/计算属性（业务层应通过 import UFPCore 调用）
MIGRATED_EXTENSIONS = {
    "maskedPhoneNumber",        # String+Masking
    "isCJKCharacter",           # Character+CJK
    "formatted(as:)",           # Date+Formatting
    "wordCount",                # TextAnalyzer
}

# 已迁移的通用常量命名空间（业务层应引用 SystemConstants/NetworkConstants）
MIGRATED_CONSTANT_NAMESPACES = {
    "SystemConstants",
    "NetworkConstants",
}

# ==================== 模式检测规则 ====================

# 规则 A: 通用工具函数重新定义（业务层不应重新定义已迁移的函数）
# 检测 `func <已迁移函数名>` 在业务层的定义（非 typealias/转发）
MIGRATED_FUNC_PATTERN = re.compile(
    r'^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:static\s+|class\s+)?'
    r'func\s+(' + '|'.join(MIGRATED_EXTENSIONS) + r')\b',
    re.MULTILINE
)

# 规则 B: 通用常量命名空间重新定义（业务层不应重新定义 SystemConstants/NetworkConstants）
REDEFINED_NAMESPACE_PATTERN = re.compile(
    r'^\s*(?:public\s+|internal\s+)?'
    r'(?:enum|struct|class)\s+(SystemConstants|NetworkConstants)\b',
    re.MULTILINE
)

# 规则 C: 通用工具类/结构体重新定义（业务层不应重新定义已迁移的类型）
REDEFINED_TYPE_PATTERN = re.compile(
    r'^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:final\s+|open\s+)?'
    r'(?:enum|struct|class|actor)\s+(' + '|'.join(MIGRATED_TYPES) + r')\b',
    re.MULTILINE
)

# 规则 D: 通用扩展方法重新定义（业务层不应重新定义已迁移的扩展方法/属性）
# 检测 `var maskedPhoneNumber` / `var isCJKCharacter` / `func formatted` 等
MIGRATED_EXTENSION_PATTERN = re.compile(
    r'^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:static\s+|class\s+)?'
    r'(?:let|var)\s+(' + '|'.join(
        name for name in MIGRATED_EXTENSIONS if name not in ("formatted(as:)", "wordCount")
    ) + r')\b',
    re.MULTILINE
)

# ==================== 白名单加载 ====================

def load_ufpcore_exempt_files():
    """加载 manual_whitelist.yml 中 ufpcore_pure_exempt 分类的豁免文件列表

    返回: set[str] 豁免的文件路径集合（相对项目根目录）
    """
    if not MANUAL_WHITELIST_PATH.exists():
        return set()

    try:
        import yaml
    except ImportError:
        print("❌ 缺少 PyYAML 依赖，请运行: pip3 install pyyaml", file=sys.stderr)
        sys.exit(1)

    try:
        with open(MANUAL_WHITELIST_PATH, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        return set()

    exempt_files = set()
    items = data.get("ufpcore_pure_exempt", [])
    if not isinstance(items, list):
        return set()

    for item in items:
        if isinstance(item, dict) and "file" in item:
            exempt_files.add(item["file"])
    return exempt_files


# ==================== 文件检测 ====================

def _has_substantive_func_body(content):
    """检测文件中是否存在超过一行转发的函数体（视为实质实现）

    参数:
        content (str): 文件全文

    返回:
        bool: True 表示存在实质函数实现
    """
    func_bodies = re.findall(r'func\s+\w+[^{]*\{([^}]*)\}', content, re.DOTALL)
    for body in func_bodies:
        body_lines = [
            l for l in body.split("\n")
            if l.strip() and not l.strip().startswith("//")
        ]
        if len(body_lines) > 1:
            return True
    return False


def is_compatibility_layer(content):
    """判断文件是否为兼容层（仅 import + 空 typealias/转发，无实质实现）

    兼容层特征：
    - 文件行数少（< COMPAT_LAYER_MAX_LINES 行）
    - 含 `import UFPCore`
    - 无实质函数体（函数体仅一行转发调用）
    - 或仅含 typealias 声明
    """
    lines = content.split("\n")
    non_empty_lines = [
        l for l in lines
        if l.strip() and not l.strip().startswith("//")
    ]
    if len(non_empty_lines) > COMPAT_LAYER_MAX_LINES:
        return False

    if "import UFPCore" not in content:
        return False

    has_typealias = bool(re.search(r'\btypealias\s+', content))
    has_substantive_impl = _has_substantive_func_body(content)

    return has_typealias or not has_substantive_impl


def _extract_type_body(content, start_pos):
    """从类型声明起始位置提取该类型的作用域内容（花括号内）

    参数:
        content (str): 文件全文
        start_pos (int): 类型声明 match 的起始位置

    返回:
        str|None: 类型作用域内容（不含外层花括号），提取失败返回 None
    """
    # 找到类型声明的左花括号
    brace_start = content.find("{", start_pos)
    if brace_start == -1:
        return None

    # 配对花括号
    depth = 0
    for i in range(brace_start, len(content)):
        if content[i] == "{":
            depth += 1
        elif content[i] == "}":
            depth -= 1
            if depth == 0:
                return content[brace_start + 1:i]
    return None


def _has_tool_type_features(type_body):
    """检测类型作用域是否含工具类型特征（实例方法或计算属性）

    参数:
        type_body (str): 类型作用域内容

    返回:
        bool: True 表示含工具类型特征（非纯常量命名空间）
    """
    has_func = bool(re.search(r'\bfunc\s+\w+', type_body))
    has_computed_var = bool(re.search(r'\b(?:let|var)\s+\w+[^=]*\{', type_body))
    return has_func or has_computed_var


def _is_namespace_declaration_line(stripped):
    """判断一行是否为纯常量命名空间允许的声明行

    允许: MARK 注释、static let 引用、嵌套 enum/struct/class、花括号

    参数:
        stripped (str): 去除首尾空白后的行内容

    返回:
        bool: True 表示该行符合纯常量命名空间规范
    """
    if stripped.startswith("//"):
        return True
    if stripped.startswith("static let "):
        return True
    if stripped.startswith(("enum ", "struct ", "class ")):
        return True
    if stripped in ("}", "{"):
        return True
    return False


def _is_pure_constant_namespace(type_body):
    """判断类型作用域是否为纯常量命名空间（仅含 static let 引用其他常量）

    纯常量命名空间特征：
    - 仅含 `static let` 声明
    - 声明值引用其他常量命名空间（如 NetworkConstants.XXX）
    - 无实例方法（func）、无计算属性（var ... { get }）、无嵌套工具类型

    参数:
        type_body (str): 类型作用域内容

    返回:
        bool: True 表示纯常量命名空间
    """
    lines = [
        l for l in type_body.split("\n")
        if l.strip() and not l.strip().startswith("//")
    ]
    if not lines:
        return False

    if _has_tool_type_features(type_body):
        return False

    for line in lines:
        stripped = line.strip()
        if not _is_namespace_declaration_line(stripped):
            return False
    return True


def _check_rule_a_func_redefine(content):
    """规则 A: 检测通用工具函数重新定义

    参数:
        content (str): 文件全文

    返回:
        list: 违规详情字典列表
    """
    errors = []
    for m in MIGRATED_FUNC_PATTERN.finditer(content):
        line_num = content[:m.start()].count("\n") + 1
        func_name = m.group(1)
        errors.append({
            "line": line_num,
            "message": f"通用工具函数 '{func_name}' 已迁移到 UFPCore，业务层不应重新定义。"
                       f"请改为 `import UFPCore` 并调用 `UFPCore.{func_name}`，或保留为转发兼容层。",
            "rule": "A_FUNC_REDEFINE"
        })
    return errors


def _check_rule_b_namespace_redefine(content):
    """规则 B: 检测通用常量命名空间重新定义

    参数:
        content (str): 文件全文

    返回:
        list: 违规详情字典列表
    """
    errors = []
    for m in REDEFINED_NAMESPACE_PATTERN.finditer(content):
        line_num = content[:m.start()].count("\n") + 1
        ns_name = m.group(1)
        errors.append({
            "line": line_num,
            "message": f"通用常量命名空间 '{ns_name}' 已迁移到 UFPCore，业务层不应重新定义。"
                       f"请改为 `import UFPCore` 并引用 `UFPCore.{ns_name}`。",
            "rule": "B_NAMESPACE_REDEFINE"
        })
    return errors


def _check_rule_c_type_redefine(content):
    """规则 C: 检测通用工具类/结构体重新定义（排除纯常量命名空间）

    参数:
        content (str): 文件全文

    返回:
        list: 违规详情字典列表
    """
    errors = []
    for m in REDEFINED_TYPE_PATTERN.finditer(content):
        line_num = content[:m.start()].count("\n") + 1
        type_name = m.group(1)

        type_body = _extract_type_body(content, m.start())
        if type_body and _is_pure_constant_namespace(type_body):
            continue

        errors.append({
            "line": line_num,
            "message": f"通用工具类型 '{type_name}' 已迁移到 UFPCore，业务层不应重新定义。"
                       f"请改为 `typealias {type_name} = UFPCore.{type_name}` 兼容层，"
                       f"或直接 `import UFPCore` 调用。",
            "rule": "C_TYPE_REDEFINE"
        })
    return errors


def _check_rule_d_extension_redefine(content):
    """规则 D: 检测通用扩展方法/属性重新定义

    参数:
        content (str): 文件全文

    返回:
        list: 违规详情字典列表
    """
    errors = []
    for m in MIGRATED_EXTENSION_PATTERN.finditer(content):
        line_num = content[:m.start()].count("\n") + 1
        ext_name = m.group(1)
        errors.append({
            "line": line_num,
            "message": f"通用扩展 '{ext_name}' 已迁移到 UFPCore，业务层不应重新定义。"
                       f"请改为 `import UFPCore` 调用 UFPCore 中的扩展。",
            "rule": "D_EXTENSION_REDEFINE"
        })
    return errors


def check_file_purity(file_path, exempt_files):
    """检查单个业务层 Swift 文件的 UFPCore 纯净化。

    参数:
        file_path (Path): Swift 文件的绝对路径
        exempt_files (set): 豁免文件路径集合

    返回:
        list: 违规详情字典列表（line/message/rule）
    """
    try:
        content = file_path.read_text(encoding="utf-8", errors="ignore")
    except Exception as e:
        return [{
            "line": 1,
            "message": f"无法读取文件进行 UFPCore 纯净化审计: {str(e)}",
            "rule": "READ_ERROR"
        }]

    rel_path = str(file_path.relative_to(PROJECT_DIR))
    if rel_path in exempt_files:
        return []

    if is_compatibility_layer(content):
        return []

    errors = []
    errors.extend(_check_rule_a_func_redefine(content))
    errors.extend(_check_rule_b_namespace_redefine(content))
    errors.extend(_check_rule_c_type_redefine(content))
    errors.extend(_check_rule_d_extension_redefine(content))
    return errors


# ==================== 主入口 ====================

def main():
    """主入口程序。执行全量扫描并输出报告。"""
    print("🔍 [UFPCore Purity] 开始执行业务层 UFPCore 纯净化静态审计...")

    # 加载白名单
    exempt_files = load_ufpcore_exempt_files()
    if exempt_files:
        print(f"📋 [UFPCore Purity] 已加载 {len(exempt_files)} 个豁免文件")

    total_files = 0
    violations_count = 0

    for scan_dir in BUSINESS_SCAN_DIRS:
        if not scan_dir.exists():
            continue

        for swift_file in scan_dir.rglob("*.swift"):
            total_files += 1
            file_errors = check_file_purity(swift_file, exempt_files)

            if file_errors:
                for err in file_errors:
                    print(
                        f"{swift_file}:{err['line']}: error: "
                        f"[UFPCore Purity Violation] {err['message']} "
                        f"(rule: {err['rule']})",
                        file=sys.stderr
                    )
                    violations_count += 1

    print(f"📊 [UFPCore Purity] 审计完成。共扫描了 {total_files} 个业务层 Swift 文件。")

    if violations_count > 0:
        print(
            f"🔴 [UFPCore Purity] 失败: 发现 {violations_count} 处通用基础能力泄漏违规。"
            f"构建已熔断阻断！",
            file=sys.stderr
        )
        sys.exit(1)
    else:
        print("🟢 [UFPCore Purity] 成功: 业务层 100% 通过 UFPCore 纯净化静态审计！")
        sys.exit(0)


if __name__ == "__main__":
    main()
