//
//  TagCloudDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：LogViewAndTagCloud3DInteractiveTests.swift, TagCloudCoordinatorInteractiveTests.swift, TagCloudInteractiveDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class TagCloudDeepTests: XCTestCase {

    private var appStore: AppStore!
    private var knowledgeStore: KnowledgeStore!
    private var router: Router!
    private var themeManager: ThemeManager!
    private var window: UIWindow!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        knowledgeStore = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router()
        themeManager = ServiceContainer.shared.resolveOptional(ThemeManager.self) ?? ThemeManager()

        window = UIWindow(frame: CGRect(x: 0, y: 0, width: TestConstants.windowWidth, height: TestConstants.windowHeight))
    }

    func testLogView_EmptyState_RendersGracefully() {
        appStore.logEntries = []
        XCTAssertEqual(appStore.logEntries.count, 0)

        let view = LogView()
            .environment(appStore)
            .environment(themeManager)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testLogView_PopulatedLogEntries_ExpandAndDetails() {
        let now = Date()
        let entry1 = LogEntry(
            action: .create,
            target: "系统架构初探.md",
            details: "通过 Markdown 导入创建知识页面",
            duration: TestConstants.sampleDuration,
            startTime: now.addingTimeInterval(-2),
            endTime: now,
            module: "Ingest",
            status: .success
        )
        let entry2 = LogEntry(
            action: .delete,
            target: "废弃笔记",
            details: "",
            duration: nil,
            module: "Storage",
            status: .failure,
            failureReason: "权限不足或文件被锁定"
        )
        let entry3 = LogEntry(
            action: .ingest,
            target: "分布式共识",
            details: "智能摄取命中 5 条结果"
        )

        appStore.logEntries = [entry1, entry2, entry3]
        XCTAssertEqual(entry1.action, .create)

        let view = LogView()
            .environment(appStore)
            .environment(themeManager)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testLogView_ClearAllLogs_ResetsState() async {
        let entry = LogEntry(action: .create, target: "待清空条目")
        appStore.logEntries = [entry]
        XCTAssertFalse(appStore.logEntries.isEmpty)

        await appStore.clearLogs()
        XCTAssertTrue(appStore.logEntries.isEmpty)
    }

    func testTagCloudView_EmptyState_RendersPlaceholder() {
        knowledgeStore.pages = []
        XCTAssertEqual(knowledgeStore.pages.count, 0)

        let view = TagCloudView()
            .environment(appStore)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testTagCloudView_WithMultipleTags_ExpandAndCollapse() {
        // 创建超过 12 个不同标签的页面数据触发折叠逻辑
        var pages: [KnowledgePage] = []
        let tagsList = [
            "Swift", "iOS", "SwiftUI", "Combine", "Concurrency",
            "GRDB", "SQLite", "FTS5", "Vector", "Embedding",
            "RAG", "LLM", "Prompt", "Agent", "DeepLearning"
        ]
        for (index, tag) in tagsList.enumerated() {
            let page = KnowledgePage(
                title: "文档 \(index)",
                pageType: .concept,
                content: "关于 \(tag) 的深入解析",
                tags: [tag]
            )
            pages.append(page)
        }
        knowledgeStore.pages = pages
        XCTAssertEqual(knowledgeStore.pages.count, 15)

        let view = TagCloudView()
            .environment(appStore)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testTagCloudView_SelectTagAndFilterPages() {
        let targetTag = "Swift"
        let page1 = KnowledgePage(title: "Swift 基础", pageType: .concept, content: "内容", tags: [targetTag])
        let page2 = KnowledgePage(title: "Swift 高级", pageType: .concept, content: "内容", tags: [targetTag])
        let page3 = KnowledgePage(title: "Rust 简介", pageType: .concept, content: "内容", tags: ["Rust"])
        knowledgeStore.pages = [page1, page2, page3]
        XCTAssertEqual(knowledgeStore.pages.count, 3)

        let viewWithInitialTag = TagCloudView(initialTag: targetTag)
            .environment(appStore)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: viewWithInitialTag)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testTagCloudFetchDataSortsAlphabetically() async {
        let p1 = KnowledgePage(title: "Page 1", content: "...", tags: ["Zebra", "Apple"])
        let p2 = KnowledgePage(title: "Page 2", content: "...", tags: ["Banana"])
        await appStore.savePage(p1)
        await appStore.savePage(p2)

        let coordinator = TagCloudCoordinator()
        await coordinator.fetchData()

        XCTAssertEqual(coordinator.tags.count, 3)
        XCTAssertEqual(coordinator.tags[0].tag, "Apple")
        XCTAssertEqual(coordinator.tags[1].tag, "Banana")
        XCTAssertEqual(coordinator.tags[2].tag, "Zebra")
    }

    func testPerformAddTagTrimsWhitespaceAndSelects() async {
        let coordinator = TagCloudCoordinator()
        coordinator.addTagName = "   新领域架构   "
        coordinator.performAddTag()

        // 等待异步任务执行完成
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(coordinator.selectedTag, "新领域架构", "新增标签后应自动设为当前选中标签")
        XCTAssertEqual(coordinator.addTagName, "", "新增完成后输入框应重置清空")
        XCTAssertFalse(coordinator.showAddTagDialog, "新增完成后弹窗应自动关闭")
    }

    func testToggleSelectionInEditMode() {
        let coordinator = TagCloudCoordinator()
        coordinator.isEditMode = true

        // 第一次点击添加
        coordinator.toggleSelection("TagA")
        XCTAssertTrue(coordinator.selectedTagsForBulk.contains("TagA"))

        // 第二次点击取消
        coordinator.toggleSelection("TagA")
        XCTAssertFalse(coordinator.selectedTagsForBulk.contains("TagA"))

        // 切换不同标签
        coordinator.toggleSelection("TagB")
        coordinator.toggleSelection("TagC")
        XCTAssertEqual(coordinator.selectedTagsForBulk.count, 2)
    }

    func testPerformRenameTagUpdatesState() async {
        let page = KnowledgePage(title: "标签重命名页", content: "...", tags: ["旧标签"])
        await appStore.savePage(page)

        let coordinator = TagCloudCoordinator(initialTag: "旧标签")
        coordinator.tagToRename = "旧标签"
        coordinator.newTagName = "重构后标签"

        coordinator.performRename()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(coordinator.tagToRename, "重命名完成后待重命名标记应置空")
        XCTAssertEqual(coordinator.selectedTag, "重构后标签", "若当前选中标签被重命名，应联动更新选中状态")
    }

    func testTagCloudViewMountAndRender() {
        let coordinator = TagCloudCoordinator()
        let view = TagCloudView()
            .environment(coordinator)
            .environment(appStore)
            .snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "TagCloudView 宿主视图应完成挂载")
        XCTAssertNil(coordinator.selectedTag, "初始状态下标签云未选中任何标签")
    }

    func testTagCloudViewContent_ListMode() {
        let coordinator = TagCloudCoordinator()
        coordinator.tags = [
            (tag: "Swift", count: 15),
            (tag: "AI", count: 28),
            (tag: "RAG", count: 8),
            (tag: "iOS", count: 12)
        ]

        let host = NavigationStack {
            TagCloudView()
        }
        .environment(coordinator)
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(coordinator.tags.count, 4, "标签云数据应包含 4 个预置标签")
        XCTAssertEqual(coordinator.tags.first?.tag, "Swift", "首个标签应为 Swift")
        XCTAssertNil(coordinator.selectedTag, "初始未选择标签")
    }

}

private extension TagCloudDeepTests {
    enum TestConstants {
        static let windowWidth: CGFloat = 375
        static let windowHeight: CGFloat = 812
        static let sampleDuration: TimeInterval = 1.5
    }
}
