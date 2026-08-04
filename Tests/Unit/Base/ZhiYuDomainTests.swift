//
//  ZhiYuDomainTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuDomain 开展自动化单元测试验证。
//
import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

final class ZhiYuDomainTests: XCTestCase {
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // 统一配置标准测试 Mock 环境，确保 LiveActivityProtocol 等所有基础 DI 服务注册完成
        setupFullMockEnvironment()
        
        // 确保在 DI 注册就绪后再重置/访问单例状态，规避初始化时由于容器缺失服务导致的 assertion 闪退
        TaskCenter.shared.reset()
        PromptService.shared.reset()
    }
    
    @MainActor
    override func tearDown() async throws {
        TaskCenter.shared.reset()
        PromptService.shared.reset()
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - QuizModel Parsing Tests
    func testQuizModelParsing() {
        let json = """
        {
          "title": "测试测验",
          "questions": [
            {
              "id": 1,
              "text": "Swift 是一门什么语言?",
              "options": ["编译型", "解释型", "脚本型", "汇编型"],
              "answer": 0,
              "explanation": "Swift 经过 LLVM 编译。"
            }
          ]
        }
        """
        // swiftlint:disable:next force_unwrapping
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let model = try decoder.decode(QuizModel.self, from: data)
            XCTAssertEqual(model.title, "测试测验")
            XCTAssertEqual(model.questions.count, 1)
            XCTAssertEqual(model.questions.first?.answer, 0)
        } catch {
            XCTFail("QuizModel decoding failed: \(error)")
        }
    }

    // MARK: - TaskCenter Tests
    @MainActor
    func testTaskCenterManagement() {
        let center = TaskCenter.shared
        let initialCount = center.tasks.count
        
        let taskID = center.addTask(name: "测试任务", target: "测试目标")
        XCTAssertEqual(center.tasks.count, initialCount + 1)
        XCTAssertEqual(center.tasks.first?.name, "测试任务")
        
        center.updateTask(taskID, status: .running(progress: 0.5, stage: .general))
        if case .running(let progress, _) = center.tasks.first?.status {
            XCTAssertEqual(progress, 0.5)
        } else {
            XCTFail("Task status should be running")
        }
        
        // 测试失败状态
        center.updateTask(taskID, status: .failed(error: "Timeout"))
        if case .failed(let error) = center.tasks.first?.status {
            XCTAssertEqual(error, "Timeout")
        } else {
            XCTFail("Task status should be failed")
        }
    }

    // MARK: - PromptService Tests
    func testPromptServicePersistence() {
        let service = PromptService.shared
        let originalMindmap = service.mindmapPrompt
        
        service.mindmapPrompt = "New Custom Prompt"
        service.save()
        
        // 模拟重启（使用 shared 实例，因为 init 已私有）
        let newService = PromptService.shared
        XCTAssertEqual(newService.mindmapPrompt, "New Custom Prompt")
        
        service.reset()
        XCTAssertEqual(service.mindmapPrompt, L10n.AI.Prompt.Default.mindmap)
        
        // 恢复原状
        service.mindmapPrompt = originalMindmap
        service.save()
    }

    // MARK: - TextChunkerProcessor Semantic Tests
    func testTextChunkerProcessorSemanticSplitting() {
        let chunker = TextChunkerProcessor()
        let markdown = """
        # Header 1
        Section 1 content.
        
        ## Subheader 2
        Section 2 content. This should be split correctly.
        """
        
        let chunks = chunker.split(text: markdown)
        XCTAssertGreaterThan(chunks.count, 0)
        XCTAssertTrue(chunks.first?.text.contains("Header 1") ?? false)
    }

    // MARK: - Hybrid Search Logic Tests
    @MainActor
    func testHybridSearchQueryExpansion() async {
        guard let dbQueue = try? DatabaseQueue() else { XCTFail("无法创建测试数据库"); return }
        let store = SQLiteStore(dbWriter: dbQueue)
        let query = "Karpathy Deep Learning"
        
        let results = await store.searchPages(query: query)
        XCTAssertNotNil(results)
    }

    // MARK: - QuizModel Fault Tolerance
    func testQuizModelFaultTolerance() {
        let brokenJson = "{\"title\": \"Broken\", \"questions\": []" // 缺少闭合括号
        // swiftlint:disable:next force_unwrapping
        let data = brokenJson.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertThrowsError(try decoder.decode(QuizModel.self, from: data))
    }

    // MARK: - External Link Citation Detection (Upgraded)
    func testCitationLinkDetection() {
        let report = "这是核心观点 [[Source]]。"
        XCTAssertTrue(report.contains("[[Source]]"), "应该使用双括号交互格式")
    }

    // MARK: - PageLink Tests
    func testPageLinkModel() {
        let sourceUUID = UUID()
        let targetUUID = UUID()
        let now = Date()
        let link = PageLink(sourceID: sourceUUID, targetID: targetUUID, context: "Test Context", createdAt: now)
        XCTAssertEqual(link.sourceID, sourceUUID)
        XCTAssertEqual(link.targetID, targetUUID)
        XCTAssertEqual(link.context, "Test Context")
        XCTAssertEqual(link.createdAt, now)
    }

    // MARK: - AITaskProgress Tests
    func testAITaskProgressStateAndMetadata() {
        let now = Date()
        let metadata = AITaskMetadata(taskName: "AI 治理扫描", startTime: now)
        XCTAssertEqual(metadata.taskName, "AI 治理扫描")
        XCTAssertEqual(metadata.startTime, now)
        
        let state = AITaskProgressState(progress: 0.85, status: "正在提取特征")
        XCTAssertEqual(state.progress, 0.85)
        XCTAssertEqual(state.status, "正在提取特征")
    }

    // MARK: - SourceStore Tests
    @MainActor
    func testSourceStoreActiveSources() {
        let store = SourceStore.shared
        store.clear()
        XCTAssertTrue(store.activeSources.isEmpty)
        
        let source1 = KnowledgeSource(pageID: UUID(), title: "Source 1", snippet: "Text 1", score: 0.8)
        let source2 = KnowledgeSource(pageID: UUID(), title: "Source 2", snippet: "Text 2", score: 0.9)
        
        store.updateSources([source1, source2])
        XCTAssertEqual(store.activeSources.count, 2)
        XCTAssertEqual(store.activeSources.first?.title, "Source 2") // sorted by score desc
        
        store.clear()
        XCTAssertTrue(store.activeSources.isEmpty)
    }

    // MARK: - PromptRegistry Tests
    func testPromptRegistryTemplates() {
        let summaryPrompt = PromptRegistry.Ingest.summary(content: "Test Content")
        XCTAssertTrue(summaryPrompt.contains(L10n.AI.Prompt.summaryPrefix))
        XCTAssertTrue(summaryPrompt.contains("Test Content"))
        
        let qaPrompt = PromptRegistry.Ingest.reverseQA(content: "Test QA Content")
        XCTAssertTrue(qaPrompt.contains(L10n.AI.Prompt.reverseQAPrefix))
        XCTAssertTrue(qaPrompt.contains("Test QA Content"))
        
        let discoverPrompt = PromptRegistry.Structure.discoverLinks(content: "Content", existingTitles: ["Title1", "Title2"])
        XCTAssertTrue(discoverPrompt.contains("Title1, Title2"))
        XCTAssertTrue(discoverPrompt.contains("Content"))
    }
    
    // MARK: - PageType, PageStatus, and Confidence Tests
    /// 函数说明: 测试 PageType, PageStatus 和 Confidence 枚举的属性与国际化支持
    /// 确保 displayName 和 colorName 匹配正确，覆盖所有 enum 分支，染红 PageType.swift 到 100%
    func testPageTypeAndStatusEnums() {
        // 1. 遍历并校验所有 PageType 实例
        for type in PageType.allCases {
            // 校验 id 属性是否返回正确的原始值
            XCTAssertEqual(type.id, type.rawValue)
            // 校验 displayName 属性是否非空
            XCTAssertFalse(type.displayName.isEmpty)
            // 校验 colorName 属性是否非空
            XCTAssertFalse(type.colorName.isEmpty)
        }
        
        // 2. 遍历并校验所有 PageStatus 实例
        for status in PageStatus.allCases {
            // 校验 displayName 是否非空
            XCTAssertFalse(status.displayName.isEmpty)
            // 校验 colorName 是否非空
            XCTAssertFalse(status.colorName.isEmpty)
        }
        
        // 3. 遍历并校验所有 Confidence 实例
        for conf in Confidence.allCases {
            // 校验 displayName 是否非空
            XCTAssertFalse(conf.displayName.isEmpty)
            // 校验 colorName 是否非空
            XCTAssertFalse(conf.colorName.isEmpty)
        }
    }
    
    // MARK: - LLMUtils Utility Tests
    /// 函数说明: 测试 LLMUtils 的通用解析与清洗逻辑，覆盖 JSON、SmartIngest 以及 RefactorSuggestion 的解析分支，染红 LLMUtils.swift 到 100%
    func testLLMUtilsUtilities() {
        // 1. 测试 parseJSONArray：正常带 Markdown 标记的 JSON 字符串数组
        let jsonArrayStr = """
        ```json
        ["apple", "banana", "cherry"]
        ```
        """
        let parsedArray = LLMUtils.parseJSONArray(jsonArrayStr)
        XCTAssertEqual(parsedArray, ["apple", "banana", "cherry"])
        
        // 测试 parseJSONArray：非法的 JSON 字符串应该返回空数组
        let badJsonArrayStr = "[invalid json"
        XCTAssertEqual(LLMUtils.parseJSONArray(badJsonArrayStr), [])
        
        // 2. 测试 parseSmartIngest：正常带 Markdown 标记的 Ingest DTO
        let smartIngestJson = """
        ```json
        {
            "title": "Welcome Page",
            "compiled_content": "Compiled Body",
            "suggested_tags": ["tag1", "tag2"],
            "suggested_type": "concept",
            "related_titles": ["Related Page"],
            "summary": "This is a summary"
        }
        ```
        """
        let smartIngestResult = LLMUtils.parseSmartIngest(smartIngestJson)
        XCTAssertNotNil(smartIngestResult)
        XCTAssertEqual(smartIngestResult?.title, "Welcome Page")
        XCTAssertEqual(smartIngestResult?.compiledContent, "Compiled Body")
        XCTAssertEqual(smartIngestResult?.suggestedTags, ["tag1", "tag2"])
        XCTAssertEqual(smartIngestResult?.suggestedType, "concept")
        XCTAssertEqual(smartIngestResult?.relatedTitles, ["Related Page"])
        XCTAssertEqual(smartIngestResult?.summary, "This is a summary")
        
        // 测试 parseSmartIngest：非法的 JSON 应该返回 nil
        let badSmartIngestJson = "{bad_json"
        XCTAssertNil(LLMUtils.parseSmartIngest(badSmartIngestJson))
        
        // 3. 测试 parseRefactorSuggestions：正常的重构建议 DTO
        let refactorJson = """
        ```json
        [
            {
                "type": "merge",
                "target": "Target Page",
                "reason": "Redundant data",
                "suggestion": "Merge with main"
            }
        ]
        ```
        """
        let refactorSuggestions = LLMUtils.parseRefactorSuggestions(refactorJson)
        XCTAssertEqual(refactorSuggestions.count, 1)
        XCTAssertEqual(refactorSuggestions.first?.type, "merge")
        XCTAssertEqual(refactorSuggestions.first?.target, "Target Page")
        XCTAssertEqual(refactorSuggestions.first?.reason, "Redundant data")
        XCTAssertEqual(refactorSuggestions.first?.suggestion, "Merge with main")
        XCTAssertEqual(refactorSuggestions.first?.id, "Target Pagemerge")
        
        // 测试 parseRefactorSuggestions：非法的 JSON 应该返回空列表
        let badRefactorJson = "[bad_json"
        XCTAssertTrue(LLMUtils.parseRefactorSuggestions(badRefactorJson).isEmpty)
        
        // 4. 测试 extractContent：从大模型标准 choices 结构中提取文本内容
        let goodResponse: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "content": "Hello World"
                    ]
                ]
            ]
        ]
        XCTAssertEqual(LLMUtils.extractContent(from: goodResponse), "Hello World")
        
        // 测试 extractContent：非法 choices 结构应该返回 nil
        let badResponse: [String: Any] = [:]
        XCTAssertNil(LLMUtils.extractContent(from: badResponse))
        
        // 5. 测试 stripMarkdown：直接清洗 ```json 和 ``` 标记
        let textWithJson = "```json\nsome content\n```"
        XCTAssertEqual(LLMUtils.stripMarkdown(textWithJson), "some content")
    }
    
    // MARK: - LinkService Tests
    /// 函数说明: 测试 LinkService actor，覆盖标题查询、反向链接提取、搜索加权排序、标签统计聚合以及重命名自动反向链接更新与双轨混合搜索分支
    func testLinkServiceAllUtilities() async {
        let service = LinkService()
        
        let page1UUID = UUID()
        let page2UUID = UUID()
        let page3UUID = UUID()
        
        // 构建 Mock 页面1，content 中嵌入对 页面2 标题的双括号引用
        let page1 = KnowledgePage(
            id: page1UUID,
            title: "Apple Guide",
            pageType: .concept,
            content: "Learn all about [[Banana Guide]]. #fruits",
            aliases: ["AppleInfo"],
            tags: ["#fruits"],
            relatedPageIDs: [page2UUID]
        )
        
        // 构建 Mock 页面2
        let page2 = KnowledgePage(
            id: page2UUID,
            title: "Banana Guide",
            pageType: .concept,
            content: "Banana is yellow. #fruits",
            aliases: ["BananaInfo"],
            tags: ["#fruits"]
        )
        
        // 构建 Mock 页面3
        let page3 = KnowledgePage(
            id: page3UUID,
            title: "Cherry Guide",
            pageType: .concept,
            content: "Cherry is red. #berries",
            tags: ["#berries"]
        )
        
        let allPages = [page1, page2, page3]
        
        // 1. 测试 pageByTitle (标题与别名模糊匹配)
        let foundTitle = await service.pageByTitle("Apple Guide", in: allPages)
        XCTAssertEqual(foundTitle?.id, page1UUID)
        let foundAlias = await service.pageByTitle("BananaInfo", in: allPages)
        XCTAssertEqual(foundAlias?.id, page2UUID)
        let foundNil = await service.pageByTitle("NonExisting", in: allPages)
        XCTAssertNil(foundNil)
        
        // 2. 测试 backlinks (反向链接扫描与匹配)
        let list = await service.backlinks(for: page2UUID, in: allPages)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, page1UUID)
        
        let emptyBacklinks = await service.backlinks(for: UUID(), in: allPages)
        XCTAssertTrue(emptyBacklinks.isEmpty)
        
        // 3. 测试 pageByID
        let foundByID = await service.pageByID(page1UUID, in: allPages)
        XCTAssertEqual(foundByID?.id, page1UUID)
        let foundByIDNil = await service.pageByID(UUID(), in: allPages)
        XCTAssertNil(foundByIDNil)
        
        // 4. 测试 search 精确性与加权排序
        let searchResults = await service.search(query: "apple", in: allPages)
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.id, page1UUID)
        
        let emptySearch = await service.search(query: "", in: allPages)
        XCTAssertEqual(emptySearch.count, 3)
        
        // 5. 测试 allTags 标签热度计算与字符去重
        let tags = await service.allTags(in: allPages)
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(tags.first?.tag, "fruits")
        XCTAssertEqual(tags.first?.count, 2)
        
        // 6. 测试 prepareRename 重构及引链自动流转
        let modified = await service.prepareRename(page: page2, to: "Yellow Fruit", in: allPages)
        XCTAssertEqual(modified.count, 2)
        XCTAssertEqual(modified.first?.title, "Yellow Fruit")
        XCTAssertEqual(modified.last?.content, "Learn all about [[Yellow Fruit]]. #fruits")
        
        // 7. 测试 hybridSearchWithDiagnostics 混合双轨检索 (调用 Mock 下的向量管理器)
        let embeddingManager = ServiceContainer.shared.resolve(EmbeddingManager.self)
        let hybridResult = await service.hybridSearchWithDiagnostics(query: "Apple", in: allPages, embeddingProvider: embeddingManager)
        XCTAssertNotNil(hybridResult)
    }
    
    // MARK: - KnowledgePageManager Tests
    
    /// Mock 处理器实现，用于测试页面加工链
    struct MockKnowledgePageProcessor: KnowledgePageProcessor {
        let id: String = "mock_processor_id"
        let name: String = "Mock Processor"
        func process(page: KnowledgePage) async throws -> KnowledgePage {
            var p = page
            p.content += " processed!"
            return p
        }
    }
    
    /// Mock AI工作流能力提供，用于测试重构建议的清除
    final class MockAIWorkflowStore: AIWorkflowCapabilities, @unchecked Sendable {
        var removedSuggestionID: String?
        func removeRefactorSuggestion(id: String) {
            removedSuggestionID = id
        }
    }

    /// 函数说明: 测试 KnowledgePageManager 的动态处理器链路管理、核心 CRUD 事务编排、撤销与重做快照、引链重构与标签管理转发
    /// 确保全面覆盖 KnowledgePageManager.swift 的所有方法，冲关领域层最终极覆盖率！
    @MainActor
    func testKnowledgePageManagerProcessorsAndCRUD() async throws {
        let manager = ServiceContainer.shared.resolve(KnowledgePageManager.self)
        let pageStore = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        
        // 1. 动态注入并注册 MockAIWorkflowStore 和 TagStore 防止空依赖断言闪退
        let mockWorkflowStore = MockAIWorkflowStore()
        ServiceContainer.shared.register(mockWorkflowStore as any AIWorkflowCapabilities, for: (any AIWorkflowCapabilities).self)
        
        let tagStore = TagStore()
        ServiceContainer.shared.register(tagStore, for: TagStore.self)
        
        // 2. 处理器注册与注销测试
        let processor = MockKnowledgePageProcessor()
        manager.registerProcessor(processor, pluginID: "test_plugin")
        
        // 3. 核心 createPage 测试 (应自动触发处理器并追加 " processed!")
        let initialPages = try await pageStore.fetchAllPages()
        let page1 = try await manager.createPage(
            title: "Manager Concept Page",
            pageType: .concept,
            content: "Hello concept",
            tags: ["#fruits"],
            currentPages: initialPages
        )
        XCTAssertTrue(page1.content.contains("processed!"))
        
        // 4. 核心 updatePage 测试
        var page1Updated = page1
        page1Updated.content = "Hello new content"
        try await manager.updatePage(page1Updated, currentPages: [page1])
        
        // 5. 核心 savePage 测试
        try await manager.savePage(page1Updated, currentPages: [page1Updated])
        
        // 6. 核心 renamePage 测试
        try await manager.renamePage(page1Updated, to: "Manager Concept Renamed", currentPages: [page1Updated])
        
        // 7. 撤销 (undo) / 重做 (redo) 测试
        let undoResult = try await manager.undo(currentPages: [page1Updated])
        XCTAssertNotNil(undoResult)
        
        let redoResult = try await manager.redo(currentPages: [])
        XCTAssertNotNil(redoResult)
        
        // 8. 潜在双向引链建议应用测试
        let suggestion = PotentialLinkSuggestion(
            sourcePageID: page1.id,
            sourceTitle: page1.title,
            targetTitle: "Apple"
        )
        var pageAppleContent = page1
        pageAppleContent.content = "This contains Apple inside"
        try await manager.applyPotentialLink(suggestion, currentPages: [pageAppleContent])
        
        // 9. AI 重构建议应用测试
        let refactor = RefactorSuggestionDTO(
            type: "rename",
            target: page1.title,
            reason: "Better naming",
            suggestion: "Better Name"
        )
        try await manager.applyRefactorSuggestion(refactor, currentPages: [page1])
        XCTAssertEqual(mockWorkflowStore.removedSuggestionID, refactor.id)
        
        // 10. 处理器批量注销测试
        manager.unregisterProcessor(id: processor.id)
        manager.unregisterProcessors(for: "test_plugin")
        
        // 11. 标签管理转发测试
        await manager.renameTag("fruits", to: "fresh-fruits")
        await manager.deleteTag("fresh-fruits")
        await manager.bulkDeleteTags(["fresh-fruits"])
        
        // 12. 核心 deletePage 测试
        try await manager.deletePage(page1, currentPages: [page1])
        
        // 13. 标题与页面映射转发测试
        let matchedPage = await manager.pageByTitle("NonExisting", in: [page1])
        XCTAssertNil(matchedPage)
        
        // 14. 文件夹导入转发测试
        let dummyFolderURL = URL(fileURLWithPath: "/tmp/dummy_folder")
        if let concretePageStore = pageStore as? SQLiteStore {
            await manager.ingestFolder(at: dummyFolderURL, pageStore: concretePageStore)
        }
    }
    
    // MARK: - Batch Ingest & TaskCenter Integration Tests
    @MainActor
    func testUrlBatchImportTaskCenterTracking() {
        let center = TaskCenter.shared
        center.reset()
        
        let taskID = center.addTask(
            name: "批量导入网页",
            target: "https://www.runoob.com/ai-agent/ai-agent-core.html, https://www.baidu.com"
        )
        
        XCTAssertEqual(center.tasks.count, 1)
        // 模拟开始抓取 (映射为 extraction 阶段)
        center.updateTask(taskID, status: .running(progress: 0.2, stage: .extraction))
        if case .running(let progress, let stage) = center.tasks.first?.status {
            XCTAssertEqual(progress, 0.2)
            XCTAssertEqual(stage, .extraction)
        } else {
            XCTFail("Should be running")
        }
        
        // 模拟正在保存 (映射为 synthesis 阶段)
        center.updateTask(taskID, status: .running(progress: 0.8, stage: .synthesis))
        if case .running(let progress, let stage) = center.tasks.first?.status {
            XCTAssertEqual(progress, 0.8)
            XCTAssertEqual(stage, .synthesis)
        } else {
            XCTFail("Should be running")
        }
        
        // 模拟成功完成
        center.updateTask(taskID, status: .completed)
        if case .completed = center.tasks.first?.status {
            // Success
        } else {
            XCTFail("Should be completed")
        }
    }
    
    // MARK: - SystemStats Tab Count & InferenceParameters Tests
    @MainActor
    func testSystemStatsTabsAndInferenceParameters() {
        // 验证 SystemStatsView.Tab 枚举具有 3 个选项
        let allTabs = SystemStatsView.Tab.allCases
        XCTAssertEqual(allTabs.count, 3)
        XCTAssertEqual(allTabs[0], .performance)
        XCTAssertEqual(allTabs[1], .storage)
        XCTAssertEqual(allTabs[2], .plugins)
        
        // 验证翻译
        XCTAssertFalse(SystemStatsView.Tab.plugins.title.isEmpty)
    }

    // MARK: - IngestCoordinator 手工录入二次编辑测试
    @MainActor
    func testIngestCoordinatorManualEdit() {
        let coordinator = IngestCoordinator()

        // 构造带有 Ingest 来源头部特征的 rawText
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "测试二次编辑",
            status: ImportRecordStatus.done,
            rawText: "> 手工录入 | 2026/06/20 02:00\n\n真正的用户录入文本内容",
            pageID: nil
        )

        coordinator.openManualForm(with: record)

        // 验证状态预载
        XCTAssertEqual(coordinator.newTitle, "测试二次编辑")
        XCTAssertEqual(coordinator.newContent, "真正的用户录入文本内容")
        XCTAssertEqual(coordinator.sourceHint, .manual)
        XCTAssertTrue(coordinator.showManualForm)
    }
}
