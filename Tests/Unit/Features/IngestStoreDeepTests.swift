//
//  IngestStoreDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L3] 表现层测试
//  核心职责：IngestStore 深度补盲测试 — 覆盖 recognizeText / finalizeSmartIngest /
//            performIngest（标准流程 + smart 流程 + 错误路径）等未覆盖方法。
//

import XCTest
import UFPCore
import Dependencies
#if canImport(UIKit)
import UIKit
#endif
@testable import ZhiYu

// MARK: - 测试专用 Mock OCR 服务

/// 可注入 stub 的 OCR 服务 Mock，用于验证 IngestStore.recognizeText 转发逻辑
final class StubOCRService: OCRServiceProtocol, @unchecked Sendable {
    /// recognizeText 返回的固定文本
    var stubRecognizedText: String = ""
    /// recognizeText 抛出的错误（优先于 stubRecognizedText）
    var stubError: Error?
    /// 记录最后一次传入的图像引用（验证转发参数）
    private(set) var lastReceivedImage: AppImage?

    func recognizeText(from image: AppImage) async throws -> String {
        lastReceivedImage = image
        if let error = stubError { throw error }
        return stubRecognizedText
    }
}

// MARK: - 测试专用：可配置 smartIngest 返回值的 LLM 服务

/// 可注入 stubSmartIngestResult 的 LLM 服务，用于测试 performIngest smart 流程
@MainActor
final class StubSmartIngestLLMService: LLMService, @unchecked Sendable {
    /// smartIngest 返回的 stub 结果
    var stubSmartIngestResult: SmartIngestResultDTO = SmartIngestResultDTO(
        title: nil, compiledContent: "", suggestedTags: [],
        suggestedType: "", relatedTitles: [], summary: ""
    )
    /// smartIngest 抛出的错误（优先于 stubSmartIngestResult）
    var stubSmartIngestError: Error?

    override var isEnabled: Bool { get { _isEnabled } set { _isEnabled = newValue } }
    private var _isEnabled = true

    override func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        if let error = stubSmartIngestError { throw error }
        return stubSmartIngestResult
    }

    override func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: "")
    }

    override func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    override func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        ""
    }

    override func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] { [] }
    override func foldContent(existingContent: String, newContent: String, title: String) async throws -> String { "" }
    override func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] { [] }
    override func rewriteQuery(_ query: String) async -> String { query }
    override func expandQuery(_ query: String) async -> [String] { [query] }
    override func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] { candidates }
    override func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] { chunks }
    override func generateHypotheticalDocument(query: String) async -> String { query }
}

// MARK: - IngestStore 深度测试

@MainActor
final class IngestStoreDeepTests: XCTestCase {

    private var store: IngestStore!
    private var mockPDF: MockPDFService!
    private var stubOCR: StubOCRService!
    private var stubLLM: StubSmartIngestLLMService!
    private var pageStore: (any AnyPageStoreCapabilities)!

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()

