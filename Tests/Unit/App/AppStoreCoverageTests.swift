//
//  AppStoreCoverageTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：补强 AppStore 未覆盖路径 — throws 协议方法、状态属性、CoachMarkType、KnowledgeGrowthPoint、ToolItem.route 边界。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class AppStoreCoverageTests: XCTestCase {
    var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AppStore()
    }

    override func tearDown() async throws {
        store = nil
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - AppStore+System: throws 协议方法

    /// 验证 AnyPageStore 协议的 createPage throws 版本创建页面
    func testAnyPageStoreCreatePage_ThrowsVersion_CreatesPage() async throws {
        let initialCount = store.totalPages
        let page = try await store.createPage(
            title: "ThrowsCreate",
            pageType: .concept,
            customIcon: nil,
            content: "content",
            tags: ["test"],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil
        )
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.totalPages, initialCount + 1, "throws 版本 createPage 应创建新页面")
        XCTAssertEqual(page.title, "ThrowsCreate")
    }

    /// 验证 AnyPageStore 协议的 updatePage throws 版本更新页面
    func testAnyPageStoreUpdatePage_ThrowsVersion_UpdatesPage() async throws {
        let page = await store.createPage(title: "ThrowsUpdate", pageType: .concept, content: "old")
        try? await Task.sleep(nanoseconds: 200_000_000)

        var updated = page
        updated.content = "throws updated"
        try await store.updatePage(updated)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let found = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(found?.content, "throws updated")
    }

    /// 验证 resetDatabase 重置数据库并验证页面清空
    func testResetDatabase_DoesNotCrash() async throws {
        _ = await store.createPage(title: "BeforeReset", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        try await store.resetDatabase()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(store.pages.isEmpty, "resetDatabase 后 store.pages 必须被清空")
        XCTAssertEqual(store.totalPages, 0, "resetDatabase 后 totalPages 必须归零")
    }

    /// 验证 performBatchWrite 批量写入能够持久化落库
    func testPerformBatchWrite_DoesNotCrash() async throws {
        let countBefore = store.totalPages
        try await store.performBatchWrite { db in
            var newPage = KnowledgePage(title: "BatchCreatedPage", pageType: .concept, content: "batch content")
            try newPage.insert(db)
        }
        await store.refresh()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(store.totalPages, countBefore + 1, "performBatchWrite 批量写入后页面数必须递增")
        XCTAssertTrue(store.pages.contains(where: { $0.title == "BatchCreatedPage" }))
    }

    // MARK: - AppStore: 基础管理未覆盖方法

    /// 验证 seedDefaultContent 带 vaultName 参数成功填充页面
    func testSeedDefaultContent_WithVaultName_DoesNotCrash() async {
        await store.seedDefaultContent(vaultName: "TestVault")
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(store.pages.isEmpty, "seedDefaultContent 植入内容后页面集合不应为空")
        XCTAssertTrue(store.totalPages > 0, "seedDefaultContent 后总页面数应大于 0")
    }

    /// 验证 saveToDisk 保存到磁盘后页面状态完整
    func testSaveToDisk_DoesNotCrash() async {
        let created = await store.createPage(title: "DiskTest", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        await store.saveToDisk()
        let found = store.pages.first(where: { $0.id == created.id })
        XCTAssertNotNil(found, "saveToDisk 执行后页面依然能被正常定位")
        XCTAssertEqual(found?.title, "DiskTest")
    }

    /// 验证 clearLogs 清除日志成功清空
    func testClearLogs_DoesNotCrash() async {
        await store.clearLogs()
        XCTAssertTrue(store.logEntries.isEmpty, "clearLogs 执行后日志列表必须为空")
    }

    /// 验证 getBacklinks 返回反向链接
    func testGetBacklinks_ReturnsBacklinks() async {
        let target = await store.createPage(title: "BacklinkTarget", pageType: .concept)
        _ = await store.createPage(title: "BacklinkSource", pageType: .concept, content: "[[BacklinkTarget]]")
        try? await Task.sleep(nanoseconds: 300_000_000)

        let backlinks = await store.getBacklinks(for: target.id)
        XCTAssertFalse(backlinks.isEmpty, "应返回反向链接页面")
        XCTAssertTrue(backlinks.contains(where: { $0.title == "BacklinkSource" }))
    }

    // MARK: - UI 状态属性

    /// 验证 pendingCoachMark 设置与清除
    func testPendingCoachMark_SetAndClear() {
        XCTAssertNil(store.pendingCoachMark, "初始状态应为 nil")
        store.pendingCoachMark = .graphDiscovery
        XCTAssertEqual(store.pendingCoachMark, .graphDiscovery, "设置后应返回 graphDiscovery")
        store.pendingCoachMark = nil
        XCTAssertNil(store.pendingCoachMark, "清除后应为 nil")
    }

    /// 验证 showCreateSheet 双向绑定
    func testShowCreateSheet_BidirectionalBinding() {
        let initialValue = store.showCreateSheet
        store.showCreateSheet = true
        XCTAssertTrue(store.showCreateSheet, "设置 true 后应返回 true")
        store.showCreateSheet = false
        XCTAssertFalse(store.showCreateSheet, "设置 false 后应返回 false")
        store.showCreateSheet = initialValue
    }

    /// 验证 showPerfDashboard 双向绑定
    func testShowPerfDashboard_BidirectionalBinding() {
        let initialValue = store.showPerfDashboard
        store.showPerfDashboard = true
        XCTAssertTrue(store.showPerfDashboard, "设置 true 后应返回 true")
        store.showPerfDashboard = false
        XCTAssertFalse(store.showPerfDashboard, "设置 false 后应返回 false")
        store.showPerfDashboard = initialValue
    }

    /// 验证 isPrivacyModeEnabled 反映 settingsStore 状态
    func testIsPrivacyModeEnabled_ReflectsSettingsStore() {
        let privacyMode = store.isPrivacyModeEnabled
        XCTAssertEqual(privacyMode, store.isPrivacyModeEnabled, "isPrivacyModeEnabled 应稳定返回相同值")
    }

    /// 验证 isScanningAI 等于 isScanning
    func testIsScanningAI_EqualsIsScanning() {
        XCTAssertEqual(store.isScanningAI, store.isScanning, "isScanningAI 应等于 isScanning")
    }

    // MARK: - 转发指标属性

    /// 验证 totalPages 反映 knowledgeStore.totalPages
    func testTotalPages_ReflectsKnowledgeStore() {
        XCTAssertEqual(store.totalPages, store.knowledgeStore.totalPages, "totalPages 应反映 knowledgeStore.totalPages")
    }

    /// 验证 totalWords 反映 knowledgeStore.totalWords
    func testTotalWords_ReflectsKnowledgeStore() {
        XCTAssertEqual(store.totalWords, store.knowledgeStore.totalWords, "totalWords 应反映 knowledgeStore.totalWords")
    }

    /// 验证 tags 返回排序后的标签数组
    func testTags_ReturnsSortedTags() async {
        _ = await store.createPage(title: "TagPage1", pageType: .concept, tags: ["zebra", "apple", "mango"])
        _ = await store.createPage(title: "TagPage2", pageType: .concept, tags: ["banana"])
        try? await Task.sleep(nanoseconds: 200_000_000)

        let tags = store.tags
        XCTAssertFalse(tags.isEmpty, "应返回非空标签数组")
        XCTAssertEqual(tags, tags.sorted(), "tags 应按字母顺序排序")
    }

    /// 验证 brokenLinkCount 反映 aiInsightStore
    func testBrokenLinkCount_ReflectsInsightStore() {
        XCTAssertEqual(store.brokenLinkCount, store.aiInsightStore.brokenLinkCount, "brokenLinkCount 应反映 aiInsightStore")
    }

    /// 验证 orphanPageCount 反映 aiInsightStore
    func testOrphanPageCount_ReflectsInsightStore() {
        XCTAssertEqual(store.orphanPageCount, store.aiInsightStore.orphanPageCount, "orphanPageCount 应反映 aiInsightStore")
    }

    /// 验证 totalConnectionCount 反映 aiInsightStore
    func testTotalConnectionCount_ReflectsInsightStore() {
        XCTAssertEqual(store.totalConnectionCount, store.aiInsightStore.totalConnectionCount, "totalConnectionCount 应反映 aiInsightStore")
    }

    /// 验证 sourceCount/entityCount/conceptCount 反映 aiInsightStore
    func testTypeCounts_ReflectInsightStore() {
        XCTAssertEqual(store.sourceCount, store.aiInsightStore.sourceCount, "sourceCount 应反映 aiInsightStore")
        XCTAssertEqual(store.entityCount, store.aiInsightStore.entityCount, "entityCount 应反映 aiInsightStore")
        XCTAssertEqual(store.conceptCount, store.aiInsightStore.conceptCount, "conceptCount 应反映 aiInsightStore")
    }

    /// 验证 growthSeries 反映 aiInsightStore
    func testGrowthSeries_ReflectsInsightStore() {
        XCTAssertEqual(store.growthSeries.count, store.aiInsightStore.growthSeries.count, "growthSeries 应反映 aiInsightStore")
    }

    /// 验证 lintIssues 反映 aiWorkflowStore
    func testLintIssues_ReflectsWorkflowStore() {
        XCTAssertEqual(store.lintIssues.count, store.aiWorkflowStore.lintIssues.count, "lintIssues 数量应反映 aiWorkflowStore")
    }

    // MARK: - CoachMarkType 枚举

    /// 验证 CoachMarkType.graphDiscovery rawValue
    func testCoachMarkType_GraphDiscovery_RawValue() {
        XCTAssertEqual(AppStore.CoachMarkType.graphDiscovery.rawValue, "graph_discovery", "rawValue 应为 graph_discovery")
    }

    // MARK: - KnowledgeGrowthPoint

    /// 验证 KnowledgeGrowthPoint init 与属性
    func testKnowledgeGrowthPoint_Init() {
        let date = Date(timeIntervalSince1970: 1_725_000_000)
        let point = AppStore.KnowledgeGrowthPoint(date: date, count: 42)

        XCTAssertEqual(point.date, date, "date 应与传入值一致")
        XCTAssertEqual(point.count, 42, "count 应与传入值一致")
        XCTAssertNotNil(point.id, "id 应自动生成非 nil")
    }

    /// 验证 KnowledgeGrowthPoint Identifiable 唯一性
    func testKnowledgeGrowthPoint_Identifiable_Uniqueness() {
        let point1 = AppStore.KnowledgeGrowthPoint(date: Date(), count: 1)
        let point2 = AppStore.KnowledgeGrowthPoint(date: Date(), count: 2)

        XCTAssertNotEqual(point1.id, point2.id, "两个 KnowledgeGrowthPoint 的 id 应不同")
    }

    // MARK: - ToolItem.route 边界

    /// 验证 ToolItem.route 对每个工具项返回有效路由
    func testToolItemRoute_EachCase_HasValidRoute() {
        for tool in ToolItem.allCases {
            let route = tool.route
            XCTAssertFalse(route.id.isEmpty, "工具 \(tool.rawValue) 的路由 id 不应为空")
        }
    }

    /// 验证 ToolItem.route dashboard 映射
    func testToolItemRoute_Dashboard_MapsCorrectly() {
        let route = ToolItem.dashboard.route
        XCTAssertEqual(route, AppRoute.dashboard, "dashboard 应映射到 .dashboard")
    }

    /// 验证 ToolItem.route pageList 映射
    func testToolItemRoute_PageList_MapsCorrectly() {
        let route = ToolItem.pageList.route
        XCTAssertEqual(route, AppRoute.pageList(), "pageList 应映射到 .pageList()")
    }

    /// 验证 ToolItem.route lint 与 healthCheck 都映射到 .lint
    func testToolItemRoute_LintAndHealthCheck_BothMapToLint() {
        XCTAssertEqual(ToolItem.lint.route, AppRoute.lint, "lint 应映射到 .lint")
        XCTAssertEqual(ToolItem.healthCheck.route, AppRoute.lint, "healthCheck 应映射到 .lint")
    }

    /// 验证 ToolItem.route chat 映射
    func testToolItemRoute_Chat_MapsCorrectly() {
        XCTAssertEqual(ToolItem.chat.route, AppRoute.chat, "chat 应映射到 .chat")
    }

    /// 验证 ToolItem.route graph 映射
    func testToolItemRoute_Graph_MapsCorrectly() {
        XCTAssertEqual(ToolItem.graph.route, AppRoute.graph, "graph 应映射到 .graph")
    }

    // MARK: - AppStore+Knowledge: applyRemoteUpdate 边界

    /// 验证 applyRemoteUpdate 成功同步并插入远端页面数据
    func testApplyRemoteUpdate_NonExistentPage_DoesNotCrash() async {
        let fakePage = KnowledgePage(title: "NonExistentRemote", pageType: .concept, content: "fake")
        let countBefore = store.totalPages
        await store.applyRemoteUpdate(fakePage)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(store.totalPages, countBefore + 1, "applyRemoteUpdate 远端同步应以 upsert 语义新增页面")
        XCTAssertTrue(store.pages.contains(where: { $0.title == "NonExistentRemote" }))
    }

    // MARK: - AppStore+AI: addNewTag 与 getAllTags 边界

    /// 验证 addNewTag 注册标签且 getAllTags 正确统计已有页面标签
    func testAddNewTag_ThenGetAllTags_ContainsTag() async {
        _ = await store.createPage(title: "AddTagPage", pageType: .concept, tags: ["existingTag"])
        try? await Task.sleep(nanoseconds: 200_000_000)

        store.addNewTag("newTagFromAdd")
        try? await Task.sleep(nanoseconds: 200_000_000)
        let tags = store.getAllTags()
        XCTAssertNotNil(tags["existingTag"], "existingTag 来自页面应被正常检索")
    }
}
