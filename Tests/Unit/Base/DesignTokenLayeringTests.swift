//
//  DesignTokenLayeringTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
@testable import ZhiYu

final class DesignTokenLayeringTests: XCTestCase {
    
    // MARK: - 1. 3-Tier Layering Token 标尺级映射校验
    
    func testTier1PhysicalScales() {
        XCTAssertEqual(DesignSystem.Tier1.Spacing.space4, 4, "Tier 1 Spacing space4 标尺须为 4pt")
        XCTAssertEqual(DesignSystem.Tier1.Spacing.space16, 16, "Tier 1 Spacing space16 标尺须为 16pt")
        XCTAssertEqual(DesignSystem.Tier1.Radius.r16, 16, "Tier 1 Radius r16 标尺须为 16pt")
    }
    
    func testTier2SemanticTokenMapping() {
        XCTAssertEqual(
            DesignSystem.Tier2.Spacing.standard,
            DesignSystem.Tier1.Spacing.space16,
            "Tier 2 standard 语义间距须精准映射至 Tier 1 space16 物理标尺"
        )
        XCTAssertEqual(
            DesignSystem.Tier2.Radius.card,
            DesignSystem.Tier1.Radius.r16,
            "Tier 2 card 语义圆角须精准映射至 Tier 1 r16 物理标尺"
        )
    }
    
    func testTier3ComponentTokenMapping() {
        XCTAssertEqual(
            DesignSystem.Tier3.Sidebar.rowSpacing,
            DesignSystem.Tier2.Spacing.compact,
            "Tier 3 Sidebar.rowSpacing 须引用 Tier 2 语义 compact 间距"
        )
        XCTAssertEqual(
            DesignSystem.Tier3.Action.minTouchTargetTouch,
            44,
            "Tier 3 触控设备最小点击热区须符合 HIG 44pt 规范"
        )
    }
    
    // MARK: - 2. PlatformContext 多平台上下文动态解耦校验
    
    func testPlatformContextResolutionPhone() {
        let phoneContext = PlatformContext(deviceFamily: .phone, isTouchOptimized: true)
        
        let cardPadding = DesignTokenRegistry.shared.resolveSpacing(.cardPadding, in: phoneContext)
        let touchTarget = DesignTokenRegistry.shared.resolveTouchTarget(in: phoneContext)
        let sidebarWidth = DesignTokenRegistry.shared.resolveSidebarWidth(in: phoneContext)
        
        XCTAssertEqual(cardPadding, 16, "Phone 平台的 Card Padding 应为 16pt")
        XCTAssertEqual(touchTarget, 44, "Phone 平台的 触碰热区 应为 44pt")
        XCTAssertEqual(sidebarWidth, 280, "Phone 平台的 侧边栏宽度 应为 280pt")
    }
    
    func testPlatformContextResolutionMac() {
        let macContext = PlatformContext(deviceFamily: .mac, isTouchOptimized: false)
        
        let cardPadding = DesignTokenRegistry.shared.resolveSpacing(.cardPadding, in: macContext)
        let touchTarget = DesignTokenRegistry.shared.resolveTouchTarget(in: macContext)
        let sidebarWidth = DesignTokenRegistry.shared.resolveSidebarWidth(in: macContext)
        
        XCTAssertEqual(cardPadding, 12, "Mac 平台的 Card Padding 应为 12pt (更紧凑)")
        XCTAssertEqual(touchTarget, 28, "Mac 平台的 触碰热区 应为 28pt (光标精准控制)")
        XCTAssertEqual(sidebarWidth, 240, "Mac 平台的 侧边栏宽度 应为 240pt")
    }
    
    func testPlatformContextResolutionWatch() {
        let watchContext = PlatformContext(deviceFamily: .watch, isTouchOptimized: true)
        
        let cardPadding = DesignTokenRegistry.shared.resolveSpacing(.cardPadding, in: watchContext)
        let touchTarget = DesignTokenRegistry.shared.resolveTouchTarget(in: watchContext)
        
        XCTAssertEqual(cardPadding, 8, "Watch 平台的 Card Padding 应为 8pt (小屏适配)")
        XCTAssertEqual(touchTarget, 32, "Watch 平台的 触碰热区 应为 32pt")
    }
}
