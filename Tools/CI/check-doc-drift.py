#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-doc-drift.py
#  ZhiYu
#
#  系统层级：[Tools/CI] 守卫网关
#  核心职责：检测文档与代码的漂移——扫描 Docs/ 下所有 Markdown 文档中引用的
#           Swift 类型名（`ClassName`、`ProtocolName`、`MethodName()`），
#           验证这些引用是否在代码/SDK/第三方库/手动白名单中存在。
#           发现"幽灵引用"（文档引用了不存在的类型）将报告为漂移。
#
#  动态白名单机制：
#    本脚本通过 ExemptionRegistry 加载三层动态符号集 + 手动白名单：
#    1. 项目代码符号（Sources/Tests/，实时扫描）
#    2. Apple SDK 符号（xcrun swift-symbolgraph-extract，缓存）
#    3. 第三方库符号（.build/checkouts/，缓存）
#    4. 手动白名单（Config/exemptions/manual_whitelist.yml）
#    不再硬编码任何白名单变量。
#
#  报告为 WARNING（不熔断 CI，仅提示文档需更新）
#

import re
import sys
from pathlib import Path
from collections import defaultdict

# 项目根目录（Tools/CI/ → 退 2 层）
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
DOCS_DIR = PROJECT_DIR / "Docs"

# 导入统一注册中心
sys.path.insert(0, str(PROJECT_DIR / "Tools" / "CI"))
from exemption_registry import ExemptionRegistry

# 常量
REPORT_SEPARATOR_WIDTH = 60
MAX_ABBREVIATION_LENGTH = 5  # 全大写缩写最大长度（URL/UUID/LLM/RAG/AI/FTS/DI/SPM/CI/CD）

# 反引号标识符正则：`PascalCase` 或 `camelCase` 或 `snake_case`
IDENTIFIER_PATTERN = re.compile(r'`([A-Za-z][A-Za-z0-9_]*)`')


def is_skippable_reference(ref, registry):
    """判断引用是否应跳过（非 Swift 类型引用）

    动态查询 ExemptionRegistry，不再使用硬编码白名单
    """
    # 跳过全大写缩写（URL/UUID/LLM 等）
    if ref.upper() == ref and len(ref) <= MAX_ABBREVIATION_LENGTH:
        return True

    # 跳过 snake_case 标识符（SQL 列名/Python 变量，非 Swift 命名规范）
    if "_" in ref and ref == ref.lower():
        return True

    # 动态查询注册中心（项目代码 + SDK + 第三方库 + 手动白名单）
    if registry.is_exempt(ref):
        return True

    return False


def is_camelcase_word(ref, registry):
    """判断 camelCase 引用是否为普通英文单词（非代码符号）"""
    if ref[0].islower() and "_" not in ref:
        # 若注册中心未收录，视为普通英文单词
        if not registry.is_exempt(ref):
            return True
    return False


def scan_doc_file(md_file, registry, drift_issues):
    """扫描单个 Markdown 文件的代码符号引用"""
    refs_in_file = 0
    try:
        content = md_file.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0

    rel_path = md_file.relative_to(PROJECT_DIR)

    for m in IDENTIFIER_PATTERN.finditer(content):
        ref = m.group(1)

        if is_skippable_reference(ref, registry):
            continue

        if is_camelcase_word(ref, registry):
            continue

        refs_in_file += 1

        # 再次确认是否豁免（camelCase 可能在此处才被收录）
        if not registry.is_exempt(ref):
            drift_issues[str(rel_path)].append(ref)

    return refs_in_file


def print_drift_report(drift_issues, total_refs, total_docs):
    """打印文档漂移报告"""
    print(f"   扫描 {total_docs} 个文档，发现 {total_refs} 个代码符号引用\n")

    if not drift_issues:
        print("=" * REPORT_SEPARATOR_WIDTH)
        print("✅ [Doc Drift Checker] 文档与代码一致性良好，未发现漂移。")
        return 0

    print("=" * REPORT_SEPARATOR_WIDTH)
    print(f"⚠️  [Doc Drift Checker] 发现 {len(drift_issues)} 个文档存在幽灵引用：\n")

    total_ghosts = 0
    for doc_path, ghosts in sorted(drift_issues.items()):
        unique_ghosts = sorted(set(ghosts))
        total_ghosts += len(unique_ghosts)
        print(f"  📄 {doc_path}")
        for g in unique_ghosts:
            print(f"     • `{g}` — 代码/SDK/白名单中未找到此符号")
        print()

    print("=" * REPORT_SEPARATOR_WIDTH)
    print(f"⚠️  共 {total_ghosts} 个幽灵引用，分布于 {len(drift_issues)} 个文档。")
    print("   这些引用可能指向已删除/重命名的类型，建议更新文档。")
    print("   （本检查为 WARNING，不熔断 CI）")
    return 0


def scan_doc_drift():
    """扫描文档漂移（使用 ExemptionRegistry 动态白名单）"""
    print("📄 [Doc Drift Checker] 开始检测文档与代码漂移...\n")

    if not DOCS_DIR.exists():
        print(f"❌ 文档目录不存在: {DOCS_DIR}")
        return 1

    # 加载动态白名单注册中心
    print("📋 加载 ExemptionRegistry（项目代码 + Apple SDK + 第三方库 + 手动白名单）...")
    registry = ExemptionRegistry()
    registry.load()
    stats = registry.get_stats()
    print(f"   项目代码符号:   {stats['project_symbols']}")
    print(f"   Apple SDK 符号: {stats['sdk_symbols']}")
    print(f"   第三方库符号:   {stats['third_party_symbols']}")
    print(f"   手动白名单:     {stats['manual_whitelist']}")
    print(f"   总计:           {stats['total']}\n")

    # 扫描文档引用
    print("🔍 扫描 Docs/ 文档引用...")
    drift_issues = defaultdict(list)
    total_refs = 0
    total_docs = 0

    for md_file in DOCS_DIR.rglob("*.md"):
        total_docs += 1
        total_refs += scan_doc_file(md_file, registry, drift_issues)

    return print_drift_report(drift_issues, total_refs, total_docs)


if __name__ == "__main__":
    sys.exit(scan_doc_drift())
