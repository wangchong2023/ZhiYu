//
//  DomainBranchCoverageTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/26.
//  系统层级：[Shared] 测试层
//  核心职责：Domain 层未覆盖分支补齐——LinkService/PromptTemplateEngine/FeatureGateManager/AIContentEnricher 边界与异常路径。
//

import XCTest
import CryptoKit
import UFPCore
@testable import ZhiYu

// MARK: - 测试专用 EmbeddingProvider Mock

/// 可编程语义搜索结果 Mock，用于测试 LinkService.filterSemanticResults 各分支
private final class ProgrammableEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    var searchResults: [(id: UUID, score: Float)] = []
    func getAllEmbeddings() async -> [UUID: [Float]] { [:] }
    func syncEmbeddings(pages: [KnowledgePage]) async {}
    func updateEmbedding(for page: KnowledgePage) async {}
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async {}
    func vectorizeChunks(chunks: [String]) async -> [[Float]] { [] }
    func search(query: String, topK: Int) async -> [(id: UUID, score: Float)] { searchResults }
    func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)] { [] }
    func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] { [] }
    func loadInitialCache() async {}
    func clearCacheAndReload() async {}
}

// MARK: - LinkService 边界分支测试

@MainActor
final class DomainLinkServiceBranchTests: XCTestCase {
    var sut: LinkService!

    override func setUp() async throws {
        try await super.setUp()
        sut = LinkService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: pageByTitle 未匹配返回 nil

    func testPageByTitle_未匹配返回nil() async {
        let pages = [KnowledgePage(title: "Swift", content: "")]
        let result = await sut.pageByTitle("不存在的标题", in: pages)
        XCTAssertNil(result, "未匹配标题时应返回 nil")
    }

    func testPageByTitle_空页面集合返回nil() async {
        let result = await sut.pageByTitle("任意", in: [])
        XCTAssertNil(result, "空页面集合应返回 nil")
    }

    // MARK: backlinks pageID 不存在

    func testBacklinks_pageID不存在返回空数组() async {
        let pages = [KnowledgePage(title: "A", content: "内容")]
        let result = await sut.backlinks(for: UUID(), in: pages)
        XCTAssertTrue(result.isEmpty, "pageID 不存在时应返回空数组")
    }

    func testBacklinks_无反向链接返回空数组() async {
        let pageA = KnowledgePage(title: "A", content: "独立内容无链接")
        let pageB = KnowledgePage(title: "B", content: "另一独立页面")
        let result = await sut.backlinks(for: pageA.id, in: [pageA, pageB])
        XCTAssertTrue(result.isEmpty, "无反向链接时应返回空数组")
    }

    // MARK: search 别名匹配分支

    func testSearch_别名匹配分支() async {
        var page = KnowledgePage(title: "架构设计", content: "内容不含关键词")
        page.aliases = ["Architecture"]
        let results = await sut.search(query: "architecture", in: [page])
        XCTAssertEqual(results.count, 1, "应通过别名匹配到页面")
        XCTAssertEqual(results.first?.title, "架构设计")
    }

    // MARK: search 空查询返回原集合

    func testSearch_空查询返回原集合() async {
        let pages = [
            KnowledgePage(title: "A", content: "a"),
            KnowledgePage(title: "B", content: "b")
        ]
        let results = await sut.search(query: "", in: pages)
        XCTAssertEqual(results.count, 2, "空查询应返回原集合全部")
    }

    // MARK: rrf 空输入

    func testRRF_空输入返回空数组() async {
        let result = await sut.rrf(keywordResults: [], semanticResults: [])
        XCTAssertTrue(result.isEmpty, "空输入应返回空数组")
    }

    func testRRF_仅关键词结果() async {
        let page = KnowledgePage(title: "Only", content: "")
        let result = await sut.rrf(keywordResults: [page], semanticResults: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, page.id)
    }

    func testRRF_仅语义结果() async {
        let page = KnowledgePage(title: "OnlySemantic", content: "")
        let result = await sut.rrf(keywordResults: [], semanticResults: [page])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, page.id)
    }

    // MARK: allTags 空集合与无标签

