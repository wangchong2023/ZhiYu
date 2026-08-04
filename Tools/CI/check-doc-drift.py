#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-doc-drift.py
#  ZhiYu
#
#  系统层级：[Tools/CI] 守卫网关
#  核心职责：检测文档与代码的漂移——扫描 Docs/ 下所有 Markdown 文档中引用的
#           Swift 类型名（`ClassName`、`ProtocolName`、`MethodName()`），
#           验证这些引用是否在 Sources/ 代码中实际存在。
#           发现"幽灵引用"（文档引用了已删除/重命名的类型）将报告为漂移。
#
#  设计原则：
#    - 仅检测反引号包裹的 PascalCase 或 camelCase 标识符（`KnowledgePage`、`processMemory()`）
#    - 跳过全大写缩写（`URL`、`UUID`、`LLM`、`RAG`、`AI`、`FTS`、`DI`、`SPM`、`CI`、`CD`）
#    - 跳过非 Swift 标识符（含连字符、点号、空格）
#    - 报告为 WARNING（不熔断 CI，仅提示文档需更新）
#

import os
import re
import sys
from pathlib import Path
from collections import defaultdict

# 项目根目录（Tools/CI/ → 退 2 层）
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
DOCS_DIR = PROJECT_DIR / "Docs"
SOURCES_DIR = PROJECT_DIR / "Sources"
TESTS_DIR = PROJECT_DIR / "Tests"

# 常量定义（避免魔鬼数字）
MAX_ABBREVIATION_LENGTH = 5  # 全大写缩写最大长度（如 URL/UUID/LLM）
REPORT_SEPARATOR_WIDTH = 60  # 报告分隔线宽度

# 跳过的全大写缩写（非 Swift 类型）
SKIP_ABBREVIATIONS = {
    "URL", "UUID", "LLM", "RAG", "AI", "FTS", "DI", "SPM", "CI", "CD",
    "API", "SDK", "UI", "UX", "OS", "DB", "SQL", "JSON", "XML", "HTTP",
    "HTTPS", "CSS", "HTML", "JS", "TS", "PR", "MR", "MVP", "MVVM",
    "OOP", "FP", "RP", "CRUD", "ACID", "ORM", "DTO", "DAO", "BLL",
    "GRDB", "XCTest", "SwiftUI", "AppKit", "UIKit", "WatchKit",
    "KVO", "KVC", "ARC", "GC", "TDD", "BDD", "DDD", "EDA",
    "REST", "GraphQL", "gRPC", "RPC", "CRDT", "OT",
    "AES", "RSA", "HMAC", "SHA", "MD5", "GCM", "CBC",
    "W3C", "RFC", "ISO", "IEEE", "ACM",
    "TODO", "FIXME", "HACK", "XXX", "NOTE",
    "OK", "KO", "N/A", "TBD",
}

