#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对 ZhiYu 单元测试环境中的依赖注入（DI）完整性进行静态防线审计。
# 分为两阶段防护：
# 1. 检查测试用例的 setUp 方法中直接使用高风险单例时，是否调用了 Mock 环境初始化方法；
# 2. 检查 Mock 场景初始化方法 setupFullMockEnvironment 中，是否完整注册了 Sources 依赖项中 @Inject 的属性。
#

"""
Gatekeeper: 检查测试 DI 依赖注册完整性（两层防护）。

Phase 1 — 测试端：setUp() 访问 DI 单例但未调用 setupFullMockEnvironment()
Phase 2 — Mock 端：setupFullMockEnvironment() 缺失 @Inject 依赖的注册
"""

import re
import sys
from pathlib import Path

TESTS_DIR = Path("Tests")
SOURCES_DIR = Path("Sources")
MOCK_FILE = TESTS_DIR / "Shared" / "TestMocks.swift"

# 测试 setUp 中访问的高风险 DI 单例
DI_SINGLETON_PATTERNS = [
    (r"LLMService\.shared", "LLMService.shared"),
    (r"AppStore\(\)", "AppStore()"),
    (r"VaultService\.shared", "VaultService.shared"),
    (r"AIWorkflowStore\(\)", "AIWorkflowStore()"),
]

DI_SETUP_MARKERS = [
    r"setupFullMockEnvironment\(\)",
    r"ServiceContainer\.shared\.register\(.+for:",
]

# 终端打印输出分割线长度
DIVIDER_LENGTH = 72


def _find_closure_end(content: str, start_index: int) -> int:
    """
    匹配 Swift 代码中成对的大括号，找到闭合括号的结束位置索引。
    
    参数:
        content (str): 源文件字符串
        start_index (int): 大括号开始位置后的第一个字符索引
        
    返回:
        int: 闭合大括号的字符索引（若未找到匹配的闭合则返回 -1）
    """
    depth = 1
    i = start_index
    length = len(content)
    while i < length and depth > 0:
        char = content[i]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        i += 1
    return i - 1 if depth == 0 else -1


# ── Phase 1: 测试端检查 ──────────────────────────────────────

def extract_setup_block(content: str) -> str:
    """
    从 Swift 源文件内容中提取出 override func setUp() 块的内部代码。
    通过匹配大括号层级来圈定函数体的边界。
    """
    pattern = r"override\s+func\s+setUp\s*\([^)]*\)\s*(?:async\s+)?throws\s*\{"
    matches = list(re.finditer(pattern, content))
    if not matches:
        return ""
    blocks = []
    for m in matches:
        start = m.end()
        end_idx = _find_closure_end(content, start)
        if end_idx != -1:
            blocks.append(content[start:end_idx])
    return "\n".join(blocks)


def has_di_setup(content: str) -> bool:
    for marker in DI_SETUP_MARKERS:
        if re.search(marker, content):
            return True
    return False


def find_di_singletons(setup_block: str) -> list[tuple[str, str]]:
    findings = []
    for pattern, name in DI_SINGLETON_PATTERNS:
        if re.search(pattern, setup_block):
            findings.append((name, f"setupFullMockEnvironment() 或手动注册 {name} 所需依赖"))
    return findings


def phase1_check() -> list[str]:
    """检查测试文件 setUp 中 DI 单例访问是否有对应的注册。"""
    violations = []
    for fp in TESTS_DIR.rglob("*.swift"):
        if fp == MOCK_FILE:
            continue
        try:
            content = fp.read_text(encoding="utf-8")
        except Exception:
            continue
        setup_block = extract_setup_block(content)
        if not setup_block:
            continue
        findings = find_di_singletons(setup_block)
        if not findings:
            continue
        if has_di_setup(setup_block):
            continue
        for name, hint in findings:
            violations.append(
                f"  {fp}: setUp() 访问 {name}，未调用 setupFullMockEnvironment() 或手动注册\n"
                f"    修复: setUp() 开头添加 setupFullMockEnvironment() 或 {hint}"
            )
    return violations


# ── Phase 2: Mock 端完整性检查 ───────────────────────────────

def scan_inject_deps() -> dict[str, set[str]]:
    """扫描 Sources 中所有类的 @Inject 依赖。
    返回 {类名: {依赖类型集合}}。
    """
    deps: dict[str, set[str]] = {}
    class_pattern = re.compile(
        r"(?:class|actor)\s+(\w+).*?\{", re.DOTALL
    )
    inject_pattern = re.compile(
        r"@Inject\s+(?:private\s+)?(?:var|let)\s+\w+\s*:\s*(?:any\s+)?(\w+(?:\.\w+)*)"
    )

    for fp in SOURCES_DIR.rglob("*.swift"):
        try:
            content = fp.read_text(encoding="utf-8")
        except Exception:
            continue

        for cm in re.finditer(class_pattern, content):
            class_name = cm.group(1)
            body_start = cm.end()
            end_idx = _find_closure_end(content, body_start)
            if end_idx == -1:
                continue
            body = content[body_start:end_idx]

            for im in inject_pattern.finditer(body):
                dep_type = im.group(1)
                dep_type = re.sub(r"^\s*any\s+", "", dep_type)
                if class_name not in deps:
                    deps[class_name] = set()
                deps[class_name].add(dep_type)

    return deps


