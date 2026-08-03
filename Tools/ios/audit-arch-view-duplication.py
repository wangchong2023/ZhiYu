#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-arch-view-duplication.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/01.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 架构与代码复用门禁
#  核心职责：基于 AST 结构树与修饰符链 (Modifier Chains) 启发式检测跨 Feature 域的 View 相似度，
#           自动提示建议提取沉淀至 Sources/Shared/UIComponents/。
#

import re
import sys
from pathlib import Path
from typing import List, Dict, Set, Tuple

# 引入 GatekeeperReporter
TOOLS_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS_DIR))

try:
    from gatekeeper_reporter import GatekeeperReporter
except ImportError:
    class GatekeeperReporter:
        def __init__(self, name): self.name = name
        def add_issue(self, f, l, m, level="WARNING", content=""):
            print(f"{f}:{l}: {level.lower()}: {m}")
        def report(self): pass

PROJECT_ROOT = TOOLS_DIR.parent.parent
FEATURES_DIR = PROJECT_ROOT / "Sources" / "Features"

# ── 常量定义 ──
SIMILARITY_THRESHOLD = 0.82
MODIFIER_WEIGHT = 0.6
ELEMENT_WEIGHT = 0.4
PERCENTAGE_MULTIPLIER = 100.0
MIN_MODIFIER_COUNT = 5

# 常见的 SwiftUI View 修饰符与节点正则匹配模式
MODIFIER_PATTERN = re.compile(r'\.([a-zA-Z0-9_]+)\s*\(')
ELEMENT_PATTERN = re.compile(
    r'\b(HStack|VStack|ZStack|LazyVStack|LazyHStack|Text|Image|Button|ProgressView|ScrollView|Group)\b'
)


def extract_domain(file_path: Path) -> str:
    """提取文件所属的功能域 (Feature Domain)。"""
    rel = file_path.relative_to(FEATURES_DIR)
    parts = rel.parts
    return parts[0] if parts else "Unknown"


def parse_view_signature(content: str) -> Tuple[List[str], Set[str]]:
    """从 View 代码中提取结构元素与修饰符链签名。"""
    elements = ELEMENT_PATTERN.findall(content)
    modifiers = set(MODIFIER_PATTERN.findall(content))
    return elements, modifiers


def calculate_jaccard_similarity(set1: Set[str], set2: Set[str]) -> float:
    """计算 Jaccard 集合相似度。"""
    if not set1 and not set2:
        return 1.0
    intersection = len(set1.intersection(set2))
    union = len(set1.union(set2))
    return intersection / union if union > 0 else 0.0


def _collect_view_signatures(view_files: List[Path]) -> Dict[Path, Tuple[str, List[str], Set[str]]]:
    """收集所有合法 View 文件的结构特征与签名。"""
    signatures: Dict[Path, Tuple[str, List[str], Set[str]]] = {}
    for file_path in view_files:
        try:
            content = file_path.read_text(encoding="utf-8")
            if "some View" in content or "@ViewBuilder" in content:
                domain = extract_domain(file_path)
                elements, modifiers = parse_view_signature(content)
                if len(modifiers) >= MIN_MODIFIER_COUNT:
                    signatures[file_path] = (domain, elements, modifiers)
        except Exception:
            continue
    return signatures


def _evaluate_cross_domain_duplicates(
    signatures: Dict[Path, Tuple[str, List[str], Set[str]]],
    reporter: GatekeeperReporter
):
    """评估跨 Feature 域视图的结构相似度并向 reporter 汇报建议。"""
    file_list = list(signatures.keys())
    reported_pairs: Set[Tuple[str, str]] = set()

    for i in range(len(file_list)):
        for j in range(i + 1, len(file_list)):
            f1, f2 = file_list[i], file_list[j]
            domain1, elem1, mod1 = signatures[f1]
            domain2, elem2, mod2 = signatures[f2]

            if domain1 == domain2:
                continue

            mod_sim = calculate_jaccard_similarity(mod1, mod2)
            elem_sim = calculate_jaccard_similarity(set(elem1), set(elem2))
            combined_score = MODIFIER_WEIGHT * mod_sim + ELEMENT_WEIGHT * elem_sim

            if combined_score >= SIMILARITY_THRESHOLD:
                pair_id = tuple(sorted([str(f1), str(f2)]))
                if pair_id not in reported_pairs:
                    reported_pairs.add(pair_id)
                    rel_f1 = f1.relative_to(PROJECT_ROOT)
                    rel_f2 = f2.relative_to(PROJECT_ROOT)
                    percent = combined_score * PERCENTAGE_MULTIPLIER
                    msg = (
                        f"[启发式重构建议] 跨 Feature 域视图 ({domain1} ↔ {domain2}) 相似度达 {percent:.1f}%。"
                        f" 与 [{f2.name}]({rel_f2}) 结构高度重合，建议提取公共 View 沉淀至 Sources/Shared/UIComponents/"
                    )
                    reporter.add_issue(
                        filepath=str(rel_f1),
                        line_no=1,
                        message=msg,
                        level="WARNING"
                    )


def main():
    """主逻辑函数：执行基于 AST/修饰符链的启发式 View 复用门禁。"""
    reporter = GatekeeperReporter("Heuristic View Duplication Check")
    
    if not FEATURES_DIR.exists():
        print(f"✅ [View Duplication Audit] 跳过：目录 {FEATURES_DIR} 不存在")
        sys.exit(0)

    view_files: List[Path] = [
        p for p in FEATURES_DIR.glob("**/*.swift")
        if "View" in p.name or "Panel" in p.name
    ]

    signatures = _collect_view_signatures(view_files)
    _evaluate_cross_domain_duplicates(signatures, reporter)

    reporter.report()
    print("✅ [View Duplication Audit] 启发式视图结构复用校验完成。")
    sys.exit(0)


if __name__ == "__main__":
    main()
