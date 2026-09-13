//
//  SynthesisStoreTypeDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SynthesisStore 深度补盲测试（Type 属性分片）— 覆盖 6 类 SynthesisType 的 title/icon/formatIcon/
//            rawValue/id/customPromptPlaceholder/allCases 属性、SynthesisStatus.isError 语义与 error 消息携带，
//            以发现生产代码潜在 bug 为首要目标。
//
//  说明：从 SynthesisStoreDeepTests.swift 拆分而来（按 MARK 分段）。本文件聚焦 SynthesisType 与
//        SynthesisStatus 的属性语义验证，确保 6 类合成类型的元数据唯一性与稳定性。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - 可控 LLM Mock（支持按调用返回不同结果 / 抛错 / 记录调用）

/// 可控 LLM 服务 Mock：记录所有 generate 调用，支持按 prompt 关键字返回不同响应或抛错。
/// 复用 AISynthesisServiceDeepTests 的设计模式，但独立定义以避免测试套件间耦合。
@MainActor
final class SynthesisStoreControllableLLM: LLMServiceProtocol, @unchecked Sendable {
    /// 默认响应（无 handler 命中时返回）
    var defaultResponse: String = ""
    /// 按 systemPrompt 关键字匹配的自定义 handler
    var generateHandler: ((String, String) async throws -> String)?
    /// 是否在下次 generate 抛错
    var shouldThrow: Bool = false
    /// 抛错时使用的 Error
    var throwError: Error = LLMError.notConfigured
    /// 记录所有 generate 调用的 (prompt, systemPrompt)
    private(set) var generateCalls: [(prompt: String, systemPrompt: String)] = []

    var isEnabled: Bool = true
    var provider: LLMProvider = .custom
    var apiKey: String = ""
    var baseURL: String = ""
    var model: String = ""
    var autoScan: Bool = false
    var autoRefactor: Bool = false

    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: defaultResponse)
    }

    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        generateCalls.append((prompt, systemPrompt))
        if shouldThrow { throw throwError }
        if let handler = generateHandler {
            return try await handler(prompt, systemPrompt)
        }
        return defaultResponse
    }

    func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        SmartIngestResultDTO(title: title, compiledContent: "", suggestedTags: [], suggestedType: "", relatedTitles: [], summary: "")
    }
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] { [] }
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String { "" }
    func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] { [] }
    func rewriteQuery(_ query: String) async -> String { query }
    func expandQuery(_ query: String) async -> [String] { [query] }
    func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] { candidates }
    func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] { chunks }
    func generateHypotheticalDocument(query: String) async -> String { query }
}

// MARK: - SynthesisStore Type 属性深度测试

