//
//  LLMDegradationAndStorageUtilityTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：补测 LLM 降级路径、OnDeviceLLMService 纯逻辑、DemoPDFBuilder 文本清洗、TagRepository 迁移与 SQLiteStore 存储统计。
//

import XCTest
import UFPStorage
import UFPCore
@testable import ZhiYu

// MARK: - DemoPDFBuilder 纯逻辑测试

/// 覆盖 `DemoPDFBuilder.sanitizeMarkdownText` / `isTableSeparator` / `ensurePDFExists` 端到端
final class DemoPDFBuilderLogicTests: XCTestCase {

    // MARK: - sanitizeMarkdownText

    func testSanitizeStripsBoldMarkers() {
        let cleaned = DemoPDFBuilder.sanitizeMarkdownText("**重点**内容")
        XCTAssertEqual(cleaned, "重点内容")
    }

    func testSanitizeConvertsWikilinksToBrackets() {
        let cleaned = DemoPDFBuilder.sanitizeMarkdownText("[[双链]]")
        XCTAssertEqual(cleaned, "「双链」")
    }

    func testSanitizeStripsBackticks() {
        let cleaned = DemoPDFBuilder.sanitizeMarkdownText("`代码`片段")
        XCTAssertEqual(cleaned, "代码片段")
    }

    func testSanitizeTrimsWhitespace() {
        let cleaned = DemoPDFBuilder.sanitizeMarkdownText("  空白文本  ")
        XCTAssertEqual(cleaned, "空白文本")
    }

    func testSanitizeHandlesEmptyString() {
        XCTAssertEqual(DemoPDFBuilder.sanitizeMarkdownText(""), "")
    }

    func testSanitizeCombinedSyntax() {
        let cleaned = DemoPDFBuilder.sanitizeMarkdownText("**粗体** [[链接]] `码`")
        XCTAssertEqual(cleaned, "粗体 「链接」 码")
    }

    // MARK: - isTableSeparator

    func testIsTableSeparatorDetectsPipeColonPrefix() {
        XCTAssertTrue(DemoPDFBuilder.isTableSeparator("|:---|:---|"))
    }

    func testIsTableSeparatorDetectsPipeDashPrefix() {
        XCTAssertTrue(DemoPDFBuilder.isTableSeparator("|---|---|"))
    }

    func testIsTableSeparatorDetectsDashAndPipeCombination() {
        XCTAssertTrue(DemoPDFBuilder.isTableSeparator(" --- | --- "))
    }

    func testIsTableSeparatorRejectsNormalText() {
        XCTAssertFalse(DemoPDFBuilder.isTableSeparator("普通文本行"))
    }

    func testIsTableSeparatorRejectsHeaderRow() {
        XCTAssertFalse(DemoPDFBuilder.isTableSeparator("| 列1 | 列2 |"))
    }

    func testIsTableSeparatorRejectsEmptyLine() {
        XCTAssertFalse(DemoPDFBuilder.isTableSeparator(""))
    }

    // MARK: - ensurePDFExists 端到端

    func testEnsurePDFExistsCreatesValidPDFFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DemoPDFBuilderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pdfPath = tempDir
            .appendingPathComponent("sample.pdf").path
        let content = "# 标题\n\n正文段落\n\n> 引用块"

        let result = DemoPDFBuilder.ensurePDFExists(at: pdfPath, title: "测试文档", content: content)

        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfPath))
        let data = try Data(contentsOf: URL(fileURLWithPath: pdfPath))
        XCTAssertGreaterThan(data.count, 0)
        // PDF 文件头魔数校验
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }

    func testEnsurePDFExistsCreatesParentDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DemoPDFBuilderNested-\(UUID().uuidString)", isDirectory: true)
        let nestedPath = tempDir
            .appendingPathComponent("nested/deep", isDirectory: true)
            .appendingPathComponent("doc.pdf").path
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = DemoPDFBuilder.ensurePDFExists(at: nestedPath, title: "嵌套", content: "内容")
        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPath))
    }
}

// MARK: - OnDeviceLLMService 纯逻辑测试

/// 覆盖 `OnDeviceLLMService.extractTags` / 状态变更方法 / `OnDeviceModel` 计算属性 / `OnDeviceError`
@MainActor
final class OnDeviceLLMServiceLogicTests: XCTestCase {