    func testAllTags_空页面集合返回空数组() async {
        let result = await sut.allTags(in: [])
        XCTAssertTrue(result.isEmpty, "空页面集合应返回空标签列表")
    }

    func testAllTags_无标签页面返回空数组() async {
        let page = KnowledgePage(title: "NoTags", content: "")
        let result = await sut.allTags(in: [page])
        XCTAssertTrue(result.isEmpty, "无标签页面应返回空数组")
    }

    // MARK: prepareRename 无反向链接

    func testPrepareRename_无反向链接仅返回主页面() async {
        let mainPage = KnowledgePage(title: "OldName", content: "内容")
        let otherPage = KnowledgePage(title: "Other", content: "无引用")
        let result = await sut.prepareRename(page: mainPage, to: "NewName", in: [mainPage, otherPage])
        XCTAssertEqual(result.count, 1, "无反向链接时仅返回主页面")
        XCTAssertEqual(result[0].title, "NewName")
    }

    // MARK: hybridSearch 短查询高置信度分支

    func testHybridSearch_短查询高置信度语义结果保留() async throws {
        setupFullMockEnvironment()
        let pageID = UUID()
        let page = KnowledgePage(id: pageID, title: "3D", content: "三维渲染")
        let provider = ProgrammableEmbeddingProvider()
        // 高置信度分数 > 0.85，应被保留
        provider.searchResults = [(id: pageID, score: 0.95)]
        let result = await sut.hybridSearchWithDiagnostics(query: "3D", in: [page], embeddingProvider: provider)
        XCTAssertTrue(result.results.contains { $0.id == pageID }, "高置信度语义结果应被保留")
    }

    func testHybridSearch_短查询低置信度但标题含查询词保留() async throws {
        setupFullMockEnvironment()
        let pageID = UUID()
        let page = KnowledgePage(id: pageID, title: "3D Graphics", content: "内容")
        let provider = ProgrammableEmbeddingProvider()
        // 低置信度但标题含查询词 "3D"，应被保留
        provider.searchResults = [(id: pageID, score: 0.3)]
        let result = await sut.hybridSearchWithDiagnostics(query: "3D", in: [page], embeddingProvider: provider)
        XCTAssertTrue(result.results.contains { $0.id == pageID }, "标题含查询词的低置信度结果应被保留")
    }

    func testHybridSearch_短查询低置信度且标题不含查询词过滤() async throws {
        setupFullMockEnvironment()
        let pageID = UUID()
        let page = KnowledgePage(id: pageID, title: "无关标题", content: "内容")
        let provider = ProgrammableEmbeddingProvider()
        // 低置信度且标题不含查询词，应被过滤
        provider.searchResults = [(id: pageID, score: 0.3)]
        let result = await sut.hybridSearchWithDiagnostics(query: "3D", in: [page], embeddingProvider: provider)
        XCTAssertFalse(result.results.contains { $0.id == pageID }, "低置信度且标题不含查询词应被过滤")
    }

    func testHybridSearch_长查询高于阈值保留() async throws {
        setupFullMockEnvironment()
        let pageID = UUID()
        let page = KnowledgePage(id: pageID, title: "SwiftUI", content: "声明式UI")
        let provider = ProgrammableEmbeddingProvider()
        // 长查询分支，score > semanticThresholdLong(0.75) 应保留
        provider.searchResults = [(id: pageID, score: 0.8)]
        let result = await sut.hybridSearchWithDiagnostics(query: "swiftui declarative", in: [page], embeddingProvider: provider)
        XCTAssertTrue(result.results.contains { $0.id == pageID }, "长查询高于阈值应保留")
    }

    func testHybridSearch_语义结果ID不在pages中被过滤() async throws {
        setupFullMockEnvironment()
        let realPage = KnowledgePage(title: "Real", content: "真实页面")
        let ghostID = UUID()
        let provider = ProgrammableEmbeddingProvider()
        // 语义搜索返回一个不存在于 pages 的 ID
        provider.searchResults = [(id: ghostID, score: 0.99)]
        let result = await sut.hybridSearchWithDiagnostics(query: "test query long", in: [realPage], embeddingProvider: provider)
        XCTAssertFalse(result.results.contains { $0.id == ghostID }, "不在 pages 中的语义结果应被 compactMap 过滤")
    }
}

