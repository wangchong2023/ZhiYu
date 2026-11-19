#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-platform-macro-distribution.py
#  ZhiYu
#
#  Created by Antigravity on 2026/11/19.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：审计 Sources/Shared|App|Core|Infrastructure 四层的平台宏（#if os()）分布。
#           分级判定：适配层白名单 / 视图语义化豁免 / 服务分发点 / 平台能力豁免 / 已知豁免，
#           对不在任何白名单的散落 #if os() 标记违规并给出抽象建议（CrossPlatform/PlatformModifiers/PlatformRegistrar）。
#           与 check-code-platform-macros.py 互补：后者守 Features/Domain 0 宏，本脚本守其余层。
#           参考规范：Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md。
#

import sys
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"


def _rel(path: Path) -> str:
    """转为相对项目根目录的 posix 字符串路径（作为白名单/豁免键）。"""
    return path.relative_to(PROJECT_ROOT).as_posix()


# 需要检查的目录（Shared / App / Core / Infrastructure 四层）
CHECK_DIRS = [
    SOURCES_DIR / "Shared",
    SOURCES_DIR / "App",
    SOURCES_DIR / "Core",
    SOURCES_DIR / "Infrastructure",
]

# 拦截平台条件编译宏的正则表达式（与 check-code-platform-macros.py 对齐）
# 允许形式：#if canImport( 框架依赖判断 / #if targetEnvironment(simulator) 运行环境判断（不命中以下正则）
OS_MACRO_PATTERNS = [
    re.compile(r'#if\s+os\('),
    re.compile(r'#if\s+!os\('),
    re.compile(r'#elseif\s+os\('),
    re.compile(r'#elseif\s+!os\('),
    re.compile(r'#if\s+.*&&\s*!os\('),
    re.compile(r'#if\s+.*\|\|\s*!os\('),
    re.compile(r'#elseif\s+.*&&\s*!os\('),
    re.compile(r'#elseif\s+.*\|\|\s*!os\('),
    re.compile(r'#if\s+targetEnvironment\(\s*macCatalyst\s*\)'),
    re.compile(r'#elseif\s+targetEnvironment\(\s*macCatalyst\s*\)'),
]

# 分层白名单（前缀目录匹配）
# 1) 适配层白名单：跨平台适配器 + 全平台目录（平台实现归属地），不判违规
ADAPTER_DIR_PREFIXES = [
    "Sources/Shared/Platforms/Adaptor/",
    "Sources/Platforms/",
]
# 2) 视图语义化豁免：已语义化封装（PlatformModifiers/DesignModifiers）的 UI 组件与布局
VIEW_SEMANTIC_DIR_PREFIXES = [
    "Sources/Shared/UIComponents/",
    "Sources/App/Scenes/Layout/",
]
VIEW_SEMANTIC_FILES = {
    "Sources/App/Scenes/ContentView.swift",
}
# 3) 服务分发/环境/入口点白名单：平台分发与初始化编排的合法归属地
DISPATCH_FILES = {
    "Sources/App/Core/ModuleRegistrar.swift",
    "Sources/App/Scenes/AppSceneBuilder.swift",
    "Sources/App/Core/AppEnvironment.swift",
    "Sources/App/Core/ZhiYuApp.swift",
}
DISPATCH_DIR_PREFIXES = [
    "Sources/App/Environment/",
    "Sources/Core/System/Haptic/",
]
# 4) 平台能力豁免（文件级）：协议内平台能力声明 / OCR 平台分支
PLATFORM_CAPABILITY_FILES = {
    "Sources/Core/Base/Protocols/KeyStoreProtocol.swift",
    "Sources/Core/Base/Protocols/PlatformCapabilities.swift",
    "Sources/Infrastructure/LLM/LLMModels.swift",
}
# 4b) watchOS 能力隔离豁免（文件级）：watchOS target 缺省能力或框架（Keychain/DEBUG/JavaScriptCore/UIKit/PDFKit），
#     用 !os(watchOS) 或 canImport(...) && !os(watchOS) 隔离，属基础设施平台能力，非业务散落点。
WATCHOS_CAPABILITY_FILES = {
    "Sources/Shared/DesignSystem/DesignSystem.swift",
    "Sources/Core/System/Security/KeychainService.swift",
    "Sources/Core/System/Security/SecurityManager.swift",
    "Sources/Infrastructure/Plugins/JavaScriptPlugin.swift",
    "Sources/Infrastructure/Plugins/PluginEnginePool.swift",
    "Sources/Infrastructure/Plugins/PluginLoader.swift",
    "Sources/Infrastructure/Plugins/PluginSandboxGateway.swift",
    "Sources/Infrastructure/Storage/Utility/DemoPDFBuilder.swift",
    "Sources/Infrastructure/Storage/Utility/DemoImageBuilder.swift",
}

# 5) 已知豁免（显式列出 + 原因）：不视为违规，但脚本输出说明，供治理审查
# 键：相对路径；值：(行号集合, 原因说明)
KNOWN_EXEMPTIONS = {
    "Sources/Core/System/Security/JailbreakDetector.swift": (
        {12, 82},
        "越狱检测依赖 UIApplication.shared.open 的 success Bool（canOpen 语义，替代废弃 canOpenURL，"
        "VULN-010 修复路径）；URLOpenerProtocol.open 为 async 且不返回 Bool，语义不匹配，强行改造会改变安全关键行为。",
    ),
    "Sources/Infrastructure/Processors/ImageExtractor.swift": (
        {14, 154},
        "L14 import UIKit 仅用于 AppImage(data:)（AppImage 为 CrossPlatform typealias=UIImage，init(data:) 属 UIKit，"
        "import 不跨文件传播，CrossPlatform 未提供 data init 封装，移除会破坏 iOS 编译）；L154 为 iOS OCR 平台分支，"
        "OCR 已走 @Dependency(\\\\.ocrService) 协议注入收敛，保留平台能力。",
    ),
}