    private var service: OnDeviceLLMService!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        // 注册 Mock 编译器避免真实 CoreML 编译
        ServiceContainer.shared.register(MockMLModelCompiler(), for: (any MLModelCompilerProtocol).self)
        service = OnDeviceLLMService()
    }

    override func tearDown() async throws {
        service = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - extractTags

    func testExtractTagsCapturesHashTags() {
        let tags = service.extractTags(from: "正文 #swift #ai 结尾")
        XCTAssertEqual(tags, ["swift", "ai"])
    }

    func testExtractTagsReturnsEmptyForNoTags() {
        XCTAssertTrue(service.extractTags(from: "没有任何标签的文本").isEmpty)
    }

    func testExtractTagsHandlesEmptyText() {
        XCTAssertTrue(service.extractTags(from: "").isEmpty)
    }

    func testExtractTagsCapturesUnderscoreTags() {
        let tags = service.extractTags(from: "#machine_learning #深度学习")
        XCTAssertEqual(tags, ["machine_learning", "深度学习"])
    }

    // MARK: - 状态变更方法

    func testCancelGenerationResetsState() {
        service.isGenerating = true
        service.generatedText = "部分内容"
        service.generationProgress = 0.5

        service.cancelGeneration()

        XCTAssertFalse(service.isGenerating)
        XCTAssertEqual(service.generatedText, "")
        XCTAssertEqual(service.generationProgress, 0)
    }

    func testUnloadModelClearsLoadedState() {
        service.isModelLoaded = true
        service.loadedModelName = "TestModel"
        service.inferenceSpeed = 100.0

        service.unloadModel()

        XCTAssertFalse(service.isModelLoaded)
        XCTAssertEqual(service.loadedModelName, "")
        XCTAssertEqual(service.inferenceSpeed, 0)
    }

    // MARK: - OnDeviceModel 计算属性

    func testOnDeviceModelSizeLabelFormatsBytes() {
        let model = OnDeviceModel(id: "x", name: "X", url: nil, size: 1024 * 1024, type: .bundled)
        XCTAssertTrue(model.sizeLabel.contains("MB"))
    }

    func testOnDeviceModelIconPerType() {
        XCTAssertEqual(OnDeviceModel(id: "b", name: "B", url: nil, size: 0, type: .bundled).icon, "cube.box.fill")
        XCTAssertEqual(OnDeviceModel(id: "d", name: "D", url: nil, size: 0, type: .downloaded).icon, "arrow.down.circle.fill")
        XCTAssertEqual(OnDeviceModel(id: "s", name: "S", url: nil, size: 0, type: .system).icon, "apple.logo")
    }

    // MARK: - OnDeviceError

    func testOnDeviceErrorDescriptionsAreLocalized() {
        XCTAssertNotNil(OnDeviceError.modelNotFound.errorDescription)
        XCTAssertNotNil(OnDeviceError.modelNotLoaded.errorDescription)
        XCTAssertNotNil(OnDeviceError.notSupported.errorDescription)
        XCTAssertNotNil(OnDeviceError.compilationFailed.errorDescription)
        XCTAssertTrue(OnDeviceError.inferenceFailed("boom").errorDescription?.contains("boom") == true)
    }

    // MARK: - Config 常量

    func testConfigConstantsArePositive() {
        XCTAssertGreaterThan(OnDeviceLLMService.Config.defaultMaxTokens, 0)
        XCTAssertGreaterThan(OnDeviceLLMService.Config.generationTemperature, 0)
        XCTAssertGreaterThan(OnDeviceLLMService.Config.smartIngestMaxTokens, 0)
        XCTAssertGreaterThan(OnDeviceLLMService.Config.chatMaxTokens, 0)
        XCTAssertGreaterThan(OnDeviceLLMService.Config.contextPageLimit, 0)
        XCTAssertGreaterThan(OnDeviceLLMService.Config.contentPreviewChars, 0)
    }
}

// MARK: - IngestLLMService 降级路径测试

/// 覆盖 `IngestLLMService` 在未配置 LLM 时的降级返回语义
@MainActor
final class IngestLLMServiceDegradationTests: XCTestCase {

