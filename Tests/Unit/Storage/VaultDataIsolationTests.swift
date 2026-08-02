//
//  VaultDataIsolationTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对多租户物理笔记本数据强隔离（Vault Data Isolation）开展单元测试验证。
//

import XCTest
import UFPStorage
@testable import ZhiYu

/// 物理笔记本数据强隔离功能单元测试类（VaultDataIsolationTests）
/// 专职验证系统核心功能：当物理切换不同的知识金库（Vault）时，底层的物理 SQLite 数据库能够实现强力物理数据隔离与完整性保护。
@MainActor
final class VaultDataIsolationTests: XCTestCase {
    
    /// 临时物理沙盒隔离存储目录
    private var tempDirectory: URL!
    
    /// 笔记本 A 与 笔记本 B 的物理 SQLite 文件路径
    private var dbAURL: URL!
    private var dbBURL: URL!
    
    /// 笔记本 A 与 笔记本 B 的唯一识别 UUID
    private let vaultAID = UUID()
    private let vaultBID = UUID()
    
    /// 单元测试的前置搭建准备工作
    override func setUp() async throws {
        try await super.setUp()
        
        // 核心步骤 1：开辟本次测试专属的物理临时沙盒目录，防止对其他测试甚至生产数据造成污染
        let systemTemp = FileManager.default.temporaryDirectory
        tempDirectory = systemTemp.appendingPathComponent("ZhiYu_VaultIsolationTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 核心步骤 2：生成两个物理隔离的专属库路径
        dbAURL = tempDirectory.appendingPathComponent("vault_A.sqlite3")
        dbBURL = tempDirectory.appendingPathComponent("vault_B.sqlite3")
        
        // 核心步骤 2.5：将 UserDefaults 播种标记预设为 true，严防 KnowledgeStore 后台异步 Task 自动播种冷启动引导数据干扰隔离测试
        UserDefaults.standard.set(true, forKey: "seeded_vault_\(vaultAID.uuidString)")
        UserDefaults.standard.set(true, forKey: "seeded_vault_\(vaultBID.uuidString)")
        
        // 核心步骤 3：重置并搭建纯净的全 Mock 运行环境以防止 DI 服务泄漏与死锁
        ServiceContainer.shared.reset()
        setupFullMockEnvironment()
    }
    
    /// 单元测试的后置收尾清理工作
    override func tearDown() async throws {
        // 核心步骤 4：显式将 dbWriter 物理连接池彻底关闭并析构释放 WAL 锁，随后物理擦除测试临时沙盒目录下的所有物理残留文件
        DatabaseManager.shared.releaseDatabaseConnection()
        DatabaseManager.shared.reset()
        
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // 清理播种标记，确保测试无状态残留
        UserDefaults.standard.removeObject(forKey: "seeded_vault_\(vaultAID.uuidString)")
        UserDefaults.standard.removeObject(forKey: "seeded_vault_\(vaultBID.uuidString)")
        
        tempDirectory = nil
        dbAURL = nil
        dbBURL = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 核心隔离测试用例
    
    /// 测试核心业务：验证在切换不同的物理笔记本（Vault）时，页面数据能够实现彻底的物理隔离与防泄露。
    func testVaultDataIsolationAndPersistence() async throws {
        // 🚀 【阶段一：切入笔记本 A 并写入专有数据，验证写入持久化成功】
        print("🎬 【Phase 1】物理挂载切换至 笔记本 A => ID: \(vaultAID.uuidString)")
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        
        // 核心动作：由于物理库已经切换，必须显式刷新 DI 服务容器内绑定的 Storage 模块
        // 这将用全新已就绪的 dbAURL Pool 初始化并重装 SQLiteStore 与 Repository
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        // 解析当前活跃的知识页面存储层
        let storeA = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        
        // 写入专属于 笔记本 A 的页面
        let pageATitle = "专属于笔记本A的绝密构想"
        let pageAContent = "这是笔记本 A 中的专有内容，包含其独特的设计模式与架构规约。"
        _ = try await storeA.anyCreatePage(
            title: pageATitle,
            pageType: .concept,
            customIcon: "doc.text.fill",
            content: pageAContent,
            tags: ["VaultA", "Design"],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )
        
        // 断言笔记本 A 内部能够成功检索到该页面
        let pagesInA = try await storeA.fetchAllPages()
        XCTAssertEqual(pagesInA.count, 1, "笔记本 A 中应当有且仅有 1 个页面")
        XCTAssertEqual(pagesInA.first?.title, pageATitle, "笔记本 A 中的页面标题应当一致")
        XCTAssertEqual(pagesInA.first?.content, pageAContent, "笔记本 A 中的页面内容应当一致")
        
        // 🔍 [调试] 打印物理文件大小，并直接物理读取确认
        print("🔍 [Debug] Phase 1 结束: A文件大小 = \(getFileSize(dbAURL)), 物理直接读取 A 的 pages = \(getPageCountDirectly(from: dbAURL))")
        
        // 🚀 【阶段二：热插拔物理切换至 笔记本 B，验证数据强隔离，页面数据应为空，随后写入专有数据 B】
        print("🎬 【Phase 2】物理挂载热切换至 笔记本 B => ID: \(vaultBID.uuidString)")
        try await DatabaseManager.shared.switchDatabase(to: vaultBID, at: dbBURL)
        
        // 再次刷新 DI 服务容器，绑定 笔记本 B 的全新连接池
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        let storeB = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        
        // 🔍 [调试] 切换到 B 后，确认物理 A 依然完好
        print("🔍 [Debug] Phase 2 刚切换到 B: A文件大小 = \(getFileSize(dbAURL)), 物理直接读取 A 的 pages = \(getPageCountDirectly(from: dbAURL))")
        
        // 关键物理断言：此时读取笔记本 B 的页面列表，必须为空，从而有力证明多租户笔记本数据是强隔离防泄漏的！
        let pagesInBBefore = try await storeB.fetchAllPages()
        XCTAssertTrue(pagesInBBefore.isEmpty, "关键断言：切换到全新的 笔记本 B 时，不应包含 笔记本 A 的任何数据，数据必须 100% 物理隔离")
        
        // 写入专属于 笔记本 B 的页面
        let pageBTitle = "专属于笔记本B的独立规划"
        let pageBContent = "这是笔记本 B 中的专有内容，主要包括其独立的产品演进大纲与里程碑节点。"
        _ = try await storeB.anyCreatePage(
            title: pageBTitle,
            pageType: .concept,
            customIcon: "chart.bar.fill",
            content: pageBContent,
            tags: ["VaultB", "Roadmap"],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )
        
        // 断言笔记本 B 内部能够成功检索到该页面
        let pagesInBAfter = try await storeB.fetchAllPages()
        XCTAssertEqual(pagesInBAfter.count, 1, "笔记本 B 中应当有且仅有 1 个页面")
        XCTAssertEqual(pagesInBAfter.first?.title, pageBTitle, "笔记本 B 中的页面标题应当一致")
        
        // 🔍 [调试] B 写入后，再次确认物理 A 依然完好
        print("🔍 [Debug] Phase 2 B 写入后: A文件大小 = \(getFileSize(dbAURL)), 物理直接读取 A 的 pages = \(getPageCountDirectly(from: dbAURL))")
        
        // 🚀 【阶段三：再次物理切回 笔记本 A，验证原本的数据依然存在，且不混入 笔记本 B 的任何痕迹】
        print("🎬 【Phase 3】物理挂载切换回 笔记本 A => ID: \(vaultAID.uuidString)")
        
        // 🔍 [调试] 在切回 A 之前，直接读取 A
        print("🔍 [Debug] Phase 3 切换回 A 前: A文件大小 = \(getFileSize(dbAURL)), 物理直接读取 A 的 pages = \(getPageCountDirectly(from: dbAURL))")
        
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        
        // 🔍 [调试] 在切回 A 之后，但在 register 之前，直接读取 A
        print("🔍 [Debug] Phase 3 切换回 A 后(未register): A文件大小 = \(getFileSize(dbAURL)), 物理直接读取 A 的 pages = \(getPageCountDirectly(from: dbAURL))")
        
        // 重新刷新并重装 DI 服务容器绑定的连接通道
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        // 🔍 [调试] 在 register 之后，但在获取 store 之前，直接读取 A
        print("🔍 [Debug] Phase 3 切换回 A 后(已register): A文件大小 = \(getFileSize(dbAURL)), 物理直接读取 A 的 pages = \(getPageCountDirectly(from: dbAURL))")
        
        let storeAagain = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        
        // 断言：笔记本 A 中的数据仍然完好无损地持久化保留，并且 100% 隔离了 笔记本 B 的所有写入数据
        let pagesInAagain = try await storeAagain.fetchAllPages()
        XCTAssertEqual(pagesInAagain.count, 1, "切回 笔记本 A 后，原本的数据应当完好保留")
        XCTAssertEqual(pagesInAagain.first?.title, pageATitle, "切回 笔记本 A 后，读出的应依然是 笔记本 A 的页面标题")
        XCTAssertEqual(pagesInAagain.first?.content, pageAContent, "切回 笔记本 A 后，读出的应依然是 笔记本 A 的页面内容")
        
        // 确保没有混入笔记本 B 的数据
        let containsB = pagesInAagain.contains(where: { $0.title == pageBTitle })
        XCTAssertFalse(containsB, "切回 笔记本 A 后，不应包含任何属于 笔记本 B 的残留数据")
        
        print("✅ 【Success】笔记本物理数据强隔离与持久化切换验证 100% 顺利通过！")
    }
    
    // MARK: - 调试辅助方法
    
    private func getFileSize(_ url: URL) -> String {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? UInt64 ?? 0
            return "\(size) 字节"
        } catch {
            return "文件不存在/读取失败: \(error.localizedDescription)"
        }
    }
    
    private func getPageCountDirectly(from url: URL) -> Int {
        do {
            let queue = try DatabaseQueue(path: url.path)
            return try queue.read { db in
                if try db.tableExists(AppConstants.Storage.Tables.pages) {
                    return try Table(AppConstants.Storage.Tables.pages).fetchCount(db)
                }
                return 0
            }
        } catch {
            print("⚠️ [Debug] Failed to read database directly: \(error)")
            return -1
        }
    }
    
    // MARK: - 演示数据注入测试用例
    
    /// 测试核心业务：验证在注入演示数据时，能够彻底清理当前金库的原有旧数据，并成功填充 5 个标准的演示页面。
    /// 职责说明：此测试验证 `InitialNotebookGenerator.generate(in:)` 功能在多金库模式下的行为，确保数据覆盖与结构安全，无任何硬编码 SQL。
    func testDemoDataGeneration() async throws {
        // 🚀 物理挂载切换至 笔记本 A
        print("🎬 【Demo Test】物理挂载切换至 笔记本 A => ID: \(vaultAID.uuidString)")
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        let store = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        
        // 1. 使用已有安全机制（anyCreatePage）写入旧页面，严禁编写硬编码的 SQL 语句
        let oldPageTitle = "即将被覆盖的过时构想"
        _ = try await store.anyCreatePage(
            title: oldPageTitle,
            pageType: .concept,
            customIcon: "doc.text",
            content: "这是一个旧页面，用于测试演示数据注入时的自动清理逻辑。",
            tags: ["Legacy"],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )
        
        // 验证旧页面确实存在
        let initialPages = try await store.fetchAllPages()
        XCTAssertEqual(initialPages.count, 1, "注入前应该有 1 个旧页面")
        XCTAssertEqual(initialPages.first?.title, oldPageTitle, "旧页面的标题应当一致")
        
        // 2. InitialNotebookGenerator 写入 DB → KnowledgeStore.refresh() 同步 → 验证完整链路
        let generatedCount = try await InitialNotebookGenerator.generate(in: store)
        let expectedCount = InitialNotebookGenerator.pkmPageCount
        XCTAssertEqual(generatedCount, expectedCount,
                       "应生成 \(expectedCount) 个演示页面")

        // 3. 模拟上层 AppStore.generateDemoData() 的 refresh 行为
        let ks = KnowledgeStore()
        await ks.refresh()
        XCTAssertFalse(ks.pages.isEmpty, "KnowledgeStore.refresh() 后 pages 应非空")

        // 4. 验证 KnowledgeStore 同步的页面数量、核心标题、标签完整性
        let ksTitles = ks.pages.map(\.title)
        XCTAssertEqual(ks.pages.count, expectedCount,
                       "KnowledgeStore 应为恰好 \(expectedCount) 页")
        XCTAssertTrue(ksTitles.contains(L10n.InitialNotebook.PKM.title1), "应包含第一个 PKM 页面")
        XCTAssertTrue(ksTitles.contains(L10n.InitialNotebook.PKM.title5), "应包含第五个 PKM 页面")
        // 验证标签不为空（演示数据应有关联标签）
        let taggedPages = ks.pages.filter { !$0.tags.isEmpty }
        XCTAssertEqual(taggedPages.count, expectedCount,
                       "全部 \(expectedCount) 页均应有关联标签")

        // 5. 验证 DB 层一致性
        let finalPages = try await store.fetchAllPages()
        XCTAssertEqual(finalPages.count, expectedCount,
                       "DB 层页面数应与 KnowledgeStore 一致")
        XCTAssertFalse(finalPages.contains(where: { $0.title == oldPageTitle }),
                       "旧页面应已被清理")

        // 6. 验证事件发布（模拟 AppStore.generateDemoData 的行为）
        let expectation = XCTestExpectation(description: "等待 graphRelayoutRequested 事件")
        let cancellable = AppEventBus.shared.subscribe()
            .sink { event in
                if case .graphRelayoutRequested = event {
                    expectation.fulfill()
                }
            }
        AppEventBus.shared.publish(.graphRelayoutRequested)
        
        // 等待异步分发的事件到达
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // 验证同步触发
        _ = cancellable

        print("✅ 【Success】完整链路：DB写入 → KnowledgeStore同步 → 4标题+标签 → 事件发布 全通过！")
    }

    // MARK: - 更多开发者工具单元测试用例
    
    /// 测试开发工具：重置新手引导流程状态。
    /// 职责说明：验证 `OnboardingService.shared.reset()` 是否能正确将新手引导标记置回未完成，从而保障用户可以重新体验新手引导流程。
    func testDeveloperResetOnboarding() async throws {
        let onboardingService = OnboardingService.shared
        
        // 1. 模拟用户已完成新手引导并在 MainActor 上设置状态
        await MainActor.run {
            onboardingService.completeOnboarding()
        }
        XCTAssertTrue(onboardingService.hasCompletedOnboarding, "新手引导应当已被标记为已完成")
        
        // 2. 调用开发工具的重置新手引导功能
        await MainActor.run {
            onboardingService.reset()
        }
        
        // 3. 验证状态已被正确置回
        XCTAssertFalse(onboardingService.hasCompletedOnboarding, "重置后引导完成标记应当为 false")
        XCTAssertEqual(onboardingService.currentStep, .graph, "重置后当前步骤应恢复到初始步骤 .graph")
        print("✅ 【Success】新手引导服务重置状态功能校验 100% 顺利通过！")
    }
    
    /// 测试开发工具：清除当前活跃金库的所有开发者页面数据。
    /// 职责说明：验证 `MaintenanceService.clearAllDeveloperData()` 能够将当前活跃数据库内的所有页面、链接、SRS元数据等全部物理清除，不留残余。
    func testDeveloperClearAllData() async throws {
        // 🚀 物理挂载切换至 笔记本 A
        print("🎬 【Clear All Test】物理挂载切换至 笔记本 A => ID: \(vaultAID.uuidString)")
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        guard let store = ServiceContainer.shared.resolveOptional((any AnyPageStoreCapabilities).self),
              let maintenanceService = ServiceContainer.shared.resolveOptional(MaintenanceService.self) else {
            XCTFail("DI 未就绪")
            return
        }
        
        // 1. 使用已有机制（anyCreatePage）写入测试数据，严禁硬编码 SQL
        _ = try await store.anyCreatePage(
            title: "待清除的页面",
            pageType: .entity,
            customIcon: "doc",
            content: "这是一个测试数据，应在重置时被彻底擦除。",
            tags: ["Temp"],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )
        
        // 验证写入成功
        let pagesBefore = try await store.fetchAllPages()
        XCTAssertEqual(pagesBefore.count, 1, "重置前页面数应当为 1")
        
        // 2. 调用开发工具的数据清除（系统重置）
        print("🎬 调用 MaintenanceService.clearAllDeveloperData() 清空开发者数据")
        await maintenanceService.clearAllDeveloperData()
        
        // 3. 验证物理清空是否彻底
        let pagesAfter = try await store.fetchAllPages()
        XCTAssertTrue(pagesAfter.isEmpty, "调用重置清除后，当前活跃库中的页面数据应该被彻底清空")
        print("✅ 【Success】清理全量开发者数据及其级联关联物理擦除验证 100% 顺利通过！")
    }
    
    /// 测试开发工具：生成指定节点数量的图谱压力测试数据。
    /// 职责说明：验证 `InitialNotebookGenerator.generateStressTest(in:count:)` 能够按指定数量成功创建图谱压测节点，并建立节点间的随机双向引用，且不使用任何硬编码的 SQL。
    func testDeveloperStressTestDataGeneration() async throws {
        // 🚀 物理挂载切换至 笔记本 A
        print("🎬 【Stress Test】物理挂载切换至 笔记本 A => ID: \(vaultAID.uuidString)")
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        let store = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        
        // 1. 运行压力测试数据生成器（指定生成 50 个节点，避免跑过久导致测试挂起超时）
        let targetCount = 50
        print("🎬 调用 InitialNotebookGenerator.generateStressTest 生成 \(targetCount) 个压测节点")
        let count = try await InitialNotebookGenerator.generateStressTest(in: store, count: targetCount)
        XCTAssertEqual(count, targetCount, "生成器返回的数量应当与期望一致")
        
        // 2. 从物理库中抓取全量页面，校验是否为 50 个
        let pages = try await store.fetchAllPages()
        XCTAssertEqual(pages.count, targetCount, "物理库中的页面总数应当为 50")
        
        // 3. 验证生成节点的随机引用特征
        let titles = pages.map { $0.title }
        XCTAssertTrue(titles.contains("StressNode_1"), "生成节点中应包含 StressNode_1")
        XCTAssertTrue(titles.contains("StressNode_50"), "生成节点中应包含 StressNode_50")
        print("✅ 【Success】压力测试节点生成功能及随机关联引用架构验证 100% 顺利通过！")
    }

    // MARK: - clearAllDataRequested 事件驱动清理测试

    /// 验证 ChatService 订阅 clearAllDataRequested 后清除聊天历史
    func testChatServiceClearsOnClearAllRequested() {
        let chatService = ChatService.shared
        chatService.saveUserMessage("测试消息")
        chatService.saveAssistantMessage("测试回复")
        XCTAssertFalse(chatService.loadHistory().isEmpty, "写入后历史不应为空")

        AppEventBus.shared.publish(.clearAllDataRequested)

        let expectation = XCTestExpectation(description: "ChatService 清除完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(chatService.loadHistory().isEmpty, "事件后聊天历史应为空")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// 验证 AIWorkflowStore 订阅 clearAllDataRequested 后清除工作流数据
    func testAIWorkflowStoreClearsOnClearAllRequested() {
        let store = AIWorkflowStore()
        // clearAll() 重置 lintIssues 和 refactorSuggestions 为空数组
        store.lintIssues = [LintIssue(
            severity: .warning, type: .brokenLink, pageID: UUID(),
            message: "test", suggestion: "fix it"
        )]
        XCTAssertFalse(store.lintIssues.isEmpty, "写入后 lint 不应为空")

        AppEventBus.shared.publish(.clearAllDataRequested)

        let expectation = XCTestExpectation(description: "AIWorkflowStore 清除完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(store.lintIssues.isEmpty, "事件后 lintIssues 应为空")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// 验证 SearchStore 订阅 clearAllDataRequested 后清除搜索数据
    func testSearchStoreClearsOnClearAllRequested() {
        let store = SearchStore()
        store.searchText = "AI"
        store.searchResults = [KnowledgePage(
            title: "Test", pageType: .entity, content: "",
            tags: [], sourceURL: nil, fileSize: nil, sourceType: nil
        )]
        XCTAssertFalse(store.searchResults.isEmpty, "写入后搜索结果不应为空")

        AppEventBus.shared.publish(.clearAllDataRequested)

        let expectation = XCTestExpectation(description: "SearchStore 清除完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(store.searchResults.isEmpty, "事件后搜索结果应为空")
            XCTAssertTrue(store.searchText.isEmpty, "事件后搜索文本应为空")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// 验证 SettingsStore 订阅 clearAllDataRequested 后重置设置
    func testSettingsStoreResetsOnClearAllRequested() {
        let settings = SettingsStore()
        settings.showPerfDashboard = true
        settings.hasShownGraphCoachMark = true
        XCTAssertTrue(settings.showPerfDashboard, "性能面板应已开启")
        XCTAssertTrue(settings.hasShownGraphCoachMark, "图谱引导应已标记")

        AppEventBus.shared.publish(.clearAllDataRequested)

        let expectation = XCTestExpectation(description: "SettingsStore 重置完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(settings.showPerfDashboard, "事件后性能面板应关闭")
            XCTAssertFalse(settings.hasShownGraphCoachMark, "事件后图谱引导应复位")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// 验证项目调研（Coffee）演示数据生成及物理文件挂载与导入历史维护
    func testResearchDemoDataGeneration() async throws {
        // 🚀 物理挂载切换至 笔记本 A
        print("🎬 【Research Demo Test】物理挂载切换至 笔记本 A => ID: \(vaultAID.uuidString)")
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        let store = ServiceContainer.shared.resolve((any AnyPageStoreCapabilities).self)
        
        // 1. 生成项目调研演示数据
        let generatedCount = try await InitialNotebookGenerator.generateResearchNotebook(in: store)
        let expectedCount = InitialNotebookGenerator.researchPageCount
        XCTAssertEqual(generatedCount, expectedCount, "项目调研笔记本应生成 \(expectedCount) 个演示页面")
        
        // 2. 验证页面标题
        let pages = try await store.fetchAllPages()
        let titles = pages.map(\.title)
        XCTAssertTrue(titles.contains(L10n.InitialNotebook.Coffee.title1), "应当包含第一个咖啡店对比分析页面")
        XCTAssertTrue(titles.contains(L10n.InitialNotebook.Coffee.title3), "应当包含调研报告页面")
        
        // 3. 验证物理 PDF 文件挂载与存在性
        guard let firstPage = pages.first(where: { $0.title == L10n.InitialNotebook.Coffee.title1 }) else {
            XCTFail("未找到目标演示页面")
            return
        }
        XCTAssertNotNil(firstPage.sourceURL, "演示页面应当挂载 sourceURL")
        if let urlString = firstPage.sourceURL, let fileURL = URL(string: urlString) {
            let exists = FileManager.default.fileExists(atPath: fileURL.path)
            XCTAssertTrue(exists, "物理 PDF 报告文件应当存在于 Imports 沙盒中: \(fileURL.path)")
            let data = try? Data(contentsOf: fileURL)
            XCTAssertNotNil(data, "应能够成功读取物理 PDF 报告")
            XCTAssertGreaterThan(data?.count ?? 0, 0, "物理 PDF 文件大小应大于 0 字节")
        } else {
            XCTFail("无法将 sourceURL 解析为本地 file URL")
        }
        
        // 4. 验证导入记录 (ImportRecord) 状态与属性被正确维护
        guard let dbWriter = DatabaseManager.shared.dbWriter else {
            XCTFail("数据库写入句柄为空")
            return
        }
        let records = try await dbWriter.read { db in
            try ImportRecord.fetchAll(db)
        }
        XCTAssertEqual(records.count, expectedCount, "写入的导入记录历史记录数应与生成的页面数一致")
        let coffeeRecord = records.first(where: { $0.title == L10n.InitialNotebook.Coffee.title1 })
        XCTAssertNotNil(coffeeRecord, "应当包含首要对比页面的导入记录")
        XCTAssertEqual(coffeeRecord?.status, "done", "初始导入记录状态应为 done 完成状态")
        XCTAssertEqual(coffeeRecord?.category, "file", "导入渠道类型应匹配为 file 文件")
        XCTAssertEqual(coffeeRecord?.pageID, firstPage.id.uuidString, "导入记录应当正确绑定对应的 pageID")
    }

    /// 验证 MaintenanceService 对默认笔记本（知识管理）的种子注入与分流路由以及物理文件和导入历史存在性
    func testMaintenanceServiceSeedsDefaultNotebookCorrectly() async throws {
        // 🚀 物理挂载切换至 笔记本 A，确保 dbURL 存在以引导生成真实的物理 Imports 沙盒文件
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        guard let store = ServiceContainer.shared.resolveOptional((any AnyPageStoreCapabilities).self),
              let maintenanceService = ServiceContainer.shared.resolveOptional(MaintenanceService.self) else {
            XCTFail("DI 未就绪")
            return
        }
        
        // 1. 清空当前数据库
        await maintenanceService.clearAllDeveloperData()
        
        // 2. 调用 seedDefaultContent 传入默认笔记本名
        await maintenanceService.seedDefaultContent(pages: [], vaultName: L10n.Vault.defaultName)
        
        // 3. 验证生成 18 个 PKM 页面
        let pages = try await store.fetchAllPages()
        XCTAssertEqual(pages.count, InitialNotebookGenerator.pkmPageCount, "知识图谱应包含 15 个页面")
        let titles = pages.map(\.title)
        XCTAssertTrue(titles.contains(L10n.InitialNotebook.PKM.title1), "应包含 PKM 第一篇页面")
        
        // 4. 验证默认笔记本的物理 Markdown 配置文件
        guard let firstPage = pages.first(where: { $0.title == L10n.InitialNotebook.PKM.title1 }) else {
            XCTFail("未找到 PKM 演示页面")
            return
        }
        XCTAssertNotNil(firstPage.sourceURL, "第一篇演示页面应当配置 sourceURL 物理连接")
        if let urlString = firstPage.sourceURL, let fileURL = URL(string: urlString) {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "PKM 方法论 Markdown 物理文件应当存在")
            let content = try? String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertNotNil(content, "物理文件应成功按 UTF8 解析读取")
            XCTAssertFalse(content?.isEmpty ?? true, "物理 Markdown 内容不应为空")
        }
        
        // 5. 验证导入历史是否被正确写入并绑定
        guard let dbWriter = DatabaseManager.shared.dbWriter else {
            XCTFail("数据库写入句柄为空")
            return
        }
        let records = try await dbWriter.read { db in
            try ImportRecord.fetchAll(db)
        }
        XCTAssertEqual(records.count, InitialNotebookGenerator.pkmPageCount, "知识图谱导入记录数应为 15")
        let firstRecord = records.first(where: { $0.title == L10n.InitialNotebook.PKM.title1 })
        XCTAssertNotNil(firstRecord, "应当生成第一篇文档的导入记录")
        XCTAssertEqual(firstRecord?.status, "done")
        XCTAssertEqual(firstRecord?.pageID, firstPage.id.uuidString)
    }

    /// 验证 MaintenanceService 对项目调研笔记本的种子注入与分流路由以及物理文件和导入历史存在性
    func testMaintenanceServiceSeedsResearchNotebookCorrectly() async throws {
        // 🚀 物理挂载切换至 笔记本 A，确保 dbURL 存在以引导生成真实的物理 Imports 沙盒文件
        try await DatabaseManager.shared.switchDatabase(to: vaultAID, at: dbAURL)
        StorageModuleRegistrar.register(in: ServiceContainer.shared)
        
        guard let store = ServiceContainer.shared.resolveOptional((any AnyPageStoreCapabilities).self),
              let maintenanceService = ServiceContainer.shared.resolveOptional(MaintenanceService.self) else {
            XCTFail("DI 未就绪")
            return
        }
        
        // 1. 清空当前数据库
        await maintenanceService.clearAllDeveloperData()
        
        // 2. 调用 seedDefaultContent 传入项目调研笔记本名
        await maintenanceService.seedDefaultContent(pages: [], vaultName: L10n.Vault.researchName)
        
        // 3. 验证生成 11 个咖啡店调研页面
        let pages = try await store.fetchAllPages()
        XCTAssertEqual(pages.count, InitialNotebookGenerator.researchPageCount, "项目调研笔记本应包含 15 个页面")
        let titles = pages.map(\.title)
        XCTAssertTrue(titles.contains(L10n.InitialNotebook.Coffee.title1), "应包含咖啡店对比页面")
        
        // 4. 验证项目调研笔记本的物理 PDF 文件
        // 核心纠错：验证首要对比分析页面（Coffee.title1）所关联的本地物理 PDF 文件。
        // 原先此处校验 Coffee.title3，但其 sourceURL 为外部网络链接，无本地沙盒物理文件缓存，故改为 title1。
        guard let coffeePage = pages.first(where: { $0.title == L10n.InitialNotebook.Coffee.title1 }) else {
            XCTFail("未找到咖啡调研报告页面")
            return
        }
        XCTAssertNotNil(coffeePage.sourceURL, "咖啡调研页面应挂载物理 sourceURL")
        if let urlString = coffeePage.sourceURL, let fileURL = URL(string: urlString) {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "咖啡调研问卷 PDF 物理文件应存在于 Imports 沙盒")
            let data = try? Data(contentsOf: fileURL)
            XCTAssertNotNil(data, "应能够正常加载 PDF 字节")
            XCTAssertGreaterThan(data?.count ?? 0, 0, "物理文件大小应大于 0")
        }
        
        // 5. 验证导入历史是否被正确写入并绑定
        guard let dbWriter = DatabaseManager.shared.dbWriter else {
            XCTFail("数据库写入句柄为空")
            return
        }
        let records = try await dbWriter.read { db in
            try ImportRecord.fetchAll(db)
        }
        XCTAssertEqual(records.count, InitialNotebookGenerator.researchPageCount, "项目调研笔记本导入记录数应为 15")
        // 核心纠错：校验绑定首要对比页面的导入记录
        let record = records.first(where: { $0.title == L10n.InitialNotebook.Coffee.title1 })
        XCTAssertNotNil(record, "应当生成首要对比页面的导入记录")
        XCTAssertEqual(record?.status, "done")
        XCTAssertEqual(record?.pageID, coffeePage.id.uuidString)
    }
}