def _scan_directory(check_dir: Path) -> list[tuple[Path, list[tuple[int, str]]]]:
    """扫描指定目录下所有 Swift 文件中的 #if os() 宏，返回 (文件路径, 命中行列表)。"""
    results = []
    if not check_dir.exists():
        return results
    for swift_file in check_dir.rglob("*.swift"):
        hits = []
        try:
            with open(swift_file, 'r') as f:
                for i, line in enumerate(f, 1):
                    for pattern in OS_MACRO_PATTERNS:
                        if pattern.search(line):
                            hits.append((i, line.strip()))
                            break  # 同一行不重复记录
        except Exception:
            pass
        if hits:
            results.append((swift_file, hits))
    return results


def _matches_any_prefix(rel: str, prefixes: list[str]) -> bool:
    """判断相对路径是否命中任一目录前缀。"""
    return any(rel.startswith(p) for p in prefixes)


def _classify(rel: str):
    """
    对含宏文件的相对路径做分级判定。
    返回 ("whitelist", 类别标签) 表示白名单，或 ("violation", None) 表示违规。
    """
    if _matches_any_prefix(rel, ADAPTER_DIR_PREFIXES):
        return ("whitelist", "适配层")
    if _matches_any_prefix(rel, VIEW_SEMANTIC_DIR_PREFIXES) or rel in VIEW_SEMANTIC_FILES:
        return ("whitelist", "视图语义化豁免")
    if rel in DISPATCH_FILES or _matches_any_prefix(rel, DISPATCH_DIR_PREFIXES):
        return ("whitelist", "服务分发/环境/入口点")
    if rel in PLATFORM_CAPABILITY_FILES:
        return ("whitelist", "平台能力豁免")
    if rel in WATCHOS_CAPABILITY_FILES:
        return ("whitelist", "watchOS 能力隔离豁免")
    return ("violation", None)


def _report_violations(violations: list) -> int:
    """打印违规清单并返回退出码 1。"""
    print(f"❌ FAIL: 发现 {len(violations)} 个不在白名单的 #if os() 平台宏散落点（{len(set(v for v, _ in violations))} 个文件）")
    print()
    print("这些散落点应收敛到跨平台抽象：")
    print("  Shared/Platforms/Adaptor/CrossPlatform.swift → 跨平台类型/API 桥接")
    print("  Shared/UIComponents/Modifiers/PlatformModifiers → 视图平台语义化封装")
    print("  Platforms/{platform}/Registrar → 平台服务注册（PlatformRegistrar 模式）")
    print("  或登记为白名单/已知豁免（附合理原因）")
    print()
    for rel, hits in violations:
        print(f"  {rel}:")
        for line_no, content in hits:
            print(f"    L{line_no}: {content}")
    return 1


def _classify_known_exemption(rel: str, hits: list) -> tuple[list, list]:
    """处理已知豁免文件：命中行属于登记豁免行则归豁免，其余行归违规。"""
    exempt_lines, reason = KNOWN_EXEMPTIONS[rel]
    non_exempt = [(ln, c) for ln, c in hits if ln not in exempt_lines]
    violations = [(rel, non_exempt)] if non_exempt else []
    exempted = [(rel, exempt_lines, reason)]
    return exempted, violations


def _classify_scanned(scanned: list) -> tuple[list, list, list]:
    """将扫描结果逐文件分级：返回 (白名单列表, 豁免列表, 违规列表)。"""
    whitelisted = []
    exempted = []
    violations = []

    for file_path, hits in scanned:
        rel = _rel(file_path)
        if rel in KNOWN_EXEMPTIONS:
            ex, vi = _classify_known_exemption(rel, hits)
            exempted.extend(ex)
            violations.extend(vi)
            continue
        kind, label = _classify(rel)
        if kind == "whitelist":
            whitelisted.append((rel, label, hits))
        else:
            violations.append((rel, hits))
    return whitelisted, exempted, violations


def _main():
    """审计 Shared/App/Core/Infrastructure 平台宏分布并报告。"""
    list_scanned = "--list-scanned" in sys.argv

    scanned = []
    for check_dir in CHECK_DIRS:
        scanned.extend(_scan_directory(check_dir))

    whitelisted, exempted, violations = _classify_scanned(scanned)

    if list_scanned:
        _print_scanned(whitelisted, exempted)

    total = sum(len(h) for _, h in scanned)
    print(f"📊 共扫描到 {total} 处 #if os() 宏：白名单 {len(whitelisted)} 文件 / 已知豁免 {len(exempted)} 文件 / 违规 {len(violations)} 文件")

    if violations:
        return _report_violations(violations)

    print("✅ PASS: Shared/App/Core/Infrastructure 平台宏均在白名单或已知豁免内，无散落违规")
    return 0


def _print_scanned(whitelisted: list, exempted: list):
    """--list-scanned 模式：打印各层级扫描到的宏文件清单。"""
    print()
    print("===== 分层宏文件清单 =====")
    print("▶ 白名单文件：")
    for rel, label, hits in sorted(whitelisted, key=lambda x: x[0]):
        lines = ", ".join(str(ln) for ln, _ in hits)
        print(f"  [{label}] {rel}  (L{lines})")
    print("▶ 已知豁免文件：")
    for rel, lines, _ in sorted(exempted, key=lambda x: x[0]):
        line_str = ", ".join(str(ln) for ln in sorted(lines))
        print(f"  {rel}  (L{line_str})")
    print()


if __name__ == "__main__":
    sys.exit(_main())