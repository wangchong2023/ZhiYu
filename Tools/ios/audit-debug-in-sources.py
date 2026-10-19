#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gatekeeper: 检查 Sources/ 生产代码中不当的 #if DEBUG 测试分支与 Mock 侵入。

业界最佳实践：
生产代码应保持纯净单一逻辑，测试逻辑与 Mock 数据应通过 URLProtocol、
协议注入（@Dependency）与测试工程隔离。严禁在生产服务或视图中用 #if DEBUG
内嵌伪造凭据、后门方法或业务分支。

规则：
1. 严禁在 Sources/ 的 #if DEBUG 块中包含 Mock、测试凭据、测试后门方法或业务分叉逻辑。
2. 仅允许以下收口的豁免场景：
   - SwiftUI 官方预览 #Preview 块
   - 纯调试日志输出（Logger）
   - 底层平台安全兼容（Keychain / 自签名 HTTPS 证书 / 数据库签名自愈）
   - 顶层 @main 进程入口（启动参数检测）
   - 带有 `// debug_exempt: <具体原因>` 显式注释的代码行

用法：
    python3 Tools/ios/audit-debug-in-sources.py [--strict]
"""

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

COLOR_RED = "\033[91m"
COLOR_YELLOW = "\033[93m"
COLOR_GREEN = "\033[92m"
COLOR_RESET = "\033[0m"

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCES_ROOT = REPO_ROOT / "Sources"

PREVIEW_LOOKAHEAD_LINES = 10
MAX_SNIPPET_LENGTH = 120

# ── 允许使用 #if DEBUG 的文件白名单及明确理由 ──
FILE_WHITELIST = {
    # @main 应用引导入口：仅用于检测启动参数禁用动画或清除测试会话
    "Sources/App/Core/ZhiYuApp.swift": "应用启动引导层",
    "Sources/App/Core/AppEnvironment.swift": "启动环境诊断日志",
    # 系统级服务：日志仅在 Debug 输出
    "Sources/Core/System/Logger/Logger.swift": "调试日志输出",
    "Sources/Core/System/Security/SecurityManager.swift": "模拟器与底层安全证书兼容",
    "Sources/Core/System/Security/KeychainService.swift": "watchOS 与模拟器 Keychain 兼容",
    # 基础设施：开发环境本地 DB 完整性自愈
    "Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift": "开发调试模式数据库签名自愈",
    # 业务功能与表现：开发者设置分类与 DI 容器状态诊断
    "Sources/Features/Knowledge/System/Model/KnowledgeStore.swift": "DI 容器诊断日志",
    "Sources/Features/System/Settings/View/System/SettingsView.swift": "设置中心开发者调试菜单项",
    "Sources/Domain/Subscription/FeatureGateManager.swift": "编译期匿名游客 Feature Flag",
}

# ── 非法特征词（出现在 #if DEBUG 块中直接判定违规） ──
FORBIDDEN_DEBUG_PATTERNS = [
    (re.compile(r'\b(mock_|mock[A-Z]|Mock[A-Z]|fake_|stub_)\b'), "包含 Mock/Fake/Stub 伪造逻辑或假凭据"),
    (re.compile(r'\b\w+ForTesting\b'), "暴露测试专用后门方法 (*ForTesting)"),
    (re.compile(r'\bTestModeDetector\b'), "在业务中直接探查 TestModeDetector 测试模式"),
    (re.compile(r'\b(testSession|forceMock\w*|isMock\w*|testOverride)\b'), "声明或读取测试专用后门属性"),
]



@dataclass
class Finding:
    file: str
    line: int
    rule: str
    detail: str
    snippet: str


def is_file_whitelisted(filepath: Path) -> Tuple[bool, str]:
    """检查文件是否在预定义白名单中。"""
    rel_path = str(filepath.relative_to(REPO_ROOT))
    if rel_path in FILE_WHITELIST:
        return True, FILE_WHITELIST[rel_path]
    return False, ""


def is_preview_block(lines: List[str], debug_line_idx: int) -> bool:
    """检查是否属于 SwiftUI #Preview 预览块。"""
    end_idx = min(len(lines), debug_line_idx + PREVIEW_LOOKAHEAD_LINES)
    for j in range(debug_line_idx + 1, end_idx):
        if "#Preview" in lines[j]:
            return True
    return False


