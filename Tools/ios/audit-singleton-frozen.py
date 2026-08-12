#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智宇 (ZhiYu) 单例冻结门禁工具 (audit-singleton-frozen.py)

功能说明:
1. 扫描 Sources/ 目录下所有 Swift 文件，检测 `static let shared` 声明。
2. 仅允许白名单 (Config/exemptions/singleton_whitelist.yml) 内列出的 file+class 组合保留单例。
3. 白名单外的 `static let shared` 声明将导致 CI 阻断（error）。
4. 兼容 Xcode 编译器报错输出格式，如有违规在 Xcode 编译时直接以 error 标红并阻断构建。

使用方法:
    python3 Tools/ios/audit-singleton-frozen.py

退出码:
    0: 审计通过（所有单例均在白名单内）
    1: 审计失败（发现未注册的单例声明）
"""

import os
import sys
import re
import yaml

# ==================== 配置常量 ====================
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")
WHITELIST_PATH = os.path.join(PROJECT_DIR, "Config", "exemptions", "singleton_whitelist.yml")

# 匹配 `static let shared` 声明（支持带 @MainActor 等属性前缀）
# 格式: static let shared = XxxClass()
STATIC_LET_SHARED_PATTERN = re.compile(
    r'^\s*(?:@\w+\s+)*static\s+let\s+shared\b',
    re.MULTILINE
)

# 匹配类定义，用于确定单例所属的类名
CLASS_PATTERN = re.compile(
    r'^\s*(?:@\w+\s+)*(?:public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)*'
    r'(?:final\s+)?class\s+(\w+)',
    re.MULTILINE
)


def load_whitelist():
    """加载单例白名单配置"""
    try:
        with open(WHITELIST_PATH, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        whitelist = {}
        for entry in data.get("singleton_whitelist", []):
            key = (entry["file"], entry["class"])
            whitelist[key] = entry
        return whitelist
    except Exception as e:
        print(f"error: 无法加载白名单配置 {WHITELIST_PATH}: {e}", file=sys.stderr)
        sys.exit(1)


def find_class_for_line(content, target_line_num):
    """根据行号找到所属的类名"""
    lines = content.split("\n")
    class_name = None
    for i, line in enumerate(lines, 1):
        match = CLASS_PATTERN.match(line)
        if match:
            class_name = match.group(1)
        if i == target_line_num:
            break
    return class_name


def scan_swift_files():
    """扫描所有 Swift 文件，检测 static let shared 声明"""
    whitelist = load_whitelist()
    violations = []

    for root, dirs, files in os.walk(SOURCES_DIR):
        # 跳过隐藏目录
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

            for match in STATIC_LET_SHARED_PATTERN.finditer(content):
                line_num = content[:match.start()].count("\n") + 1
                class_name = find_class_for_line(content, line_num)

                if class_name is None:
                    continue

                # 检查是否在白名单中
                key = (rel_path, class_name)
                if key not in whitelist:
                    violations.append({
                        "file": rel_path,
                        "line": line_num,
                        "class": class_name,
                    })

    return violations, len(whitelist)


def main():
    violations, whitelist_count = scan_swift_files()

    if violations:
        print(f"❌ 单例冻结审计失败：发现 {len(violations)} 个未注册的单例声明\n", file=sys.stderr)
        print(f"   白名单配置: {WHITELIST_PATH}\n", file=sys.stderr)
        for v in violations:
            print(f"   {v['file']}:{v['line']}:1: error: 类 '{v['class']}' 的 `static let shared` "
                  f"未在白名单注册。请在 singleton_whitelist.yml 添加或迁移至 DependencyContainer。",
                  file=sys.stderr)
        print(f"\n   当前白名单共 {whitelist_count} 项。", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"✅ [Singleton Frozen Audit] 审计通过：所有单例均在白名单内（{whitelist_count} 项）。")
        sys.exit(0)


if __name__ == "__main__":
    main()