// MARK: - PromptTemplateEngine 边界分支测试

@MainActor
final class DomainPromptTemplateEngineBranchTests: XCTestCase {
    private var promptEngine: PromptTemplateEngine!
    private var mockSession: URLSession!

    private class MockURLProtocol: URLProtocol {
        static var mockData: Data?
        static var mockResponse: URLResponse?
        static var mockError: Error?
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            if let error = Self.mockError {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            // 确保 response 存在以满足 URLProtocol 契约（didReceive 必须在 didLoad 之前）
            let response: URLResponse
            if let mockResp = Self.mockResponse {
                response = mockResp
            } else {
                let fallbackURL = URL(fileURLWithPath: "/mock")
                let fallbackResponse = HTTPURLResponse(
                    url: fallbackURL,
                    statusCode: 200, httpVersion: nil, headerFields: nil
                )
                if let resp = fallbackResponse {
                    response = resp
                } else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                    return
                }
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = Self.mockData {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        promptEngine = PromptTemplateEngine(session: mockSession)
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
    }

    override func tearDown() async throws {
        await promptEngine.clearCache()
        promptEngine = nil
        mockSession = nil
        try await super.tearDown()
    }

    // MARK: parse 空模板与空变量

    func testParse_空模板返回空字符串() {
        let result = promptEngine.parse(template: "", with: ["key": "value"])
        XCTAssertEqual(result, "", "空模板应返回空字符串")
    }

    func testParse_空变量字典返回原模板() {
        let template = "无占位符的模板 {{unfilled}}"
        let result = promptEngine.parse(template: template, with: [:])
        XCTAssertEqual(result, template, "空变量字典应返回原模板")
    }

    func testParse_多占位符全部替换() {
        let template = "{{a}}-{{b}}-{{c}}"
        let result = promptEngine.parse(template: template, with: ["a": "1", "b": "2", "c": "3"])
        XCTAssertEqual(result, "1-2-3", "所有占位符应被替换")
    }

    // MARK: renderPrompt 远程空内容降级

    func testRenderPrompt_远程返回空内容降级到本地模板() async {
        let skill = AgentSkill(
            skillId: "test_empty_remote",
            displayName: "空远程",
            description: "Remote returns empty",
            systemPromptTemplate: "本地兜底：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/empty.md",
            version: "1.0.0"
        )
        MockURLProtocol.mockData = Data("   \n  ".utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: skill.remotePromptURLString!)!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )
        let rendered = await promptEngine.renderPrompt(for: skill, with: ["query": "测试"])
        XCTAssertEqual(rendered, "本地兜底：测试", "远程返回空白内容应降级到本地模板")
    }

    // MARK: renderPrompt 远程非200状态码降级

    func testRenderPrompt_远程非200状态码降级到本地模板() async {
        let skill = AgentSkill(
            skillId: "test_500",
            displayName: "500错误",
            description: "Server error",
            systemPromptTemplate: "本地兜底：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/error.md",
            version: "1.0.0"
        )
        MockURLProtocol.mockData = Data("内容".utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: skill.remotePromptURLString!)!,
            statusCode: 500, httpVersion: nil, headerFields: nil
        )
        let rendered = await promptEngine.renderPrompt(for: skill, with: ["query": "测试"])
        XCTAssertEqual(rendered, "本地兜底：测试", "非200状态码应降级到本地模板")
    }

    // MARK: renderPrompt SHA256 校验失败降级

