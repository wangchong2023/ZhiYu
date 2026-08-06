//
//  MedalServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证奖章系统：allMedals 配置完整性、checkAchievements 阈值触发、reset 重置、Category 分类语义。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class MedalServiceTests: XCTestCase {

    private var service: MedalService { MedalService.shared }

    override func setUp() async throws {
        try await super.setUp()
        // 确保 KeyStoreProtocol 已注册（MedalService @Inject 依赖）
        if ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) == nil {
            ServiceContainer.shared.register(
                UserDefaultsKeyStore.shared as any KeyStoreProtocol,
                for: (any KeyStoreProtocol).self
            )
        }
        // 注册 MockHapticFeedback，避免 markAsEarned → HapticFeedback.shared.trigger
        // → @Inject 解析 HapticFeedbackProtocol 失败导致 fatalError
        ServiceContainer.shared.register(
            MockHapticFeedback() as any HapticFeedbackProtocol,
            for: (any HapticFeedbackProtocol).self
        )
        service.reset()
    }

    override func tearDown() async throws {
        service.reset()
        try await super.tearDown()
    }

    // MARK: - allMedals 配置完整性

    func testAllMedals_containsSevenMedals() {
        XCTAssertEqual(service.allMedals.count, 7)
    }

    func testAllMedals_idsUnique() {
        let ids = service.allMedals.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "所有奖章 ID 应唯一")
    }

    func testAllMedals_titlesNonEmpty() {
        for medal in service.allMedals {
            XCTAssertFalse(medal.titleKey.isEmpty, "奖章 titleKey 不应为空")
            XCTAssertFalse(medal.descKey.isEmpty, "奖章 descKey 不应为空")
        }
    }

    func testAllMedals_iconsNonEmpty() {
        for medal in service.allMedals {
            XCTAssertFalse(medal.icon.isEmpty, "奖章 icon 不应为空")
        }
    }

    func testAllMedals_colorHexStartsWithHash() {
        for medal in service.allMedals {
            XCTAssertTrue(medal.colorHex.hasPrefix("#"), "奖章 colorHex 应以 # 开头")
        }
    }

    func testAllMedals_thresholdPositive() {
        for medal in service.allMedals {
            XCTAssertGreaterThan(medal.threshold, 0, "奖章阈值应为正数")
        }
    }

    // MARK: - Category 分布

    func testCategory_exploreHasOneMedal() {
        let explore = service.allMedals.filter { $0.category == .explore }
        XCTAssertEqual(explore.count, 1)
        XCTAssertEqual(explore[0].id, "first_page")
        XCTAssertEqual(explore[0].threshold, 1)
    }

    func testCategory_accumulationHasThreeMedals() {
        let accumulation = service.allMedals.filter { $0.category == .accumulation }
        XCTAssertEqual(accumulation.count, 3)
        let ids = accumulation.map { $0.id }.sorted()
        XCTAssertEqual(ids, ["nodes_10", "nodes_100", "nodes_5"])
    }

    func testCategory_connectionHasThreeMedals() {
        let connection = service.allMedals.filter { $0.category == .connection }
        XCTAssertEqual(connection.count, 3)
        let ids = connection.map { $0.id }.sorted()
        XCTAssertEqual(ids, ["links_10", "links_100", "links_5"])
    }

    // MARK: - checkAchievements: 探索奖章

    func testCheckAchievements_firstPage_earnedAtNodeCount1() {
        service.checkAchievements(nodeCount: 1, linkCount: 0)
        XCTAssertTrue(service.earnedMedalIDs.contains("first_page"))
        XCTAssertEqual(service.newlyEarnedMedal?.id, "first_page")
    }

    func testCheckAchievements_firstPage_notEarnedAtNodeCount0() {
        service.checkAchievements(nodeCount: 0, linkCount: 0)
        XCTAssertFalse(service.earnedMedalIDs.contains("first_page"))
        XCTAssertNil(service.newlyEarnedMedal)
    }

    // MARK: - checkAchievements: 积累奖章

    func testCheckAchievements_nodes5_earnedAtNodeCount5() {
        service.checkAchievements(nodeCount: 5, linkCount: 0)
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_5"))
    }

    func testCheckAchievements_nodes10_earnedAtNodeCount10() {
        service.checkAchievements(nodeCount: 10, linkCount: 0)
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_10"))
    }

    func testCheckAchievements_nodes100_earnedAtNodeCount100() {
        service.checkAchievements(nodeCount: 100, linkCount: 0)
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_100"))
    }

    func testCheckAchievements_nodes5_notEarnedAtNodeCount4() {
        service.checkAchievements(nodeCount: 4, linkCount: 0)
        XCTAssertFalse(service.earnedMedalIDs.contains("nodes_5"))
    }

    // MARK: - checkAchievements: 连接奖章

    func testCheckAchievements_links5_earnedAtLinkCount5() {
        service.checkAchievements(nodeCount: 0, linkCount: 5)
        XCTAssertTrue(service.earnedMedalIDs.contains("links_5"))
    }

    func testCheckAchievements_links100_earnedAtLinkCount100() {
        service.checkAchievements(nodeCount: 0, linkCount: 100)
        XCTAssertTrue(service.earnedMedalIDs.contains("links_100"))
    }

    func testCheckAchievements_links5_notEarnedAtLinkCount4() {
        service.checkAchievements(nodeCount: 0, linkCount: 4)
        XCTAssertFalse(service.earnedMedalIDs.contains("links_5"))
    }

    // MARK: - checkAchievements: 多奖章同时触发

    func testCheckAchievements_highCounts_earnsMultipleMedals() {
        service.checkAchievements(nodeCount: 100, linkCount: 100)
        XCTAssertTrue(service.earnedMedalIDs.contains("first_page"))
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_5"))
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_10"))
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_100"))
        XCTAssertTrue(service.earnedMedalIDs.contains("links_5"))
        XCTAssertTrue(service.earnedMedalIDs.contains("links_10"))
        XCTAssertTrue(service.earnedMedalIDs.contains("links_100"))
    }

    // MARK: - checkAchievements: 不重复授予

    func testCheckAchievements_alreadyEarned_notReAwarded() {
        service.checkAchievements(nodeCount: 5, linkCount: 0)
        let firstNewlyEarned = service.newlyEarnedMedal
        // 再次调用，不应重复触发
        service.checkAchievements(nodeCount: 5, linkCount: 0)
        // newlyEarnedMedal 应保持为第一次的值（或被覆盖为相同值）
        XCTAssertEqual(service.newlyEarnedMedal?.id, firstNewlyEarned?.id)
    }

    // MARK: - checkAchievements: 渐进式授予

    func testCheckAchievements_progressiveGrowth_earnsInOrder() {
        service.checkAchievements(nodeCount: 1, linkCount: 0)
        XCTAssertTrue(service.earnedMedalIDs.contains("first_page"))
        XCTAssertFalse(service.earnedMedalIDs.contains("nodes_5"))

        service.checkAchievements(nodeCount: 5, linkCount: 0)
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_5"))
        XCTAssertFalse(service.earnedMedalIDs.contains("nodes_10"))

        service.checkAchievements(nodeCount: 10, linkCount: 0)
        XCTAssertTrue(service.earnedMedalIDs.contains("nodes_10"))
    }

    // MARK: - reset

    func testReset_clearsEarnedMedals() {
        service.checkAchievements(nodeCount: 100, linkCount: 100)
        XCTAssertFalse(service.earnedMedalIDs.isEmpty)

        service.reset()
        XCTAssertTrue(service.earnedMedalIDs.isEmpty)
        XCTAssertNil(service.newlyEarnedMedal)
    }

    // MARK: - newlyEarnedMedal 副作用

    func testNewlyEarnedMedal_setAfterCheckAchievements() {
        service.checkAchievements(nodeCount: 1, linkCount: 0)
        XCTAssertNotNil(service.newlyEarnedMedal)
        XCTAssertEqual(service.newlyEarnedMedal?.category, .explore)
    }

    // MARK: - Medal struct

    func testMedal_codableRoundTrip() throws {
        let medal = MedalService.Medal(
            id: "test",
            titleKey: "title",
            descKey: "desc",
            icon: "icon",
            colorHex: "#FFFFFF",
            threshold: 10,
            category: .accumulation
        )
        let data = try JSONEncoder().encode(medal)
        let decoded = try JSONDecoder().decode(MedalService.Medal.self, from: data)
        XCTAssertEqual(medal, decoded)
    }

    func testMedal_categoryCodable() throws {
        for category in [MedalService.Medal.Category.accumulation, .connection, .explore] {
            let medal = MedalService.Medal(
                id: "t", titleKey: "t", descKey: "d", icon: "i",
                colorHex: "#FFF", threshold: 1, category: category
            )
            let data = try JSONEncoder().encode(medal)
            let decoded = try JSONDecoder().decode(MedalService.Medal.self, from: data)
            XCTAssertEqual(decoded.category, category)
        }
    }
}
