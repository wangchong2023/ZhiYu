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
#  核心职责：审计 Shared/App/Core/Infrastructure 及底层 SPM 包的 #if os() / macCatalyst 分布。
#           采用精确文件级白名单 + 宏数量棘轮上限（只减不增），拦截任何新增散落点与正则绕过写法。
#           与 check-code-platform-macros.py 互补：后者守 Features/Domain 0 宏，本脚本守其余层。
#           参考规范：Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md。
#

from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# 需要审计的目录（Shared / App / Core / Infrastructure + 底层 SPM 包）
CHECK_DIRS = [
    PROJECT_ROOT / "Sources" / "Shared",
    PROJECT_ROOT / "Sources" / "App",
    PROJECT_ROOT / "Sources" / "Core",
    PROJECT_ROOT / "Sources" / "Infrastructure",
    PROJECT_ROOT / "Packages" / "UFPCore" / "Sources",
    PROJECT_ROOT / "Packages" / "UFPStorage" / "Sources",
    PROJECT_ROOT / "Packages" / "UFPDesignSystem" / "Sources",
    PROJECT_ROOT / "Packages" / "ZhiYuAICore" / "Sources",
]

# 宏总数棘轮上限（只减不增；收敛清理后请同步调低此阈值）
MAX_TOTAL_MACROS = 148

# 统一平台宏正则（去注释后匹配，拦截正向/反向/括号/复合条件中的 os() 与 macCatalyst）
OS_MACRO_PATTERN = re.compile(
    r"^\s*#(if|elseif)\b.*(\bos\s*\(|\btargetEnvironment\s*\(\s*macCatalyst\s*\))"
)

# 1) 核心跨平台桥接/修饰器文件白名单（合法平台抽象归属地）
BRIDGE_FILES = {
    "Sources/Shared/Platforms/Adaptor/CrossPlatform.swift",
    "Sources/Shared/Platforms/Adaptor/PlatformTraits.swift",
    "Sources/Shared/UIComponents/Modifiers/PlatformModifiers.swift",
    "Sources/Shared/UIComponents/Modifiers/DesignModifiers.swift",
    "Sources/Shared/UIComponents/Modifiers/AppToolbarModifier.swift",
}

# 2) 服务分发/环境/入口点白名单
DISPATCH_FILES = {
    "Sources/App/Core/ModuleRegistrar.swift",
    "Sources/App/Scenes/AppSceneBuilder.swift",
    "Sources/App/Core/AppEnvironment.swift",
    "Sources/App/Core/ZhiYuApp.swift",
}

# 3) 平台能力与 watchOS 基础设施隔离白名单（精确文件级）
PLATFORM_CAPABILITY_FILES = {
    "Sources/Core/Base/Protocols/KeyStoreProtocol.swift",
    "Sources/Core/Base/Protocols/PlatformCapabilities.swift",
    "Sources/Infrastructure/LLM/LLMModels.swift",
    "Sources/Shared/DesignSystem/DesignSystem.swift",
    "Sources/Infrastructure/Plugins/JavaScriptPlugin.swift",
    "Sources/Infrastructure/Plugins/PluginEnginePool.swift",
    "Sources/Infrastructure/Plugins/PluginLoader.swift",
    "Sources/Infrastructure/Plugins/PluginSandboxGateway.swift",
    "Sources/Infrastructure/Storage/Utility/DemoPDFBuilder.swift",
    "Sources/Infrastructure/Storage/Utility/DemoImageBuilder.swift",
    "Packages/UFPDesignSystem/Sources/UFPDesignSystem/Adapters/AppLottieView.swift",
    "Packages/UFPDesignSystem/Sources/UFPDesignSystem/Adapters/UFPMarkdownView.swift",
    "Packages/UFPDesignSystem/Sources/UFPDesignSystem/Components/Inputs.swift",
    "Packages/UFPDesignSystem/Sources/UFPDesignSystem/Feedback/AppErrorView.swift",
    "Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Colors.swift",
    "Packages/ZhiYuAICore/Sources/ZhiYuAICore/Multimodal/VideoMomentIndexer.swift",
}

# 4) 存量 UI 组件/布局文件冻结基线（替代过宽的目录白名单，禁止新增文件；应逐步向 PlatformModifiers / interfaceIdiom 收敛）
LEGACY_VIEW_FILES = {
    "Sources/App/Scenes/ContentView.swift",
    "Sources/App/Scenes/Layout/Components/AppLayoutComponents.swift",
    "Sources/App/Scenes/Layout/Components/SidebarRowComponents.swift",
    "Sources/Shared/UIComponents/Backgrounds/PageBackground.swift",
    "Sources/Shared/UIComponents/Editors/MarkdownEditorView.swift",
    "Sources/Shared/UIComponents/Editors/MarkdownRendererView.swift",
    "Sources/Shared/UIComponents/Editors/MermaidWebView.swift",
    "Sources/Shared/UIComponents/Editors/PlatformTextEditor.swift",
    "Sources/Shared/UIComponents/Menus/UserProfileMenu.swift",
    "Sources/Shared/UIComponents/Overlays/ActivityView.swift",
}