# Apple SDK / Swift 标准库符号白名单（文档常引用但不在本项目 Sources/ 中）
APPLE_SDK_SYMBOLS = {
    # Swift 标准库
    "Sendable", "AsyncStream", "AsyncSequence", "AsyncIterator",
    "Result", "Error", "Codable", "Encodable", "Decodable",
    "Hashable", "Equatable", "Comparable", "Identifiable",
    "Sequence", "Collection", "Array", "Dictionary", "Set",
    "Optional", "Any", "Never", "Void",
    "Publisher", "Subscriber", "Subscription",  # Combine
    # SwiftUI
    "View", "ViewBuilder", "EnvironmentKey", "EnvironmentValues",
    "EnvironmentValue", "PreferenceKey", "ViewModifier",
    "DragGesture", "GeometryReader", "ZStack", "VStack", "HStack",
    "NavigationStack", "NavigationPath", "NavigationLink",
    "List", "ScrollView", "ForEach", "Section", "Group",
    "Spacer", "Divider", "EmptyView", "TupleView",
    "State", "Binding", "ObservedObject", "StateObject",
    "EnvironmentObject", "ObservableObject", "Published",
    "Color", "Font", "Image", "Label", "Text",
    "Button", "Toggle", "Slider", "TextField", "SecureField",
    "Picker", "DatePicker", "Stepper",
    "TabView", "Sheet", "FullScreenCover", "Alert", "ConfirmationDialog",
    "AsyncImage", "TimelineView", "Canvas",
    "ScaledMetric", "DynamicTypeSize",
    "FocusState", "FocusedValue", "FocusedObject",
    "ContainerRelativeShape", "BackgroundProminence",
    "SymbolEffect", "ContentTransition", "Transition", "AnyTransition",
    "withAnimation", "withObservationTracking",
    "App", "Scene", "WindowGroup", "Settings", "DocumentGroup",
    "Commands", "Menu", "ToolbarContent", "ToolbarItem",
    "PlatformTraits", "PlatformModifiers", "PrefersTabNavigationEnvironmentKey",
    # UIKit
    "UITraitCollection", "UITraitBridgedEnvironmentKey", "UIUserInterfaceIdiom",
    "UIViewController", "UIView", "UIColor", "UIImage", "UIFont",
    "UIScreen", "UIWindow", "UIApplication", "UIDevice",
    "UIResponder", "UIEvent", "UIGestureRecognizer",
    "UIBezierPath", "CAShapeLayer", "CALayer",
    "NSAttributedString", "NSAttributedString",
    # Foundation
    "URL", "URLRequest", "URLSession", "URLResponse", "URLSessionTask",
    "Data", "Date", "DateFormatter", "ISO8601DateFormatter",
    "JSONDecoder", "JSONEncoder", "PropertyListDecoder", "PropertyListEncoder",
    "NotificationCenter", "Notification",
    "FileManager", "Bundle", "ProcessInfo", "Process",
    "Thread", "DispatchQueue", "DispatchSemaphore", "DispatchGroup",
    "OperationQueue", "Operation",
    "NSLock", "NSRecursiveLock", "NSCondition", "NSConditionLock",
    "Timer", "RunLoop", "Port",
    "Locale", "TimeZone", "Calendar", "DateComponents",
    "NumberFormatter", "ByteCountFormatter", "Measurement", "Unit",
    "IndexPath", "IndexSet", "NSIndexSet",
    "NSRange", "CGAffineTransform", "CGPoint", "CGRect", "CGSize",
    "UUID", "ObjectIdentifier",
    "Predicate", "Expression",
    "SortDescriptor", "FetchDescriptor",
    "ModelContainer", "ModelContext", "Model",  # SwiftData
    "Attribute", "Macro", "Observable",
    # CoreLocation / MapKit / 其他框架
    "CLLocation", "CLLocationManager", "CLAuthorizationStatus",
    "MKMapView", "MKAnnotation", "MKCoordinateRegion",
    # CoreML / Vision
    "MLModel", "MLFeatureProvider", "VNRequest", "VNImageRequestHandler",
    # Security
    "SecKey", "SecCertificate", "SecIdentity", "SecTrust",
    "SecItem", "SecAccessControl", "SecKeyAlgorithm",
    # Combine
    "PassthroughSubject", "CurrentValueSubject", "AnyPublisher", "AnyCancellable",
    "NotificationCenterPublisher", "TimerPublisher",
    # Concurrency
    "Task", "TaskGroup", "ThrowingTaskGroup",
    "withTaskGroup", "withThrowingTaskGroup",
    "withCheckedContinuation", "withCheckedThrowingContinuation",
    "withUnsafeContinuation", "withUnsafeThrowingContinuation",
    "Actor", "GlobalActor", "MainActor", "Nonisolated",
    "SerialExecutor", "TaskExecutor",
    "JobPriority", "TaskPriority",
    # Macros
    "Observable", "FreestandingMacro", "AttachedMacro",
    "ExpressionMacro", "AccessorMacro", "MemberMacro", "MemberAttributeMacro",
    "PeerMacro", "ExtensionMacro",
    "CodeItem", "SyntaxProtocol", "DeclSyntax", "ExprSyntax",
    # Xcode / Build
    "Makefile", "xcodebuild", "swiftc", "swift",
    "PROJECT_DIR", "SOURCE_DATE_EPOCH", "SKIP_TESTS", "CI_PIPELINE_STATUS",
    "SERVICE_TO_SWIFT", "platform_macros",
    # Testing
    "XCTestCase", "XCTAssert", "XCTAssertEqual", "XCTAssertTrue",
    "XCTAssertFalse", "XCTAssertNil", "XCTAssertNotNil",
    "XCTAssertThrowsError", "XCTAssertNoThrow",
    "XCTMeasure", "XCTMetric", "XCTPerformanceMetric",
    "XCTestObservation", "XCTestObservationCenter",
    # GRDB
    "Database", "DatabaseQueue", "DatabasePool", "DatabaseSnapshot",
    "DatabaseMigrator", "Record", "FetchableRecord", "MutablePersistableRecord",
    "TableRecord", "Column", "SelectionRequest",
    "FTS5", "FTS5TokenizerDescriptor", "FTS5Tokenizer",
    # 项目 SPM 包名（非类型，但文档常引用）
    "ZhiYuDomain", "ZhiYuAICore", "ZhiYuFeatures",
    "UFPCore", "UFPStorage", "UFPDesignSystem",
    # 测试类（可能仅在 Tests/ 目录）
    "ContractBridgeTests", "KnowledgeRepositoryContract",
    # === 扩充白名单（第二轮清理） ===
    # Swift 标准库 / 语言关键字
    "AnyObject", "Any", "Bool", "Int", "Int64", "String", "Double", "Float",
    "Function", "Hash", "Hasher", "Range", "Repository", "Service", "Store",
    "Base", "Core", "Logic", "Manager", "Delegate", "Link", "Pages", "Panel",
    "Sync", "Measure", "Compile", "Imports", "Layouts", "Editors", "Protocols",
    "Observation", "Markdown", "NaturalLanguage", "RealityKit", "WebSocket",
    "Signpost", "SceneStorage", "Localizable", "DynamicType",
    "CheckedContinuation", "Unauthorized", "TERMINATED",
    # Apple SDK 框架/类型
    "AppIntents", "AppNotifications", "AuthenticationServices", "AVAudioRecorder",
    "BGTaskScheduler", "CADisplayLink", "CFAbsoluteTime", "CFBundleShortVersionString",
    "CFBundleVersion", "CLKComplicationDataSource", "CommandGroup",
    "JavaScriptCore", "JSContext", "LAContext", "LocalAuthentication",
    "LocalizedStringResource", "LSApplicationCategoryType",
    "ModelEntity", "NavigationSplitView", "NSColor", "NSFileCoordinator",
    "NSImage", "NSPasteboard", "NSView", "OCRProcessor", "PartialJSON",
    "PlistBuddy", "RealityKit", "SCNTransaction", "SecKeyVerifySignature",
    "SnapshotTesting", "UIBlurEffect", "UIComponents", "UIDocumentPicker",
    "UIImpactFeedbackGenerator", "UIPasteboard", "UndoManager",
    "URLSessionDownloadTask", "UserDefaults", "UserInterfaceSizeClass",
    "WCSession", "WKWebView", "XCTestExpectation", "XCUIApplication",
    "XMLHttpRequest", "ZIPFoundation", "GRDBReexport",
    "SUPPORTS_MACCATALYST", "BUILD_TIMESTAMP", "GIT_SHORT_HASH",
    "WOODPECKER_LABELS",
    # 第三方 SDK
    "ATAuthSDK", "WechatOpenSDK", "PptxGenJS", "SwiftJSONSanitizer",
    # 项目 target / 模块名
    "ZhiYu", "ZhiYuMac", "ZhiYuWatch", "ZhiYuWidgets",
    "ZhiYuTests", "ZhiYuAICoreTests", "ZhiYuFeaturesTests",
    "UFPStorageTests", "UFPDesignSystemTests", "UFPCoreTests", "UFPCoreTestMocks",
    "ZhiYuDomainTestMocks",
    # 项目协议后缀占位符（文档示例用）
    "Adapter", "XxxAdapter", "XxxPlugin", "XxxProtocol", "XxxProvider",
    "AnyXxx", "AnyPageStoreCapabilities", "MockProvider",
    "AppPlatformAdapter", "PlatformCapabilities", "GlassStyle",
    # CI/工具变量（Python/Shell）
    "COMMON_KEYWORDS", "forbidden_rules", "exclude_suffixes", "depends_on",
    "domain_all_entities", "domain_models_entities", "domain_services_entities",
    "file_signatures", "run_parallel_task", "arch_exempt", "inject_exempt",
    "snake_case", "os_unfair_lock", "OSAllocatedUnfairLock", "memset_s",
    "SELECT",
    # 业务常量/枚举（文档引用但分散定义）
    "BusinessConstants", "StorageConstants", "GlobalMigrator",
    "EmbeddingIndexProvider", "EmbeddingSearchProvider",
    "ContextBuilder", "JSONRepairProcessor", "PDFProcessor",
    "PrivacyBlurOverlayView", "PrivacyCoverManager", "PrivacyManager",
    "PrivacySanitizer", "PluginRateLimiter", "PluginWatchdog",
    "HealthCheckService", "WikiEventBus", "WidgetEntry",
    "VoiceNoteService", "VaultSecurityService", "VaultWidgetSyncManager",
    "ActivityLogService", "AppCloudSyncService", "IngestQueueService",
    "LogService", "LogServiceProtocol", "RouterProtocol",
    "BiometricAuthenticator", "ConflictResolution", "ConflictResolverView",
    "KnowledgeBase", "KnowledgeGraphView", "KnowledgePageStore", "KnowledgeStats",
    "PageMetadata", "GraphView", "MarkdownTextView", "AppLottieView",
    "ChatMessage", "ChatViewModel", "OpenAIClient", "VectorStore",
    "SQLiteKnowledgeRepository", "LatencyRepository", "RAGEvaluationRepository",
    "RetrievalMetricsRepository", "TokenUsageRepository",
    "RecursiveChunker", "WatchAIRegistrar",
    # 测试类
    "AuditLoggerTests", "DatabaseIntegrityTests", "GraphCanvasUITests",
    "GraphLayoutEngineTests", "GraphNodeUITests", "OnDeviceLLMServiceTests",
    "RecapTests", "WatchOCRServiceTests",
    # SQL 迁移版本号
    "v1_initial", "v2_fts", "v3_rag_chunks", "v4_unique_title",
    "v5_upgrade_page_chunks", "v6_resource_audit", "v7_enhanced_governance",
    "v8_karpathy_metadata", "v9_distributed_sync",
    # 架构分层目录名 / 概念词（非 Swift 类型）
    "Infrastructure", "Sources", "AITasks",
    # 算法名 / UserDefaults key（非 Swift 类型）
    "SHA256", "daily_recap_yyyyMMdd",
}

