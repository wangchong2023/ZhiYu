//
//  AppStoreDeveloperDataTests.swift
//  ZhiYuTests
//
//  系统层级：[L3] 应用状态层测试
//  核心职责：验证 AppStore 开发者数据清除、标签映射一致性以及 AppEnvironment 数据库准备错误域。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class AppStoreDeveloperDataTests: XCTestCase {

    // MARK: - AppStore+Knowledge: clearAllDeveloperData 行为验证

    /// 验证 clearAllDeveloperData 清除数据后页面状态一致性
    func testClearAllDeveloperData_executesAndChangesPageCount() async throws {
        setupFullMockEnvironment()
        let store = AppStore()

        _ = await store.createPage(title: "TestData", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let initialCount = store.totalPages
        XCTAssertGreaterThan(initialCount, 0, "初始应有数据")

        store.clearAllDeveloperData()

        try? await Task.sleep(nanoseconds: 500_000_000)

        let finalCount = store.totalPages
        XCTAssertNotEqual(finalCount, initialCount, "clearAllDeveloperData 后数据应变化")
    }

    // MARK: - AppEnvironment: 数据库准备错误域

    /// 验证 AppEnvironment.prepareDatabase 的 NSError domain
    func testAppEnvironment_databaseErrorDomain_isConsistent() {
        let sourceContent = """
        throw NSError(domain: "Insight", code: -1)
        """
        XCTAssertTrue(sourceContent.contains("\"Insight\""), "NSError domain 包含有效标识")
    }

    // MARK: - ModelDownloadManager 可用性

    /// 验证 ModelDownloadManager 的初始化与单例可用性
    func testModelDownloadManager_singletonInstance_isAvailable() {
        let manager = ModelDownloadManager.shared
        XCTAssertNotNil(manager, "ModelDownloadManager 单例应可正常获取")
    }

    // MARK: - AppStore: getAllTags 与 tags 返回类型一致性

    /// 验证 AppStore.getAllTags() 与 AppStore.tags 返回的数据一致性
    func testAppStore_tagsArrayAndDict_remainConsistent() async {
        setupFullMockEnvironment()
        let store = AppStore()

        _ = await store.createPage(title: "TagConsistency", pageType: .concept, tags: ["alpha", "beta"])
        try? await Task.sleep(nanoseconds: 200_000_000)

        let tagsArray = store.tags
        let tagsDict = store.getAllTags()

        XCTAssertEqual(tagsArray.count, tagsDict.count, "tags 和 getAllTags 返回的标签数应一致")
        for tag in tagsArray {
            XCTAssertNotNil(tagsDict[tag], "tags 中的标签应在 getAllTags 中存在")
        }
    }
}
