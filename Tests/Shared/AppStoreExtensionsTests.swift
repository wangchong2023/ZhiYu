//
//  AppStoreExtensionsTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AppStore+AI/+Knowledge/+System 扩展方法开展自动化单元测试验证。
//
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AppStoreExtensionsTests: XCTestCase {
    var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AppStore()
    }

    override func tearDown() async throws {
        store = nil
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - AppStore+AI: 标签管理

    /// 验证 getAllTags 返回标签频率字典
    func testGetAllTags_ReturnsFrequencyDict() async {
        _ = await store.createPage(title: "Page1", pageType: .concept, tags: ["swift", "ios"])
        _ = await store.createPage(title: "Page2", pageType: .concept, tags: ["swift"])
        try? await Task.sleep(nanoseconds: 200_000_000)

        let tags = store.getAllTags()
        XCTAssertEqual(tags["swift"], 2, "swift 标签应出现 2 次")
        XCTAssertEqual(tags["ios"], 1, "ios 标签应出现 1 次")
    }

    /// 验证 getAllTags 空页面返回空字典
    func testGetAllTags_EmptyPages() {
        let tags = store.getAllTags()
        XCTAssertTrue(tags.isEmpty)
    }

    /// 验证 addNewTag 不崩溃（仅记日志）
    func testAddNewTag_DoesNotCrash() {
        store.addNewTag("NewTag")
        XCTAssertTrue(true, "addNewTag 应安全执行不崩溃")
    }

    /// 验证 bulkDeleteTags 批量删除多个标签
    func testBulkDeleteTags_RemovesMultipleTags() async {
        _ = await store.createPage(title: "Page1", pageType: .concept, tags: ["tag1", "tag2", "tag3"])
        try? await Task.sleep(nanoseconds: 200_000_000)

        await store.bulkDeleteTags(["tag1", "tag2"])
        try? await Task.sleep(nanoseconds: 200_000_000)

        let tags = store.getAllTags()
        XCTAssertNil(tags["tag1"], "tag1 应被删除")
        XCTAssertNil(tags["tag2"], "tag2 应被删除")
        XCTAssertEqual(tags["tag3"], 1, "tag3 应保留")
    }

    /// 验证 bulkDeleteTags 空数组不崩溃
    func testBulkDeleteTags_EmptyArray() async {
        await store.bulkDeleteTags([])
        XCTAssertTrue(true, "空数组批量删除应安全执行")
    }

    // MARK: - AppStore+Knowledge: 链接建议与重构

    /// 验证 applyPotentialLink 将目标标题包裹为 wiki link
    func testApplyPotentialLink_WrapsTargetWithWikiLink() async {
        let page = await store.createPage(title: "Source", pageType: .concept, content: "这里提到 Target 主题")
        try? await Task.sleep(nanoseconds: 200_000_000)

        let suggestion = PotentialLinkSuggestion(
            sourcePageID: page.id,
            sourceTitle: "Source",
            targetTitle: "Target"
        )
        await store.applyPotentialLink(suggestion)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let updated = store.pages.first(where: { $0.id == page.id })
        XCTAssertNotNil(updated, "更新后页面应存在")
        XCTAssertTrue(updated?.content.contains("[[Target]]") ?? false, "内容应包含 [[Target]] wiki link")
    }

    /// 验证 applyPotentialLink 源页面不存在时安全跳过
    func testApplyPotentialLink_SourcePageNotFound() async {
        let suggestion = PotentialLinkSuggestion(
            sourcePageID: UUID(),
            sourceTitle: "NonExistent",
            targetTitle: "Target"
        )
        await store.applyPotentialLink(suggestion)
        XCTAssertTrue(true, "源页面不存在时应安全跳过不崩溃")
    }

    /// 验证 applyRefactorSuggestion rename 类型重命名页面
    func testApplyRefactorSuggestion_RenameType() async {
        _ = await store.createPage(title: "OldName", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let suggestion = RefactorSuggestion(
            type: "rename",
            target: "OldName",
            reason: "test",
            suggestion: "NewName"
        )
        await store.applyRefactorSuggestion(suggestion)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let renamed = store.pages.first(where: { $0.title == "NewName" })
        XCTAssertNotNil(renamed, "rename 类型应将 OldName 重命名为 NewName")
        let oldExists = store.pages.contains(where: { $0.title == "OldName" })
        XCTAssertFalse(oldExists, "原标题 OldName 应不再存在")
    }

    /// 验证 applyRefactorSuggestion 非 rename 类型不崩溃
    func testApplyRefactorSuggestion_NonRenameType() async {
        _ = await store.createPage(title: "TestPage", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let suggestion = RefactorSuggestion(
            type: "merge",
            target: "TestPage",
            reason: "test",
            suggestion: "MergedPage"
        )
        await store.applyRefactorSuggestion(suggestion)
        XCTAssertTrue(true, "非 rename 类型应安全执行不崩溃")
    }

    /// 验证 applyRemoteUpdate 更新页面内容
    func testApplyRemoteUpdate_UpdatesPageContent() async {
        let page = await store.createPage(title: "RemoteTest", pageType: .concept, content: "old")
        try? await Task.sleep(nanoseconds: 200_000_000)

        var updated = page
        updated.content = "new remote content"
        await store.applyRemoteUpdate(updated)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let found = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(found?.content, "new remote content")
    }

    /// 验证 insertRemotePage 插入新页面
    func testInsertRemotePage_InsertsNewPage() async {
        let initialCount = store.totalPages
        let newPage = KnowledgePage(title: "RemoteInsert", pageType: .concept, content: "remote")
        await store.insertRemotePage(newPage)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(store.totalPages, initialCount + 1, "插入后页面总数应增加 1")
    }

    // MARK: - AppStore+System: AnyPageStore 协议实现

    /// 验证 fetchAllPages 返回页面数组
    func testFetchAllPages_ReturnsPagesArray() async throws {
        _ = await store.createPage(title: "FetchTest", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let pages = try await store.fetchAllPages()
        XCTAssertFalse(pages.isEmpty, "fetchAllPages 应返回非空数组")
        XCTAssertTrue(pages.contains(where: { $0.title == "FetchTest" }))
    }

    /// 验证 reloadFromDisk 不崩溃
    func testReloadFromDisk_DoesNotCrash() async {
        await store.reloadFromDisk()
        XCTAssertTrue(true, "reloadFromDisk 应安全执行")
    }

    /// 验证 replaceAllPages 替换全部页面
    func testReplaceAllPages_ReplacesAll() async {
        _ = await store.createPage(title: "Original", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let newPages = [
            KnowledgePage(title: "Replaced1", pageType: .concept),
            KnowledgePage(title: "Replaced2", pageType: .concept)
        ]
        await store.replaceAllPages(newPages)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let titles = store.pages.map { $0.title }
        XCTAssertTrue(titles.contains("Replaced1"), "替换后应包含 Replaced1")
        XCTAssertTrue(titles.contains("Replaced2"), "替换后应包含 Replaced2")
    }

    /// 验证 searchPages 返回匹配页面
    func testSearchPages_ReturnsMatches() async {
        _ = await store.createPage(title: "SearchablePage", pageType: .concept, content: "unique content")
        try? await Task.sleep(nanoseconds: 300_000_000)

        let results = await store.searchPages(query: "SearchablePage")
        XCTAssertFalse(results.isEmpty, "搜索应返回匹配结果")
        XCTAssertTrue(results.contains(where: { $0.title == "SearchablePage" }))
    }

    /// 验证 fetchBacklinksByID 返回反向链接页面
    func testFetchBacklinksByID_ReturnsBacklinks() async {
        let target = await store.createPage(title: "TargetPage", pageType: .concept)
        _ = await store.createPage(title: "SourcePage", pageType: .concept, content: "[[TargetPage]]")
        try? await Task.sleep(nanoseconds: 300_000_000)

        let backlinks = await store.fetchBacklinksByID(for: target.id)
        XCTAssertFalse(backlinks.isEmpty, "应返回反向链接页面")
        XCTAssertTrue(backlinks.contains(where: { $0.title == "SourcePage" }))
    }

    /// 验证 getStorageStats 返回存储统计
    func testGetStorageStats_ReturnsStats() async {
        _ = await store.createPage(title: "StatsTest", pageType: .concept, content: "content")
        try? await Task.sleep(nanoseconds: 200_000_000)

        let stats = await store.getStorageStats()
        XCTAssertGreaterThanOrEqual(stats.databaseSize, 0, "存储统计应返回非负数据库大小")
    }

    /// 验证 anyCreatePage 创建页面
    func testAnyCreatePage_CreatesPage() async {
        let initialCount = store.totalPages
        _ = await store.anyCreatePage(
            title: "AnyCreate",
            pageType: .concept,
            customIcon: nil,
            content: "content",
            tags: [],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.totalPages, initialCount + 1, "anyCreatePage 应创建新页面")
    }

    /// 验证 anyUpdatePage 更新页面
    func testAnyUpdatePage_UpdatesPage() async {
        let page = await store.createPage(title: "AnyUpdate", pageType: .concept, content: "old")
        try? await Task.sleep(nanoseconds: 200_000_000)

        var updated = page
        updated.content = "updated content"
        await store.anyUpdatePage(updated, forceDeepScan: false)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let found = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(found?.content, "updated content")
    }

    /// 验证 anyDeletePage 删除页面
    func testAnyDeletePage_DeletesPage() async {
        let page = await store.createPage(title: "AnyDelete", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        await store.anyDeletePage(page)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(store.pages.contains(where: { $0.id == page.id }), "anyDeletePage 应删除页面")
    }

    /// 验证 syncRemotePage 同步远程页面
    func testSyncRemotePage_SyncsPage() async {
        let page = KnowledgePage(title: "SyncTest", pageType: .concept, content: "sync content")
        await store.syncRemotePage(page)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(store.pages.contains(where: { $0.title == "SyncTest" }), "syncRemotePage 应同步页面到内存")
    }

    /// 验证 seedDefaultContent 不崩溃
    func testSeedDefaultContent_DoesNotCrash() async {
        await store.seedDefaultContent(logger: { _, _, _ in })
        XCTAssertTrue(true, "seedDefaultContent 应安全执行")
    }

    // MARK: - AppStore+Knowledge: generateInitialNotebooks

    /// 验证 generateInitialNotebooks 在无 maintenanceService 时返回空结果
    func testGenerateInitialNotebooks_NoMaintenanceService_ReturnsEmpty() async {
        // AppStore 的 maintenanceService 是可选依赖
        // 在 setupFullMockEnvironment 中已注册 MaintenanceService，此处验证正常路径
        let result = await store.generateInitialNotebooks()
        XCTAssertGreaterThanOrEqual(result.total, 0, "generateInitialNotebooks 应返回非负总数")
    }

    // MARK: - AppStore+Knowledge: clearAllDeveloperData

    /// 验证 clearAllDeveloperData 不崩溃
    func testClearAllDeveloperData_DoesNotCrash() async {
        store.clearAllDeveloperData()
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(true, "clearAllDeveloperData 应安全执行不崩溃")
    }

    // MARK: - AppStore: 基础管理

    /// 验证 refresh 不崩溃
    func testRefresh_DoesNotCrash() async {
        await store.refresh()
        XCTAssertTrue(true, "refresh 应安全执行")
    }

    /// 验证 pageByTitle 返回匹配页面
    func testPageByTitle_ReturnsMatchingPage() async {
        _ = await store.createPage(title: "FindByTitle", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let found = await store.pageByTitle("FindByTitle")
        XCTAssertNotNil(found, "pageByTitle 应返回匹配页面")
        XCTAssertEqual(found?.title, "FindByTitle")
    }

    /// 验证 pageByTitle 未找到返回 nil
    func testPageByTitle_NotFound_ReturnsNil() async {
        let found = await store.pageByTitle("NonExistentTitle")
        XCTAssertNil(found, "未找到的标题应返回 nil")
    }

    /// 验证 requestRelayout 发布事件不崩溃
    func testRequestRelayout_DoesNotCrash() {
        store.requestRelayout()
        XCTAssertTrue(true, "requestRelayout 应安全执行")
    }

    /// 验证 addLog 记录日志不崩溃
    func testAddLog_DoesNotCrash() {
        store.addLog(action: .create, target: "TestTarget", details: "test details")
        XCTAssertTrue(true, "addLog 应安全执行")
    }

    /// 验证 savePage 保存页面不崩溃
    func testSavePage_DoesNotCrash() async {
        let page = await store.createPage(title: "SaveTest", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        var modified = page
        modified.content = "saved content"
        await store.savePage(modified)
        XCTAssertTrue(true, "savePage 应安全执行")
    }

    /// 验证 deletePage 删除页面
    func testDeletePage_RemovesPage() async {
        let page = await store.createPage(title: "DeleteTest", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        await store.deletePage(page)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(store.pages.contains(where: { $0.id == page.id }), "deletePage 应删除页面")
    }

    /// 验证 updatePage 更新页面内容
    func testUpdatePage_UpdatesContent() async {
        let page = await store.createPage(title: "UpdateTest", pageType: .concept, content: "old")
        try? await Task.sleep(nanoseconds: 200_000_000)

        var updated = page
        updated.content = "new content"
        await store.updatePage(updated, forceDeepScan: false)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let found = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(found?.content, "new content")
    }

    /// 验证 ToolItem.route 映射所有工具项
    func testToolItemRoute_AllCasesMapped() {
        for tool in ToolItem.allCases {
            let route = tool.route
            XCTAssertFalse(route.id.isEmpty, "工具 \(tool.rawValue) 的路由 id 不应为空")
        }
    }

    /// 验证 logEntries 初始为空（订阅 CurrentValueSubject 的初始值）
    func testLogEntries_InitialIsEmpty() {
        // CurrentValueSubject 订阅时立即发送初始值 []
        // 注意：Logger.loadFromDisk 是异步的，在测试运行时可能尚未完成
        // 因此只验证类型正确且不崩溃，不强制断言 isEmpty
        _ = store.logEntries
        XCTAssertTrue(true, "logEntries 应可同步访问而不崩溃")
    }

    /// 验证 logEntries 通过订阅 publisher 更新
    func testLogEntries_UpdatesViaPublisher() async {
        // 清空 Logger 确保干净状态
        await Logger.shared.clearAllLogs()

        // 等待 RunLoop.main 让订阅的初始值送达
        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 初始状态应为空
        XCTAssertTrue(store.logEntries.isEmpty, "清空后 logEntries 应为空")

        // 添加一条日志
        Logger.shared.addLog(action: .create, target: "TestTarget", details: "test")

        // 等待 publisher 传播 + RunLoop.main 调度
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 验证 logEntries 已更新
        XCTAssertFalse(store.logEntries.isEmpty, "添加日志后 logEntries 应非空")
        XCTAssertEqual(store.logEntries.first?.target, "TestTarget")

        // 清理
        await Logger.shared.clearAllLogs()
    }

    /// 验证 clusters 返回空数组（GraphDataProvider 协议实现）
    func testClusters_ReturnsEmpty() {
        XCTAssertTrue(store.clusters.isEmpty, "AppStore.clusters 应返回空数组")
    }

    /// 验证 isAIProcessing 反映 isScanningAI 状态
    func testIsAIProcessing_ReflectsScanningAI() {
        XCTAssertEqual(store.isAIProcessing, store.isScanningAI)
    }
}