# 反引号标识符正则：`PascalCase` 或 `camelCase` 或 `snake_case`
# 必须以反引号包裹，内部为字母/数字/下划线，首字符为字母
IDENTIFIER_PATTERN = re.compile(r'`([A-Za-z][A-Za-z0-9_]*)`')

# 方法调用模式：`methodName()`
METHOD_PATTERN = re.compile(r'`([a-z][A-Za-z0-9_]*)\(\)`')


def collect_code_symbols():
    """收集 Sources/ 和 Tests/ 下所有 Swift 文件中的类型/方法/属性名"""
    symbols = set()

    search_dirs = [SOURCES_DIR]
    if TESTS_DIR.exists():
        search_dirs.append(TESTS_DIR)

    for search_dir in search_dirs:
        for swift_file in search_dir.rglob("*.swift"):
            try:
                content = swift_file.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue

            # 类型声明：class/struct/protocol/enum/actor Name
            for m in re.finditer(
                r'\b(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
                r'(?:final\s+|open\s+)?'
                r'(class|struct|protocol|enum|actor)\s+([A-Z][A-Za-z0-9_]*)',
                content
            ):
                symbols.add(m.group(2))

            # 方法声明：func name(
            for m in re.finditer(
                r'\b(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
                r'(?:static\s+|class\s+)?'
                r'func\s+([a-z][A-Za-z0-9_]*)',
                content
            ):
                symbols.add(m.group(1))

            # 属性声明：var/let name
            for m in re.finditer(
                r'\b(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
                r'(?:static\s+|class\s+)?'
                r'(?:let|var)\s+([a-z][A-Za-z0-9_]*)',
                content
            ):
                symbols.add(m.group(1))

            # case 名称（枚举 case）
            for m in re.finditer(
                r'\bcase\s+([a-z][A-Za-z0-9_]*)',
                content
            ):
                symbols.add(m.group(1))

    return symbols


