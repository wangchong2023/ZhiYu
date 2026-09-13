//
//  SharedCardAndRainbowBadgeDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 Shared 通用卡片体系 (AppCard/GlassCard/BorderedCard) 与彩虹呼吸光晕指示微标。
//

import XCTest
import SwiftUI
@testable import ZhiYu
import UFPCore

@MainActor
final class SharedCardAndRainbowBadgeDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. AppCard 多构造器与修饰符测试

    func testAppCard_TokensAndLegacyInits() {
        // 1. Token 构造器
        let card1 = AppCard(cornerRadiusToken: .card, paddingToken: .standardPadding) {
            Text("Token Card")
        }
        let host1 = UIHostingController(rootView: card1.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)
        XCTAssertEqual(card1.cornerRadiusToken, .card)
        XCTAssertEqual(card1.paddingToken, .standardPadding)

        // 2. CGFloat 映射构造器分支覆盖
        let card2 = AppCard(cornerRadius: Spacing.microRadius, padding: Spacing.atomic) {
            Text("Micro Atomic")
        }
        let host2 = UIHostingController(rootView: card2.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
        XCTAssertEqual(card2.cornerRadiusToken, .micro)

        let card3 = AppCard(cornerRadius: Spacing.largeRadius, padding: Spacing.giant) {
            Text("Large Giant")
        }
        let host3 = UIHostingController(rootView: card3.snapshotEnvironment())
        host3.view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host3.view.layoutIfNeeded()
        XCTAssertNotNil(host3.view)
        XCTAssertEqual(card3.cornerRadiusToken, .large)

        let card4 = AppCard(cornerRadius: Spacing.chipRadius, padding: Spacing.huge) {
            Text("Chip Huge")
        }
        let host4 = UIHostingController(rootView: card4.snapshotEnvironment())
        host4.view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host4.view.layoutIfNeeded()
        XCTAssertNotNil(host4.view)
        XCTAssertEqual(card4.paddingToken, .huge)
    }

    // MARK: - 2. AppBorderedCard & AppGlassCard 变体测试

    func testAppBorderedAndGlassCard() {
        // 1. 描边卡片
        let bordered = AppBorderedCard(cornerRadius: Spacing.cardRadius, borderColor: .appBorder) {
            Text("Bordered Card Content")
        }
        let host1 = UIHostingController(rootView: bordered.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)
        XCTAssertEqual(bordered.cornerRadius, Spacing.cardRadius)

        // 2. 玻璃拟态卡片 - 普通态
        let glassNormal = AppGlassCard(cornerRadius: Spacing.cardRadius, isHighlighted: false) {
            Text("Glass Normal")
        }
        let host2 = UIHostingController(rootView: glassNormal.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
        XCTAssertFalse(glassNormal.isHighlighted)

        // 3. 玻璃拟态卡片 - 高亮态
        let glassHighlighted = AppGlassCard(cornerRadius: Spacing.cardRadius, isHighlighted: true) {
            Text("Glass Highlighted")
        }
        let host3 = UIHostingController(rootView: glassHighlighted.snapshotEnvironment())
        host3.view.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        host3.view.layoutIfNeeded()
        XCTAssertNotNil(host3.view)
        XCTAssertTrue(glassHighlighted.isHighlighted)

        // 4. 卡片顶部色彩条
        let accent = AppCardAccent(color: .appAccent, height: Spacing.Decorator.accentLineWidth)
        let host4 = UIHostingController(rootView: accent.snapshotEnvironment())
        host4.view.frame = CGRect(x: 0, y: 0, width: 300, height: 10)
        host4.view.layoutIfNeeded()
        XCTAssertNotNil(host4.view)
        XCTAssertEqual(accent.height, Spacing.Decorator.accentLineWidth)
    }

    // MARK: - 3. View Extension 修饰符测试

    func testViewCardExtensions() {
        let viewToken = Text("Hello").appCard(cornerRadiusToken: .medium, paddingToken: .standardPadding)
        let host1 = UIHostingController(rootView: viewToken.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 200, height: 80)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        let viewLegacy = Text("World").appCard(cornerRadius: Spacing.smallRadius, padding: Spacing.small)
        let host2 = UIHostingController(rootView: viewLegacy.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 200, height: 80)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
        XCTAssertEqual(Spacing.smallRadius, 8)
    }

    // MARK: - 4. AIRainbowGlowBadge 呼吸指示微标渲染测试

    func testAIRainbowGlowBadge_Rendering() {
        let modelManager = GlobalModelManager.shared
        let badge = AIRainbowGlowBadge()
        _ = badge.body
        let host = UIHostingController(rootView: badge.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "AIRainbowGlowBadge 应成功挂载")
        XCTAssertNotNil(modelManager)
    }
}
