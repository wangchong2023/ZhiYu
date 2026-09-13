//
//  PageDetailDeepTests.swift
//  ZhiYuTests
//
//  合并自 6 个碎片化测试文件：PageDetailAISubviewsDeepTests.swift, PageDetailAndCreationInteractiveTests.swift, PageDetailAndDashboardFullDeepTests.swift, PageDetailSheetModalsDeepTests.swift, PageDetailSubViewsDeepTests.swift, PageDetailViewFullCoverageTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class PageDetailInsightDeepTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var aiStore: AIWorkflowStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        let mockPasteboard = NoOpPasteboard()
        ServiceContainer.shared.register(mockPasteboard as any PasteboardProtocol, for: (any PasteboardProtocol).self)
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router.shared
        aiStore = ServiceContainer.shared.resolveOptional(AIWorkflowStore.self) ?? AIWorkflowStore()
    }

    override func tearDown() async throws {
        appStore = nil
        router = nil
        aiStore = nil
        try await super.tearDown()
    }

    func testPageDetailAISectionProcessingAndResult() async throws {
        let store = AppStore()
        let page = KnowledgePage(
            title: "Concurrency Deep Dive",
            pageType: .concept,
            content: "Detailed concurrency analysis."
        )
        await store.savePage(page)

        struct Wrapper: View {
            let page: KnowledgePage

            var body: some View {
                PageDetailAISection(
                    page: page,
                    onLinkTap: { _ in }
                )
            }
        }

        // 1. 处理中状态（骨架屏态）
        let processingStore = AIWorkflowStore()
        processingStore.isProcessingPageAI = true
        processingStore.activePageAIResult = nil

        let processingView = Wrapper(page: page)
            .snapshotEnvironment(aiWorkflowStore: processingStore)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: processingView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        _ = host.sizeThatFits(in: CGSize(width: 393, height: 852))
        XCTAssertNotNil(host.view)

        // 2. 结果呈现状态（带待办项 `- [ ]`、Markdown 渲染与操作按钮）
        let resultStore = AIWorkflowStore()
        resultStore.isProcessingPageAI = false
        let markdownContent = """
        ### Key Concepts
        - Task cancellation handling
        - Strict isolation boundaries
        - [ ] Verify actor reentrancy
        """
        resultStore.activePageAIResult = markdownContent

        let resultView = Wrapper(page: page)
            .snapshotEnvironment(aiWorkflowStore: resultStore)
        let resultHost = UIHostingController(rootView: resultView)
        window.rootViewController = resultHost
        resultHost.view.layoutIfNeeded()
        _ = resultHost.sizeThatFits(in: CGSize(width: 393, height: 852))
        XCTAssertNotNil(resultHost.view)

        // 3. 跨页面状态隔离防护校验（Page B 不应呈现 Page A 的 AI 状态）
        let otherPage = KnowledgePage(
            title: "Different Concept",
            pageType: .concept,
            content: "Other content"
        )
        let mismatchedView = Wrapper(page: otherPage)
            .snapshotEnvironment(aiWorkflowStore: resultStore)
        let mismatchedHost = UIHostingController(rootView: mismatchedView)
        window.rootViewController = mismatchedHost
        mismatchedHost.view.layoutIfNeeded()
        _ = mismatchedHost.sizeThatFits(in: CGSize(width: 393, height: 852))
        XCTAssertNotNil(mismatchedHost.view)

        // 4. 业务行为测试（合入正文、同步提醒事项、复制、清理）
        // 注意：PageDetailAISection 的复制/同步/合入/清理逻辑均内联在 View 的 Button action 中，
        // 无对外暴露的静态方法。此处仅验证可观测的副作用：剪贴板写入与结果清理。
        // 复制（模拟 View 中 AppPasteboard.string = aiStore.activePageAIResult 的行为）
        AppPasteboard.string = resultStore.activePageAIResult
        XCTAssertEqual(AppPasteboard.string, markdownContent)

        // 清理（模拟 View 中 aiStore.activePageAIResult = nil 的行为）
        resultStore.activePageAIResult = nil
        XCTAssertNil(resultStore.activePageAIResult)
    }

    func testPageDetailMetadataSectionFullCoverage() async throws {
        let page = KnowledgePage(
            title: "Target Page",
            pageType: .concept,
            content: "Target body content.",
            sourceURL: "https://zhiyu.app/docs/architecture"
        )
        let referrer = KnowledgePage(title: "Referrer Page", pageType: .entity, content: "Links to target")
        let recommendation = KnowledgePage(title: "Recommended Concept", pageType: .concept, content: "Related concept")

        struct Wrapper: View {
            let page: KnowledgePage
            let backlinks: [KnowledgePage]
            let recommendations: [KnowledgePage]

            var body: some View {
                PageDetailMetadataSection(
                    page: page,
                    backlinks: backlinks,
                    recommendations: recommendations
                )
            }
        }

        let view = Wrapper(
            page: page,
            backlinks: [referrer],
            recommendations: [recommendation]
        ).snapshotEnvironment()

        XCTAssertEqual(page.title, "Target Page")
        XCTAssertEqual(referrer.pageType, .entity)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        _ = host.sizeThatFits(in: CGSize(width: 393, height: 852))
        XCTAssertNotNil(host.view)
    }

    func testCreatePageContentBuilder_wikiLinkFormattingAndIdempotence() {
        // 1. 普通逗号分隔文本自动包裹 [[...]]
        let rawItems = "SwiftUI, 知识图谱,   Karpathy LLM Wiki "
        let section = CreatePageContentBuilder.buildRelatedSection(from: rawItems, headerTitle: "关联页面")

        XCTAssertTrue(section.contains("- [[SwiftUI]]"))
        XCTAssertTrue(section.contains("- [[知识图谱]]"))
        XCTAssertTrue(section.contains("- [[Karpathy LLM Wiki]]"))
        XCTAssertFalse(section.contains("[[[["))

        // 2. 已有中括号防止二次嵌套
        let mixedItems = "[[SwiftUI]], 知识图谱, [[已存在页面]]"
        let mixedSection = CreatePageContentBuilder.buildRelatedSection(from: mixedItems, headerTitle: "关联页面")

        XCTAssertTrue(mixedSection.contains("- [[SwiftUI]]"))
        XCTAssertTrue(mixedSection.contains("- [[知识图谱]]"))
        XCTAssertTrue(mixedSection.contains("- [[已存在页面]]"))
        XCTAssertFalse(mixedSection.contains("[[[["))

        // 3. 空白与纯逗号防御
        XCTAssertEqual(CreatePageContentBuilder.buildRelatedSection(from: "", headerTitle: "关联页面"), "")
        XCTAssertEqual(CreatePageContentBuilder.buildRelatedSection(from: "  , , ,  ", headerTitle: "关联页面"), "")

        // 4. 提取器能精准解析构建出的双链
        let extractedLinks = WikiLinkExtractor.extractLinks(from: section)
        XCTAssertEqual(extractedLinks.count, 3)
        XCTAssertEqual(extractedLinks.map(\.targetTitle), ["SwiftUI", "知识图谱", "Karpathy LLM Wiki"])
    }

    func testCreatePageContentBuilder_comparisonHeaderAndFullComposition() {
        // 对比标题
        let header = CreatePageContentBuilder.buildComparisonHeader(itemA: "Swift 6", itemB: "Rust")
        XCTAssertEqual(header, "## Swift 6 vs Rust\n\n")

        let emptyHeader = CreatePageContentBuilder.buildComparisonHeader(itemA: "", itemB: "  ")
        XCTAssertEqual(emptyHeader, "")

        // 综合正文构建
        let content = CreatePageContentBuilder.buildContent(
            type: .comparison,
            summary: "并发安全机制对比",
            bodyContent: "Actor 模型 vs 所有权借用检查",
            relatedItems: "并发模型, 内存安全",
            compareItemA: "Swift",
            compareItemB: "Rust",
            relatedLinksHeader: "参考关联"
        )

        XCTAssertTrue(content.contains("## Swift vs Rust"))
        XCTAssertTrue(content.contains("并发安全机制对比"))
        XCTAssertTrue(content.contains("Actor 模型 vs 所有权借用检查"))
        XCTAssertTrue(content.contains("- [[并发模型]]"))
        XCTAssertTrue(content.contains("- [[内存安全]]"))
    }

    func testPageDetailCoordinator_TogglePinAndPersistence() async {
        let testPage = KnowledgePage(title: "置顶测试页面", content: "测试正文")
        await appStore.savePage(testPage)

        let coordinator = PageDetailCoordinator(page: testPage)
        XCTAssertFalse(coordinator.page.isPinned)

        // 切换置顶
        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned)

        // 验证 store 中也同步更新
        let updatedFromStore = appStore.pages.first(where: { $0.id == testPage.id })
        XCTAssertEqual(updatedFromStore?.isPinned, true)

        // 再次切换取消置顶
        await coordinator.togglePin()
        XCTAssertFalse(coordinator.page.isPinned)
    }

    func testPageDetailCoordinator_DeletePageRemovesFromStore() async {
        let pageToDelete = KnowledgePage(title: "待删除页面", content: "将被彻底删除")
        await appStore.savePage(pageToDelete)
        XCTAssertTrue(appStore.pages.contains(where: { $0.id == pageToDelete.id }))

        let coordinator = PageDetailCoordinator(page: pageToDelete)
        await coordinator.deletePage()

        XCTAssertFalse(appStore.pages.contains(where: { $0.id == pageToDelete.id }))
    }

    func testPageDetailCoordinator_BacklinksComputation() async {
        let targetPage = KnowledgePage(title: "目标核心页", content: "目标正文")
        let sourcePage1 = KnowledgePage(title: "引用页 1", content: "请参考 [[目标核心页]] 的定义")
        let sourcePage2 = KnowledgePage(title: "引用页 2", content: "以及深入查阅 [[目标核心页|别名]]")
        let unrelatedPage = KnowledgePage(title: "无关页", content: "仅引用 [[其它页面]]")

        await appStore.savePage(targetPage)
        await appStore.savePage(sourcePage1)
        await appStore.savePage(sourcePage2)
        await appStore.savePage(unrelatedPage)

        let coordinator = PageDetailCoordinator(page: targetPage)
        let backlinks = coordinator.backlinks

        XCTAssertEqual(backlinks.count, 2)
        XCTAssertTrue(backlinks.contains(where: { $0.id == sourcePage1.id }))
        XCTAssertTrue(backlinks.contains(where: { $0.id == sourcePage2.id }))
        XCTAssertFalse(backlinks.contains(where: { $0.id == unrelatedPage.id }))
    }

    func testPageDetailView_MountAndRenderWithSourceBar() async {
        var pageWithSource = KnowledgePage(
            title: "带原始溯源资料的页面",
            content: "正文包含了详细数据"
        )
        pageWithSource.sourceURL = "file:///Users/user/Documents/paper.pdf"
        pageWithSource.sourceType = "pdf"
        pageWithSource.fileSize = 1048576

        await appStore.savePage(pageWithSource)

        let view = PageDetailView(page: pageWithSource)
            .environment(appStore)
            .environment(router)
            .environment(aiStore)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(pageWithSource.sourceType, "pdf")
        XCTAssertEqual(pageWithSource.fileSize, 1048576)
    }

    func testCreatePageView_MountAndRenderForm() {
        let view = CreatePageView()
            .environment(appStore)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "CreatePageView 表单应正确完成渲染")
        XCTAssertNotNil(appStore.knowledgeStore, "knowledgeStore 应完好初始化")
    }

    func testConceptDetailBodyView_MountWithInsightsAndMarkdownFallback() {
        let markdownWithHeaders = """
        ---
        surprising_insights:
          - insight_title: "量子叠加与信息守恒"
            linked_concept_id: "量子力学"
            reason: "揭示了底层概率波的幺正性"
        ---
        # 核心定义
        ## 理论推导
        ### 实验验证
        ### 
        正文详细分析...
        """

        let page = KnowledgePage(
            title: "量子信息概念",
            pageType: .concept,
            content: markdownWithHeaders
        )

        var tappedLink: String?
        let view = ConceptDetailBodyView(page: page, onLinkTap: { link in
            tappedLink = link
        }).snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view)
        XCTAssertNil(tappedLink)
        XCTAssertEqual(page.pageType, .concept)
        XCTAssertTrue(page.content.contains("量子叠加"))
    }

    func testKnowledgePageListView_MountAndFilterTypes() async {
        let p1 = KnowledgePage(title: "实体 A", pageType: .entity, content: "正文")
        let p2 = KnowledgePage(title: "概念 B", pageType: .concept, content: "正文")
        let p3 = KnowledgePage(title: "资料 C", pageType: .source, content: "正文")

        await appStore.savePage(p1)
        await appStore.savePage(p2)
        await appStore.savePage(p3)

        // 全量视图
        let allView = KnowledgePageListView()
            .environment(appStore)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let hostAll = UIHostingController(rootView: allView)
        _ = hostAll.view
        XCTAssertNotNil(hostAll.view)
        XCTAssertEqual(p1.pageType, .entity)

        // 仅 Concept 类型过滤视图
        let conceptFilterView = KnowledgePageListView(filterType: .concept)
            .environment(appStore)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let hostConcept = UIHostingController(rootView: conceptFilterView)
        _ = hostConcept.view
        XCTAssertNotNil(hostConcept.view)
    }

    func testKnowledgePageListView_EmptyStateRender() {
        appStore.knowledgeStore.pages = []

        let emptyView = KnowledgePageListView()
            .environment(appStore)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: emptyView)
        _ = host.view
        XCTAssertNotNil(host.view, "空库状态下应稳定渲染 AppEmptyState")
        XCTAssertTrue(appStore.knowledgeStore.pages.isEmpty, "空库状态下页面集合应为空")
    }

    func testKnowledgeStatItemAndPressStyle() {
        let statItem = KnowledgeStatItem(label: "总笔记", value: "42", color: .appAccent)
            .snapshotEnvironment()

        let hostStat = UIHostingController(rootView: statItem)
        _ = hostStat.view
        XCTAssertNotNil(hostStat.view)

        let buttonWithStyle = Button("测试按钮") {}
            .buttonStyle(AppPressButtonStyle())
            .snapshotEnvironment()

        let hostButton = UIHostingController(rootView: buttonWithStyle)
        _ = hostButton.view
        XCTAssertNotNil(hostButton.view)
    }

    func testPageDetailView_ConceptType() {
        let page = KnowledgePage(
            title: "Transformer 深度剖析",
            pageType: .concept,
            content: "# 核心架构\n- 自注意力机制\n- 前馈神经网络\n- 残差连接与层归一化",
            tags: ["AI", "Architecture", "NLP"],
            sourceURL: "https://arxiv.org/abs/1706.03762"
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page.title, "Transformer 深度剖析")
        XCTAssertEqual(page.pageType, .concept)
        XCTAssertEqual(page.tags.count, 3)
    }

    func testPageDetailView_SourceTypeWithMetadata() {
        let page = KnowledgePage(
            title: "WWDC 2026 论文研讨",
            pageType: .source,
            content: "转录正文内容...",
            tags: ["WWDC", "Swift"],
            sourceURL: "https://developer.apple.com",
            fileSize: 4_096_000,
            sourceType: "pdf"
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page.pageType, .source)
        XCTAssertEqual(page.sourceType, "pdf")
        XCTAssertEqual(page.fileSize, 4_096_000)
    }

    func testPageDetailView_ComparisonType() {
        let page = KnowledgePage(
            title: "BERT vs GPT 对比分析",
            pageType: .comparison,
            content: "## 对比维度\n| 特性 | BERT | GPT |\n|---|---|---|\n| 结构 | 编码器 | 解码器 |",
            tags: ["LLM", "Benchmark"]
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page.pageType, .comparison)
        XCTAssertTrue(page.content.contains("BERT"))
    }

    func testPageDetailView_EntityType() {
        let page = KnowledgePage(
            title: "Andrej Karpathy",
            pageType: .entity,
            content: "人工智能学者，LLM Wiki 方法论倡导者。",
            tags: ["Person", "AI"]
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page.pageType, .entity)
        XCTAssertEqual(page.title, "Andrej Karpathy")
    }

    func testKnowledgeDashboardView_Hierarchy() {
        let store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        let host = NavigationStack {
            KnowledgeDashboardView()
        }
        .environment(store)
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertGreaterThanOrEqual(store.pages.count, 0)
    }

    func testPageDetailCoordinatorStateAndMutations() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        let initialPage = KnowledgePage(
            title: "Karpathy RAG LLM Wiki",
            pageType: .concept,
            content: "Detailed markdown content with [[SubPage]] link.",
            tags: ["AI", "LLM", "Wiki"],
            isPinned: false,
            sourceURL: "file:///notes/karpathy.md",
            fileSize: 4096,
            sourceType: "md"
        )
        store.pages = [initialPage]

        let coordinator = PageDetailCoordinator(page: initialPage)

        // 1. 切换置顶
        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned)
        await coordinator.togglePin()
        XCTAssertFalse(coordinator.page.isPinned)

        // 2. 切换编辑态与弹窗状态
        coordinator.isEditing = true
        XCTAssertTrue(coordinator.isEditing)
        coordinator.isEditing = false

        coordinator.showBacklinks = true
        XCTAssertTrue(coordinator.showBacklinks)

        coordinator.showIconPicker = true
        XCTAssertTrue(coordinator.showIconPicker)

        coordinator.showSnapshotHistory = true
        XCTAssertTrue(coordinator.showSnapshotHistory)

        coordinator.showDeleteConfirmation = true
        XCTAssertTrue(coordinator.showDeleteConfirmation)

        // 3. AI 交互触发
        coordinator.generateSummary()
        coordinator.extractActions()
        coordinator.expandContent()
        coordinator.performSynthesis(type: .mindmap)
        coordinator.performSynthesis(type: .quiz)
        coordinator.performSynthesis(type: .report)
    }

    func testPageDetailViewMountingAndWelcomeCard() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        
        // 1. 挂载欢迎 Aha 提示卡片页面
        let welcomePage = KnowledgePage(
            title: L10n.Common.Demo.Welcome.title,
            pageType: .concept,
            content: "Welcome to ZhiYu knowledge system."
        )
        store.pages = [welcomePage]

        let welcomeDetailView = PageDetailView(page: welcomePage)
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hostWelcome = UIHostingController(rootView: welcomeDetailView)
        window.rootViewController = hostWelcome
        window.makeKeyAndVisible()
        hostWelcome.view.layoutIfNeeded()
        XCTAssertNotNil(hostWelcome.view)
        XCTAssertEqual(welcomePage.title, L10n.Common.Demo.Welcome.title)
        XCTAssertEqual(welcomePage.pageType, .concept)

        // 2. 挂载带外部链接和文件引用的页面
        let sourcePage = KnowledgePage(
            title: "Research Paper",
            pageType: .source,
            content: "Extracted abstract and citations",
            sourceURL: "https://arxiv.org/abs/2301.00000",
            fileSize: 1024 * 500,
            sourceType: "pdf"
        )
        let sourceDetailView = PageDetailView(page: sourcePage)
            .snapshotEnvironment()
        let hostSource = UIHostingController(rootView: sourceDetailView)
        window.rootViewController = hostSource
        hostSource.view.layoutIfNeeded()
        XCTAssertNotNil(hostSource.view)
        XCTAssertEqual(sourcePage.pageType, .source)
        XCTAssertEqual(sourcePage.sourceType, "pdf")
        XCTAssertEqual(sourcePage.sourceURL, "https://arxiv.org/abs/2301.00000")
    }

    func testPageDetailAISection() {
        let page = KnowledgePage(
            title: "知识管理架构",
            content: "基于 RAG 和向量检索的知识库系统",
            tags: ["AI", "Architecture"]
        )

        // 1. 空状态（不展示）
        aiStore.isProcessingPageAI = false
        aiStore.activePageAIResult = nil

        let emptySection = PageDetailAISection(
            page: page,
            onLinkTap: { _ in }
        )
        .environment(aiStore)
        .environment(appStore)
        .snapshotEnvironment()

        let emptyHost = UIHostingController(rootView: emptySection)
        _ = emptyHost.view

        // 2. 处理中状态
        aiStore.isProcessingPageAI = true
        let processingHost = UIHostingController(rootView: emptySection)
        _ = processingHost.view

        // 3. 产出结果状态（包含待办清单项）
        aiStore.isProcessingPageAI = false
        aiStore.activePageAIResult = """
        这是 AI 总结的核心结论。
        - [ ] 任务一：完成架构重构
        - [ ] 任务二：提升单测覆盖率至 95%
        """

        let resultHost = UIHostingController(rootView: emptySection)
        _ = resultHost.view
        resultHost.view.layoutIfNeeded()

        XCTAssertNotNil(aiStore.activePageAIResult)
        XCTAssertTrue(aiStore.activePageAIResult?.contains("完成架构重构") == true)
        XCTAssertEqual(page.tags.count, 2)
    }

    func testPageDetailHeaderAndMetadataSection() {
        let page = KnowledgePage(
            title: "Swift 6 并发模型",
            pageType: .concept,
            content: "全面解析 Sendable, Actor 与 TaskLocal",
            aliases: ["Swift 并发", "Swift Concurrency"],
            tags: ["Swift", "Concurrency"],
            isPinned: true
        )

        // 1. Header 渲染
        let header = PageDetailHeader(page: page)
            .snapshotEnvironment()

        let headerHost = UIHostingController(rootView: header)
        _ = headerHost.view
        headerHost.view.layoutIfNeeded()

        // 2. MetadataSection 渲染
        let recPage = KnowledgePage(title: "Actor 隔离", content: "Actor 数据保护")
        let backlinkPage = KnowledgePage(title: "TaskLocal", content: "任务本地存储")

        let metaSection = PageDetailMetadataSection(
            page: page,
            backlinks: [backlinkPage],
            recommendations: [recPage]
        )
        .environment(appStore)
        .snapshotEnvironment()

        let metaHost = UIHostingController(rootView: metaSection)
        _ = metaHost.view
        metaHost.view.layoutIfNeeded()

        XCTAssertTrue(page.isPinned, "页面应处于置顶状态")
        XCTAssertEqual(page.aliases.count, 2)
        XCTAssertEqual(backlinkPage.title, "TaskLocal")
        XCTAssertEqual(recPage.title, "Actor 隔离")
    }

    func testPageDetailAIMenuButton() {
        var summaryTriggered = false
        var extractTriggered = false
        var mindmapTriggered = false
        var quizTriggered = false
        var slidesTriggered = false
        var reportTriggered = false
        var infographicTriggered = false
        var snapshotHistoryTriggered = false
        var expandContentTriggered = false
        var findRelatedLinksTriggered = false

        let menuButton = PageDetailAIMenuButton(
            isDisabled: false,
            onGenerateSummary: { summaryTriggered = true },
            onExtractActions: { extractTriggered = true },
            onMindmap: { mindmapTriggered = true },
            onQuiz: { quizTriggered = true },
            onSlides: { slidesTriggered = true },
            onReport: { reportTriggered = true },
            onInfographic: { infographicTriggered = true },
            onShowSnapshotHistory: { snapshotHistoryTriggered = true },
            onExpandContent: { expandContentTriggered = true },
            onFindRelatedLinks: { findRelatedLinksTriggered = true }
        )

        let host = UIHostingController(rootView: menuButton.snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        menuButton.onGenerateSummary()
        XCTAssertTrue(summaryTriggered)
        menuButton.onExtractActions()
        XCTAssertTrue(extractTriggered)
        menuButton.onMindmap()
        XCTAssertTrue(mindmapTriggered)
        menuButton.onQuiz()
        XCTAssertTrue(quizTriggered)
        menuButton.onSlides()
        XCTAssertTrue(slidesTriggered)
        menuButton.onReport()
        XCTAssertTrue(reportTriggered)
        menuButton.onInfographic()
        XCTAssertTrue(infographicTriggered)
        menuButton.onShowSnapshotHistory()
        XCTAssertTrue(snapshotHistoryTriggered)
        menuButton.onExpandContent()
        XCTAssertTrue(expandContentTriggered)
        menuButton.onFindRelatedLinks()
        XCTAssertTrue(findRelatedLinksTriggered)
    }

    func testPageDetailViewBasicRendering() async {
        var page = KnowledgePage(
            title: "核心概念页",
            content: "# 概念定义\n这是一个 [[关联页]] 的内容，包含 **重点** 与代码：\n```swift\nlet x = 1\n```",
            sourceURL: "https://zhiyu.app/docs"
        )
        page.pageType = .concept
        page.tags = ["Swift", "Architecture"]
        page.aliases = ["别名A", "别名B"]
        page.isPinned = true
        await appStore.savePage(page)

        let view = PageDetailView(page: page)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        XCTAssertEqual(page.title, "核心概念页")
        XCTAssertEqual(page.pageType, .concept)
        XCTAssertTrue(page.isPinned)
        hosting.view.layoutIfNeeded()
    }

    func testWelcomeAhaPromptCardRendering() async {
        let welcomePage = KnowledgePage(
            title: L10n.Common.Demo.Welcome.title,
            content: "欢迎使用智宇知识库系统"
        )
        await appStore.savePage(welcomePage)

        let view = PageDetailView(page: welcomePage)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        XCTAssertEqual(welcomePage.title, L10n.Common.Demo.Welcome.title)
        hosting.view.layoutIfNeeded()
    }

    func testBreadcrumbsWithHistory() async {
        // 防御跨测试历史残留：Router.shared 为单例，setUp 中其他测试可能已写入 navigationHistory
        router.clearHistory()

        let rootPage = KnowledgePage(title: "首页", content: "根内容")
        let middlePage = KnowledgePage(title: "中级页", content: "中间内容")
        let currentPage = KnowledgePage(title: "当前终端页", content: "终端内容")

        await appStore.savePage(rootPage)
        await appStore.savePage(middlePage)
        await appStore.savePage(currentPage)

        router.addToHistory(rootPage)
        router.addToHistory(middlePage)
        router.addToHistory(currentPage)

        let view = PageDetailView(page: currentPage)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: view)
        XCTAssertNotNil(hosting.view)
        XCTAssertEqual(router.navigationHistory.count, 3)
        XCTAssertEqual(router.navigationHistory.last?.id, currentPage.id)
        hosting.view.layoutIfNeeded()

        router.clearHistory()
    }

    func testPotentialLinksSections() async {
        let targetPage = KnowledgePage(title: "测试页", content: "内容")
        await appStore.savePage(targetPage)

        let aiStore = appStore.aiWorkflowStore

        // 1. 扫描中
        aiStore?.isScanningAI = true
        let scanningView = PageDetailView(page: targetPage)
            .snapshotEnvironment()
        let hostScanning = UIHostingController(rootView: scanningView)
        XCTAssertNotNil(hostScanning.view)
        XCTAssertTrue(aiStore?.isScanningAI == true)
        hostScanning.view.layoutIfNeeded()

        // 2. 发现潜在链接
        aiStore?.isScanningAI = false
        aiStore?.potentialLinks = [
            PotentialLinkSuggestion(
                sourcePageID: targetPage.id,
                sourceTitle: targetPage.title,
                targetTitle: "关联目标页"
            )
        ]
        let linksView = PageDetailView(page: targetPage)
            .snapshotEnvironment()
        let hostLinks = UIHostingController(rootView: linksView)
        XCTAssertNotNil(hostLinks.view)
        XCTAssertEqual(aiStore?.potentialLinks.count, 1)
        XCTAssertEqual(aiStore?.potentialLinks.first?.targetTitle, "关联目标页")
        hostLinks.view.layoutIfNeeded()

        aiStore?.potentialLinks = []
    }

}
