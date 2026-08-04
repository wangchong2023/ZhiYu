//
//  TagCloudCoordinatorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证标签云视图协调器（TagCloudCoordinator）的数据流更新、联动搜索过滤、增删改重命名以及批量删除等业务流逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class TagCloudCoordinatorTests: XCTestCase {
    
    /// 被测协调器实例
    private var coordinator: TagCloudCoordinator!
    
    /// 全局数据仓库实例
    private var store: AppStore!
    
    override func setUp() async throws {
        try await super.setUp()
        // 1. 初始化测试用全 Mock 依赖注入环境
        setupFullMockEnvironment()
        
        // 2. 初始化被测对象和依赖的 AppStore
        store = AppStore()
        coordinator = TagCloudCoordinator()
    }
    
    override func tearDown() async throws {
        coordinator = nil
        store = nil
        
        // 3. 释放协程资源，复位全局数据库和依赖容器，防止测试用例干扰
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        
        try await super.tearDown()
    }
    
    /// 验证协调器的基础初始化状态
    func testInitialization() {
        let customCoordinator = TagCloudCoordinator(initialTag: "Swift")
        XCTAssertEqual(customCoordinator.selectedTag, "Swift", "初始化时传入的初始标签必须正确保留在 selectedTag 属性中")
        XCTAssertNil(coordinator.selectedTag, "默认初始化时 selectedTag 应为 nil")
        XCTAssertFalse(coordinator.isEditMode, "初始化时默认编辑模式应为关闭状态")
        XCTAssertTrue(coordinator.searchText.isEmpty, "初始化时默认搜索文本应为空")
        XCTAssertTrue(coordinator.selectedTagsForBulk.isEmpty, "初始化时默认批量选中集合应为空")
    }
    
    /// 验证从 Store 抓取数据并映射、排序的正确性
    func testFetchData() async {
        // 1. 在测试数据库中注入模拟页面与标签数据
        _ = await store.createPage(title: "Page A", pageType: .concept, content: "Content A", tags: ["ZTag", "ATag"])
        _ = await store.createPage(title: "Page B", pageType: .concept, content: "Content B", tags: ["MTag"])
        
        // 等待数据落库和 ValueObservation 更新
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // 2. 执行数据抓取
        await coordinator.fetchData()
        
        // 3. 验证标签数组已成功提取并按照字母升序排列
        XCTAssertEqual(coordinator.tags.count, 3, "应该包含三个不重复的标签")
        XCTAssertEqual(coordinator.tags[0].tag, "ATag", "首位标签应为升序排列第一的 ATag")
        XCTAssertEqual(coordinator.tags[1].tag, "MTag", "次位标签应为 MTag")
        XCTAssertEqual(coordinator.tags[2].tag, "ZTag", "末位标签应为 ZTag")
    }
    
    /// 验证联动的过滤过滤逻辑 (基于 searchText 动态过滤过滤 tags)
    func testFilteredTags() async {
        // 1. 注入模拟标签数据
        _ = await store.createPage(title: "Page A", pageType: .concept, tags: ["SwiftUI", "Combine", "SwiftLint"])
        try? await Task.sleep(nanoseconds: 200_000_000)
        await coordinator.fetchData()
        
        // 2. 默认无搜索文本时，返回全部标签
        XCTAssertEqual(coordinator.filteredTags.count, 3, "空搜索条件应返回所有标签")
        
        // 3. 设置非空搜索文本，不区分大小写匹配
        coordinator.searchText = "swift"
        let filtered = coordinator.filteredTags
        XCTAssertEqual(filtered.count, 2, "搜索关键字 'swift' 应匹配到 SwiftUI 和 SwiftLint")
        XCTAssertTrue(filtered.contains { $0.tag == "SwiftUI" })
        XCTAssertTrue(filtered.contains { $0.tag == "SwiftLint" })
        XCTAssertFalse(filtered.contains { $0.tag == "Combine" })
    }
    
    /// 验证点击选中标签时，关联页面的筛选联动效果
    func testFilteredPages() async {
        // 1. 创建带不同标签的页面
        _ = await store.createPage(title: "Page Swift 1", pageType: .concept, tags: ["Swift"])
        _ = await store.createPage(title: "Page Swift 2", pageType: .concept, tags: ["Swift", "iOS"])
        _ = await store.createPage(title: "Page iOS Only", pageType: .concept, tags: ["iOS"])
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // 2. 当没有选中任何标签时，默认应返回全量页面
        coordinator.selectedTag = nil
        XCTAssertEqual(coordinator.filteredPages.count, 3, "未选择标签时，filteredPages 应返回全局所有页面")
        
        // 3. 选中 "Swift" 标签时，应仅返回包含 Swift 的页面
        coordinator.selectedTag = "Swift"
        let swiftPages = coordinator.filteredPages
        XCTAssertEqual(swiftPages.count, 2, "选中 'Swift' 标签应筛出关联的两个页面")
        XCTAssertTrue(swiftPages.contains { $0.title == "Page Swift 1" })
        XCTAssertTrue(swiftPages.contains { $0.title == "Page Swift 2" })
        XCTAssertFalse(swiftPages.contains { $0.title == "Page iOS Only" })
    }
    
    /// 验证创建新标签及其自动选中逻辑
    func testAddTag() async {
        // 1. 配置准备创建的标签
        coordinator.addTagName = "  NewCreatedTag  " // 带空格，验证 Trim 逻辑
        coordinator.showAddTagDialog = true
        
        // 2. 执行创建动作
        coordinator.performAddTag()
        
        // 3. 等待异步数据变更落库
        try? await Task.sleep(nanoseconds: 250_000_000)
        
        // 4. 验证标签创建效果
        XCTAssertFalse(coordinator.showAddTagDialog, "创建完毕后应自动关闭弹窗")
        XCTAssertTrue(coordinator.addTagName.isEmpty, "创建完毕后 addTagName 字段应清空复位")
        XCTAssertEqual(coordinator.selectedTag, "NewCreatedTag", "新建的标签应去除空格并自动成为当前选中标签")
        
        // 5. 验证是否成功落库及同步
        XCTAssertTrue(coordinator.tags.contains { $0.tag == "NewCreatedTag" }, "抓取的标签列表中必须包含新建标签")
    }
    
    /// 验证重命名标签及其同步联动逻辑
    func testRenameTag() async {
        // 1. 创建初始页面与标签
        _ = await store.createPage(title: "Tag Test", pageType: .concept, tags: ["OriginalTag"])
        try? await Task.sleep(nanoseconds: 200_000_000)
        await coordinator.fetchData()
        
        // 2. 选中该标签并配置重命名参数
        coordinator.selectedTag = "OriginalTag"
        coordinator.tagToRename = "OriginalTag"
        coordinator.newTagName = "RenamedTag"
        
        // 3. 执行重命名
        coordinator.performRename()
        try? await Task.sleep(nanoseconds: 250_000_000)
        
        // 4. 验证选中状态和标签已被同步重命名
        XCTAssertEqual(coordinator.selectedTag, "RenamedTag", "若重命名的标签正被选中，selectedTag 应该同步更新为新名字")
        XCTAssertNil(coordinator.tagToRename, "重命名完毕后 tagToRename 应该清空复位")
        XCTAssertTrue(coordinator.tags.contains { $0.tag == "RenamedTag" }, "抓取列表中应该包含新名字")
        XCTAssertFalse(coordinator.tags.contains { $0.tag == "OriginalTag" }, "抓取列表中不应再包含老名字")
    }
    
    /// 验证删除标签及置空选中状态的逻辑
    func testDeleteTag() async {
        // 1. 创建标签并选中
        _ = await store.createPage(title: "Delete Test", pageType: .concept, tags: ["DeleteMe"])
        try? await Task.sleep(nanoseconds: 200_000_000)
        await coordinator.fetchData()
        
        coordinator.selectedTag = "DeleteMe"
        coordinator.tagToDelete = "DeleteMe"
        
        // 2. 执行删除
        coordinator.performDelete()
        try? await Task.sleep(nanoseconds: 250_000_000)
        
        // 3. 验证选中状态已被置空，且标签从列表中移除
        XCTAssertNil(coordinator.selectedTag, "已删除的选中标签应当在 selectedTag 中被置空")
        XCTAssertNil(coordinator.tagToDelete, "删除完毕后 tagToDelete 应当清空复位")
        XCTAssertFalse(coordinator.tags.contains { $0.tag == "DeleteMe" }, "列表应该不包含已被删除的标签")
    }
    
    /// 验证批量选择标签和批量删除业务
    func testBulkDeleteTags() async {
        // 1. 创建多个不同标签的页面
        _ = await store.createPage(title: "P1", pageType: .concept, tags: ["Tag1"])
        _ = await store.createPage(title: "P2", pageType: .concept, tags: ["Tag2"])
        _ = await store.createPage(title: "P3", pageType: .concept, tags: ["Tag3"])
        try? await Task.sleep(nanoseconds: 200_000_000)
        await coordinator.fetchData()
        
        // 2. 进入编辑模式，选中 Tag1 和 Tag3
        coordinator.isEditMode = true
        coordinator.toggleSelection("Tag1")
        coordinator.toggleSelection("Tag3")
        XCTAssertEqual(coordinator.selectedTagsForBulk.count, 2, "此时应有两个标签处于批量删除待选池中")
        
        // 3. 执行批量删除
        coordinator.performBulkDelete()
        try? await Task.sleep(nanoseconds: 250_000_000)
        
        // 4. 验证删除状态
        XCTAssertFalse(coordinator.isEditMode, "批量删除完成后，编辑模式应自动关闭")
        XCTAssertTrue(coordinator.selectedTagsForBulk.isEmpty, "批量删除池应在操作完成后清空")
        XCTAssertEqual(coordinator.tags.count, 1, "应该只剩下一个未被选中的 Tag2")
        XCTAssertEqual(coordinator.tags[0].tag, "Tag2", "保留的标签应为 Tag2")
    }
}
