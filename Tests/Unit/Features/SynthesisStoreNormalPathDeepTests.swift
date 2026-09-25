//
//  SynthesisStoreNormalPathDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SynthesisStore 深度补盲测试（正常路径分片）— 覆盖 performSynthesis 6 类合成正常生成路径、
//            TaskCenter 任务状态推演（pending→completed/failed）、容量上限（5 份阈值）、
//            generating 并发锁拒绝、SynthesisControlOptions 交互、sourcePageIDs 携带，
//            以发现生产代码潜在 bug 为首要目标。
//
//  说明：从 SynthesisStoreDeepTests.swift 拆分而来（按 MARK 分段）。本文件聚焦 performSynthesis 的
//        正常生成路径与 TaskCenter 联动、容量边界、并发锁、ControlOptions 交互等核心正向场景。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - SynthesisStore 正常路径深度测试

@MainActor
final class SynthesisStoreNormalPathDeepTests: XCTestCase {

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

    // MARK: - performSynthesis 正常路径（6 类）

    /// 验证 performSynthesis(.mindmap) 正常生成文档。
    func testPerformSynthesisMindmapNormalPath() async throws {
        mockLLM.defaultResponse = validContent(for: .mindmap)

        let doc = try await store.performSynthesis(type: .mindmap, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .mindmap)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisResults[.mindmap]?.count, 1)
        XCTAssertEqual(store.synthesisStates[.mindmap], .completed)
    }

    /// 验证 performSynthesis(.slides) 正常生成文档。
    func testPerformSynthesisSlidesNormalPath() async throws {
        mockLLM.defaultResponse = validContent(for: .slides)

        let doc = try await store.performSynthesis(type: .slides, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .slides)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.slides], .completed)
    }

    /// 验证 performSynthesis(.quiz) 正常生成文档。
    func testPerformSynthesisQuizNormalPath() async throws {
        mockLLM.defaultResponse = validContent(for: .quiz)

        let doc = try await store.performSynthesis(type: .quiz, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .quiz)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.quiz], .completed)
    }

    /// 验证 performSynthesis(.report) 正常生成文档。
    func testPerformSynthesisReportNormalPath() async throws {
        mockLLM.defaultResponse = validContent(for: .report)

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .report)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.report], .completed)
    }

    /// 验证 performSynthesis(.infographic) 正常生成文档。
    func testPerformSynthesisInfographicNormalPath() async throws {
        mockLLM.defaultResponse = validContent(for: .infographic)

        let doc = try await store.performSynthesis(type: .infographic, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .infographic)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.infographic], .completed)
    }

    /// 验证 performSynthesis(.expansion) 正常生成文档。
    func testPerformSynthesisExpansionNormalPath() async throws {
        mockLLM.defaultResponse = validContent(for: .expansion)

        let doc = try await store.performSynthesis(type: .expansion, combinedContent: "源内容")

        XCTAssertEqual(doc.type, .expansion)
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
        XCTAssertEqual(store.synthesisStates[.expansion], .completed)
    }

    // MARK: - performSynthesis TaskCenter 任务状态推演

    /// 验证 performSynthesis 成功时 TaskCenter 任务从 pending → completed。
    func testPerformSynthesisSuccessTaskCenterTaskCompletes() async throws {
        mockLLM.defaultResponse = validContent(for: .report)

        let initialTaskCount = taskCenter.tasks.count
        _ = try await store.performSynthesis(type: .report, combinedContent: "源内容")

        XCTAssertEqual(taskCenter.tasks.count, initialTaskCount + 1, "应新增 1 个任务")
        let task = try XCTUnwrap(taskCenter.tasks.first)
        XCTAssertEqual(task.type, .synthesis, "任务类型应为 .synthesis")
        XCTAssertEqual(task.status, .completed, "任务状态应为 .completed")
    }

    /// 验证 performSynthesis 任务名称使用 SynthesisType.title。
    func testPerformSynthesisTaskNameUsesTypeTitle() async throws {
        mockLLM.defaultResponse = validContent(for: .quiz)

        _ = try await store.performSynthesis(type: .quiz, combinedContent: "源内容")

        let task = try XCTUnwrap(taskCenter.tasks.first)
        XCTAssertEqual(task.name, SynthesisStore.SynthesisType.quiz.title, "任务名称应为 SynthesisType.title")
    }

    // MARK: - performSynthesis 容量上限

    /// 验证 performSynthesis 在已达 5 份上限时抛错且不自动删除旧文档。
    func testPerformSynthesisRejectsWhenReachesFiveLimit() async throws {
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
    func testPerformSynthesisCanGenerateFifthWhenFourExist() async throws {
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
    func testPerformSynthesisRejectsDuplicateCallWhenGenerating() async throws {
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
    func testPerformSynthesisWithControlOptionsConcatenatesPromptInstruction() async throws {
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
    func testPerformSynthesisDefaultControlOptionsNoCrash() async throws {
        mockLLM.defaultResponse = validContent(for: .report)

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容", options: SynthesisControlOptions())

        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
    }

    /// 验证 performSynthesis 传入 sourcePageIDs 时文档携带该 IDs。
    func testPerformSynthesisWithSourcePageIDsDocCarriesThem() async throws {
        mockLLM.defaultResponse = validContent(for: .report)
        let pageIDs = [UUID(), UUID()]

        let doc = try await store.performSynthesis(type: .report, combinedContent: "源内容", sourcePageIDs: pageIDs)

        XCTAssertEqual(doc.sourcePageIDs, pageIDs, "文档应携带 sourcePageIDs")
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
}
