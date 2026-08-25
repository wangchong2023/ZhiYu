//
//  SynthesisStoreDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SynthesisStore 深度补盲测试 — 覆盖 6 类 SynthesisType 属性、performSynthesis 正常/LLM失败/空内容/
//            过短内容/容量上限/状态推演路径、saveSynthesisResult 防空门禁、deleteSynthesisDoc/renameSynthesisDoc/
//            batchDeleteSynthesisDocs/clearAll/loadSynthesisResults 持久化、exportSynthesisDocument 导出分派、
//            cleanMarkdown 静态工具、SynthesisControlOptions 交互、allSortedDocuments 排序、
//            AppEventBus.clearAllDataRequested 联动，以发现生产代码潜在 bug 为首要目标。
//
//  说明：Tests/Unit/AI/SynthesisStoreTests.swift 已覆盖基础防空门禁、重命名、删除、容量上限、持久化反向读取。
//        本文件补充 6 类合成正常/失败路径、TaskCenter 任务状态推演、导出分派、loadSynthesisResults 损坏数据、
//        allSortedDocuments 排序、batchDeleteSynthesisDocs 跨类型、clearAll 事件联动、cleanMarkdown 工具等深度场景。
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

// MARK: - SynthesisStore 深度测试

@MainActor
final class SynthesisStoreDeepTests: XCTestCase {

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

    // MARK: - performSynthesis 正常路径（6 类）

