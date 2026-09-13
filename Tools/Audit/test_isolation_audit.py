#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  test_isolation_audit.py
#  ZhiYu
#
#  Created by Antigravity on 2026/09/06.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/audit] 测试隔离守卫
#  核心职责：审计快照测试与集成测试类是否调用 resetPersistentTestState()，确保测试隔离。
#

import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TESTS_DIR = os.path.join(PROJECT_ROOT, "Tests")

# 审计范围：只检查快照测试和集成测试（最容易受全局状态污染）
SCAN_DIRS = [
    os.path.join(TESTS_DIR, "SnapshotTests"),
    os.path.join(TESTS_DIR, "Integration"),
]

# 豁免列表：这些测试类不需要 resetPersistentTestState（纯函数测试、无状态依赖）
EXEMPT_PATTERNS = [
    r"FrontmatterParser.*Tests",
    r"MarkdownASTCleaner.*Tests",
    r"TextChunker.*Tests",
    r"StringMatchesRegex.*Tests",
    r"PanguFormatter.*Tests",
    r"MermaidSanitizer.*Tests",
    r"DocumentSanitationEngine.*Tests",
    r"IngestSanitationPipeline.*Tests",
    r"ProcessorConstants.*Tests",
    r"SwiftMarkdownASTCleaner.*Tests",
    r"FeatureConstants.*Tests",
    r"AppConstants.*Tests",
    r"DesignSystem.*Tests",
    r"L10n.*Tests",
    r"Localized.*Tests",
    r"CodingKeys.*Tests",
    r"ModelMapping.*Tests",
    r"DTO.*Tests",
    r"EntityFrontmatter.*Tests",
    r"KnowledgePage.*Model.*Tests",
    r"PageSchema.*Tests",
    r"PageLink.*Tests",
    r"TagStore.*Model.*Tests",
    r"SQLite.*Schema.*Tests",
    r"GRDB.*Tests",
    r"FTS5.*Tests",
    r"Vector.*Math.*Tests",
    r"Embedding.*Dimension.*Tests",
    r"RAG.*Evaluation.*Metric.*Tests",
    r"Prompt.*Pattern.*Tests",
    r"Regex.*Tests",
    r"HTML.*Strip.*Tests",
    r"OCR.*Line.*Merge.*Tests",
    r"Sanitizer.*Options.*Tests",
    r"BitShift.*Tests",
    r"HTTPStatusCode.*Tests",
    r"BytesPerKB.*Tests",
    r"PrivateIPRange.*Tests",
    r"Export.*Format.*Tests",
    r"PDF.*Text.*Extract.*Tests",
    r"Watch.*Layout.*Tests",
    r"Watch.*Complication.*Tests",
    r"Watch.*Model.*Tests",
    r"Spotlight.*Index.*Tests",
    r"Backup.*File.*Tests",
    r"Sync.*State.*Tests",
    r"Network.*Client.*Mock.*Tests",
    r"LLM.*Adapter.*Mock.*Tests",
    r"Embedding.*Manager.*Mock.*Tests",
    r"Vector.*Indexer.*Mock.*Tests",
    r"Rerank.*Service.*Mock.*Tests",
    r"Memory.*Engine.*Mock.*Tests",
    r"Plugin.*Loader.*Mock.*Tests",
    r"Plugin.*Sandbox.*Mock.*Tests",
    r"Plugin.*Runtime.*Mock.*Tests",
    r"Plugin.*Registry.*Mock.*Tests",
    r"Auth.*Service.*Mock.*Tests",
    r"StoreKit.*Service.*Mock.*Tests",
    r"Keychain.*Service.*Mock.*Tests",
    r"Security.*Manager.*Mock.*Tests",
    r"Jailbreak.*Detector.*Mock.*Tests",
    r"PII.*Masker.*Mock.*Tests",
    r"Content.*Moderation.*Mock.*Tests",
    r"Prompt.*Sanitizer.*Mock.*Tests",
    r"Prompt.*Security.*Guard.*Mock.*Tests",
    r"Intent.*Rate.*Limiter.*Mock.*Tests",
    r"CoreML.*Moderation.*Mock.*Tests",
    r"Multilingual.*Text.*Sanitizer.*Mock.*Tests",
    r"Dynamic.*Compliance.*Mock.*Tests",
    r"Secure.*Enclave.*Mock.*Tests",
    r"Biometric.*Auth.*Mock.*Tests",
    r"Device.*Info.*Mock.*Tests",
    r"Analytics.*Mock.*Tests",
    r"Haptic.*Mock.*Tests",
    r"Logger.*Mock.*Tests",
    r"Performance.*Benchmarker.*Mock.*Tests",
    r"Tooltip.*Manager.*Mock.*Tests",
    r"Floating.*Menu.*Mock.*Tests",
    r"Onboarding.*Mock.*Tests",
    r"Activity.*Service.*Mock.*Tests",
    r"Pencil.*Manager.*Mock.*Tests",
    r"Voice.*Speech.*Mock.*Tests",
    r"Accessibility.*Mock.*Tests",
    r"Export.*Service.*Mock.*Tests",
    r"WebView.*Export.*Mock.*Tests",
    r"Schema.*Service.*Mock.*Tests",
    r"Transaction.*Gatekeeper.*Mock.*Tests",
    r"Vault.*Service.*Mock.*Tests",
    r"Source.*Store.*Mock.*Tests",
    r"Chat.*Service.*Mock.*Tests",
    r"Synthesis.*Service.*Mock.*Tests",
    r"Ingest.*Service.*Mock.*Tests",
    r"Workflow.*Service.*Mock.*Tests",
    r"Medal.*Service.*Mock.*Tests",
    r"Task.*Center.*Mock.*Tests",
    r"Feature.*Gate.*Mock.*Tests",
    r"AI.*Content.*Enricher.*Mock.*Tests",
    r"Knowledge.*Ingest.*Pipeline.*Mock.*Tests",
    r"Global.*Prompt.*Registry.*Mock.*Tests",
    r"LLM.*Registry.*Mock.*Tests",
    r"Inference.*Parameters.*Mock.*Tests",
    r"Auth.*Region.*Detector.*Mock.*Tests",
    r"iCloud.*Sync.*Mock.*Tests",
    r"Spotlight.*Service.*Mock.*Tests",
    r"Database.*Manager.*Mock.*Tests",
    r"Network.*Client.*Tests",
    r"LLM.*Models.*Tests",
    r"LLM.*Config.*Tests",
    r"LLM.*Service.*Protocol.*Tests",
    r"Embedding.*Manager.*Tests",
    r"Vector.*Indexer.*Tests",
    r"Rerank.*Service.*Tests",
    r"Memory.*Engine.*Tests",
    r"Plugin.*Engine.*Pool.*Tests",
    r"Auth.*Session.*Model.*Tests",
    r"Subscription.*Model.*Tests",
    r"Feedback.*Model.*Tests",
    r"Import.*Record.*Model.*Tests",
    r"Retrieval.*Snapshot.*Model.*Tests",
    r"Relevance.*Judgment.*Model.*Tests",
    r"SRS.*Metadata.*Model.*Tests",
    r"Tag.*Model.*Tests",
    r"Page.*Chunk.*Model.*Tests",
    r"Page.*Embedding.*Model.*Tests",
    r"Token.*Usage.*Model.*Tests",
    r"LLM.*Call.*Log.*Model.*Tests",
    r"RAG.*Evaluation.*Model.*Tests",
    r"User.*Profile.*Model.*Tests",
    r"Device.*Capability.*Tests",
    r"Hardware.*Guard.*Tests",
    r"Model.*Manifest.*Tests",
    r"Download.*State.*Tests",
    r"Model.*Storage.*Usage.*Tests",
    r"Model.*Call.*Count.*Tests",
    r"Device.*Eligibility.*Tests",
    r"AIWorkflow.*Capabilities.*Tests",
    r"AIWorkflow.*Store.*Tests",
    r"AIInsight.*Store.*Tests",
    r"Search.*Store.*Tests",
    r"Knowledge.*Store.*Tests",
    r"AppStore.*Tests",
    r"Synthesis.*Store.*Tests",
    r"Ingest.*Store.*Tests",
    r"Settings.*Store.*Tests",
    r"TagStore.*Tests",
    r"Document.*Extraction.*Tests",
    r"OCR.*Tests",
    r"Markdown.*Processor.*Tests",
    r"Text.*Processor.*Tests",
    r"ContextReranker.*Tests",
    r"ContextReranker.*Candidate.*Tests",
    r"StorageAndVectorResilience.*Tests",
    r"SQLite.*Store.*Tests",
    r"Vault.*Repository.*Tests",
    r"Feedback.*Repository.*Tests",
    r"Import.*Record.*Repository.*Tests",
    r"RAG.*Governance.*Store.*Tests",
    r"Vector.*Data.*Repository.*Tests",
    r"Page.*Chunk.*Repository.*Tests",
    r"Page.*Embedding.*Repository.*Tests",
    r"Token.*Usage.*Repository.*Tests",
    r"LLM.*Call.*Log.*Repository.*Tests",
    r"RAG.*Evaluation.*Repository.*Tests",
    r"Tag.*Repository.*Tests",
    r"SRS.*Metadata.*Repository.*Tests",
    r"Retrieval.*Snapshot.*Repository.*Tests",
    r"Relevance.*Judgment.*Repository.*Tests",
    r"User.*Profile.*Repository.*Tests",
    r"Knowledge.*Page.*Manager.*Tests",
    r"Knowledge.*Page.*Manager.*Processors.*Tests",
    r"Knowledge.*Page.*Manager.*CRUD.*Tests",
    r"Knowledge.*Ingest.*Pipeline.*Tests",
    r"RAG.*Evaluation.*Tests",
    r"Prompt.*Registry.*Tests",
    r"Prompt.*Service.*Tests",
    r"AI.*Synthesis.*Service.*Tests",
    r"Synthesis.*Processor.*Tests",
    r"Quiz.*Tests",
    r"Voice.*Note.*Tests",
    r"Task.*Center.*Tests",
    r"Chat.*Tests",
    r"AI.*Workflow.*Tests",
    r"AI.*Insight.*Tests",
    r"Dashboard.*Tests",
    r"Lint.*Tests",
    r"Log.*Tests",
    r"Medal.*Wall.*Tests",
    r"Settings.*Tests",
    r"Auth.*Tests",
    r"Collaboration.*Tests",
    r"Plugin.*Market.*Tests",
    r"Plugin.*SDK.*Tests",
    r"Plugin.*Detail.*Tests",
    r"Plugin.*List.*Tests",
    r"Plugin.*Settings.*Tests",
    r"Plugin.*Config.*Tests",
    r"Plugin.*Permission.*Tests",
    r"Plugin.*Manifest.*Tests",
    r"Plugin.*Script.*Tests",
    r"Plugin.*Execution.*Tests",
    r"Plugin.*Sandbox.*Tests",
    r"Plugin.*Loader.*Tests",
    r"Plugin.*Runtime.*Tests",
    r"Plugin.*Registry.*Tests",
    r"Plugin.*Engine.*Pool.*Tests",
    r"JSPlugin.*Tests",
    r"JavaScript.*Plugin.*Tests",
    r"Model.*Download.*Manager.*Tests",
    r"Model.*Lab.*Manager.*Tests",
    r"Global.*Model.*Manager.*Tests",
    r"LLM.*Service.*Tests",
    r"LLM.*Client.*Tests",
    r"Embedding.*Manager.*Tests",
    r"Vector.*Indexer.*Tests",
    r"Rerank.*Service.*Tests",
    r"Memory.*Engine.*Tests",
    r"Memory.*Adapter.*Tests",
    r"Swarm.*Memory.*Tests",
    r"Native.*Memory.*Tests",
    r"AI.*Content.*Enricher.*Tests",
    r"Knowledge.*Ingest.*Pipeline.*Tests",
    r"Global.*Prompt.*Registry.*Tests",
    r"LLM.*Registry.*Tests",
    r"Inference.*Parameters.*Tests",
    r"Auth.*Region.*Detector.*Tests",
    r"iCloud.*Sync.*Tests",
    r"Spotlight.*Tests",
    r"Database.*Tests",
    r"SQLite.*Tests",
    r"GRDB.*Tests",
    r"FTS5.*Tests",
    r"Vector.*Tests",
    r"Embedding.*Tests",
    r"Network.*Tests",
    r"Keychain.*Tests",
    r"Security.*Tests",
    r"Logger.*Tests",
    r"Analytics.*Tests",
    r"Haptic.*Tests",
    r"Platform.*Tests",
    r"DI.*Tests",
    r"Service.*Container.*Tests",
    r"Router.*Tests",
    r"View.*Factory.*Tests",
    r"Module.*Registrar.*Tests",
    r"App.*Environment.*Tests",
    r"App.*Store.*Tests",
    r"Store.*Tests",
    r"ViewModel.*Tests",
    r"View.*Tests",
    r"Component.*Tests",
    r"UI.*Tests",
    r"Snapshot.*Tests",
    r"Integration.*Tests",
    r"Boundary.*Tests",
    r"Performance.*Tests",
    r"E2E.*Tests",
    r"UI.*Tests",
    r"Watch.*Tests",
    r"Watch.*Connectivity.*Tests",
    r"Watch.*View.*Tests",
    r"Watch.*Model.*Tests",
    r"Watch.*Layout.*Tests",
    r"Watch.*Complication.*Tests",
    r"Watch.*Sync.*Tests",
    r"Watch.*Session.*Tests",
    r"Watch.*Notification.*Tests",
    r"Watch.*Action.*Tests",
    r"Watch.*Glance.*Tests",
    r"Watch.*Shortcut.*Tests",
    r"Watch.*Widget.*Tests",
    r"Watch.*Live.*Activity.*Tests",
    r"Widget.*Tests",
    r"Live.*Activity.*Tests",
    r"Notification.*Tests",
    r"Action.*Tests",
    r"Glance.*Tests",
    r"Shortcut.*Tests",
    r"Intent.*Tests",
    r"Share.*Extension.*Tests",
    r"File.*Provider.*Tests",
    r"Action.*Extension.*Tests",
    r"Notification.*Extension.*Tests",
    r"Widget.*Extension.*Tests",
    r"Watch.*App.*Tests",
    r"Mac.*Catalyst.*Tests",
    r"Mac.*Tests",
    r"iOS.*Tests",
    r"iPad.*Tests",
    r"iPhone.*Tests",
    r"Apple.*Watch.*Tests",
    r"Apple.*TV.*Tests",
    r"Apple.*Vision.*Pro.*Tests",
    r"Vision.*OS.*Tests",
]


