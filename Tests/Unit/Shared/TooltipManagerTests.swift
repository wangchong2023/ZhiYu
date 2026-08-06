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

    func testInitial_shownTooltips为空() {
        XCTAssertTrue(manager.shownTooltips.isEmpty)
    }

    func testInitial_activeTooltip为nil() {
        XCTAssertNil(manager.activeTooltip)
    }

    func testInitial_pendingTooltips包含全部6个() {
        XCTAssertEqual(manager.pendingTooltips.count, 6)
    }

    // MARK: - markShown 状态机

    func testMarkShown_添加到shownTooltips() {
        manager.markShown(.createPage)
        XCTAssertTrue(manager.shownTooltips.contains(TooltipManager.TooltipType.createPage.rawValue))
    }

    func testMarkShown_从pendingTooltips移除() {
        manager.markShown(.createPage)
        XCTAssertFalse(manager.pendingTooltips.contains(.createPage))
    }

    func testMarkShown_多个Tooltip() {
        manager.markShown(.createPage)
        manager.markShown(.chat)
        manager.markShown(.tag)
        XCTAssertEqual(manager.shownTooltips.count, 3)
        XCTAssertEqual(manager.pendingTooltips.count, 3)
    }

    func testMarkShown_重复标记不增加() {
        manager.markShown(.createPage)
        manager.markShown(.createPage)
        XCTAssertEqual(manager.shownTooltips.count, 1, "重复标记不应增加计数")
    }

    func testMarkShown_全部标记后pending为空() {
        for tooltip in TooltipManager.TooltipType.allCases {
            manager.markShown(tooltip)
        }
        XCTAssertTrue(manager.pendingTooltips.isEmpty)
    }

    // MARK: - isShown 查询

    func testIsShown_未标记返回false() {
        XCTAssertFalse(manager.isShown(.createPage))
    }

    func testIsShown_标记后返回true() {
        manager.markShown(.createPage)
        XCTAssertTrue(manager.isShown(.createPage))
    }

    func testIsShown_不影响其他Tooltip() {
        manager.markShown(.createPage)
        XCTAssertTrue(manager.isShown(.createPage))
        XCTAssertFalse(manager.isShown(.chat))
    }

    // MARK: - resetAll 状态机

    func testResetAll_清空shownTooltips() {
        manager.markShown(.createPage)
        manager.markShown(.chat)
        manager.resetAll()
        XCTAssertTrue(manager.shownTooltips.isEmpty)
    }

    func testResetAll_恢复pendingTooltips() {
        manager.markShown(.createPage)
        manager.markShown(.chat)
        manager.resetAll()
        XCTAssertEqual(manager.pendingTooltips.count, 6)
    }

    func testResetAll_无数据时不崩溃() {
        manager.resetAll()
        XCTAssertTrue(manager.shownTooltips.isEmpty)
    }

    // MARK: - pendingTooltips 计算

    func testPendingTooltips_按allCases顺序() {
        let pending = manager.pendingTooltips
        XCTAssertEqual(pending, TooltipManager.TooltipType.allCases)
    }

    func testPendingTooltips_标记后排除() {
        manager.markShown(.ingest)
        let pending = manager.pendingTooltips
        XCTAssertFalse(pending.contains(.ingest))
        XCTAssertEqual(pending.count, 5)
    }

    // MARK: - 持久化

    func testMarkShown_持久化到UserDefaults() {
        manager.markShown(.createPage)
        let saved = testDefaults.stringArray(forKey: "app_shown_tooltips")
        XCTAssertNotNil(saved)
        XCTAssertTrue(saved?.contains("create_page") ?? false)
    }

    func testResetAll_从UserDefaults删除() {
        manager.markShown(.createPage)
        manager.resetAll()
        let saved = testDefaults.stringArray(forKey: "app_shown_tooltips")
        XCTAssertNil(saved)
    }

    func testInit_从UserDefaults恢复() {
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

    func testAllCases包含6个case() {
        XCTAssertEqual(TooltipManager.TooltipType.allCases.count, 6)
    }

    func testRawValue正确() {
        XCTAssertEqual(TooltipManager.TooltipType.createPage.rawValue, "create_page")
        XCTAssertEqual(TooltipManager.TooltipType.appLink.rawValue, "page_link")
        XCTAssertEqual(TooltipManager.TooltipType.graphFilter.rawValue, "graph_filter")
        XCTAssertEqual(TooltipManager.TooltipType.ingest.rawValue, "ingest")
        XCTAssertEqual(TooltipManager.TooltipType.chat.rawValue, "chat")
        XCTAssertEqual(TooltipManager.TooltipType.tag.rawValue, "tag")
    }

    // MARK: - titleKey 映射

    func testTitleKey_所有case返回非空字符串() {
        for tooltip in TooltipManager.TooltipType.allCases {
            XCTAssertFalse(tooltip.titleKey.isEmpty, "titleKey 不应为空")
        }
    }

    func testTitleKey_各case返回不同值() {
        let keys = TooltipManager.TooltipType.allCases.map { $0.titleKey }
        XCTAssertEqual(keys.count, Set(keys).count, "各 case 的 titleKey 应唯一")
    }

    // MARK: - descriptionKey 映射

    func testDescriptionKey_所有case返回非空字符串() {
        for tooltip in TooltipManager.TooltipType.allCases {
            XCTAssertFalse(tooltip.descriptionKey.isEmpty, "descriptionKey 不应为空")
        }
    }

    func testDescriptionKey_各case返回不同值() {
        let keys = TooltipManager.TooltipType.allCases.map { $0.descriptionKey }
        XCTAssertEqual(keys.count, Set(keys).count, "各 case 的 descriptionKey 应唯一")
    }

    // MARK: - icon 映射

    func testIcon_所有case返回非空字符串() {
        for tooltip in TooltipManager.TooltipType.allCases {
            XCTAssertFalse(tooltip.icon.isEmpty, "icon 不应为空")
        }
    }

    func testIcon_各case返回不同值() {
        let icons = TooltipManager.TooltipType.allCases.map { $0.icon }
        XCTAssertEqual(icons.count, Set(icons).count, "各 case 的 icon 应唯一")
    }
}