# 5) 已知豁免（精确行号 + 原因说明）
KNOWN_EXEMPTIONS = {
    "Sources/Core/System/Security/JailbreakDetector.swift": (
        {12, 82},
        "越狱检测依赖 UIApplication.shared.open 的 success Bool（VULN-010 安全路径）。",
    ),
}


def strip_line_comment(line: str) -> str:
    """去除 Swift 单行注释，避免注释中的说明性宏文本触发误报。"""
    return line.split("//", 1)[0]


def _scan_directory(check_dir: Path, root: Path = PROJECT_ROOT) -> list[tuple[str, list[tuple[int, str]]]]:
    """扫描指定目录下所有 Swift 文件中的平台宏，返回 (相对路径, 命中行列表)。"""
    results: list[tuple[str, list[tuple[int, str]]]] = []
    if not check_dir.exists():
        return results
    for swift_file in sorted(check_dir.rglob("*.swift")):
        hits: list[tuple[int, str]] = []
        try:
            content = swift_file.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for idx, line in enumerate(content.splitlines(), 1):
            if OS_MACRO_PATTERN.search(strip_line_comment(line)):
                hits.append((idx, line.strip()))
        if hits:
            results.append((swift_file.relative_to(root).as_posix(), hits))
    return results


def _classify(rel: str) -> tuple[str, str | None]:
    """对含宏文件的相对路径执行精确文件级分类。"""
    if rel in BRIDGE_FILES:
        return ("whitelist", "核心桥接层")
    if rel in DISPATCH_FILES:
        return ("whitelist", "服务分发/入口点")
    if rel in PLATFORM_CAPABILITY_FILES:
        return ("whitelist", "平台能力隔离")
    if rel in LEGACY_VIEW_FILES:
        return ("whitelist", "存量视图冻结基线")
    return ("violation", None)


def _classify_scanned(scanned: list[tuple[str, list[tuple[int, str]]]]):
    """将扫描结果分为白名单、已知豁免与违规三类。"""
    whitelisted, exempted, violations = [], [], []
    for rel, hits in scanned:
        if rel in KNOWN_EXEMPTIONS:
            exempt_lines, reason = KNOWN_EXEMPTIONS[rel]
            non_exempt = [(ln, text) for ln, text in hits if ln not in exempt_lines]
            exempted.append((rel, exempt_lines, reason))
            if non_exempt:
                violations.append((rel, non_exempt))
            continue
        kind, label = _classify(rel)
        if kind == "whitelist":
            whitelisted.append((rel, label, hits))
        else:
            violations.append((rel, hits))
    return whitelisted, exempted, violations


def _print_scanned(whitelisted: list, exempted: list) -> None:
    """--list-scanned 模式：打印全部含宏文件的分类清单。"""
    print("\n===== 分层宏文件清单 =====")
    print("▶ 精确文件白名单：")
    for rel, label, hits in sorted(whitelisted, key=lambda item: item[0]):
        lines = ", ".join(str(ln) for ln, _ in hits)
        print(f"  [{label}] {rel}  (L{lines})")
    print("▶ 已知豁免文件：")
    for rel, lines, _ in sorted(exempted, key=lambda item: item[0]):
        line_str = ", ".join(str(ln) for ln in sorted(lines))
        print(f"  {rel}  (L{line_str})\n")


def _report_violations(violations: list) -> None:
    """打印不在文件级白名单内的散落平台宏。"""
    print(f"❌ FAIL: 发现 {len(violations)} 个不在文件级白名单内的 #if os() / macCatalyst 散落文件")
    print("  请收敛至 CrossPlatform / PlatformModifiers / PlatformRegistrar 或使用 @Environment(\\.interfaceIdiom)。")
    for rel, hits in violations:
        print(f"  {rel}:")
        for line_no, text in hits:
            print(f"    L{line_no}: {text}")


def main() -> int:
    """审计 Shared/App/Core/Infrastructure 及底层 SPM 包平台宏分布并校验棘轮上限。"""
    list_scanned = "--list-scanned" in sys.argv
    scanned: list[tuple[str, list[tuple[int, str]]]] = []
    for check_dir in CHECK_DIRS:
        scanned.extend(_scan_directory(check_dir))

    whitelisted, exempted, violations = _classify_scanned(scanned)
    if list_scanned:
        _print_scanned(whitelisted, exempted)

    total = sum(len(hits) for _, hits in scanned)
    print(
        f"📊 共扫描到 {total}/{MAX_TOTAL_MACROS} 处 #if os() 宏："
        f"白名单 {len(whitelisted)} 文件 / 已知豁免 {len(exempted)} 文件 / 违规 {len(violations)} 文件"
    )

    failed = False
    if violations:
        _report_violations(violations)
        failed = True
    if total > MAX_TOTAL_MACROS:
        print(
            f"❌ FAIL: 平台宏总数 ({total}) 超出棘轮上限 ({MAX_TOTAL_MACROS})，"
            "禁止新增平台宏，请优先使用跨平台抽象或运行时 Trait。"
        )
        failed = True

    if failed:
        return 1

    print("✅ PASS: 平台宏分布符合文件级白名单且未突破棘轮上限")
    return 0


if __name__ == "__main__":
    sys.exit(main())