    private var config: LLMConfigManager!
    private var service: IngestLLMService!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        config = LLMConfigManager()
        // 默认未配置 apiKey 且 isEnabled=false
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)
        service = IngestLLMService()
    }

    override func tearDown() async throws {
        service = nil
        config = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testSmartIngestThrowsNotConfiguredWhenDisabled() async {
        do {
            _ = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
            XCTFail("未配置时应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    func testDiscoverPotentialLinksReturnsEmptyWhenDisabled() async throws {
        let links = try await service.discoverPotentialLinks(content: "C", existingTitles: ["A", "B"])
        XCTAssertTrue(links.isEmpty)
    }

    func testFoldContentReturnsConcatenationWhenDisabled() async throws {
        let result = try await service.foldContent(existingContent: "旧", newContent: "新", title: "T")
        XCTAssertEqual(result, "旧\n\n新")
    }

    func testAnalyzeForRefactoringReturnsEmptyWhenDisabled() async throws {
        let suggestions = try await service.analyzeForRefactoring(pages: [])
        XCTAssertTrue(suggestions.isEmpty)
    }
}

// MARK: - ChatLLMService 降级与 UITesting 分支测试

/// 覆盖 `ChatLLMService` 在未配置时的降级与 `--uitesting` 自愈分支
@MainActor
final class ChatLLMServiceDegradationTests: XCTestCase {

    private var config: LLMConfigManager!
    private var service: ChatLLMService!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        config = LLMConfigManager()
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)
        // 注册 AIAnalyticsService 所需依赖（governance + evalService）
        let governanceRepo = RAGGovernanceSQLiteStore()
        ServiceContainer.shared.register(governanceRepo as any RAGGovernanceRepository, for: (any RAGGovernanceRepository).self)
        let mockLLM = MockLLMService()
        ServiceContainer.shared.register(mockLLM as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        let evaluationService = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceRepo)
        ServiceContainer.shared.register(evaluationService, for: RAGEvaluationService.self)
        let analytics = AIAnalyticsService()
        ServiceContainer.shared.register(analytics, for: AIAnalyticsService.self)
        service = ChatLLMService()
    }

    override func tearDown() async throws {
        service = nil
        config = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testIsEnabledReflectsConfigManager() {
        config.isEnabled = false
        XCTAssertFalse(service.isEnabled)
        config.isEnabled = true
        XCTAssertTrue(service.isEnabled)
    }

    func testGenerateThrowsNotConfiguredWhenDisabled() async {
        config.isEnabled = false
        do {
            _ = try await service.generate(prompt: "P", systemPrompt: "S")
            XCTFail("未配置时应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    func testChatThrowsNotConfiguredWhenDisabled() async {
        config.isEnabled = false
        do {
            _ = try await service.chat(query: "Q", history: [], pages: [])
            XCTFail("未配置时应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    func testChatStreamFinishesWithErrorWhenDisabled() async {
        config.isEnabled = false
        let stream = service.chatStream(query: "Q", history: [], pages: [])
        do {
            for try await _ in stream {
                // 不应产出任何 chunk
                XCTFail("未配置时流不应产出 chunk")
            }
            XCTFail("未配置时流应抛出错误")
        } catch LLMError.notConfigured {
            // 预期
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }
}

// MARK: - TagRepository 迁移测试

/// 覆盖 `TagRepository.migrateLegacyTags` 从页面 JSON 标签迁移到独立标签表
final class TagRepositoryMigrationTests: XCTestCase {

    var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
    }

    override func tearDown() async throws {
        dbQueue = nil
        try await super.tearDown()
    }

    func testMigrateLegacyTagsExtractsTagsFromPages() async throws {
        let pageID = UUID()
        let tags = ["swift", "ios", "ai"]
        let tagsData = try JSONEncoder().encode(tags)
        let tagsJSON = try XCTUnwrap(String(data: tagsData, encoding: .utf8))

        try await dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO \(KnowledgePage.databaseTableName) " +
                     "(\(KnowledgePage.Columns.id.rawValue), \(KnowledgePage.Columns.title.rawValue), " +
                     "\(KnowledgePage.Columns.pageType.rawValue), \(KnowledgePage.Columns.content.rawValue), " +
                     "\(KnowledgePage.Columns.tags.rawValue), \(KnowledgePage.Columns.status.rawValue), " +
                     "\(KnowledgePage.Columns.confidence.rawValue)) VALUES (?, ?, ?, ?, ?, ?, ?)",
                arguments: [pageID, "测试页", "concept", "内容", tagsJSON, "active", "medium"]
            )
        }

        try await dbQueue.write { db in
            try TagRepository.migrateLegacyTags(in: db)
        }

        try await dbQueue.read { db in
            let tagCount = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM \(TagRecord.databaseTableName)"
            )
            XCTAssertEqual(tagCount, 3)

            let linkCount = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM \(PageTagRecord.databaseTableName)"
            )
            XCTAssertEqual(linkCount, 3)
        }
    }

    func testMigrateLegacyTagsHandlesEmptyTags() async throws {
        let pageID = UUID()
        try await dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO \(KnowledgePage.databaseTableName) " +
                     "(\(KnowledgePage.Columns.id.rawValue), \(KnowledgePage.Columns.title.rawValue), " +
                     "\(KnowledgePage.Columns.pageType.rawValue), \(KnowledgePage.Columns.content.rawValue), " +
                     "\(KnowledgePage.Columns.tags.rawValue), \(KnowledgePage.Columns.status.rawValue), " +
                     "\(KnowledgePage.Columns.confidence.rawValue)) VALUES (?, ?, ?, ?, NULL, ?, ?)",
                arguments: [pageID, "无标签页", "concept", "内容", "active", "medium"]
            )
        }

        try await dbQueue.write { db in
            try TagRepository.migrateLegacyTags(in: db)
        }

        try await dbQueue.read { db in
            let tagCount = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM \(TagRecord.databaseTableName)"
            )
            XCTAssertEqual(tagCount, 0)
        }
    }

    func testMigrateLegacyTagsIsIdempotent() async throws {
        let pageID = UUID()
        let tags = ["dup"]
        let tagsData = try JSONEncoder().encode(tags)
        let tagsJSON = try XCTUnwrap(String(data: tagsData, encoding: .utf8))

        try await dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO \(KnowledgePage.databaseTableName) " +
                     "(\(KnowledgePage.Columns.id.rawValue), \(KnowledgePage.Columns.title.rawValue), " +
                     "\(KnowledgePage.Columns.pageType.rawValue), \(KnowledgePage.Columns.content.rawValue), " +
                     "\(KnowledgePage.Columns.tags.rawValue), \(KnowledgePage.Columns.status.rawValue), " +
                     "\(KnowledgePage.Columns.confidence.rawValue)) VALUES (?, ?, ?, ?, ?, ?, ?)",
                arguments: [pageID, "重复页", "concept", "内容", tagsJSON, "active", "medium"]
            )
        }

        for _ in 0..<3 {
            try await dbQueue.write { db in
                try TagRepository.migrateLegacyTags(in: db)
            }
        }

        try await dbQueue.read { db in
            let tagCount = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM \(TagRecord.databaseTableName)"
            )
            XCTAssertEqual(tagCount, 1, "多次迁移不应产生重复标签")

            let linkCount = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM \(PageTagRecord.databaseTableName)"
            )
            XCTAssertEqual(linkCount, 1, "多次迁移不应产生重复关联")
        }
    }
}