def scan_shared_singletons() -> dict[str, str]:
    """找有 @Inject 依赖且定义了 static let shared 的类。
    返回 {类名: 文件名}。
    """
    inject_deps = scan_inject_deps()
    shared_map: dict[str, str] = {}
    shared_pat = re.compile(r"static\s+let\s+shared\s*=\s*(\w+)\(\)")

    for fp in SOURCES_DIR.rglob("*.swift"):
        try:
            content = fp.read_text(encoding="utf-8")
        except Exception:
            continue

        for cm in re.finditer(r"(?:class|actor)\s+(\w+).*?\{", content, re.DOTALL):
            class_name = cm.group(1)
            body_start = cm.end()
            end_idx = _find_closure_end(content, body_start)
            if end_idx == -1:
                continue
            body = content[body_start:end_idx]

            for sm in shared_pat.finditer(body):
                if sm.group(1) == class_name:
                    deps = inject_deps.get(class_name, set())
                    if deps:
                        shared_map[class_name] = str(fp.relative_to(SOURCES_DIR))
                    break

    return shared_map


def scan_mock_registrations() -> set[str]:
    """扫描 setupFullMockEnvironment() 中注册的服务类型。"""
    if not MOCK_FILE.exists():
        return set()

    content = MOCK_FILE.read_text(encoding="utf-8")

    m = re.search(r"func\s+setupFullMockEnvironment\s*\(\s*\)\s*\{", content)
    if not m:
        return set()

    start = m.end()
    end_idx = _find_closure_end(content, start)
    if end_idx == -1:
        return set()
    body = content[start:end_idx]

    registered: set[str] = set()
    for m in re.finditer(r"register\(.+?\bas\s+(?:any\s+)?(\w+)\s*[,\)]", body):
        registered.add(m.group(1))
    for m in re.finditer(r"register\(.+?,\s*for:\s*(\w+)\.self\)", body):
        registered.add(m.group(1))
    for m in re.finditer(r"for:\s*\(\s*any\s+(\w+)\s*\)", body):
        registered.add(m.group(1))

    return registered


def is_shared_used_in_tests(class_name: str) -> bool:
    """检查 ClassName.shared 是否在任何测试文件中被引用。"""
    pattern = re.compile(rf"\b{class_name}\.shared\b")
    for fp in TESTS_DIR.rglob("*.swift"):
        try:
            if pattern.search(fp.read_text(encoding="utf-8")):
                return True
        except Exception:
            continue
    return False


def phase2_check() -> list[str]:
    """检查 setupFullMockEnvironment() 是否注册了所有 shared 单例的 @Inject 依赖。"""
    violations = []
    inject_deps = scan_inject_deps()
    shared_map = scan_shared_singletons()
    registered = scan_mock_registrations()

    for class_name, filename in shared_map.items():
        if not is_shared_used_in_tests(class_name):
            continue

        deps = inject_deps.get(class_name, set())
        missing = deps - registered
        if missing:
            violations.append(
                f"  {class_name} ({SOURCES_DIR / filename}): shared 单例的 @Inject 依赖未在 setupFullMockEnvironment() 中注册\n"
                f"    缺失: {', '.join(sorted(missing))}\n"
                f"    修复: 在 Tests/Shared/TestMocks.swift 的 setupFullMockEnvironment() 中添加对应 Mock 注册"
            )

    return violations


# ── 主入口 ────────────────────────────────────────────────────

def main() -> int:
    """
    主入口函数。执行 Phase 1 (测试用例设置检查) 和 Phase 2 (Mock 环境依赖注册完整性检查)。
    若任一检查发现遗漏或违规，将输出详细错误信息并返回非零错误码。
    """
    exit_code = 0

    # Phase 1
    p1 = phase1_check()
    if p1:
        print("=" * DIVIDER_LENGTH)
        print("❌ Phase 1: 测试文件 setUp() 缺少 DI 注册调用")
        print("=" * DIVIDER_LENGTH)
        for v in p1:
            print(v)
        print()
        exit_code = 1
    else:
        print("✅ Phase 1: 所有测试文件 setUp() 正确调用了 DI 注册")

    # Phase 2
    p2 = phase2_check()
    if p2:
        print("=" * DIVIDER_LENGTH)
        print("❌ Phase 2: setupFullMockEnvironment() 缺少 @Inject 依赖注册")
        print("=" * DIVIDER_LENGTH)
        print("以下 shared 单例的 @Inject 依赖未在 Mock 环境中注册：")
        print()
        for v in p2:
            print(v)
        print()
        print("⚠️  测试 setUp 调用 setupFullMockEnvironment() 后仍会 fatalError。")
        print("=" * DIVIDER_LENGTH)
        exit_code = 1
    else:
        print("✅ Phase 2: setupFullMockEnvironment() 所有 @Inject 依赖已注册")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
