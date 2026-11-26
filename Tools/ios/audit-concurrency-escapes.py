#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-concurrency-escapes.py
#  ZhiYu
#
#  Created by Antigravity on 2026/11/25.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：Swift 6 并发逃生舱水位线审计（Ratchet Gatekeeper）。
#           锁定生产源码（Sources/ 与 Packages/*/Sources/）中 `@unchecked Sendable`
#           与 `nonisolated(unsafe)` 的存量上限，确保“只减不增”，守住 Swift 6 严格并发安全底线。
#

import os
import re
import sys

# ==============================================================================
# MARK: - 水位线配置（只减不增）
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCAN_ROOTS = [
    os.path.join(PROJECT_DIR, "Sources"),
    os.path.join(PROJECT_DIR, "Packages"),
]
EXCLUDE_DIRS = {".git", ".build", ".swiftpm", "build", "DerivedData", "Tests"}

# 存量水位线基线（2026-11-26 审计精准锁死：37 / 3，零松弛余量，禁止新增）
MAX_UNCHECKED_SENDABLE = 37
MAX_NONISOLATED_UNSAFE = 3

# 允许使用 nonisolated(unsafe) 的合法文件白名单（精准指纹控制）
ALLOWED_NONISOLATED_UNSAFE_FILES = {
    "Logger.swift",                   # Combine entriesSubject 当前值订阅
    "KnowledgePageRepository.swift",  # GRDB TableRecord belongsTo 静态关联定义
    "iOSSpeechService.swift",         # 跨 actor 音频识别请求 SFSpeechAudioBufferRecognitionRequest
}

UNCHECKED_SENDABLE_PATTERN = re.compile(r"@unchecked\s+Sendable\b")
NONISOLATED_UNSAFE_PATTERN = re.compile(r"nonisolated\(unsafe\)")


def _count_in_file(file_path):
    """统计单个 Swift 文件中两类并发逃生舱出现次数（忽略单行注释）。"""
    unchecked_count = 0
    nonisolated_count = 0
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                code_part = line.split("//", 1)[0]
                if not code_part:
                    continue
                unchecked_count += len(UNCHECKED_SENDABLE_PATTERN.findall(code_part))
                nonisolated_count += len(NONISOLATED_UNSAFE_PATTERN.findall(code_part))
    except OSError:
        return 0, 0
    return unchecked_count, nonisolated_count


def _scan_roots():
    """遍历所有生产源码目录，聚合并发逃生舱总数与违规文件。"""
    total_unchecked = 0
    total_nonisolated = 0
    disallowed_nonisolated = []
    for root_dir in SCAN_ROOTS:
        if not os.path.isdir(root_dir):
            continue
        for current_root, dirs, files in os.walk(root_dir):
            dirs[:] = [name for name in dirs if name not in EXCLUDE_DIRS]
            for file_name in files:
                if file_name.endswith(".swift"):
                    file_path = os.path.join(current_root, file_name)
                    unchecked, nonisolated = _count_in_file(file_path)
                    total_unchecked += unchecked
                    total_nonisolated += nonisolated
                    if nonisolated > 0 and file_name not in ALLOWED_NONISOLATED_UNSAFE_FILES:
                        rel_path = os.path.relpath(file_path, PROJECT_DIR)
                        disallowed_nonisolated.append((rel_path, nonisolated))
    return total_unchecked, total_nonisolated, disallowed_nonisolated


def run_audit():
    """扫描全量生产源码并校验并发逃生舱是否突破水位线与白名单。"""
    total_unchecked, total_nonisolated, disallowed_nonisolated = _scan_roots()

    print(
        f"📊 [Concurrency Escapes Audit] @unchecked Sendable: {total_unchecked}/{MAX_UNCHECKED_SENDABLE} | "
        f"nonisolated(unsafe): {total_nonisolated}/{MAX_NONISOLATED_UNSAFE}"
    )

    violations = 0
    if total_unchecked > MAX_UNCHECKED_SENDABLE:
        print(
            f"❌ [Concurrency Escapes Audit] @unchecked Sendable 数量 ({total_unchecked}) "
            f"超过水位线上限 ({MAX_UNCHECKED_SENDABLE})！请优先使用 actor 或 OSAllocatedUnfairLock。",
            file=sys.stderr,
        )
        violations += 1

    if total_nonisolated > MAX_NONISOLATED_UNSAFE:
        print(
            f"❌ [Concurrency Escapes Audit] nonisolated(unsafe) 数量 ({total_nonisolated}) "
            f"超过水位线上限 ({MAX_NONISOLATED_UNSAFE})！请改用 Sendable 不可变常量或 actor 隔离。",
            file=sys.stderr,
        )
        violations += 1

    if disallowed_nonisolated:
        for path, count in disallowed_nonisolated:
            print(
                f"❌ [Concurrency Escapes Audit] 未授权文件使用了 nonisolated(unsafe) ({count} 处): {path}",
                file=sys.stderr,
            )
        violations += len(disallowed_nonisolated)

    if violations == 0:
        print("✅ [Concurrency Escapes Audit] Swift 6 并发逃生舱水位线审计通过。")
    return violations


def main():
    """门禁入口：发现水位线突破即非零退出阻断。"""
    sys.exit(1 if run_audit() > 0 else 0)


if __name__ == "__main__":
    main()
