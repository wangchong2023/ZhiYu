# -*- coding: utf-8 -*-
#!/usr/bin/env python3
"""
[Gatekeeper] 依赖注入完整性检查

扫描 Sources/ 中所有 @Inject 声明，与 container.register 调用交叉验证，
检测未注册的依赖类型。避免因 DI 缺失导致运行时 fatalError 崩溃。

用法:
    python3 Tools/ios/check-arch-di-registration.py
"""

import os
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"
SEPARATOR_WIDTH = 60

# 每个缺失类型最多显示的文件引用数
MAX_FILE_LOCATIONS = 3

# 导入统一免白名单注册中心
sys.path.insert(0, str(PROJECT_ROOT / "Tools" / "CI"))
from exemption_registry import ExemptionRegistry  # noqa: E402


def extract_inject_types() -> set:
    """从 @Inject 声明中提取所有依赖类型。"""
    inject_types = set()
    pattern = re.compile(r'@Inject\s+(?:private\s+|internal\s+|public\s+)?var\s+\w+\s*:\s*((?:any\s+)?\w[\w.]*)')
    for root, _, files in os.walk(SOURCES_DIR):
        # 跳过 Tests 目录
        if "Tests" in root:
            continue
        for f in files:
            if not f.endswith(".swift"):
                continue
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as fh:
                content = fh.read()
            for match in pattern.finditer(content):
                type_name = match.group(1)
                # 清理: 去除 "any " 前缀, "()" 后缀, "?" / "!" 后缀
                type_name = type_name.replace("any ", "").rstrip("?!")
                # 跳过单字母泛型类型参数（如 T），避免误报
                if len(type_name) <= 1:
                    continue
                inject_types.add(type_name)
    return inject_types


def extract_register_types() -> set:
    """从 container.register() 调用中提取所有已注册类型。"""
    register_types = set()
    # 匹配: container.register(xxx as ... , for: SomeType.self)
    # 或: container.register(xxx, for: SomeType.self)
    pattern_for = re.compile(r'container\.register\([^,]+,\s*for:\s*\(?(?:any\s+)?([\w.]+)\)?\.self')

    for root, _, files in os.walk(SOURCES_DIR):
        for f in files:
            if not f.endswith(".swift"):
                continue
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as fh:
                content = fh.read()
            for match in pattern_for.finditer(content):
                type_name = match.group(1)
                register_types.add(type_name)
    return register_types


def find_missing_types(inject_types: set, register_types: set, whitelist: set) -> list:
    """交叉比对 @Inject 类型与已注册类型，返回未注册类型列表。"""
    missing = []
    for t in sorted(inject_types):
        if t in whitelist:
            continue
        if t in register_types:
            continue
        # 模糊匹配: 检查是否有同类名注册（如协议的不同模块声明）
        if any(rt for rt in register_types if rt.endswith(t.split(".")[-1])):
            continue
        missing.append(t)
    return missing


def find_files_with_inject_type(type_name: str) -> list:
    """在 Sources 目录中查找使用了指定 @Inject 类型的 Swift 文件。"""
    files_found = []
    for root, _, files in os.walk(SOURCES_DIR):
        if "Tests" in root:
            continue
        for f in files:
            if not f.endswith(".swift"):
                continue
            fp = os.path.join(root, f)
            with open(fp, "r", encoding="utf-8") as fh:
                content = fh.read()
                short_name = type_name.split(".")[-1]
                if f"@Inject {type_name}" in content or f"@Inject var {short_name}" in content:
                    files_found.append(os.path.relpath(fp, PROJECT_ROOT))
    return files_found


def report_missing_types(missing: list) -> None:
    """输出未注册依赖类型的详细报告。"""
    print(f"\n🚨 发现 {len(missing)} 个未注册的 @Inject 依赖类型：")
    for t in missing:
        files_found = find_files_with_inject_type(t)
        for fp in files_found[:MAX_FILE_LOCATIONS]:
            print(f"    • {t} — {fp}")
    print("\n💡 请添加 container.register 调用，或将类型加入白名单。")


def main() -> int:
    """DI 注册完整性验证入口。"""
    os.chdir(PROJECT_ROOT)

    print("=" * SEPARATOR_WIDTH)
    print("[Gatekeeper] 依赖注入 (DI) 注册完整性检查")
    print("=" * SEPARATOR_WIDTH)

    inject_types = extract_inject_types()
    register_types = extract_register_types()

    # 从 ExemptionRegistry 加载 DI 注册豁免（di_registration_exempt 分类）
    registry = ExemptionRegistry()
    registry.load()
    di_exempt_items = registry.whitelist_data.get("di_registration_exempt", [])
    whitelist = {
        item["symbol"] for item in di_exempt_items
        if isinstance(item, dict) and "symbol" in item
    }

    missing = find_missing_types(inject_types, register_types, whitelist)

    if missing:
        report_missing_types(missing)
        return 1

    total_registered = len(inject_types) - len(whitelist)
    print(f"\n✅ 所有 {total_registered} 个 @Inject 类型均已注册。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