def _check_forbidden_patterns(rel_path: str, line_no: int, raw_line: str, stripped: str) -> Optional[Finding]:
    """检查 DEBUG 块内的单行是否触碰非法特征词。"""
    if "// debug_exempt:" in raw_line or stripped.startswith("//"):
        return None

    for pattern, desc in FORBIDDEN_DEBUG_PATTERNS:
        if pattern.search(raw_line):
            return Finding(
                file=rel_path,
                line=line_no,
                rule="FORBIDDEN_DEBUG_LOGIC",
                detail=f"#if DEBUG 块内违规：{desc}",
                snippet=stripped[:MAX_SNIPPET_LENGTH]
            )
    return None


def _handle_debug_start(filepath: Path, rel_path: str, lines: List[str], idx: int, raw_line: str, stripped: str) -> Tuple[bool, Optional[Finding]]:
    """处理 #if DEBUG 起始行，判定是否应进入 DEBUG 块或记录通用警告。"""
    line_no = idx + 1
    # 豁免：SwiftUI #Preview
    if is_preview_block(lines, idx):
        return False, None

    # 豁免：白名单文件
    is_wl, _ = is_file_whitelisted(filepath)
    if is_wl:
        return True, None

    # 豁免：行级注释
    if "// debug_exempt:" in raw_line:
        return False, None

    # 非白名单且非 Preview 出现 #if DEBUG
    finding = Finding(
        file=rel_path,
        line=line_no,
        rule="DEBUG_IN_SOURCES",
        detail="生产代码禁止内嵌 #if DEBUG 分支（应通过依赖注入或测试工程隔离）",
        snippet=stripped[:MAX_SNIPPET_LENGTH]
    )
    return True, finding


def scan_file(filepath: Path) -> List[Finding]:
    """扫描单个 Swift 文件中的 #if DEBUG 语法块与测试代码侵入。"""
    findings: List[Finding] = []
    rel_path = str(filepath.relative_to(REPO_ROOT))

    try:
        content = filepath.read_text(encoding="utf-8")
    except Exception:
        return findings

    lines = content.splitlines()
    in_debug_block = False

    for idx, raw_line in enumerate(lines):
        stripped = raw_line.strip()

        if re.match(r'^\s*#if\s+DEBUG\b', raw_line):
            in_debug, finding = _handle_debug_start(filepath, rel_path, lines, idx, raw_line, stripped)
            in_debug_block = in_debug
            if finding:
                findings.append(finding)
            continue

        if in_debug_block and re.match(r'^\s*#endif\b', raw_line):
            in_debug_block = False
            continue

        if in_debug_block:
            pattern_finding = _check_forbidden_patterns(rel_path, idx + 1, raw_line, stripped)
            if pattern_finding:
                findings.append(pattern_finding)

    return findings


def main() -> int:
    """主入口函数：解析命令行参数并扫描 Sources 目录下所有 Swift 文件。"""
    parser = argparse.ArgumentParser(
        description="Gatekeeper: 检查 Sources/ 生产代码中不当的 #if DEBUG 测试分支"
    )
    parser.add_argument(
        "--strict", action="store_true",
        help="发现违规直接阻断构建 (CI 模式)"
    )
    args = parser.parse_args()

    all_findings: List[Finding] = []
    for fp in SOURCES_ROOT.rglob("*.swift"):
        all_findings.extend(scan_file(fp))

    if not all_findings:
        print(f"{COLOR_GREEN}✅ Sources/ 生产代码 #if DEBUG 纯净化检查通过 — 无非法测试分支{COLOR_RESET}\n")
        return 0

    print(f"\n{COLOR_RED}=== 发现 {len(all_findings)} 处不当的 #if DEBUG 生产代码侵入 ==={COLOR_RESET}\n")
    for f in all_findings:
        print(f"  📄 {f.file}:{f.line}")
        print(f"     [{f.rule}] {f.detail}")
        print(f"     代码: {f.snippet}\n")

    if args.strict:
        print(f"{COLOR_RED}❌ STRICT 模式阻断：发现生产代码中存在不当的 #if DEBUG 侵入。{COLOR_RESET}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
