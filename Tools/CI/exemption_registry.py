#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  exemption_registry.py
#  ZhiYu
#
#  系统层级：[Tools/CI] 免白名单统一注册中心
#  核心职责：统一加载、管理、动态收集、反向校验所有审计脚本的豁免白名单。
#           实现"代码变更 → 白名单自动感知"的动态维护机制。
#
#  三层符号来源：
#    1. 项目代码符号：扫描 Sources/ + Tests/（实时）
#    2. Apple SDK 符号：xcrun swift-symbolgraph-extract（按需重建）
#    3. 第三方库符号：扫描 .build/checkouts/（依赖变更时）
#    4. 手动白名单：Config/exemptions/manual_whitelist.yml（概念词/SQL/占位符）
#
#  动态维护机制：
#    - 自动收集：运行时自动扫描三层来源，生成动态符号集
#    - 反向校验：expiry_check=true 的手动项若已在代码中实现，报告为过期
#    - 缓存机制：SDK/第三方符号集缓存至 .exemption_cache/，按需重建
#

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from collections import defaultdict

try:
    import yaml
except ImportError:
    print("❌ 缺少 PyYAML 依赖，请运行: pip3 install pyyaml")
    sys.exit(1)


# ==============================================================================
# 常量定义
# ==============================================================================

# 项目根目录（Tools/CI/ → 退 2 层）
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent

# 手动白名单 SSOT
MANUAL_WHITELIST_PATH = PROJECT_DIR / "Config" / "exemptions" / "manual_whitelist.yml"

# 符号缓存目录（gitignore）
CACHE_DIR = PROJECT_DIR / ".exemption_cache"

# 三层符号缓存文件
PROJECT_SYMBOLS_CACHE = CACHE_DIR / "project_symbols.json"
SDK_SYMBOLS_CACHE = CACHE_DIR / "sdk_symbols.json"
THIRD_PARTY_SYMBOLS_CACHE = CACHE_DIR / "third_party_symbols.json"

# 源码目录
SOURCES_DIR = PROJECT_DIR / "Sources"
TESTS_DIR = PROJECT_DIR / "Tests"

# 第三方库 checkout 目录（SPM）
SPM_CHECKOUTS_DIR = PROJECT_DIR / ".build" / "checkouts"

# Apple SDK 模块列表（需提取符号的框架）
APPLE_SDK_MODULES = [
    "Swift",  # Swift 标准库（Sendable/AsyncStream/Result 等）
    "SwiftUI", "UIKit", "AppKit", "Foundation", "Combine",
    "SwiftData", "CoreLocation", "MapKit", "CoreML", "Vision",
    "Security", "WebKit", "WatchKit", "WatchConnectivity",
    "LocalAuthentication", "AuthenticationServices",
    "JavaScriptCore", "NaturalLanguage", "RealityKit",
    "SceneKit", "AppIntents", "BackgroundTasks",
    "PDFKit", "QuartzCore", "CoreGraphics", "CoreText",
    "CoreAnimation", "CoreImage", "CoreData",
]

# Swift 类型声明正则
TYPE_PATTERN = re.compile(
    r'\b(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:final\s+|open\s+)?'
    r'(class|struct|protocol|enum|actor|extension)\s+([A-Z][A-Za-z0-9_]*)'
)

# Swift 方法声明正则
FUNC_PATTERN = re.compile(
    r'\b(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:static\s+|class\s+)?'
    r'func\s+([a-z][A-Za-z0-9_]*)'
)

# Swift 属性声明正则
VAR_PATTERN = re.compile(
    r'\b(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?:static\s+|class\s+)?'
    r'(?:let|var)\s+([a-z][A-Za-z0-9_]*)'
)

# Swift 枚举 case 正则
CASE_PATTERN = re.compile(
    r'\bcase\s+([a-z][A-Za-z0-9_]*)'
)


# ==============================================================================
# 手动白名单加载
# ==============================================================================

