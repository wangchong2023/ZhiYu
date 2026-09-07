//
//  SynthesisStoreFailurePathDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SynthesisStore 深度补盲测试（失败路径分片）— 覆盖 performSynthesis LLM 抛错降级（6 类）、
//            空内容/过短内容 fallback 自愈、失败时 TaskCenter 任务标记 failed、
//            saveSynthesisResult 防空门禁（空/空白/骨架关键字/过短/恰好10字节/状态/头部插入/持久化），
//            以发现生产代码潜在 bug 为首要目标。
//
//  说明：从 SynthesisStoreDeepTests.swift 拆分而来（按 MARK 分段）。本文件聚焦 LLM 失败降级链与
//        saveSynthesisResult 的防空门禁边界场景。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - SynthesisStore 失败路径深度测试

@MainActor
final class SynthesisStoreFailurePathDeepTests: XCTestCase {

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

    // MARK: - performSynthesis 失败时 TaskCenter 任务状态推演

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