    func testRenderPrompt_远程SHA256不匹配降级到本地模板() async {
        let skill = AgentSkill(
            skillId: "test_hash_mismatch",
            displayName: "哈希不匹配",
            description: "Hash mismatch",
            systemPromptTemplate: "本地兜底：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/mismatch.md",
            remotePromptSHA256: "aaaa0000bbbb0000cccc0000dddd0000eeee0000ffff00001111000022220000",
            version: "1.0.0"
        )
        MockURLProtocol.mockData = Data("实际内容".utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: skill.remotePromptURLString!)!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )
        let rendered = await promptEngine.renderPrompt(for: skill, with: ["query": "测试"])
        XCTAssertEqual(rendered, "本地兜底：测试", "SHA256 不匹配应降级到本地模板")
    }

    // MARK: renderPrompt SHA256 校验通过使用远程内容

    func testRenderPrompt_远程SHA256匹配使用远程内容() async throws {
        let remoteContent = "远程正确内容：{{query}}"
        let skill = AgentSkill(
            skillId: "test_hash_match",
            displayName: "哈希匹配",
            description: "Hash match",
            systemPromptTemplate: "本地兜底：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/match.md",
            remotePromptSHA256: sha256Hex(remoteContent),
            version: "1.0.0"
        )
        MockURLProtocol.mockData = Data(remoteContent.utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: skill.remotePromptURLString!)!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )
        let rendered = await promptEngine.renderPrompt(for: skill, with: ["query": "测试"])
        XCTAssertEqual(rendered, "远程正确内容：测试", "SHA256 匹配应使用远程内容")
    }

    // MARK: renderPrompt 无效URL降级

    func testRenderPrompt_无效URLString降级到本地模板() async {
        let skill = AgentSkill(
            skillId: "test_invalid_url",
            displayName: "无效URL",
            description: "Invalid URL",
            systemPromptTemplate: "本地兜底：{{query}}",
            remotePromptURLString: "not-a-valid-url",
            version: "1.0.0"
        )
        let rendered = await promptEngine.renderPrompt(for: skill, with: ["query": "测试"])
        XCTAssertEqual(rendered, "本地兜底：测试", "无效URL应降级到本地模板")
    }

    // MARK: renderPrompt 路径遍历防护

    func testRenderPrompt_路径遍历skillId被清理() async throws {
        let skill = AgentSkill(
            skillId: "../../../etc/passwd",
            displayName: "路径遍历",
            description: "Path traversal",
            systemPromptTemplate: "本地：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/traversal.md",
            version: "1.0.0"
        )
        MockURLProtocol.mockData = Data("远程内容".utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: skill.remotePromptURLString!)!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )
        let rendered = await promptEngine.renderPrompt(for: skill, with: ["query": "测试"])
        // 应正常渲染，路径分隔符被替换为下划线，不会越权访问沙盒外
        XCTAssertEqual(rendered, "远程内容", "路径遍历 skillId 应被清理后正常缓存")
    }

    // MARK: clearCache 清空缓存

    func testClearCache_清空后远程重新拉取() async {
        let skill = AgentSkill(
            skillId: "test_clear_cache",
            displayName: "清缓存",
            description: "Clear cache",
            systemPromptTemplate: "本地：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/clear.md",
            version: "1.0.0"
        )
        MockURLProtocol.mockData = Data("第一次内容".utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: skill.remotePromptURLString!)!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )
        _ = await promptEngine.renderPrompt(for: skill, with: ["query": "1"])
        await promptEngine.clearCache()
        MockURLProtocol.mockData = Data("第二次内容".utf8)
        let rendered = await promptEngine.renderPrompt(for: skill, with: ["query": "2"])
        XCTAssertEqual(rendered, "第二次内容", "清缓存后应重新拉取远程内容")
    }

    // MARK: 辅助

    private func sha256Hex(_ text: String) -> String {
        let hash = CryptoKit.SHA256.hash(data: Data(text.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - FeatureGateManager 边界分支测试

@MainActor
final class DomainFeatureGateManagerBranchTests: XCTestCase {
    private var testUserDefaults: UserDefaults?
    private var sut: FeatureGateManager?

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: "DomainFeatureGateBranchTestsDomain")
        suite?.removePersistentDomain(forName: "DomainFeatureGateBranchTestsDomain")
        testUserDefaults = suite
        if let defaults = testUserDefaults {
            sut = FeatureGateManager(userDefaults: defaults)
        }
    }

    override func tearDown() {
        testUserDefaults?.removePersistentDomain(forName: "DomainFeatureGateBranchTestsDomain")
        testUserDefaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: isQuotaExceeded -1 无限不超限

    func testIsQuotaExceeded_无限配额不超限() throws {
        let manager = try XCTUnwrap(sut)
        let proVo = PlanQuotasVo.createProDefault
        manager.updateActiveQuotas(proVo)
        // dailyAiMessages = -1 表示无限
        XCTAssertFalse(manager.isQuotaExceeded(\.dailyAiMessages, currentUsage: 999999), "-1 无限配额绝不超限")
    }

    // MARK: isQuotaExceeded 恰好等于限制算超限

    func testIsQuotaExceeded_恰好等于限制算超限() throws {
        let manager = try XCTUnwrap(sut)
        let liteVo = PlanQuotasVo.createLiteDefault
        manager.updateActiveQuotas(liteVo)
        // maxVaultsCount = 2，currentUsage = 2 应算超限
        XCTAssertTrue(manager.isQuotaExceeded(\.maxVaultsCount, currentUsage: 2), "usage == limit 应算超限")
    }

    // MARK: isQuotaExceeded 低于限制不超限

    func testIsQuotaExceeded_低于限制不超限() throws {
        let manager = try XCTUnwrap(sut)
        let liteVo = PlanQuotasVo.createLiteDefault
        manager.updateActiveQuotas(liteVo)
        XCTAssertFalse(manager.isQuotaExceeded(\.maxVaultsCount, currentUsage: 1), "usage < limit 不超限")
    }

    // MARK: getQuotaLimit 无缓存且禁用游客返回0

    func testGetQuotaLimit_无缓存禁用游客返回0() throws {
        let manager = try XCTUnwrap(sut)
        manager.clearQuotasCache()
        // DEBUG 模式下 isGuestModeAllowed = true，会返回 offlineColdStartQuotas
        // 验证 DEBUG 模式下返回 Lite 默认值
        #if DEBUG
        XCTAssertEqual(manager.getQuotaLimit(\.maxKnowledgePages), 1000, "DEBUG 模式无缓存应返回 Lite 保底")
        #else
        XCTAssertEqual(manager.getQuotaLimit(\.maxKnowledgePages), 0, "Release 模式无缓存禁用游客应返回 0")
        #endif
    }

    // MARK: isFeatureEnabled 无缓存返回false（Release模式）

    func testIsFeatureEnabled_无缓存返回默认值() throws {
        let manager = try XCTUnwrap(sut)
        manager.clearQuotasCache()
        #if DEBUG
        XCTAssertTrue(manager.isFeatureEnabled(\.customLocalLlmEnabled), "DEBUG 模式应返回 Lite 保底 customLocalLlmEnabled = true")
        XCTAssertFalse(manager.isFeatureEnabled(\.cloudLlmModelsEnabled), "DEBUG 模式应返回 Lite 保底 cloudLlmModelsEnabled = false")
        #else
        XCTAssertFalse(manager.isFeatureEnabled(\.customLocalLlmEnabled), "Release 模式无缓存应返回 false")
        #endif
    }

    // MARK: clearQuotasCache 清空后 activeQuotas 为 nil

    func testClearQuotasCache_清空后activeQuotas为Nil() throws {
        let manager = try XCTUnwrap(sut)
        manager.updateActiveQuotas(PlanQuotasVo.createProDefault)
        XCTAssertNotNil(manager.activeQuotas)
        manager.clearQuotasCache()
        XCTAssertNil(manager.activeQuotas, "清空缓存后 activeQuotas 应为 nil")
    }

    // MARK: updateActiveQuotas 触发通知

    func testUpdateActiveQuotas_触发quotasSubject通知() throws {
        let manager = try XCTUnwrap(sut)
        let expectation = XCTestExpectation(description: "quotasSubject 应发送通知")
        let cancellable = manager.quotasSubject.sink { quotas in
            if quotas != nil { expectation.fulfill() }
        }
        manager.updateActiveQuotas(PlanQuotasVo.createLiteDefault)
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    // MARK: loadCachedQuotas 损坏数据返回nil

    func testLoadCachedQuotas_损坏数据返回Nil() throws {
        let defaults = try XCTUnwrap(testUserDefaults)
        // 写入损坏的 JSON 数据
        defaults.set(Data("not-json".utf8), forKey: "zhiyu_cached_plan_quotas")
        let manager = FeatureGateManager(userDefaults: defaults)
        XCTAssertNil(manager.activeQuotas, "损坏的缓存数据应导致 activeQuotas 为 nil")
    }
}

// MARK: - AIContentEnricher 边界分支测试

@MainActor
final class DomainAIContentEnricherBranchTests: XCTestCase {
    private var enricher: AIContentEnricher!
    private var mockLLM: MockLLMService!

    override func setUp() async throws {
        try await super.setUp()
        enricher = AIContentEnricher.shared
        mockLLM = MockLLMService()
    }

    override func tearDown() async throws {
        enricher = nil
        mockLLM = nil
        try await super.tearDown()
    }

    // MARK: enrich 纯文本不触发增强

    func testEnrich_纯文本不触发增强() async {
        let content = "这是一段纯文本，没有任何表格或图片。"
        let result = await enricher.enrich(content, llm: mockLLM)
        XCTAssertEqual(result, content, "纯文本应直接返回原内容")
    }

    // MARK: enrich 空内容不触发增强

    func testEnrich_空内容不触发增强() async {
        let result = await enricher.enrich("", llm: mockLLM)
        XCTAssertEqual(result, "", "空内容应直接返回")
    }

    // MARK: enrich 表格LLM抛错返回原表格

    func testEnrich_表格LLM抛错返回原表格() async {
        mockLLM.generateHandler = { _, _ in throw NSError(domain: "test", code: 1) }
        let table = """
        | 名称 | 值 |
        | --- | --- |
        | A | 1 |
        """
        let result = await enricher.enrich(table, llm: mockLLM)
        XCTAssertTrue(result.contains("| A | 1 |"), "LLM 抛错时应保留原表格内容")
    }

    // MARK: enrich 图片alt为空不触发LLM

    func testEnrich_图片alt为空不触发LLM() async {
        var llmCalled = false
        mockLLM.generateHandler = { _, _ in llmCalled = true; return "描述" }
        let content = "![](https://example.com/image.png)"
        let result = await enricher.enrich(content, llm: mockLLM)
        XCTAssertFalse(llmCalled, "alt 为空时不应调用 LLM")
        XCTAssertTrue(result.contains("https://example.com/image.png"), "应保留原图片URL")
    }

    // MARK: enrich 图片LLM抛错返回原图片

    func testEnrich_图片LLM抛错返回原图片() async {
        mockLLM.generateHandler = { _, _ in throw NSError(domain: "test", code: 1) }
        let content = "![描述](https://example.com/image.png)"
        let result = await enricher.enrich(content, llm: mockLLM)
        XCTAssertTrue(result.contains("![描述](https://example.com/image.png)"), "LLM 抛错时应保留原图片Markdown")
    }

    // MARK: enrich 表格后紧跟文本正确分块

    func testEnrich_表格后紧跟文本正确分块() async {
        mockLLM.generateHandler = { _, _ in "增强洞察" }
        let content = """
        前置文本

        | 名称 | 值 |
        | --- | --- |
        | A | 1 |

        后置文本
        """
        let result = await enricher.enrich(content, llm: mockLLM)
        XCTAssertTrue(result.contains("前置文本"), "应保留前置文本")
        XCTAssertTrue(result.contains("增强洞察"), "表格应被增强")
        XCTAssertTrue(result.contains("后置文本"), "应保留后置文本")
    }

    // MARK: enrich 多图片并行增强

    func testEnrich_多图片并行增强() async {
        mockLLM.generateHandler = { _, _ in "图片描述" }
        let content = """
        ![图1](https://example.com/1.png)

        ![图2](https://example.com/2.png)
        """
        let result = await enricher.enrich(content, llm: mockLLM)
        XCTAssertTrue(result.contains("图片描述"), "多图片应都被增强")
    }
}