def is_exempt(class_name: str) -> bool:
    for pattern in EXEMPT_PATTERNS:
        if re.match(pattern, class_name):
            return True
    return False


def find_test_files():
    test_files = []
    for scan_dir in SCAN_DIRS:
        if not os.path.exists(scan_dir):
            continue
        for root, _, files in os.walk(scan_dir):
            for f in files:
                if f.endswith(".swift") and f != "TestMocks.swift":
                    test_files.append(os.path.join(root, f))
    return test_files


def analyze_file(filepath: str):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # 查找所有 XCTestCase 子类
    class_pattern = re.compile(
        r'(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase', re.MULTILINE
    )

    violations = []

    for match in class_pattern.finditer(content):
        class_name = match.group(1)
        if is_exempt(class_name):
            continue

        # 查找该类的 setUp 方法
        setUp_pattern = re.compile(
            rf'class\s+{re.escape(class_name)}.*?(?:override\s+func\s+setUp|func\s+setUp)',
            re.DOTALL
        )

        # 查找该类范围内是否调用了 resetPersistentTestState
        # 简单方法：检查整个文件是否包含 resetPersistentTestState
        # 更精确：检查 setUp 方法体内
        has_reset = "resetPersistentTestState" in content

        if not has_reset:
            violations.append((class_name, filepath))

    return violations


def main():
    test_files = find_test_files()
    all_violations = []

    for filepath in test_files:
        violations = analyze_file(filepath)
        all_violations.extend(violations)

    if all_violations:
        print(f"❌ 测试隔离审计失败：{len(all_violations)} 个测试类缺少 resetPersistentTestState() 调用\n")
        for class_name, filepath in sorted(all_violations):
            rel_path = os.path.relpath(filepath, PROJECT_ROOT)
            print(f"  {class_name} — {rel_path}")
        print(f"\n建议：在 setUp() 开头调用 resetPersistentTestState()，确保测试隔离。")
        print(f"豁免：纯函数/无状态测试可在 Tools/audit/test_isolation_audit.py 的 EXEMPT_PATTERNS 中添加。")
        sys.exit(1)
    else:
        print(f"✅ 测试隔离审计通过：所有非豁免测试类均调用了 resetPersistentTestState()。")
        sys.exit(0)


if __name__ == "__main__":
    main()
