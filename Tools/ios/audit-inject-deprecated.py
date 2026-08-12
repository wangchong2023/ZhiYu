#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智宇 (ZhiYu) 废弃注入门禁工具 (audit-inject-deprecated.py)

功能说明:
1. 扫描 Sources/ 目录下所有 Swift 文件，检测 `@Inject` 和 `ServiceContainer.shared` 的使用。
2. 仅允许白名单 (Config/exemptions/inject_deprecated_whitelist.yml) 内列出的 file+line 组合保留。
3. 白名单外的使用将导致 CI 阻断（error）。
4. 配合 P7 渐进式迁移（Strangler Fig Pattern）：先冻结存量，逐步迁移，每批迁移后从白名单删除对应条目。

使用方法:
    python3 Tools/ios/audit-inject-deprecated.py

退出码:
    0: 审计通过（所有使用均在白名单内）
    1: 审计失败（发现未注册的使用）
"""

import os
import sys
import re
import yaml

# ==================== 配置常量 ====================
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")
WHITELIST_PATH = os.path.join(PROJECT_DIR, "Config", "exemptions", "inject_deprecated_whitelist.yml")

# 匹配 @Inject 属性包装器（支持 @Inject private/var name: Type）
INJECT_PATTERN = re.compile(r'^\s*@Inject\b', re.MULTILINE)

# 匹配 ServiceContainer.shared 调用
SERVICE_CONTAINER_PATTERN = re.compile(r'\bServiceContainer\.shared\b')


def load_whitelist():
    """加载废弃注入白名单配置"""
    try:
        with open(WHITELIST_PATH, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data:
            return {}
        whitelist = {}
        for entry in data.get("inject_deprecated_whitelist", []):
            key = (entry["file"], entry["line"])
            whitelist[key] = entry
        return whitelist
    except FileNotFoundError:
        print(f"⚠️  白名单文件不存在: {WHITELIST_PATH}", file=sys.stderr)
        print("   请先创建白名单文件。", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"error: 无法加载白名单配置 {WHITELIST_PATH}: {e}", file=sys.stderr)
        sys.exit(1)


def _is_line_exempt(line_num, comment_lines, exempt_marked_lines, exempt_ranges=None, is_service_container=False):
    """判断某行是否被豁免（注释行、inject_exempt 标记、DependencyKey 范围）"""
    if line_num in comment_lines:
        return True
    if line_num in exempt_marked_lines:
        return True
    if is_service_container and exempt_ranges:
        if any(start <= line_num <= end for start, end in exempt_ranges):
            return True
    return False


def _detect_violations(content, rel_path, whitelist):
    """检测单个文件中的 @Inject 和 ServiceContainer.shared 违规"""
    found = []

    # 预计算 DependencyKey liveValue/testValue/previewValue 的行范围，自动豁免
    # 这些是 P7 过渡期的合法用法（DependencyKey 从 ServiceContainer 解析）
    exempt_ranges = _compute_dependency_key_ranges(content)

    # 预计算注释行（/// 或 //），跳过注释中的匹配
    comment_lines = _compute_comment_lines(content)

    # 预计算含 inject_exempt 标记的行（行尾注释），跳过
    exempt_marked_lines = _compute_exempt_marked_lines(content)

    for match in INJECT_PATTERN.finditer(content):
        line_num = content[:match.start()].count("\n") + 1
        if _is_line_exempt(line_num, comment_lines, exempt_marked_lines):
            continue
        if (rel_path, line_num) not in whitelist:
            found.append({"file": rel_path, "line": line_num, "type": "@Inject"})

    for match in SERVICE_CONTAINER_PATTERN.finditer(content):
        line_num = content[:match.start()].count("\n") + 1
        if _is_line_exempt(line_num, comment_lines, exempt_marked_lines, exempt_ranges, True):
            continue
        if (rel_path, line_num) not in whitelist:
            found.append({"file": rel_path, "line": line_num, "type": "ServiceContainer.shared"})

    return found


def _compute_comment_lines(content):
    """计算注释行的行号集合（/// 或 // 开头的行，跳过字符串内的）"""
    lines = content.split("\n")
    comment_lines = set()
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("///"):
            comment_lines.add(i + 1)  # 1-indexed
    return comment_lines


# 向前搜索 inject_exempt 注释的最大行数
EXEMPT_LOOKBACK_LINES = 5


def _compute_exempt_marked_lines(content):
    """计算含 inject_exempt 标记的行号集合。

    豁免规则：
    1. 当前行含 inject_exempt（行尾注释）
    2. 向前最多 EXEMPT_LOOKBACK_LINES 行内有 inject_exempt 注释行（纯注释行 // inject_exempt: ...）
    """
    lines = content.split("\n")
    exempt_lines = set()
    for i, line in enumerate(lines):
        if "inject_exempt" in line:
            exempt_lines.add(i + 1)  # 当前行
    # 向前搜索：对每个含 ServiceContainer.shared 的代码行，检查前 N 行是否有 inject_exempt 注释
    for i, line in enumerate(lines):
        if "ServiceContainer.shared" in line or "@Inject" in line:
            lookback_start = max(0, i - EXEMPT_LOOKBACK_LINES)
            for j in range(lookback_start, i):
                if "inject_exempt" in lines[j]:
                    exempt_lines.add(i + 1)
                    break
    return exempt_lines


def _compute_dependency_key_ranges(content):
    """计算 DependencyKey liveValue/testValue/previewValue 属性的行范围（自动豁免）"""
    ranges = []
    lines = content.split("\n")
    # 匹配 static var liveValue / testValue / previewValue 的起始行
    pattern = re.compile(r'^\s*(?:public\s+)?static\s+var\s+(liveValue|testValue|previewValue)\b')
    for i, line in enumerate(lines):
        if pattern.match(line):
            # 找到属性体的结束（简单的括号匹配或下一个属性/方法）
            start = i + 1  # 1-indexed
            depth = 0
            end = start
            for j in range(i, len(lines)):
                depth += lines[j].count("{") - lines[j].count("}")
                end = j + 1  # 1-indexed
                if depth <= 0 and j > i:
                    break
            ranges.append((start, end))
    return ranges


def scan_swift_files():
    """扫描所有 Swift 文件，检测 @Inject 和 ServiceContainer.shared 使用"""
    whitelist = load_whitelist()
    violations = []

    for root, dirs, files in os.walk(SOURCES_DIR):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for filename in files:
            if not filename.endswith(".swift"):
                continue
            filepath = os.path.join(root, filename)
            rel_path = os.path.relpath(filepath, PROJECT_DIR)

            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                continue

            violations.extend(_detect_violations(content, rel_path, whitelist))

    return violations, len(whitelist)


def main():
    violations, whitelist_count = scan_swift_files()

    if violations:
        print(f"❌ [Inject Deprecated Audit] 审计失败：发现 {len(violations)} 个未注册的废弃注入使用\n",
              file=sys.stderr)
        print(f"   白名单配置: {WHITELIST_PATH}\n", file=sys.stderr)
        for v in violations:
            print(f"   {v['file']}:{v['line']}:1: error: `{v['type']}` "
                  f"未在白名单注册。请迁移至 @Dependency 或在 inject_deprecated_whitelist.yml 添加。",
                  file=sys.stderr)
        print(f"\n   当前白名单共 {whitelist_count} 项。", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"✅ [Inject Deprecated Audit] 审计通过：所有废弃注入均在白名单内（{whitelist_count} 项）。")
        sys.exit(0)


if __name__ == "__main__":
    main()
