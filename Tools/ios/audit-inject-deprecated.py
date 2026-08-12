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


def scan_swift_files():
    """扫描所有 Swift 文件，检测 @Inject 和 ServiceContainer.shared 使用"""
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

            # 检测 @Inject
            for match in INJECT_PATTERN.finditer(content):
                line_num = content[:match.start()].count("\n") + 1
                key = (rel_path, line_num)
                if key not in whitelist:
                    violations.append({
                        "file": rel_path,
                        "line": line_num,
                        "type": "@Inject",
                    })

            # 检测 ServiceContainer.shared
            for match in SERVICE_CONTAINER_PATTERN.finditer(content):
                line_num = content[:match.start()].count("\n") + 1
                key = (rel_path, line_num)
                if key not in whitelist:
                    violations.append({
                        "file": rel_path,
                        "line": line_num,
                        "type": "ServiceContainer.shared",
                    })

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
