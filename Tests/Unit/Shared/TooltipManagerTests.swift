//
//  TooltipManagerTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证引导提示管理器的状态机（标记已显示/查询/重置/待显示列表）与 TooltipType 枚举映射完整性。
//

import XCTest
@testable import ZhiYu

@MainActor
final class TooltipManagerTests: XCTestCase {

    private var manager: TooltipManager!
    private var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        // 使用独立的 UserDefaults suite，避免污染全局状态
        let suiteName = "test.tooltips.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建测试用 UserDefaults suite")
            return
        }
        testDefaults = defaults
        manager = TooltipManager(defaults: testDefaults)
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: testDefaults.dictionaryRepresentation().keys.first ?? "")
        manager = nil
        testDefaults = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialShownTooltipsEmpty() {
        XCTAssertTrue(manager.shownTooltips.isEmpty)
    }

    func testInitialActiveTooltipIsNil() {
        XCTAssertNil(manager.activeTooltip)
    }

    func testInitialPendingTooltipsContainsAllSix() {
        XCTAssertEqual(manager.pendingTooltips.count, 6)
    }

    // MARK: - markShown 状态机

    func testMarkShownAddsToShownTooltips() {
        manager.markShown(.createPage)
        XCTAssertTrue(manager.shownTooltips.contains(TooltipManager.TooltipType.createPage.rawValue))
    }

    func testMarkShownRemovesFromPendingTooltips() {
        manager.markShown(.createPage)
        XCTAssertFalse(manager.pendingTooltips.contains(.createPage))
    }

    func testMarkShownMultipleTooltips() {
        manager.markShown(.createPage)
        manager.markShown(.chat)
        manager.markShown(.tag)
        XCTAssertEqual(manager.shownTooltips.count, 3)
        XCTAssertEqual(manager.pendingTooltips.count, 3)
    }

    func testMarkShownDuplicateMarkNoIncrease() {
        manager.markShown(.createPage)
        manager.markShown(.createPage)
        XCTAssertEqual(manager.shownTooltips.count, 1, "重复标记不应增加计数")
    }

    func testMarkShownAllMarkedPendingEmpty() {
        for tooltip in TooltipManager.TooltipType.allCases {
            manager.markShown(tooltip)
        }
        XCTAssertTrue(manager.pendingTooltips.isEmpty)
    }

    // MARK: - isShown 查询

    func testIsShownNotMarkedReturnsFalse() {
        XCTAssertFalse(manager.isShown(.createPage))
    }

    func testIsShownMarkedReturnsTrue() {
        manager.markShown(.createPage)
        XCTAssertTrue(manager.isShown(.createPage))
    }

    func testIsShownDoesNotAffectOtherTooltip() {
        manager.markShown(.createPage)
        XCTAssertTrue(manager.isShown(.createPage))
        XCTAssertFalse(manager.isShown(.chat))
    }

    // MARK: - resetAll 状态机

    func testResetAllClearsShownTooltips() {
        manager.markShown(.createPage)
        manager.markShown(.chat)
        manager.resetAll()
        XCTAssertTrue(manager.shownTooltips.isEmpty)
    }

    func testResetAllRestoresPendingTooltips() {
        manager.markShown(.createPage)
        manager.markShown(.chat)
        manager.resetAll()
        XCTAssertEqual(manager.pendingTooltips.count, 6)
    }

    func testResetAllNoDataNoCrash() {
        manager.resetAll()
        XCTAssertTrue(manager.shownTooltips.isEmpty)
    }

    // MARK: - pendingTooltips 计算

    func testPendingTooltipsInAllCasesOrder() {
        let pending = manager.pendingTooltips
        XCTAssertEqual(pending, TooltipManager.TooltipType.allCases)
    }

    func testPendingTooltipsExcludedAfterMarked() {
        manager.markShown(.ingest)
        let pending = manager.pendingTooltips
        XCTAssertFalse(pending.contains(.ingest))
        XCTAssertEqual(pending.count, 5)
    }

    // MARK: - 持久化

    func testMarkShownPersistsToUserDefaults() {
        manager.markShown(.createPage)
        let saved = testDefaults.stringArray(forKey: "app_shown_tooltips")
        XCTAssertNotNil(saved)
        XCTAssertTrue(saved?.contains("create_page") ?? false)
    }

    func testResetAllDeletesFromUserDefaults() {
        manager.markShown(.createPage)
        manager.resetAll()
        let saved = testDefaults.stringArray(forKey: "app_shown_tooltips")
        XCTAssertNil(saved)
    }

    func testInitRestoresFromUserDefaults() {
        testDefaults.set(["create_page", "chat"], forKey: "app_shown_tooltips")
        let newManager = TooltipManager(defaults: testDefaults)
        XCTAssertTrue(newManager.isShown(.createPage))
        XCTAssertTrue(newManager.isShown(.chat))
        XCTAssertFalse(newManager.isShown(.tag))
        XCTAssertEqual(newManager.pendingTooltips.count, 4)
    }
}

// MARK: - TooltipType 枚举测试

final class TooltipTypeTests: XCTestCase {

    // MARK: - CaseIterable 完整性

    func testAllCasesContainsSixCases() {
        XCTAssertEqual(TooltipManager.TooltipType.allCases.count, 6)
    }
    // MARK: - titleKey 映射

    func testTitleKeyAllCasesReturnNonEmptyString() {
        for tooltip in TooltipManager.TooltipType.allCases {
            XCTAssertFalse(tooltip.titleKey.isEmpty, "titleKey 不应为空")
        }
    }

    func testTitleKeyEachCaseReturnsDifferentValue() {
        let keys = TooltipManager.TooltipType.allCases.map { $0.titleKey }
        XCTAssertEqual(keys.count, Set(keys).count, "各 case 的 titleKey 应唯一")
    }

    // MARK: - descriptionKey 映射

    func testDescriptionKeyAllCasesReturnNonEmptyString() {
        for tooltip in TooltipManager.TooltipType.allCases {
            XCTAssertFalse(tooltip.descriptionKey.isEmpty, "descriptionKey 不应为空")
        }
    }

    func testDescriptionKeyEachCaseReturnsDifferentValue() {
        let keys = TooltipManager.TooltipType.allCases.map { $0.descriptionKey }
        XCTAssertEqual(keys.count, Set(keys).count, "各 case 的 descriptionKey 应唯一")
    }

    // MARK: - icon 映射
}
