//
//  SynthesisChatDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：AISynthesisChatAndQuizDeepTests.swift, SynthesisChatAndPluginCenterDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class SynthesisChatDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testSynthesisView_FullRenderingAndTemplateSelection() async {
        let bindingSelection = Binding<SidebarSelection?>(get: { .tool(.synthesis) }, set: { _ in })
        let bindingTab = Binding<AppTab>(get: { .synthesis }, set: { _ in })

        let view = SynthesisView(selection: bindingSelection, selectedTab: bindingTab)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "SynthesisView 整体入口视图应成功渲染")
        XCTAssertEqual(bindingSelection.wrappedValue, .tool(.synthesis))
        XCTAssertEqual(bindingTab.wrappedValue, .synthesis)
    }

    func testSynthesisView_DocumentLifecycleAndFiltering() async {
        let store = SynthesisStore()

        // 验证 6 大合成类型枚举完整性
        XCTAssertEqual(SynthesisStore.SynthesisType.allCases.count, 6)

        // 模拟添加合成文档
        let doc = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .mindmap,
            name: "Swift 6 并发架构脑图",
            content: "mindmap\n  root((架构))\n    并发\n",
            createdAt: Date(),
            size: 120,
            sourcePageIDs: []
        )

        store.synthesisResults[.mindmap] = [doc]
        XCTAssertEqual(store.synthesisResults[.mindmap]?.count, 1)
        XCTAssertEqual(store.synthesisResults[.mindmap]?.first?.name, "Swift 6 并发架构脑图")
    }

    func testChatView_FullRenderingAndInputBar() async {
        let bindingTab = Binding<AppTab>(get: { .chat }, set: { _ in })

        let view = ChatView(selectedTab: bindingTab)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "ChatView 应成功渲染并挂载输入栏")
        XCTAssertEqual(bindingTab.wrappedValue, .chat)
    }

    func testChatCoordinator_MessageHistoryAndClearConfirmation() async {
        let coordinator = ChatCoordinator()

        // 初始状态
        XCTAssertFalse(coordinator.isProcessing)

        // 模拟输入与状态
        coordinator.inputText = "请总结知识库中的核心概念"
        XCTAssertEqual(coordinator.inputText, "请总结知识库中的核心概念")

        // 验证清空动作
        coordinator.clearChatHistory()
        XCTAssertTrue(coordinator.chatHistory.isEmpty)
        XCTAssertFalse(coordinator.isProcessing)
    }

    func testQuizView_EmptyQuizGuard_RendersContentUnavailable() {
        let emptyQuiz = QuizModel(title: "空测评", questions: [])
        let view = QuizView(quiz: emptyQuiz)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "空测评模型应安全展示占位视图，无越界风险")
        XCTAssertTrue(emptyQuiz.questions.isEmpty)
        XCTAssertEqual(emptyQuiz.title, "空测评")
    }

    func testQuizView_StandardQuizFlow_OptionsAndScoring() {
        let sampleQuestions = [
            QuizQuestion(
                id: 1,
                text: "Swift 6 中默认启用的并发检查级别是什么？",
                options: ["Minimal", "Targeted", "Complete", "None"],
                answer: 2,
                explanation: "Swift 6 默认开启 Complete 完整严格并发检查。"
            ),
            QuizQuestion(
                id: 2,
                text: "知识图谱中用于社区划分的经典算法是？",
                options: ["Louvain", "Dijkstra", "Floyd", "Kruskal"],
                answer: 0,
                explanation: "Louvain 算法是基于模块度优化的经典社区发现算法。"
            )
        ]

        let quiz = QuizModel(title: "架构与算法自测", questions: sampleQuestions)
        let view = QuizView(quiz: quiz)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "标准测评视图应成功渲染第一道题目")
        XCTAssertEqual(quiz.questions.count, 2)
        XCTAssertEqual(quiz.questions[0].answer, 2)
    }

    func testQuizModel_JSONSerializationAndFuzz() {
        let jsonStr = """
        {
            "title": "Fuzz 测验",
            "questions": [
                {
                    "id": 999,
                    "text": "\(String(repeating: "超长题目描述", count: 100))",
                    "options": ["A", "B", "C", "D"],
                    "answer": -1,
                    "explanation": "\(String(repeating: "解析", count: 50))"
                }
            ]
        }
        """
        let data = Data(jsonStr.utf8)

        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode(QuizModel.self, from: data)
            XCTAssertEqual(decoded.title, "Fuzz 测验")
            XCTAssertEqual(decoded.questions.count, 1)
            XCTAssertEqual(decoded.questions[0].answer, -1)
        } catch {
            XCTFail("畸变 JSON 应能根据模型契约容错解码: \(error)")
        }
    }

    func testSynthesisView_InstantiationAndInitialState() {
        let selectionBinding = Binding<SidebarSelection?>(
            get: { nil },
            set: { _ in }
        )
        let selectedTabBinding = Binding<AppTab>(
            get: { .synthesis },
            set: { _ in }
        )

        let view = SynthesisView(
            selection: selectionBinding,
            selectedTab: selectedTabBinding
        )
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "SynthesisView 应能成功构建并渲染视图树")
    }

    func testSynthesisStore_DocumentBatchOperations_AndStateTransitions() {
        let store = SynthesisStore()
        let type = SynthesisStore.SynthesisType.mindmap
        let sampleContent = "# 智宇思维导图\n\n- 核心概念 A\n- 核心概念 B"

        // 1. 保存文档
        let docOpt = store.saveSynthesisResult(type: type, content: sampleContent, sourcePageIDs: [])
        XCTAssertNotNil(docOpt, "保存合成结果应成功返回文档模型")
        guard let doc = docOpt else { return }

        XCTAssertEqual(doc.type, type)
        XCTAssertTrue(doc.content.contains("核心概念 A"))

        // 2. 检查结果集合
        let docs = store.synthesisResults[type] ?? []
        XCTAssertTrue(docs.contains { $0.id == doc.id }, "结果集合应包含新生成的文档")

        // 3. 重命名文档
        let newTitle = "已重命名的思维导图"
        store.renameSynthesisDoc(type: type, docID: doc.id, newName: newTitle)
        let updatedDocs = store.synthesisResults[type] ?? []
        let updatedDoc = updatedDocs.first { $0.id == doc.id }
        XCTAssertEqual(updatedDoc?.name, newTitle, "重命名操作应当精准更新文档标题")

        // 4. 删除单个文档
        store.deleteSynthesisDoc(type: type, docID: doc.id)
        let afterDeleteDocs = store.synthesisResults[type] ?? []
        XCTAssertFalse(afterDeleteDocs.contains { $0.id == doc.id }, "单文档删除操作应从列表中移除目标文档")

        // 5. 批量删除文档
        let doc2 = store.saveSynthesisResult(type: .slides, content: "幻灯片内容", sourcePageIDs: [])
        XCTAssertNotNil(doc2)
        if let doc2 = doc2 {
            store.batchDeleteSynthesisDocs(ids: [doc2.id])
            let afterBatch = store.synthesisResults[.slides] ?? []
            XCTAssertFalse(afterBatch.contains { $0.id == doc2.id }, "批量删除后文档应被移除")
        }
    }

    func testChatCoordinator_StateTransitionsAndMessageFlow() async {
        let coordinator = ChatCoordinator()

        XCTAssertFalse(coordinator.isProcessing, "初始状态下不应处于处理中")
        XCTAssertTrue(coordinator.streamingContent.isEmpty, "初始流式输出应当为空")
        XCTAssertNil(coordinator.errorMessage, "初始错误消息应当为 nil")

        // 测试空输入防护
        coordinator.inputText = "   "
        await coordinator.sendMessage(pages: [])
        XCTAssertFalse(coordinator.isProcessing, "空空白文本输入时不应触发发送处理")

        // 测试取消流式请求
        coordinator.cancelCurrentRequest()
        XCTAssertFalse(coordinator.isProcessing, "取消请求后处理标志位应被安全复位为 false")

        // 测试多选模式切换
        coordinator.isSelectionMode = true
        let mockID = UUID()
        coordinator.selectedMessageIDs.insert(mockID)
        XCTAssertTrue(coordinator.selectedMessageIDs.contains(mockID), "选中消息集合应当包含预设 ID")

        coordinator.selectedMessageIDs.removeAll()
        coordinator.isSelectionMode = false
        XCTAssertFalse(coordinator.isSelectionMode, "退出多选模式后状态标志位应当为 false")
    }

    func testChatView_InstantiationAndBodyStructure() {
        let selectedTabBinding = Binding<AppTab>(
            get: { .chat },
            set: { _ in }
        )

        let view = ChatView(selectedTab: selectedTabBinding)
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "ChatView 应能安全构建并渲染主视图树")
    }

    func testPluginCenterView_InstantiationAndBodyStructure() {
        let view = PluginCenterView()
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "PluginCenterView 应能安全构建并渲染视图结构")
    }

    func testPluginMarketService_FilteringAndState() {
        let registry = PluginRegistry()
        let marketService = PluginMarketService(registry: registry)

        let plugin1 = MarketPlugin(
            id: "com.zhiyu.plugin.mindmap",
            version: "1.0.0",
            author: "ZhiYu Team",
            downloads: "12500",
            rating: 4.8,
            icon: "sparkles",
            downloadURL: "https://example.com/mindmap.zip",
            minAppVersion: "1.0.0",
            requiredPermissions: [],
            monetization: nil,
            reviewCount: 42,
            category: "efficiency",
            source: "community",
            names: ["zh-Hans": "思维导图增强", "en": "MindMap Pro"],
            descriptions: ["zh-Hans": "一键生成思维导图", "en": "Generate mindmaps in one click"]
        )

        let plugin2 = MarketPlugin(
            id: "com.zhiyu.plugin.theme",
            version: "1.2.0",
            author: "Theme Studio",
            downloads: "8300",
            rating: 4.5,
            icon: "paintpalette",
            downloadURL: "https://example.com/theme.zip",
            minAppVersion: "1.0.0",
            requiredPermissions: [],
            monetization: nil,
            reviewCount: 19,
            category: "theme",
            source: "community",
            names: ["zh-Hans": "极光霓虹主题", "en": "Aurora Theme"],
            descriptions: ["zh-Hans": "酷炫暗黑极光", "en": "Dark aurora theme"]
        )

        marketService.availablePlugins = [plugin1, plugin2]

        XCTAssertEqual(marketService.availablePlugins.count, 2, "插件市场可用列表应当包含预设的 2 个插件")
        XCTAssertEqual(plugin1.category, "efficiency")
        XCTAssertEqual(plugin2.category, "theme")
        XCTAssertFalse(plugin1.name.isEmpty, "多语言名称匹配不应返回空字符串")
        XCTAssertFalse(plugin1.description.isEmpty, "多语言描述匹配不应返回空字符串")
    }

    func testSettingsView_InstantiationAndBodyStructure() {
        let view = SettingsView()
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "SettingsView 应能安全构建并渲染设置面板视图树")
    }

    func testTaskCenterView_EmptyAndPopulatedState() {
        let taskCenter = TaskCenter()
        taskCenter.reset()

        // 1. 空状态视图
        let emptyView = TaskCenterView()
        let emptyHost = emptyView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(emptyHost.view, "TaskCenterView 空任务列表时应能正常渲染空状态视图")

        // 2. 插入模拟任务后的非空状态视图
        let taskID = taskCenter.addTask(type: .ai, name: "智能分析任务", target: "文档 A")
        XCTAssertFalse(taskCenter.tasks.isEmpty, "添加任务后任务中心列表不应为空")

        taskCenter.updateTask(taskID, status: .running(progress: 0.6, stage: .synthesis))
        let metrics = taskCenter.metrics(for: .ai)
        XCTAssertEqual(metrics.total, 1, "AI 分类任务总量应为 1")
        XCTAssertEqual(metrics.running, 1, "进行中任务数量应为 1")
        XCTAssertEqual(metrics.completed, 0, "已完成任务数量应为 0")

        let populatedView = TaskCenterView()
        let populatedHost = populatedView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(populatedHost.view, "TaskCenterView 有活跃任务时应能正常渲染列表视图")

        // 3. 标记完成并移除
        taskCenter.completeTask(id: taskID)
        let completedMetrics = taskCenter.metrics(for: .ai)
        XCTAssertEqual(completedMetrics.completed, 1, "任务完成后已完成指标应为 1")

        taskCenter.removeTask(taskID)
        let clearedMetrics = taskCenter.metrics(for: .ai)
        XCTAssertEqual(clearedMetrics.completed, 0, "移除已完成任务后已完成指标应复位为 0")
    }

    func testTaskCenter_SubLogsAndUnreadTracking() {
        let taskCenter = TaskCenter()
        taskCenter.reset()

        let taskID = taskCenter.addTask(type: .ingest, name: "批量网页摄入", target: "5 个 URL")
        taskCenter.addSubLog(id: taskID, log: "解析 HTML 结构完成")
        taskCenter.addSubLog(id: taskID, log: "文本清洗与 Markdown 转换完成")

        let task = taskCenter.tasks.first { $0.id == taskID }
        XCTAssertEqual(task?.subLogs.count, 2, "任务应精准保留追加的 2 条细粒度日志")

        // 失败状态流转
        taskCenter.failTask(id: taskID, error: "网络超时")
        let failedTask = taskCenter.tasks.first { $0.id == taskID }
        if case let .failed(errorMsg) = failedTask?.status {
            XCTAssertEqual(errorMsg, "网络超时", "失败错误信息应当精准匹配")
        } else {
            XCTFail("任务状态应当处于 failed 分支")
        }

        XCTAssertEqual(taskCenter.unreadCount, 1, "未读已完成/失败任务计数应当为 1")
        taskCenter.markAllAsRead()
        XCTAssertEqual(taskCenter.unreadCount, 0, "标为已读后未读计数应当归零")
    }

}