def load_manual_whitelist():
    """加载手动白名单 YAML 文件"""
    if not MANUAL_WHITELIST_PATH.exists():
        return {}

    with open(MANUAL_WHITELIST_PATH, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    return data


def get_manual_symbols(whitelist_data):
    """提取所有手动白名单符号（扁平化）"""
    symbols = set()
    for category, items in whitelist_data.items():
        if not isinstance(items, list):
            continue
        for item in items:
            if isinstance(item, dict) and "symbol" in item:
                symbols.add(item["symbol"])
    return symbols


def get_expiry_check_symbols(whitelist_data):
    """提取参与过期检测的符号（expiry_check=true）"""
    symbols = set()
    for category, items in whitelist_data.items():
        if not isinstance(items, list):
            continue
        for item in items:
            if isinstance(item, dict) and item.get("expiry_check", False):
                symbols.add(item["symbol"])
    return symbols


# ==============================================================================
# P2: 项目符号自动收集
# ==============================================================================

def collect_project_symbols():
    """扫描 Sources/ + Tests/ 下所有 Swift 文件，收集类型/方法/属性名"""
    symbols = set()

    search_dirs = [SOURCES_DIR]
    if TESTS_DIR.exists():
        search_dirs.append(TESTS_DIR)

    for search_dir in search_dirs:
        if not search_dir.exists():
            continue
        for swift_file in search_dir.rglob("*.swift"):
            try:
                content = swift_file.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue

            for pattern in [TYPE_PATTERN, FUNC_PATTERN, VAR_PATTERN, CASE_PATTERN]:
                for m in pattern.finditer(content):
                    # TYPE_PATTERN 有 2 个 group（第 2 个是名称），其余 1 个
                    symbol = m.group(2) if pattern == TYPE_PATTERN else m.group(1)
                    symbols.add(symbol)

    return symbols


# ==============================================================================
# P3: Apple SDK 符号自动收集
# ==============================================================================

def collect_sdk_symbols(force_rebuild=False):
    """使用 xcrun swift-symbolgraph-extract 收集 Apple SDK 符号

    缓存机制：首次收集后缓存至 .exemption_cache/sdk_symbols.json
    若缓存存在且未过期（SDK 版本未变），直接加载缓存

    降级策略：若 xcrun 不可用或 SDK 提取失败，返回空集（不阻断审计）
    """
    # 检查缓存
    if not force_rebuild and SDK_SYMBOLS_CACHE.exists():
        try:
            with open(SDK_SYMBOLS_CACHE, "r", encoding="utf-8") as f:
                return set(json.load(f))
        except (json.JSONDecodeError, IOError):
            pass  # 缓存损坏，重建

    symbols = set()

    # 动态获取 SDK 路径（优先 macosx，兼容非 iOS 开发环境）
    sdk_path = None
    for sdk_name in ["macosx", "iphoneos", "iphonesimulator"]:
        try:
            result = subprocess.run(
                ["xcrun", "--sdk", sdk_name, "--show-sdk-path"],
                capture_output=True, text=True, timeout=10, check=False,
            )
            if result.returncode == 0 and result.stdout.strip():
                sdk_path = result.stdout.strip()
                break
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue

    if not sdk_path:
        # SDK 不可用，降级为空集
        _save_cache(SDK_SYMBOLS_CACHE, symbols)
        return symbols

    # 提取每个模块的符号图
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        for module_name in APPLE_SDK_MODULES:
            try:
                result = subprocess.run(
                    [
                        "xcrun", "swift-symbolgraph-extract",
                        "-module-name", module_name,
                        "-output-dir", tmpdir,
                        "-sdk", sdk_path,
                    ],
                    capture_output=True, text=True, timeout=30, check=False,
                )
                if result.returncode != 0:
                    continue

                # 解析 .symbols.json 文件
                for json_file in Path(tmpdir).glob(f"{module_name}*.symbols.json"):
                    try:
                        with open(json_file, "r", encoding="utf-8") as f:
                            graph = json.load(f)
                        for symbol_obj in graph.get("symbols", []):
                            # 优先使用 names.title（可读符号名）
                            names = symbol_obj.get("names", {})
                            title = names.get("title", "")
                            if title:
                                # 仅保留 PascalCase/camelCase 标识符
                                # 跳过含空格/冒号/括号的（如 "init(_:)" / "==" ）
                                if re.match(r'^[A-Za-z][A-Za-z0-9_]*$', title):
                                    symbols.add(title)
                    except (json.JSONDecodeError, IOError):
                        continue
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue

    _save_cache(SDK_SYMBOLS_CACHE, symbols)
    return symbols


# ==============================================================================
# P4: 第三方库符号自动收集
# ==============================================================================

def collect_third_party_symbols(force_rebuild=False):
    """扫描 .build/checkouts/ 下所有 SPM 依赖的 Swift 文件

    缓存机制：首次收集后缓存至 .exemption_cache/third_party_symbols.json
    """
    # 检查缓存
    if not force_rebuild and THIRD_PARTY_SYMBOLS_CACHE.exists():
        try:
            with open(THIRD_PARTY_SYMBOLS_CACHE, "r", encoding="utf-8") as f:
                return set(json.load(f))
        except (json.JSONDecodeError, IOError):
            pass

    symbols = set()

    if not SPM_CHECKOUTS_DIR.exists():
        # SPM 依赖未 resolve，返回空集
        _save_cache(THIRD_PARTY_SYMBOLS_CACHE, symbols)
        return symbols

    # 扫描所有 checkout 的 Sources/ 目录
    for checkout_dir in SPM_CHECKOUTS_DIR.iterdir():
        if not checkout_dir.is_dir():
            continue

        sources_subdir = checkout_dir / "Sources"
        if not sources_subdir.exists():
            continue

        for swift_file in sources_subdir.rglob("*.swift"):
            try:
                content = swift_file.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue

            for pattern in [TYPE_PATTERN, FUNC_PATTERN, VAR_PATTERN, CASE_PATTERN]:
                for m in pattern.finditer(content):
                    symbol = m.group(2) if pattern == TYPE_PATTERN else m.group(1)
                    symbols.add(symbol)

    _save_cache(THIRD_PARTY_SYMBOLS_CACHE, symbols)
    return symbols


# ==============================================================================
# 缓存工具
# ==============================================================================

def _save_cache(cache_path, symbols):
    """保存符号集到缓存文件"""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(sorted(symbols), f, ensure_ascii=False, indent=2)
    except IOError:
        pass


def clear_cache():
    """清除所有符号缓存"""
    for cache_file in [PROJECT_SYMBOLS_CACHE, SDK_SYMBOLS_CACHE, THIRD_PARTY_SYMBOLS_CACHE]:
        if cache_file.exists():
            cache_file.unlink()


def get_cache_info():
    """获取缓存状态信息"""
    info = {}
    for name, path in [
        ("project", PROJECT_SYMBOLS_CACHE),
        ("sdk", SDK_SYMBOLS_CACHE),
        ("third_party", THIRD_PARTY_SYMBOLS_CACHE),
    ]:
        if path.exists():
            stat = path.stat()
            info[name] = {
                "exists": True,
                "size": stat.st_size,
                "mtime": stat.st_mtime,
                "path": str(path.relative_to(PROJECT_DIR)),
            }
        else:
            info[name] = {"exists": False}
    return info


# ==============================================================================
# P5: 反向校验（过期白名单检测）
# ==============================================================================

def check_stale_whitelist(whitelist_data, project_symbols, third_party_symbols):
    """反向校验：检测白名单中已在代码/第三方库实现的符号（过期项）

    返回: list[dict] 过期项列表，每项含 symbol/reason/found_in
    """
    stale_items = []

    for category, items in whitelist_data.items():
        if not isinstance(items, list):
            continue
        for item in items:
            if not isinstance(item, dict):
                continue
            if not item.get("expiry_check", False):
                continue

            symbol = item.get("symbol")
            if not symbol:
                continue

            found_in = None
            if symbol in project_symbols:
                found_in = "项目代码 (Sources/Tests/)"
            elif symbol in third_party_symbols:
                found_in = "第三方库 (.build/checkouts/)"

            if found_in:
                stale_items.append({
                    "symbol": symbol,
                    "category": category,
                    "reason": item.get("reason", ""),
                    "found_in": found_in,
                    "suggestion": f"已在 {found_in} 中定义，建议从 manual_whitelist.yml 移除此豁免",
                })

    return stale_items


# ==============================================================================
# 统一查询 API
# ==============================================================================

class ExemptionRegistry:
    """免白名单统一注册中心

    用法：
        registry = ExemptionRegistry()
        registry.load()

        # 查询符号是否豁免
        if registry.is_exempt("NavigationStack"):
            ...

        # 获取所有豁免符号
        all_symbols = registry.get_all_symbols()

        # 反向校验过期项
        stale = registry.check_stale()
    """

    def __init__(self, force_rebuild_cache=False):
        self.force_rebuild = force_rebuild_cache
        self.whitelist_data = {}
        self.project_symbols = set()
        self.sdk_symbols = set()
        self.third_party_symbols = set()
        self._loaded = False

    def load(self):
        """加载所有符号集（手动 + 自动收集）"""
        # 1. 加载手动白名单
        self.whitelist_data = load_manual_whitelist()

        # 2. 自动收集项目符号（实时，不缓存）
        self.project_symbols = collect_project_symbols()

        # 3. 自动收集 Apple SDK 符号（缓存）
        self.sdk_symbols = collect_sdk_symbols(force_rebuild=self.force_rebuild)

        # 4. 自动收集第三方库符号（缓存）
        self.third_party_symbols = collect_third_party_symbols(force_rebuild=self.force_rebuild)

        self._loaded = True

    def is_exempt(self, symbol):
        """查询符号是否豁免"""
        if not self._loaded:
            self.load()

        # 1. 在手动白名单中
        manual = get_manual_symbols(self.whitelist_data)
        if symbol in manual:
            return True

        # 2. 在项目代码中（已实现 = 不算漂移）
        if symbol in self.project_symbols:
            return True

        # 3. 在 Apple SDK 中
        if symbol in self.sdk_symbols:
            return True

        # 4. 在第三方库中
        if symbol in self.third_party_symbols:
            return True

        return False

    def get_all_symbols(self):
        """获取所有已知符号集（手动 + 自动）"""
        if not self._loaded:
            self.load()

        manual = get_manual_symbols(self.whitelist_data)
        return manual | self.project_symbols | self.sdk_symbols | self.third_party_symbols

    def get_manual_symbols_by_category(self, category):
        """按分类获取手动白名单符号"""
        if not self._loaded:
            self.load()

        items = self.whitelist_data.get(category, [])
        if not isinstance(items, list):
            return set()
        return {item["symbol"] for item in items if isinstance(item, dict) and "symbol" in item}

    def check_stale(self):
        """反向校验：检测过期白名单项"""
        if not self._loaded:
            self.load()

        return check_stale_whitelist(
            self.whitelist_data,
            self.project_symbols,
            self.third_party_symbols
        )

    def get_stats(self):
        """获取符号集统计信息"""
        if not self._loaded:
            self.load()

        manual = get_manual_symbols(self.whitelist_data)
        return {
            "manual_whitelist": len(manual),
            "project_symbols": len(self.project_symbols),
            "sdk_symbols": len(self.sdk_symbols),
            "third_party_symbols": len(self.third_party_symbols),
            "total": len(manual | self.project_symbols | self.sdk_symbols | self.third_party_symbols),
        }


# ==============================================================================
# CLI 入口
# ==============================================================================

def main():
    """CLI 入口：支持 stats / check-stale / rebuild-cache / is-exempt 子命令"""
    if len(sys.argv) < 2:
        print("用法:")
        print("  python3 exemption_registry.py stats          显示符号集统计")
        print("  python3 exemption_registry.py check-stale    检测过期白名单项")
        print("  python3 exemption_registry.py rebuild-cache  重建符号缓存")
        print("  python3 exemption_registry.py is-exempt <symbol>  查询符号是否豁免")
        return 0

    cmd = sys.argv[1]

    if cmd == "stats":
        registry = ExemptionRegistry()
        registry.load()
        stats = registry.get_stats()
        print("📊 [Exemption Registry] 符号集统计:")
        print(f"  手动白名单:     {stats['manual_whitelist']}")
        print(f"  项目代码符号:   {stats['project_symbols']}")
        print(f"  Apple SDK 符号: {stats['sdk_symbols']}")
        print(f"  第三方库符号:   {stats['third_party_symbols']}")
        print(f"  ────────────────────────")
        print(f"  总计:           {stats['total']}")
        return 0

    elif cmd == "check-stale":
        registry = ExemptionRegistry()
        registry.load()
        stale = registry.check_stale()

        if not stale:
            print("✅ [Exemption Registry] 未发现过期白名单项")
            return 0

        print(f"⚠️  [Exemption Registry] 发现 {len(stale)} 个过期白名单项:\n")
        for item in stale:
            print(f"  • {item['symbol']} (category: {item['category']})")
            print(f"    found_in: {item['found_in']}")
            print(f"    suggestion: {item['suggestion']}")
            print()
        return 0

    elif cmd == "rebuild-cache":
        print("🔄 [Exemption Registry] 重建符号缓存...")
        clear_cache()
        registry = ExemptionRegistry(force_rebuild_cache=True)
        registry.load()
        stats = registry.get_stats()
        print(f"✅ 缓存重建完成:")
        print(f"  Apple SDK 符号: {stats['sdk_symbols']}")
        print(f"  第三方库符号:   {stats['third_party_symbols']}")
        return 0

    elif cmd == "is-exempt":
        if len(sys.argv) < 3:
            print("用法: python3 exemption_registry.py is-exempt <symbol>")
            return 1
        symbol = sys.argv[2]
        registry = ExemptionRegistry()
        registry.load()
        if registry.is_exempt(symbol):
            print(f"✅ '{symbol}' 已豁免")
        else:
            print(f"❌ '{symbol}' 未豁免（可能是幽灵引用）")
        return 0

    else:
        print(f"未知命令: {cmd}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