def is_skippable_reference(ref):
    """判断引用是否应跳过（非 Swift 类型引用）"""
    # 跳过全大写缩写
    if ref.upper() == ref and len(ref) <= MAX_ABBREVIATION_LENGTH:
        return True
    if ref in SKIP_ABBREVIATIONS:
        return True

    # 跳过 Apple SDK / Swift 标准库符号
    if ref in APPLE_SDK_SYMBOLS:
        return True

    # 跳过 snake_case 标识符（SQL 列名/表名/Python 变量，非 Swift 命名规范）
    # 规则：含下划线且无大写字母 = snake_case
    if "_" in ref and ref == ref.lower():
        return True

    return False


def is_camelcase_word(ref, code_symbols):
    """判断 camelCase 引用是否为普通英文单词（非代码符号）"""
    if ref[0].islower() and "_" not in ref:
        if ref not in code_symbols:
            return True
    return False


def scan_doc_file(md_file, code_symbols, drift_issues):
    """扫描单个 Markdown 文件的代码符号引用"""
    refs_in_file = 0
    try:
        content = md_file.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0

    rel_path = md_file.relative_to(PROJECT_DIR)

    for m in IDENTIFIER_PATTERN.finditer(content):
        ref = m.group(1)

        if is_skippable_reference(ref):
            continue

        if is_camelcase_word(ref, code_symbols):
            continue

        refs_in_file += 1

        if ref not in code_symbols:
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
            print(f"     • `{g}` — 代码中未找到此符号")
        print()

    print("=" * REPORT_SEPARATOR_WIDTH)
    print(f"⚠️  共 {total_ghosts} 个幽灵引用，分布于 {len(drift_issues)} 个文档。")
    print("   这些引用可能指向已删除/重命名的类型，建议更新文档。")
    print("   （本检查为 WARNING，不熔断 CI）")
    return 0


def scan_doc_drift():
    """扫描文档漂移"""
    print("📄 [Doc Drift Checker] 开始检测文档与代码漂移...\n")

    if not DOCS_DIR.exists():
        print(f"❌ 文档目录不存在: {DOCS_DIR}")
        return 1

    if not SOURCES_DIR.exists():
        print(f"❌ 源码目录不存在: {SOURCES_DIR}")
        return 1

    # 1. 收集代码符号
    print("🔍 扫描 Sources/ + Tests/ 代码符号...")
    code_symbols = collect_code_symbols()
    print(f"   收集到 {len(code_symbols)} 个代码符号\n")

    # 2. 扫描文档引用
    print("🔍 扫描 Docs/ 文档引用...")
    drift_issues = defaultdict(list)
    total_refs = 0
    total_docs = 0

    for md_file in DOCS_DIR.rglob("*.md"):
        total_docs += 1
        total_refs += scan_doc_file(md_file, code_symbols, drift_issues)

    # 3. 报告
    return print_drift_report(drift_issues, total_refs, total_docs)


if __name__ == "__main__":
    sys.exit(scan_doc_drift())