@MainActor
final class SynthesisStoreTypeDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var mockLLM: SynthesisStoreControllableLLM!
    private var taskCenter: TaskCenter!
    private var store: SynthesisStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()

        // 创建可控 LLM Mock 并双重注入：
        // 1) ServiceContainer 注册（AISynthesisService.currentLLM 优先从 DI 解析）
        // 2) AISynthesisService.shared.updateLLMForTesting（覆盖 actor 内部 llm 后备引用）
        let llm = SynthesisStoreControllableLLM()
        self.mockLLM = llm
        ServiceContainer.shared.register(llm as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        await AISynthesisService.shared.updateLLMForTesting(llm)

        // 创建独立的 TaskCenter 实例，通过 withDependencies 注入到 SynthesisStore
        self.taskCenter = TaskCenter(activityService: nil)
        self.taskCenter.reset()

        // 清理 UserDefaults.standard 中可能残留的合成文档键（跨测试隔离）
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 在 withDependencies 闭包内创建 SynthesisStore，确保 @Dependency(\.taskCenter) 解析到自定义实例
        self.store = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }
        self.store.clearAll()
    }

    override func tearDown() async throws {
        store?.clearAll()
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }
        store = nil
        taskCenter = nil
        mockLLM = nil
        await MainActor.run { resetPersistentTestState() }
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 构造足够长的有效合成内容（>= minValidSynthesisTextBytes = 10 字节）
    private func validContent(for type: SynthesisStore.SynthesisType) -> String {
        switch type {
        case .mindmap:
            return """
            # 测试思维导图

            ```mermaid
            mindmap
              root((测试主题))
                分支一
                  要点1
                  要点2
                分支二
                  要点3
            ```
            """
        case .slides:
            return "# 幻灯片1\n这是足够长的演示文稿内容用于通过最小字节校验阈值\n---\n# 幻灯片2\n第二页内容"
        case .quiz:
            return """
            {"title":"测试测验","questions":[{"id":1,"text":"1+1=?","options":["1","2"],"answer":1,"explanation":"1+1=2"}]}
            """
        case .report:
            return "# 测试报告\n这是足够长的报告正文内容用于通过最小字节校验阈值。"
        case .infographic:
            return """
            # 测试信息图表

            ```mermaid
            graph TD
              A[核心数据] --> B[存储层]
              A --> C[展现层]
            ```
            """
        case .expansion:
            return "# 知识扩充\n这是足够长的知识扩充正文内容用于通过最小字节校验阈值。"
        }
    }

    // MARK: - SynthesisType 属性验证

    /// 验证 SynthesisType 所有 case 的 title 属性非空且各不相同。
    func testSynthesisType_title非空且唯一() {
        let titles = SynthesisStore.SynthesisType.allCases.map { $0.title }
        XCTAssertEqual(titles.count, Set(titles).count, "所有 SynthesisType 的 title 必须唯一")
        for title in titles {
            XCTAssertFalse(title.isEmpty, "title 不能为空")
        }
    }

    /// 验证 SynthesisType 所有 case 的 icon 属性非空且各不相同。
    func testSynthesisType_icon非空且唯一() {
        let icons = SynthesisStore.SynthesisType.allCases.map { $0.icon }
        XCTAssertEqual(icons.count, Set(icons).count, "所有 SynthesisType 的 icon 必须唯一")
        for icon in icons {
            XCTAssertFalse(icon.isEmpty, "icon 不能为空")
        }
    }

    /// 验证 SynthesisType 所有 case 的 formatIcon 属性非空且各不相同。
    func testSynthesisType_formatIcon非空且唯一() {
        let icons = SynthesisStore.SynthesisType.allCases.map { $0.formatIcon }
        XCTAssertEqual(icons.count, Set(icons).count, "所有 SynthesisType 的 formatIcon 必须唯一")
        for icon in icons {
            XCTAssertFalse(icon.isEmpty, "formatIcon 不能为空")
        }
    }

    /// 验证 SynthesisType 的 rawValue 与 id 一致。
    func testSynthesisType_rawValue与id一致() {
        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertEqual(type.id, type.rawValue, "id 必须等于 rawValue")
        }
    }

    /// 验证 SynthesisType.customPromptPlaceholder 所有 case 非空。
    func testSynthesisType_customPromptPlaceholder非空() {
        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertFalse(type.customPromptPlaceholder.isEmpty, "\(type.rawValue) 的 customPromptPlaceholder 不能为空")
        }
    }

    /// 验证 SynthesisType.allCases 包含全部 6 个 case 且顺序固定。
    func testSynthesisType_allCases包含6个case() {
        XCTAssertEqual(SynthesisStore.SynthesisType.allCases.count, 6, "应有 6 个 SynthesisType case")
        XCTAssertEqual(SynthesisStore.SynthesisType.allCases, [.mindmap, .slides, .quiz, .report, .infographic, .expansion], "case 顺序应固定")
    }

    // MARK: - SynthesisStatus 验证

    /// 验证 SynthesisStatus.isError 在 .error 状态为 true，其他为 false。
    func testSynthesisStatus_isError语义正确() {
        XCTAssertTrue(SynthesisStore.SynthesisStatus.error("错误").isError, ".error 状态 isError 应为 true")
        XCTAssertFalse(SynthesisStore.SynthesisStatus.idle.isError, ".idle 状态 isError 应为 false")
        XCTAssertFalse(SynthesisStore.SynthesisStatus.generating.isError, ".generating 状态 isError 应为 false")
        XCTAssertFalse(SynthesisStore.SynthesisStatus.completed.isError, ".completed 状态 isError 应为 false")
    }

    /// 验证 SynthesisStatus.error 携带的错误消息可被读取。
    func testSynthesisStatus_error携带消息() {
        let status = SynthesisStore.SynthesisStatus.error("LLM 不可用")
        XCTAssertTrue(status.isError)
        if case .error(let msg) = status {
            XCTAssertEqual(msg, "LLM 不可用")
        } else {
            XCTFail("应匹配 .error case")
        }
    }
}