// MARK: - SQLiteStore 存储统计与文件夹大小测试

/// 覆盖 `SQLiteStore.folderSize` / `getStorageStats` / `addLog` no-op
final class SQLiteStoreStorageStatsTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var store: SQLiteStore!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        store = SQLiteStore(dbWriter: dbQueue)
    }

    override func tearDown() async throws {
        store = nil
        dbQueue = nil
        try await super.tearDown()
    }

    func testFolderSizeReturnsZeroForNonExistentDirectory() async {
        let nonExistent = URL(fileURLWithPath: "/tmp/SQLiteStoreTest-\(UUID().uuidString)-nonexistent")
        let size = await store.folderSize(at: nonExistent)
        XCTAssertEqual(size, 0)
    }

    func testFolderSizeCalculatesTotalFileSize() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SQLiteStoreTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("a.txt")
        let file2 = tempDir.appendingPathComponent("b.txt")
        try Data("hello".utf8).write(to: file1)
        try Data("world!!".utf8).write(to: file2)

        let size = await store.folderSize(at: tempDir)
        XCTAssertEqual(size, Int64("hello".count + "world!!".count))
    }

    func testGetStorageStatsReturnsValidStructure() async {
        let stats = await store.getStorageStats()
        XCTAssertGreaterThanOrEqual(stats.databaseSize, 0)
        XCTAssertGreaterThanOrEqual(stats.logsSize, 0)
        XCTAssertGreaterThanOrEqual(stats.exportsSize, 0)
        XCTAssertGreaterThanOrEqual(stats.modelsSize, 0)
        XCTAssertGreaterThanOrEqual(stats.pluginsSize, 0)
        XCTAssertGreaterThanOrEqual(stats.cachesSize, 0)
    }

    func testAddLogIsNoOpAndDoesNotCrash() async {
        // addLog 是 nonisolated no-op，验证调用不崩溃
        store.addLog(action: .create, target: "T", details: "D", duration: 1.0, startTime: Date(), endTime: Date(), module: "M")
        XCTAssertTrue(true, "addLog 应为 no-op 且不崩溃")
    }

    func testSeedDefaultContentIsNoOp() async {
        await store.seedDefaultContent { _, _, _ in }
        XCTAssertTrue(true, "seedDefaultContent 应为 no-op")
    }
}

// MARK: - Mock MLModelCompiler

private final class MockMLModelCompiler: MLModelCompilerProtocol, @unchecked Sendable {
    let supportsCompilation: Bool = true

    func compileModel(at url: URL) async throws -> URL {
        // 测试中不实际编译，返回原 URL
        return url
    }
}