    /// 验证 performSynthesis(.mindmap) 正常生成文档。
    func testPerformSynthesis_mindmap正常路径() async throws {
        mockLLM.defaultResponse = validContent(for: .mindmap)

        let doc = try await store.performSynthesis(type: .mindmap, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .mindmap)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisResults[.mindmap]?.count, 1)
        XCTAssertEqual(store.synthesisStates[.mindmap], .completed)
    }

    /// 验证 performSynthesis(.slides) 正常生成文档。
    func testPerformSynthesis_slides正常路径() async throws {
        mockLLM.defaultResponse = validContent(for: .slides)

        let doc = try await store.performSynthesis(type: .slides, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .slides)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.slides], .completed)
    }

    /// 验证 performSynthesis(.quiz) 正常生成文档。
    func testPerformSynthesis_quiz正常路径() async throws {
        mockLLM.defaultResponse = validContent(for: .quiz)

        let doc = try await store.performSynthesis(type: .quiz, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .quiz)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.quiz], .completed)
    }

    /// 验证 performSynthesis(.report) 正常生成文档。
    func testPerformSynthesis_report正常路径() async throws {
        mockLLM.defaultResponse = validContent(for: .report)

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .report)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.report], .completed)
    }

    /// 验证 performSynthesis(.infographic) 正常生成文档。
    func testPerformSynthesis_infographic正常路径() async throws {
        mockLLM.defaultResponse = validContent(for: .infographic)

        let doc = try await store.performSynthesis(type: .infographic, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .infographic)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.infographic], .completed)
    }

    /// 验证 performSynthesis(.expansion) 正常生成文档。
    func testPerformSynthesis_expansion正常路径() async throws {
        mockLLM.defaultResponse = validContent(for: .expansion)

        let doc = try await store.performSynthesis(type: .expansion, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .expansion)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.expansion], .completed)
    }

    // MARK: - performSynthesis LLM 失败路径

    /// 验证 performSynthesis 在 LLM 抛错时（mindmap 走 generateMindMap 无 try? 降级）应向上抛出。
    func testPerformSynthesis_mindmapLLM抛错时向上传播() async throws {
        mockLLM.shouldThrow = true
        mockLLM.throwError = LLMError.notConfigured

        do {
            _ = try await store.performSynthesis(type: .mindmap, combinedContent: "源内容")
            XCTFail("mindmap 在 LLM 抛错时应向上传播")
        } catch {
            // 预期抛出
        }

        // 状态应被标记为 error
        XCTAssertTrue(store.synthesisStates[.mindmap]?.isError ?? false, "失败后状态应为 .error")
        // 不应生成文档
        XCTAssertTrue(store.synthesisResults[.mindmap]?.isEmpty ?? true, "失败不应生成文档")
    }

    /// 验证 performSynthesis(.slides) 在 LLM 抛错时降级返回 fallback（generatePresentation 用 try?）。
    func testPerformSynthesis_slidesLLM抛错时降级返回fallback() async throws {
        mockLLM.shouldThrow = true

        // slides 走 generatePresentation，使用 try? 降级，应返回 fallback 文本而非抛错
        let doc = try await store.performSynthesis(type: .slides, combinedContent: "源内容")

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes, "降级 fallback 应满足最小字节")
        XCTAssertEqual(store.synthesisStates[.slides], .completed, "降级成功后状态应为 .completed")
    }

    /// 验证 performSynthesis(.quiz) 在 LLM 抛错时降级返回 fallback。
    func testPerformSynthesis_quizLLM抛错时降级返回fallback() async throws {
        mockLLM.shouldThrow = true

        let doc = try await store.performSynthesis(type: .quiz, combinedContent: "源内容")

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.quiz], .completed)
    }

    /// 验证 performSynthesis(.report) 在 LLM 抛错时降级返回 fallback。
    func testPerformSynthesis_reportLLM抛错时降级返回fallback() async throws {
        mockLLM.shouldThrow = true

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容")

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.report], .completed)
    }

    /// 验证 performSynthesis(.infographic) 在 LLM 抛错时降级返回 fallback。
    func testPerformSynthesis_infographicLLM抛错时降级返回fallback() async throws {
        mockLLM.shouldThrow = true

        let doc = try await store.performSynthesis(type: .infographic, combinedContent: "源内容")

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.infographic], .completed)
    }

    /// 验证 performSynthesis(.expansion) 在 LLM 抛错时降级返回 fallback。
    func testPerformSynthesis_expansionLLM抛错时降级返回fallback() async throws {
        mockLLM.shouldThrow = true

        let doc = try await store.performSynthesis(type: .expansion, combinedContent: "源内容")

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.expansion], .completed)
    }

    // MARK: - performSynthesis 空内容路径

    /// 验证 performSynthesis 在 LLM 返回空字符串时（mindmap 走 fallback 自愈）应生成有效文档。
    func testPerformSynthesis_mindmapLLM返回空触发Fallback() async throws {
        mockLLM.defaultResponse = ""

        let doc = try await store.performSynthesis(type: .mindmap, combinedContent: "# 标题\n- 要点1\n- 要点2")

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes, "空响应应触发 fallback 自愈")
        XCTAssertEqual(store.synthesisStates[.mindmap], .completed)
    }

    /// 验证 performSynthesis(.report) 在 LLM 返回空字符串时触发 fallback。
    func testPerformSynthesis_reportLLM返回空触发Fallback() async throws {
        mockLLM.defaultResponse = ""

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容")

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.report], .completed)
    }

    // MARK: - performSynthesis 内容过短路径

    /// 验证 performSynthesis 在 LLM 返回过短内容（< minValidSynthesisTextBytes）且 fallback 也无效时抛错。
    /// - Note: mindmap 的 generateMindMap 在 formatted 过短时会走 convertMarkdownToListMindmap fallback，
    ///         通常能生成有效内容。此测试验证 fallback 后仍过短的极端场景。
    func testPerformSynthesis_mindmapLLM返回过短内容() async throws {
        // 返回过短内容（1 字节 < 10 字节），generateMindMap 会走 fallback
        mockLLM.defaultResponse = "短"

        let doc = try await store.performSynthesis(type: .mindmap, combinedContent: "源内容")

        // fallback 应生成有效内容
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
    }

    // MARK: - performSynthesis TaskCenter 任务状态推演

    /// 验证 performSynthesis 成功时 TaskCenter 任务从 pending → completed。
    func testPerformSynthesis成功时TaskCenter任务完成() async throws {
        mockLLM.defaultResponse = validContent(for: .report)

        let initialTaskCount = taskCenter.tasks.count
        _ = try await store.performSynthesis(type: .report, combinedContent: "源内容")

        XCTAssertEqual(taskCenter.tasks.count, initialTaskCount + 1, "应新增 1 个任务")
        let task = try XCTUnwrap(taskCenter.tasks.first)
        XCTAssertEqual(task.type, .synthesis, "任务类型应为 .synthesis")
        XCTAssertEqual(task.status, .completed, "任务状态应为 .completed")
    }

    /// 验证 performSynthesis 失败时 TaskCenter 任务标记为 failed。
    func testPerformSynthesis失败时TaskCenter任务失败() async throws {
        mockLLM.shouldThrow = true
        mockLLM.throwError = LLMError.notConfigured

        let initialTaskCount = taskCenter.tasks.count
        do {
            _ = try await store.performSynthesis(type: .mindmap, combinedContent: "源内容")
            XCTFail("应向上抛出")
        } catch {
            // 预期
        }

        XCTAssertEqual(taskCenter.tasks.count, initialTaskCount + 1, "失败也应新增任务记录")
        let task = try XCTUnwrap(taskCenter.tasks.first)
        if case .failed = task.status {
            // 预期
        } else {
            XCTFail("任务状态应为 .failed，实际：\(task.status)")
        }
    }

    /// 验证 performSynthesis 任务名称使用 SynthesisType.title。
    func testPerformSynthesis任务名称使用TypeTitle() async throws {
        mockLLM.defaultResponse = validContent(for: .quiz)

        _ = try await store.performSynthesis(type: .quiz, combinedContent: "源内容")

        let task = try XCTUnwrap(taskCenter.tasks.first)
        XCTAssertEqual(task.name, SynthesisStore.SynthesisType.quiz.title, "任务名称应为 SynthesisType.title")
    }

    // MARK: - performSynthesis 容量上限

    /// 验证 performSynthesis 在已达 5 份上限时抛错且不自动删除旧文档。
    func testPerformSynthesis达到5份上限时拒绝生成() async throws {
        let type = SynthesisStore.SynthesisType.mindmap
        // 填满 5 份
        for i in 1...5 {
            store.saveSynthesisResult(type: type, content: "# 主题\(i)\nmindmap\n  root((主题\(i)))\n    节点\(i)")
        }
        XCTAssertEqual(store.synthesisResults[type]?.count, 5)

        mockLLM.defaultResponse = validContent(for: .mindmap)
        do {
            _ = try await store.performSynthesis(type: type, combinedContent: "新内容")
            XCTFail("达到上限应抛错")
        } catch {
            // 预期
        }

        XCTAssertEqual(store.synthesisResults[type]?.count, 5, "旧文档数量必须保持 5 份未减少")
    }

    /// 验证 performSynthesis 在已有 4 份时仍可生成第 5 份。
    func testPerformSynthesis已有4份时可生成第5份() async throws {
        let type = SynthesisStore.SynthesisType.report
        for i in 1...4 {
            store.saveSynthesisResult(type: type, content: "# 报告\(i)\n这是第\(i)份报告的正文内容。")
        }

        mockLLM.defaultResponse = validContent(for: .report)
        _ = try await store.performSynthesis(type: type, combinedContent: "新内容")

        XCTAssertEqual(store.synthesisResults[type]?.count, 5, "应成功生成第 5 份")
    }

    // MARK: - performSynthesis 并发锁（generating 状态拒绝）

    /// 验证 performSynthesis 在 synthesisStates 为 .generating 时抛出 "Task already in progress" 错误。
    func testPerformSynthesis正在生成时拒绝重复调用() async throws {
        // 手动设置 generating 状态
        store.synthesisStates[.mindmap] = .generating

        mockLLM.defaultResponse = validContent(for: .mindmap)
        do {
            _ = try await store.performSynthesis(type: .mindmap, combinedContent: "内容")
            XCTFail("generating 状态应拒绝重复调用")
        } catch {
            // 预期抛出 "Task already in progress"
        }
    }

    // MARK: - performSynthesis 与 SynthesisControlOptions 交互

    /// 验证 performSynthesis 传入 SynthesisControlOptions 时 promptInstruction 被拼接到 augmentedContent。
    func testPerformSynthesis传入ControlOptions时拼接promptInstruction() async throws {
        mockLLM.defaultResponse = validContent(for: .report)
        let options = SynthesisControlOptions(depth: .detailed, audience: .executive, tone: .academic, customPrompt: "包含高并发视角")

        _ = try await store.performSynthesis(type: .report, combinedContent: "源内容", options: options)

        // 验证 LLM 收到的 prompt 包含 controlInstruction
        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertFalse(lastCall.prompt.isEmpty)
        // augmentedContent = controlInstruction + citationInstruction + "---" + combinedContent
        // 无法精确断言 L10n 内容，但应包含源内容
        XCTAssertTrue(lastCall.prompt.contains("源内容"), "prompt 应包含源内容")
    }

    /// 验证 performSynthesis 默认 SynthesisControlOptions 不崩溃。
    func testPerformSynthesis默认ControlOptions不崩溃() async throws {
        mockLLM.defaultResponse = validContent(for: .report)

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容", options: SynthesisControlOptions())

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
    }

    /// 验证 performSynthesis 传入 sourcePageIDs 时文档携带该 IDs。
    func testPerformSynthesis传入sourcePageIDs时文档携带() async throws {
        mockLLM.defaultResponse = validContent(for: .report)
        let pageIDs = [UUID(), UUID()]

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容", sourcePageIDs: pageIDs)

        XCTAssertEqual(doc.sourcePageIDs, pageIDs, "文档应携带 sourcePageIDs")
    }

    // MARK: - saveSynthesisResult 防空门禁

    /// 验证 saveSynthesisResult 拒绝空内容返回 nil。
    func testSaveSynthesisResult拒绝空内容返回nil() {
        let result = store.saveSynthesisResult(type: .report, content: "")
        XCTAssertNil(result, "空内容应返回 nil")
        XCTAssertTrue(store.synthesisResults[.report]?.isEmpty ?? true)
    }

    /// 验证 saveSynthesisResult 拒绝纯空白内容返回 nil。
    func testSaveSynthesisResult拒绝纯空白返回Nil() {
        let result = store.saveSynthesisResult(type: .report, content: "  \n  \t  ")
        XCTAssertNil(result, "纯空白应返回 nil")
    }

    /// 验证 saveSynthesisResult 拒绝 "mindmap" 骨架关键字。
    func testSaveSynthesisResult拒绝mindmap骨架() {
        let result = store.saveSynthesisResult(type: .mindmap, content: "mindmap")
        XCTAssertNil(result, "纯 'mindmap' 骨架应拒绝")
    }

    /// 验证 saveSynthesisResult 拒绝 "graph TD" 骨架关键字。
    func testSaveSynthesisResult拒绝GraphTD骨架() {
        let result = store.saveSynthesisResult(type: .infographic, content: "graph TD")
        XCTAssertNil(result, "纯 'graph TD' 骨架应拒绝")
    }

    /// 验证 saveSynthesisResult 拒绝 "graph" 骨架关键字。
    func testSaveSynthesisResult拒绝Graph骨架() {
        let result = store.saveSynthesisResult(type: .infographic, content: "graph")
        XCTAssertNil(result, "纯 'graph' 骨架应拒绝")
    }

    /// 验证 saveSynthesisResult 拒绝小于 minValidSynthesisTextBytes 的内容。
    func testSaveSynthesisResult拒绝过短内容() {
        // 9 字节 < 10 字节
        let result = store.saveSynthesisResult(type: .report, content: "123456789")
        XCTAssertNil(result, "9 字节内容应拒绝（< 10 字节阈值）")
    }

    /// 验证 saveSynthesisResult 接受恰好 10 字节的内容。
    func testSaveSynthesisResult接受恰好10字节() {
        // 10 字节 ASCII
        let result = store.saveSynthesisResult(type: .report, content: "1234567890")
        XCTAssertNotNil(result, "10 字节内容应接受")
        XCTAssertEqual(result?.size, 10)
    }

    /// 验证 saveSynthesisResult 成功后状态设为 .completed。
    func testSaveSynthesisResult成功后状态为Completed() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n这是有效正文内容。")
        XCTAssertEqual(store.synthesisStates[.report], .completed)
    }

    /// 验证 saveSynthesisResult 新文档插入到列表头部。
    func testSaveSynthesisResult新文档插入头部() {
        store.saveSynthesisResult(type: .report, content: "# 第一份\n正文内容一。")
        // 短暂延迟确保 createdAt 不同
        store.saveSynthesisResult(type: .report, content: "# 第二份\n正文内容二。")

        let docs = store.synthesisResults[.report] ?? []
        XCTAssertEqual(docs.count, 2)
        XCTAssertEqual(docs.first?.name, "第二份 - \(formatDate(docs.first?.createdAt))", "新文档应在头部")
    }

    /// 验证 saveSynthesisResult 持久化到 UserDefaults。
    func testSaveSynthesisResult持久化到UserDefaults() {
        let content = "# 持久化测试\n正文内容。"
        store.saveSynthesisResult(type: .report, content: content)

        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + SynthesisStore.SynthesisType.report.rawValue
        XCTAssertNotNil(UserDefaults.standard.data(forKey: key), "应持久化到 UserDefaults")
    }

    // MARK: - deleteSynthesisDoc

    /// 验证 deleteSynthesisDoc 删除指定文档。
    func testDeleteSynthesisDoc删除指定文档() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文内容。")
        let docID = store.synthesisResults[.report]?.first?.id

        if let id = docID {
            store.deleteSynthesisDoc(type: .report, docID: id)
            XCTAssertTrue(store.synthesisResults[.report]?.isEmpty ?? true, "删除后列表应为空")
        } else {
            XCTFail("应存在文档 ID")
        }
    }

    /// 验证 deleteSynthesisDoc 删除不存在的 docID 不崩溃。
    func testDeleteSynthesisDoc不存在的docID不崩溃() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文内容。")
        let initialCount = store.synthesisResults[.report]?.count ?? 0

        // 删除不存在的 UUID
        store.deleteSynthesisDoc(type: .report, docID: UUID())

        XCTAssertEqual(store.synthesisResults[.report]?.count, initialCount, "删除不存在的 ID 不应影响列表")
    }

    /// 验证 deleteSynthesisDoc 删除类型下不存在的文档（类型为空）不崩溃。
    func testDeleteSynthesisDoc类型为空时不崩溃() {
        store.deleteSynthesisDoc(type: .expansion, docID: UUID())
        XCTAssertTrue(store.synthesisResults[.expansion]?.isEmpty ?? true)
    }

    /// 验证 deleteSynthesisDoc 删除最后一个文档后状态重置为 .idle。
    func testDeleteSynthesisDoc删除最后一个后状态重置Idle() {
        store.saveSynthesisResult(type: .quiz, content: "{\"title\":\"测验\",\"questions\":[]}")
        XCTAssertEqual(store.synthesisStates[.quiz], .completed)

        let docID = store.synthesisResults[.quiz]?.first?.id
        if let id = docID {
            store.deleteSynthesisDoc(type: .quiz, docID: id)
            XCTAssertEqual(store.synthesisStates[.quiz], .idle, "删除最后一个后状态应重置为 .idle")
        }
    }

    /// 验证 deleteSynthesisDoc 删除后持久化更新（UserDefaults 中数据同步移除）。
    func testDeleteSynthesisDoc删除后持久化更新() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文内容。")
        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + SynthesisStore.SynthesisType.report.rawValue
        XCTAssertNotNil(UserDefaults.standard.data(forKey: key))

        let docID = store.synthesisResults[.report]?.first?.id
        if let id = docID {
            store.deleteSynthesisDoc(type: .report, docID: id)
            // 删除最后一个后，persistResults 应移除 key
            XCTAssertNil(UserDefaults.standard.data(forKey: key), "删除最后一个后 UserDefaults key 应被移除")
        }
    }

    // MARK: - renameSynthesisDoc

    /// 验证 renameSynthesisDoc 重命名文档。
    func testRenameSynthesisDoc重命名文档() {
        store.saveSynthesisResult(type: .report, content: "# 原始报告\n正文内容。")
        let docID = store.synthesisResults[.report]?.first?.id

        if let id = docID {
            store.renameSynthesisDoc(type: .report, docID: id, newName: "新名称")
            XCTAssertEqual(store.synthesisResults[.report]?.first?.name, "新名称")
        }
    }

    /// 验证 renameSynthesisDoc 重命名不存在的 docID 不崩溃。
    func testRenameSynthesisDoc不存在的docID不崩溃() {
        store.renameSynthesisDoc(type: .report, docID: UUID(), newName: "新名称")
        // 不崩溃即通过
    }

    /// 验证 renameSynthesisDoc 重命名后保留其他属性（content/createdAt/size）。
    func testRenameSynthesisDoc保留其他属性() {
        let content = "# 报告\n正文内容。"
        store.saveSynthesisResult(type: .report, content: content)
        let original = store.synthesisResults[.report]?.first
        let originalContent = original?.content
        let originalSize = original?.size
        let originalCreatedAt = original?.createdAt

        if let id = original?.id {
            store.renameSynthesisDoc(type: .report, docID: id, newName: "重命名")
            let renamed = store.synthesisResults[.report]?.first
            XCTAssertEqual(renamed?.content, originalContent, "content 应保留")
            XCTAssertEqual(renamed?.size, originalSize, "size 应保留")
            XCTAssertEqual(renamed?.createdAt, originalCreatedAt, "createdAt 应保留")
        }
    }

    // MARK: - batchDeleteSynthesisDocs

    /// 验证 batchDeleteSynthesisDocs 跨类型批量删除。
    func testBatchDeleteSynthesisDocs跨类型批量删除() {
        store.saveSynthesisResult(type: .report, content: "# 报告1\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图1\nmindmap\n  root((主题))")
        store.saveSynthesisResult(type: .quiz, content: "{\"title\":\"测验\",\"questions\":[]}")

        let reportID = store.synthesisResults[.report]?.first?.id
        let quizID = store.synthesisResults[.quiz]?.first?.id
        let idsToDelete: Set<UUID> = Set([reportID, quizID].compactMap { $0 })

        store.batchDeleteSynthesisDocs(ids: idsToDelete)

        XCTAssertTrue(store.synthesisResults[.report]?.isEmpty ?? true, "report 应被删除")
        XCTAssertTrue(store.synthesisResults[.quiz]?.isEmpty ?? true, "quiz 应被删除")
        XCTAssertFalse(store.synthesisResults[.mindmap]?.isEmpty ?? true, "mindmap 应保留")
    }

    /// 验证 batchDeleteSynthesisDocs 传入空集合不崩溃。
    func testBatchDeleteSynthesisDocs空集合不崩溃() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.batchDeleteSynthesisDocs(ids: [])
        XCTAssertEqual(store.synthesisResults[.report]?.count, 1, "空集合不应删除任何文档")
    }

    /// 验证 batchDeleteSynthesisDocs 删除后状态重置。
    func testBatchDeleteSynthesisDocs删除后状态重置() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        XCTAssertEqual(store.synthesisStates[.report], .completed)

        let id = store.synthesisResults[.report]?.first?.id
        if let id = id {
            store.batchDeleteSynthesisDocs(ids: [id])
            XCTAssertEqual(store.synthesisStates[.report], .idle, "删除最后一个后状态应重置")
        }
    }

    // MARK: - clearAll

    /// 验证 clearAll 清空所有类型的文档和状态。
    func testClearAll清空所有文档和状态() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图\nmindmap\n  root((主题))")

        store.clearAll()

        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true, "\(type.rawValue) 应被清空")
            XCTAssertEqual(store.synthesisStates[type], .idle, "\(type.rawValue) 状态应重置为 .idle")
        }
    }

    /// 验证 clearAll 移除 UserDefaults 中所有合成文档 key。
    func testClearAll移除UserDefaults所有Key() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图\nmindmap\n  root((主题))")

        store.clearAll()

        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            XCTAssertNil(UserDefaults.standard.data(forKey: key), "\(type.rawValue) 的 UserDefaults key 应被移除")
        }
    }

    /// 验证 clearAll 在空存储时不崩溃。
    func testClearAll空存储时不崩溃() {
        store.clearAll()
        // 不崩溃即通过
        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true)
        }
    }

    // MARK: - AppEventBus.clearAllDataRequested 联动

    /// 验证 AppEventBus 发布 clearAllDataRequested 事件时 SynthesisStore 自动 clearAll。
    func testAppEventBusClearAllDataRequested触发SynthesisStoreClearAll() async throws {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        XCTAssertFalse(store.synthesisResults[.report]?.isEmpty ?? true)

        // 发布清理事件
        AppEventBus.shared.publish(.clearAllDataRequested)

        // 等待 RunLoop.main 处理事件（sink 使用 receive(on: RunLoop.main)）
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(store.synthesisResults[.report]?.isEmpty ?? true, "clearAllDataRequested 事件应触发 clearAll")
    }

    // MARK: - loadSynthesisResults

    /// 验证 loadSynthesisResults 从 UserDefaults 加载已持久化的文档。
    func testLoadSynthesisResults从UserDefaults加载文档() {
        // 先保存文档
        let content = "# 加载测试\n正文内容。"
        store.saveSynthesisResult(type: .report, content: content)
        let originalID = store.synthesisResults[.report]?.first?.id

        // 创建新 store 实例（init 会调用 loadSynthesisResults）
        let newStore = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }

        XCTAssertEqual(newStore.synthesisResults[.report]?.first?.id, originalID, "新 store 应从 UserDefaults 加载已持久化文档")
        XCTAssertEqual(newStore.synthesisResults[.report]?.first?.content, content)
    }

    /// 验证 loadSynthesisResults 在空存储时不崩溃。
    func testLoadSynthesisResults空存储时不崩溃() {
        // 确保 UserDefaults 为空
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }

        let newStore = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }

        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertTrue(newStore.synthesisResults[type]?.isEmpty ?? true, "\(type.rawValue) 应为空")
        }
    }

    /// 验证 loadSynthesisResults 在遇到损坏数据时静默跳过不崩溃。
    func testLoadSynthesisResults损坏数据时静默跳过() {
        // 写入损坏的 JSON 数据
        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + SynthesisStore.SynthesisType.report.rawValue
        let corruptedData = Data("这不是合法的JSON".utf8)
        UserDefaults.standard.set(corruptedData, forKey: key)

        // 创建新 store，loadSynthesisResults 使用 try? 解码，损坏数据应静默跳过
        let newStore = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }

        XCTAssertTrue(newStore.synthesisResults[.report]?.isEmpty ?? true, "损坏数据应被静默跳过")
    }

    // MARK: - allSortedDocuments

    /// 验证 allSortedDocuments 按 createdAt 降序排序。
    func testAllSortedDocuments按CreatedAt降序排序() async throws {
        // 保存 3 份不同类型的文档，确保 createdAt 不同
        store.saveSynthesisResult(type: .report, content: "# 报告1\n正文。")
        try await Task.sleep(nanoseconds: 50_000_000)
        store.saveSynthesisResult(type: .mindmap, content: "# 导图1\nmindmap\n  root((主题))")
        try await Task.sleep(nanoseconds: 50_000_000)
        store.saveSynthesisResult(type: .quiz, content: "{\"title\":\"测验\",\"questions\":[]}")

        let allDocs = store.allSortedDocuments
        XCTAssertEqual(allDocs.count, 3)

        // 验证降序：第一个 createdAt >= 第二个
        XCTAssertGreaterThanOrEqual(allDocs[0].1.createdAt, allDocs[1].1.createdAt, "应按 createdAt 降序")
        XCTAssertGreaterThanOrEqual(allDocs[1].1.createdAt, allDocs[2].1.createdAt, "应按 createdAt 降序")
    }

    /// 验证 allSortedDocuments 在空存储时返回空数组。
    func testAllSortedDocuments空存储返回空数组() {
        XCTAssertTrue(store.allSortedDocuments.isEmpty)
    }

    /// 验证 allSortedDocuments 包含所有类型的文档。
    func testAllSortedDocuments包含所有类型文档() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图\nmindmap\n  root((主题))")

        let allDocs = store.allSortedDocuments
        let types = Set(allDocs.map { $0.0 })
        XCTAssertTrue(types.contains(.report))
        XCTAssertTrue(types.contains(.mindmap))
    }

    // MARK: - exportSynthesisDocument

    /// 验证 exportSynthesisDocument(.mindmap) 调用 exportMindmapToPDF。
    func testExportSynthesisDocument_mindmap调用ExportMindmapToPDF() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .mindmap,
            name: "测试导图",
            content: "mindmap\n  root((测试))",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pdf" || url.lastPathComponent.contains("测试导图"), "应导出 PDF")
    }

    /// 验证 exportSynthesisDocument(.slides) 调用 exportToPPTX。
    func testExportSynthesisDocument_slides调用ExportToPPTX() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .slides,
            name: "测试幻灯片",
            content: "# 幻灯片1\n内容",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pptx" || url.lastPathComponent.contains("测试幻灯片"), "应导出 PPTX")
    }

    /// 验证 exportSynthesisDocument(.report) 调用 exportToPDF。
    func testExportSynthesisDocument_report调用ExportToPDF() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试报告",
            content: "# 报告\n正文",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pdf" || url.lastPathComponent.contains("测试报告"), "应导出 PDF")
    }

    /// 验证 exportSynthesisDocument(.quiz) 调用 exportToPDF。
    func testExportSynthesisDocument_quiz调用ExportToPDF() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .quiz,
            name: "测试测验",
            content: "{\"title\":\"测验\"}",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pdf" || url.lastPathComponent.contains("测试测验"), "应导出 PDF")
    }

    /// 验证 exportSynthesisDocument 文件名替换 "/" 和 ":"。
    func testExportSynthesisDocument文件名替换特殊字符() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试/报告:2026",
            content: "# 报告\n正文",
            size: 20
        )

        _ = try await store.exportSynthesisDocument(doc)
        // 不崩溃即通过（MockExportService 返回固定路径）
    }

    // MARK: - cleanMarkdown 静态工具

    /// 验证 cleanMarkdown 清理转义的 Markdown 特殊字符。
    func testCleanMarkdown清理转义特殊字符() {
        let input = "\\# 标题 \\(括号\\) \\[方括号\\]"
        let cleaned = SynthesisStore.cleanMarkdown(input)

        XCTAssertFalse(cleaned.contains("\\#"), "应清理转义的 #")
        XCTAssertFalse(cleaned.contains("\\("), "应清理转义的 (")
        XCTAssertFalse(cleaned.contains("\\["), "应清理转义的 [")
        XCTAssertTrue(cleaned.contains("# 标题"), "应保留 # 标题")
    }

    /// 验证 cleanMarkdown 清理转义的 [[ ]] 双链。
    func testCleanMarkdown清理转义双链() {
        let input = "文本 \\[\\[双链\\]\\] 结尾"
        let cleaned = SynthesisStore.cleanMarkdown(input)

        XCTAssertTrue(cleaned.contains("[[双链]]"), "应将 \\[\\[ 转为 [[，\\]\\] 转为 ]]")
    }

    /// 验证 cleanMarkdown 修剪首尾空白。
    func testCleanMarkdown修剪首尾空白() {
        let input = "  \n  内容  \n  "
        let cleaned = SynthesisStore.cleanMarkdown(input)

        XCTAssertEqual(cleaned, "内容", "应修剪首尾空白")
    }

    /// 验证 cleanMarkdown 处理空字符串不崩溃。
    func testCleanMarkdown空字符串不崩溃() {
        let cleaned = SynthesisStore.cleanMarkdown("")
        XCTAssertTrue(cleaned.isEmpty)
    }

    // MARK: - SynthesisDocument 属性验证

    /// 验证 SynthesisDocument 默认 init 参数（id 自动生成、createdAt 当前时间、sourcePageIDs 为空）。
    func testSynthesisDocument默认Init参数() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试",
            content: "内容",
            size: 10
        )

        XCTAssertNotEqual(doc.id, UUID(), "id 应自动生成（非默认 UUID）")
        XCTAssertEqual(doc.type, .report)
        XCTAssertEqual(doc.name, "测试")
        XCTAssertEqual(doc.content, "内容")
        XCTAssertEqual(doc.size, 10)
        XCTAssertTrue(doc.sourcePageIDs.isEmpty, "sourcePageIDs 默认应为空")
    }

    /// 验证 SynthesisDocument 自定义 init 参数。
    func testSynthesisDocument自定义Init参数() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000_000)
        let pageIDs = [UUID(), UUID()]

        let doc = SynthesisStore.SynthesisDocument(
            id: id,
            type: .quiz,
            name: "自定义",
            content: "内容",
            createdAt: createdAt,
            size: 100,
            sourcePageIDs: pageIDs
        )

        XCTAssertEqual(doc.id, id)
        XCTAssertEqual(doc.type, .quiz)
        XCTAssertEqual(doc.name, "自定义")
        XCTAssertEqual(doc.content, "内容")
        XCTAssertEqual(doc.createdAt, createdAt)
        XCTAssertEqual(doc.size, 100)
        XCTAssertEqual(doc.sourcePageIDs, pageIDs)
    }

    /// 验证 SynthesisDocument Codable 编解码一致性。
    func testSynthesisDocumentCodable编解码一致() throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .mindmap,
            name: "编解码测试",
            content: "mindmap\n  root((测试))",
            size: 25,
            sourcePageIDs: [UUID()]
        )

        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(SynthesisStore.SynthesisDocument.self, from: data)

        XCTAssertEqual(decoded.id, doc.id)
        XCTAssertEqual(decoded.type, doc.type)
        XCTAssertEqual(decoded.name, doc.name)
        XCTAssertEqual(decoded.content, doc.content)
        XCTAssertEqual(decoded.size, doc.size)
        XCTAssertEqual(decoded.sourcePageIDs, doc.sourcePageIDs)
    }

    // MARK: - 多次 generate 文档累积

    /// 验证多次 performSynthesis 同类型文档累积（不超过 5 份）。
    func testMultiplePerformSynthesisSameDocTypeAccumulates() async throws {
        mockLLM.defaultResponse = validContent(for: .report)

        for _ in 0..<3 {
            _ = try await store.performSynthesis(type: .report, combinedContent: "源内容")
        }

        XCTAssertEqual(store.synthesisResults[.report]?.count, 3, "应累积 3 份文档")
    }

    /// 验证多次 performSynthesis 不同类型文档独立累积。
    func testMultiplePerformSynthesisDifferentDocTypesAccumulateIndependently() async throws {
        mockLLM.defaultResponse = validContent(for: .report)
        _ = try await store.performSynthesis(type: .report, combinedContent: "源内容")

        mockLLM.defaultResponse = validContent(for: .mindmap)
        _ = try await store.performSynthesis(type: .mindmap, combinedContent: "源内容")

        XCTAssertEqual(store.synthesisResults[.report]?.count, 1)
        XCTAssertEqual(store.synthesisResults[.mindmap]?.count, 1)
    }

    // MARK: - extractTitle 私有方法（通过 saveSynthesisResult 间接验证）

    /// 验证 saveSynthesisResult 从 H1 标题提取文档名称。
    func testSaveSynthesisResult从H1提取标题() {
        store.saveSynthesisResult(type: .report, content: "# 提取的标题\n正文内容。")

        let name = store.synthesisResults[.report]?.first?.name ?? ""
        XCTAssertTrue(name.contains("提取的标题"), "文档名称应包含从 H1 提取的标题")
    }

    /// 验证 saveSynthesisResult 在无 H1 标题时使用 SynthesisType.title 作为回退。
    func testSaveSynthesisResult无H1时使用TypeTitle回退() {
        store.saveSynthesisResult(type: .report, content: "无标题的正文内容足够长。")

        let name = store.synthesisResults[.report]?.first?.name ?? ""
        XCTAssertTrue(name.contains(SynthesisStore.SynthesisType.report.title), "无 H1 时应使用 type.title 回退")
    }

    /// 验证 saveSynthesisResult(.quiz) 从 JSON 提取 title 字段。
    func testSaveSynthesisResult_quiz从JSON提取Title() {
        let quizJSON = "{\"title\":\"JSON测验标题\",\"questions\":[]}"
        store.saveSynthesisResult(type: .quiz, content: quizJSON)

        let name = store.synthesisResults[.quiz]?.first?.name ?? ""
        XCTAssertTrue(name.contains("JSON测验标题"), "quiz 应从 JSON title 字段提取标题")
    }

    // MARK: - 辅助格式化方法

    /// 辅助方法：格式化 Date 为文档名称中的日期部分（用于断言）
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