        // 取出已注册的 Mock 实例用于注入 stub
        mockPDF = ServiceContainer.shared.resolve((any PDFServiceProtocol).self) as? MockPDFService
        pageStore = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)

        // 替换 OCR 服务为可注入 stub 的实现，验证 recognizeText 转发
        stubOCR = StubOCRService()
        ServiceContainer.shared.register(stubOCR as any OCRServiceProtocol, for: (any OCRServiceProtocol).self)

        // 替换 LLM 服务为可配置 smartIngest 的 stub 实现
        stubLLM = StubSmartIngestLLMService()
        ServiceContainer.shared.register(stubLLM as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        ServiceContainer.shared.register(stubLLM as LLMService, for: LLMService.self)

        // 重新构造 IngestStore 以解析最新的 OCR / LLM stub
        store = IngestStore()
    }

    override func tearDown() async throws {
        store = nil
        mockPDF = nil
        stubOCR = nil
        stubLLM = nil
        pageStore = nil
        resetPersistentTestState()
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - recognizeText 转发逻辑

    /// 验证 recognizeText 将 OCR 服务的返回值原样转发
    func testRecognizeTextForwardsStubText() async throws {
        stubOCR.stubRecognizedText = "识别到的文本内容"

        #if canImport(UIKit)
        let image = UIImage()
        #else
        let image = AppImage()
        #endif
        let result = try await store.recognizeText(from: image)

        XCTAssertEqual(result, "识别到的文本内容", "应原样转发 OCR 服务的返回值")
    }

    /// 验证 recognizeText 将 OCR 服务的错误原样抛出
    func testRecognizeTextForwardsError() async {
        struct StubOCRFailure: Error, LocalizedError {
            var errorDescription: String? { "OCR 引擎不可用" }
        }
        stubOCR.stubError = StubOCRFailure()

        #if canImport(UIKit)
        let image = UIImage()
        #else
        let image = AppImage()
        #endif

        do {
            _ = try await store.recognizeText(from: image)
            XCTFail("应抛出 OCR 服务的错误")
        } catch let error as StubOCRFailure {
            XCTAssertEqual(error.errorDescription, "OCR 引擎不可用", "应原样转发错误描述")
        } catch {
            XCTFail("应抛出 StubOCRFailure 类型错误，实际：\(error)")
        }
    }

    /// 验证 recognizeText 空字符串返回值被正确转发
    func testRecognizeTextForwardsEmptyString() async throws {
        stubOCR.stubRecognizedText = ""

        #if canImport(UIKit)
        let image = UIImage()
        #else
        let image = AppImage()
        #endif
        let result = try await store.recognizeText(from: image)

        XCTAssertEqual(result, "", "空字符串返回值应被原样转发")
    }

    // MARK: - finalizeSmartIngest

    /// 验证 finalizeSmartIngest 创建页面并应用 suggestedType / tags / customIcon
    func testFinalizeSmartIngestCreatesPageWithSuggestedType() async {
        let result = SmartIngestResultDTO(
            title: "智能摄入标题",
            compiledContent: "编译后的内容",
            suggestedTags: ["AI", "知识管理"],
            suggestedType: "entity",
            relatedTitles: [],
            summary: "摘要"
        )

        let page = await store.finalizeSmartIngest(title: "智能摄入标题", result: result, customIcon: "star.fill")

        XCTAssertEqual(page.title, "智能摄入标题")
        XCTAssertEqual(page.content, "编译后的内容")
        XCTAssertEqual(page.pageType, .entity, "suggestedType='entity' 应映射为 PageType.entity")
        XCTAssertEqual(page.tags, ["AI", "知识管理"])
        XCTAssertEqual(page.customIcon, "star.fill")
        XCTAssertTrue(page.relatedPageIDs.isEmpty, "无 relatedTitles 时关联列表应为空")
    }

    /// 验证 finalizeSmartIngest 当 suggestedType 无效时回退为 .concept
    func testFinalizeSmartIngestFallsBackToConceptForInvalidType() async {
        let result = SmartIngestResultDTO(
            title: "无效类型",
            compiledContent: "内容",
            suggestedTags: [],
            suggestedType: "invalid_type_value",
            relatedTitles: [],
            summary: ""
        )

        let page = await store.finalizeSmartIngest(title: "无效类型", result: result, customIcon: nil)

        XCTAssertEqual(page.pageType, .concept, "无效 suggestedType 应回退为 .concept")
        XCTAssertNil(page.customIcon)
    }

    /// 验证 finalizeSmartIngest 当 suggestedType 为空字符串时回退为 .concept
    func testFinalizeSmartIngestFallsBackToConceptForEmptyType() async {
        let result = SmartIngestResultDTO(
            title: "空类型",
            compiledContent: "内容",
            suggestedTags: [],
            suggestedType: "",
            relatedTitles: [],
            summary: ""
        )

        let page = await store.finalizeSmartIngest(title: "空类型", result: result, customIcon: nil)

        XCTAssertEqual(page.pageType, .concept, "空 suggestedType 应回退为 .concept")
    }

    /// 验证 finalizeSmartIngest 自动建立与已有页面的关联
    func testFinalizeSmartIngestBuildsRelationsToExistingPages() async {
        // 预置两个已有页面，标题匹配 relatedTitles
        let existingPage1 = await pageStore.anyCreatePage(
            title: "已有概念A",
            pageType: .concept,
            customIcon: nil,
            content: "概念A内容",
            tags: [],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )
        let existingPage2 = await pageStore.anyCreatePage(
            title: "已有概念B",
            pageType: .concept,
            customIcon: nil,
            content: "概念B内容",
            tags: [],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )
        // 预置一个不匹配的页面
        _ = await pageStore.anyCreatePage(
            title: "不相关页面",
            pageType: .concept,
            customIcon: nil,
            content: "不相关",
            tags: [],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )

        let result = SmartIngestResultDTO(
            title: "新页面",
            compiledContent: "新内容",
            suggestedTags: [],
            suggestedType: "concept",
            relatedTitles: ["已有概念A", "已有概念B", "不存在的标题"],
            summary: ""
        )

        let page = await store.finalizeSmartIngest(title: "新页面", result: result, customIcon: nil)

        guard let page1 = existingPage1, let page2 = existingPage2 else {
            XCTFail("预置页面创建失败")
            return
        }
        XCTAssertEqual(Set(page.relatedPageIDs), Set([page1.id, page2.id]),
                       "应仅关联标题匹配的已有页面，忽略不存在的标题")
    }

    /// 验证 finalizeSmartIngest 当 relatedTitles 全部不匹配时关联列表为空
    func testFinalizeSmartIngestEmptyRelationsWhenNoTitleMatch() async {
        let result = SmartIngestResultDTO(
            title: "孤立页面",
            compiledContent: "内容",
            suggestedTags: [],
            suggestedType: "concept",
            relatedTitles: ["不存在的标题1", "不存在的标题2"],
            summary: ""
        )

        let page = await store.finalizeSmartIngest(title: "孤立页面", result: result, customIcon: nil)

        XCTAssertTrue(page.relatedPageIDs.isEmpty, "relatedTitles 全部不匹配时关联列表应为空")
    }

    /// 验证 finalizeSmartIngest 持久化页面到 pageStore
    func testFinalizeSmartIngestPersistsPageToStore() async {
        let result = SmartIngestResultDTO(
            title: "持久化测试",
            compiledContent: "待持久化内容",
            suggestedTags: ["persist"],
            suggestedType: "source",
            relatedTitles: [],
            summary: ""
        )

        let page = await store.finalizeSmartIngest(title: "持久化测试", result: result, customIcon: "doc.fill")

        // reloadFromDisk 后应能从 pageStore.pages 中找到新页面
        let allPages = await pageStore.pages
        XCTAssertTrue(allPages.contains(where: { $0.id == page.id }), "页面应被持久化到 pageStore")
    }

    // MARK: - performIngest 标准流程（非 smart）

    /// 验证 performIngest 标准流程创建页面 — 修复 Bug：返回 updatedPage 而非原始 page
    /// ✅ 修复 #1: performIngest 标准流程现在返回 updatedPage（tags/customIcon 已应用）
    func testPerformIngestStandardFlowCreatesPageWithTags() async throws {
        let page = try await store.performIngest(
            title: "标准导入标题",
            content: "标准导入内容",
            type: .source,
            tags: ["标准", "导入"],
            customIcon: "tray",
            useSmart: false,
            useDeepScan: false
        )

        XCTAssertEqual(page.title, "标准导入标题")
        // ✅ 修复: 传入 tags=["标准","导入"] 现在正确应用
        XCTAssertEqual(page.tags, ["标准", "导入"], "performIngest 标准流程应返回带传入 tags 的 updatedPage")
        // ✅ 修复: 传入 customIcon="tray" 现在正确应用
        XCTAssertEqual(page.customIcon, "tray", "performIngest 标准流程应返回带传入 customIcon 的 updatedPage")
    }

    /// 验证 performIngest 标准流程完成后 taskCenter 任务状态为 completed
    func testPerformIngestStandardFlowCompletesTask() async throws {
        @Dependency(\.taskCenter) var taskCenter: TaskCenter

        _ = try await store.performIngest(
            title: "任务完成测试",
            content: "内容",
            type: .source,
            tags: [],
            customIcon: nil,
            useSmart: false,
            useDeepScan: false
        )

        let ingestTasks = taskCenter.tasks.filter { $0.type == .ingest }
        XCTAssertTrue(ingestTasks.contains { task in
            if case .completed = task.status { return true }
            return false
        }, "标准流程完成后应存在 status=.completed 的 ingest 任务")
    }

    /// 验证 performIngest 传入 fileSize 和 sourceType 被透传到页面
    func testPerformIngestPassesFileSizeAndSourceType() async throws {
        let page = try await store.performIngest(
            title: "元数据透传",
            content: "带元数据的内容",
            type: .source,
            tags: [],
            customIcon: nil,
            useSmart: false,
            useDeepScan: false,
            fileSize: 1024,
            sourceType: "pdf"
        )

        XCTAssertEqual(page.fileSize, 1024, "fileSize 应被透传到页面")
        XCTAssertEqual(page.sourceType, "pdf", "sourceType 应被透传到页面")
    }

    // MARK: - performIngest smart 流程

    /// 验证 performIngest smart 流程（useSmart=true 且 llmService.isEnabled=true）
    func testPerformIngestSmartFlowCreatesPageWithSmartResult() async throws {
        stubLLM.isEnabled = true
        stubLLM.stubSmartIngestResult = SmartIngestResultDTO(
            title: "智能标题",
            compiledContent: "智能编译内容",
            suggestedTags: ["智能", "AI"],
            suggestedType: "entity",
            relatedTitles: [],
            summary: "智能摘要"
        )

        let page = try await store.performIngest(
            title: "智能标题",
            content: "原始内容",
            type: .source,
            tags: ["传入标签"],
            customIcon: "sparkles",
            useSmart: true,
            useDeepScan: false
        )

        XCTAssertEqual(page.title, "智能标题")
        XCTAssertEqual(page.content, "智能编译内容", "smart 流程应使用 smartIngest 返回的 compiledContent")
        XCTAssertEqual(page.pageType, .entity, "smart 流程应使用 smartIngest 返回的 suggestedType")
        XCTAssertEqual(page.tags, ["智能", "AI"], "smart 流程应使用 smartIngest 返回的 suggestedTags（非传入 tags）")
        XCTAssertEqual(page.customIcon, "sparkles")
    }

    /// 验证 performIngest 当 useSmart=true 但 llmService.isEnabled=false 时降级为标准流程
    /// ✅ 修复 #1（同上）：降级为标准流程后返回 updatedPage，传入 tags/customIcon 已应用
    func testPerformIngestDegradesToStandardWhenLLMDisabled() async throws {
        stubLLM.isEnabled = false

        let page = try await store.performIngest(
            title: "降级测试",
            content: "降级内容",
            type: .source,
            tags: ["降级标签"],
            customIcon: "tray",
            useSmart: true,
            useDeepScan: false
        )

        XCTAssertEqual(page.title, "降级测试")
        // ✅ 修复: 降级为标准流程后传入 tags=["降级标签"] 现在正确应用
        XCTAssertEqual(page.tags, ["降级标签"], "performIngest 降级流程应返回带传入 tags 的 updatedPage")
        // ✅ 修复: 降级为标准流程后传入 customIcon="tray" 现在正确应用
        XCTAssertEqual(page.customIcon, "tray", "performIngest 降级流程应返回带传入 customIcon 的 updatedPage")
    }

    /// 验证 performIngest smart 流程完成后 taskCenter 任务状态为 completed
    func testPerformIngestSmartFlowCompletesTask() async throws {
        @Dependency(\.taskCenter) var taskCenter: TaskCenter

        stubLLM.isEnabled = true
        stubLLM.stubSmartIngestResult = SmartIngestResultDTO(
            title: "智能任务",
            compiledContent: "内容",
            suggestedTags: [],
            suggestedType: "concept",
            relatedTitles: [],
            summary: ""
        )

        _ = try await store.performIngest(
            title: "智能任务",
            content: "原始",
            type: .source,
            tags: [],
            customIcon: nil,
            useSmart: true,
            useDeepScan: false
        )

        let ingestTasks = taskCenter.tasks.filter { $0.type == .ingest }
        XCTAssertTrue(ingestTasks.contains { task in
            if case .completed = task.status { return true }
            return false
        }, "smart 流程完成后应存在 status=.completed 的 ingest 任务")
    }

    // MARK: - performIngest 错误路径

    /// 验证 performIngest 当 smartIngest 抛错时 taskCenter 任务状态为 failed
    func testPerformIngestSmartFlowMarksTaskFailedOnLLMError() async {
        @Dependency(\.taskCenter) var taskCenter: TaskCenter

        stubLLM.isEnabled = true
        struct SmartIngestFailure: Error, LocalizedError {
            var errorDescription: String? { "智能摄入服务不可用" }
        }
        stubLLM.stubSmartIngestError = SmartIngestFailure()

        do {
            _ = try await store.performIngest(
                title: "错误路径",
                content: "内容",
                type: .source,
                tags: [],
                customIcon: nil,
                useSmart: true,
                useDeepScan: false
            )
            XCTFail("smart 流程应抛出 LLM 错误")
        } catch {
            // 预期抛出 SmartIngestFailure
        }

        let ingestTasks = taskCenter.tasks.filter { $0.type == .ingest }
        XCTAssertTrue(ingestTasks.contains { task in
            if case .failed = task.status { return true }
            return false
        }, "smart 流程 LLM 抛错时 ingest 任务应标记为 failed")
    }

    /// 验证 performIngest 标准流程当 ingestRawContent 抛错时 taskCenter 任务状态为 failed
    /// 通过 TransactionGatekeeper.drain() 触发 DatabaseError.draining：
    /// 先 acquire 一个事务保持 activeCount > 0，再 drain() 保持 draining=true，
    /// 此时 performIngest 内部的 incrementActiveTransactions 会抛 draining 错误
    func testPerformIngestStandardFlowMarksTaskFailedOnIngestError() async {
        @Dependency(\.taskCenter) var taskCenter: TaskCenter

        // 1. 先 acquire 一个事务，保持 activeCount > 0，使 drain() 不会立即返回
        try? await DatabaseManager.shared.transactionGatekeeper.acquire()

        // 2. 异步触发 drain()，由于 activeCount > 0，draining=true 会被保持
        let drainTask = Task { await DatabaseManager.shared.transactionGatekeeper.drain(maxWaitTime: .seconds(2)) }
        // 等待 drain() 设置 draining=true
        try? await Task.sleep(nanoseconds: 100_000_000)

        do {
            _ = try await store.performIngest(
                title: "排空错误",
                content: "内容",
                type: .source,
                tags: [],
                customIcon: nil,
                useSmart: false,
                useDeepScan: false
            )
            XCTFail("数据库排空期间应抛出 draining 错误")
        } catch {
            // 预期抛出 DatabaseError.draining
        }

        // 3. 释放持有的事务，让 drain() 完成
        await DatabaseManager.shared.transactionGatekeeper.release()
        _ = await drainTask.value

        let ingestTasks = taskCenter.tasks.filter { $0.type == .ingest }
        XCTAssertTrue(ingestTasks.contains { task in
            if case .failed = task.status { return true }
            return false
        }, "标准流程 ingestRawContent 抛错时 ingest 任务应标记为 failed")
    }

    // MARK: - performIngest useDeepScan 透传

    /// 验证 performIngest useDeepScan=true 透传到 ingestRawContent
    func testPerformIngestPassesDeepScanFlag() async throws {
        // useDeepScan=true 会触发 prepareContent 中的 RAG pipeline 路径
        // 在 mock 环境下 pipeline 可能降级，但不应崩溃
        let page = try await store.performIngest(
            title: "深度扫描",
            content: "深度扫描内容",
            type: .source,
            tags: [],
            customIcon: nil,
            useSmart: false,
            useDeepScan: true
        )

        XCTAssertEqual(page.title, "深度扫描")
        XCTAssertFalse(page.content.isEmpty, "深度扫描后页面内容不应为空")
    }
}
