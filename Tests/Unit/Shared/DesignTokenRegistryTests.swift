//
//  DesignTokenRegistryTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证多平台设计 Token 注册表的语义间距/圆角/触控热区/侧边栏宽度解析逻辑。
//

import XCTest
import SwiftUI
@testable import ZhiYu

final class DesignTokenRegistryTests: XCTestCase {

    private let registry = DesignTokenRegistry.shared

    // MARK: - resolveSpacing 基础间距 Token

    func testResolveSpacing_atomic_所有平台返回Tier1Space2() {
        for family in PlatformDeviceFamily.allCases {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            let result = registry.resolveSpacing(.atomic, in: context)
            XCTAssertEqual(result, DesignSystem.Tier1.Spacing.space2,
                           "atomic 在 \(family) 平台应返回 Tier1.space2")
        }
    }

    func testResolveSpacing_tight_所有平台返回Tier1Space4() {
        for family in PlatformDeviceFamily.allCases {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            let result = registry.resolveSpacing(.tight, in: context)
            XCTAssertEqual(result, DesignSystem.Tier1.Spacing.space4,
                           "tight 在 \(family) 平台应返回 Tier1.space4")
        }
    }

    func testResolveSpacing_compact_watch返回Tier1Space4_其他平台返回Tier2Compact() {
        let watchContext = PlatformContext(deviceFamily: .watch, isTouchOptimized: true)
        XCTAssertEqual(registry.resolveSpacing(.compact, in: watchContext),
                       DesignSystem.Tier1.Spacing.space4)

        for family in [PlatformDeviceFamily.phone, .pad, .mac] {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            XCTAssertEqual(registry.resolveSpacing(.compact, in: context),
                           DesignSystem.Tier2.Spacing.compact,
                           "compact 在 \(family) 平台应返回 Tier2.compact")
        }
    }

    func testResolveSpacing_standard_watch返回Tier1Space8_其他平台返回Tier2Standard() {
        let watchContext = PlatformContext(deviceFamily: .watch, isTouchOptimized: true)
        XCTAssertEqual(registry.resolveSpacing(.standard, in: watchContext),
                       DesignSystem.Tier1.Spacing.space8)

        for family in [PlatformDeviceFamily.phone, .pad, .mac] {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            XCTAssertEqual(registry.resolveSpacing(.standard, in: context),
                           DesignSystem.Tier2.Spacing.standard,
                           "standard 在 \(family) 平台应返回 Tier2.standard")
        }
    }

    // MARK: - resolveSpacing 容器间距 Token

    func testResolveSpacing_cardPadding_watch返回Space8_mac返回Space12_其他返回Tier2CardPadding() {
        XCTAssertEqual(
            registry.resolveSpacing(.cardPadding, in: PlatformContext(deviceFamily: .watch, isTouchOptimized: true)),
            DesignSystem.Tier1.Spacing.space8
        )
        XCTAssertEqual(
            registry.resolveSpacing(.cardPadding, in: PlatformContext(deviceFamily: .mac, isTouchOptimized: false)),
            DesignSystem.Tier1.Spacing.space12
        )
        for family in [PlatformDeviceFamily.phone, .pad] {
            XCTAssertEqual(
                registry.resolveSpacing(.cardPadding, in: PlatformContext(deviceFamily: family, isTouchOptimized: true)),
                DesignSystem.Tier2.Spacing.cardPadding,
                "cardPadding 在 \(family) 平台应返回 Tier2.cardPadding"
            )
        }
    }

    func testResolveSpacing_sectionPadding_watch返回Space12_mac返回Space16_其他返回Tier2SectionPadding() {
        XCTAssertEqual(
            registry.resolveSpacing(.sectionPadding, in: PlatformContext(deviceFamily: .watch, isTouchOptimized: true)),
            DesignSystem.Tier1.Spacing.space12
        )
        XCTAssertEqual(
            registry.resolveSpacing(.sectionPadding, in: PlatformContext(deviceFamily: .mac, isTouchOptimized: false)),
            DesignSystem.Tier1.Spacing.space16
        )
        for family in [PlatformDeviceFamily.phone, .pad] {
            XCTAssertEqual(
                registry.resolveSpacing(.sectionPadding, in: PlatformContext(deviceFamily: family, isTouchOptimized: true)),
                DesignSystem.Tier2.Spacing.sectionPadding,
                "sectionPadding 在 \(family) 平台应返回 Tier2.sectionPadding"
            )
        }
    }

    func testResolveSpacing_screenMargin_watch返回Space4_mac返回Space16_其他返回Tier2ScreenMargin() {
        XCTAssertEqual(
            registry.resolveSpacing(.screenMargin, in: PlatformContext(deviceFamily: .watch, isTouchOptimized: true)),
            DesignSystem.Tier1.Spacing.space4
        )
        XCTAssertEqual(
            registry.resolveSpacing(.screenMargin, in: PlatformContext(deviceFamily: .mac, isTouchOptimized: false)),
            DesignSystem.Tier1.Spacing.space16
        )
        for family in [PlatformDeviceFamily.phone, .pad] {
            XCTAssertEqual(
                registry.resolveSpacing(.screenMargin, in: PlatformContext(deviceFamily: family, isTouchOptimized: true)),
                DesignSystem.Tier2.Spacing.screenMargin,
                "screenMargin 在 \(family) 平台应返回 Tier2.screenMargin"
            )
        }
    }

    // MARK: - resolveRadius 圆角 Token

    func testResolveRadius_small_所有平台返回Tier2Small() {
        for family in PlatformDeviceFamily.allCases {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            XCTAssertEqual(registry.resolveRadius(.small, in: context),
                          DesignSystem.Tier2.Radius.small)
        }
    }

    func testResolveRadius_medium_所有平台返回Tier2Medium() {
        for family in PlatformDeviceFamily.allCases {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            XCTAssertEqual(registry.resolveRadius(.medium, in: context),
                          DesignSystem.Tier2.Radius.medium)
        }
    }

    func testResolveRadius_large_watch返回Tier1R8_其他返回Tier2Large() {
        XCTAssertEqual(
            registry.resolveRadius(.large, in: PlatformContext(deviceFamily: .watch, isTouchOptimized: true)),
            DesignSystem.Tier1.Radius.r8
        )
        for family in [PlatformDeviceFamily.phone, .pad, .mac] {
            XCTAssertEqual(
                registry.resolveRadius(.large, in: PlatformContext(deviceFamily: family, isTouchOptimized: true)),
                DesignSystem.Tier2.Radius.large,
                "large 在 \(family) 平台应返回 Tier2.large"
            )
        }
    }

    func testResolveRadius_card_watch返回Tier1R8_其他返回Tier2Large() {
        XCTAssertEqual(
            registry.resolveRadius(.card, in: PlatformContext(deviceFamily: .watch, isTouchOptimized: true)),
            DesignSystem.Tier1.Radius.r8
        )
        for family in [PlatformDeviceFamily.phone, .pad, .mac] {
            XCTAssertEqual(
                registry.resolveRadius(.card, in: PlatformContext(deviceFamily: family, isTouchOptimized: true)),
                DesignSystem.Tier2.Radius.large,
                "card 在 \(family) 平台应返回 Tier2.large (= Tier2.card)"
            )
        }
    }

    func testResolveRadius_capsule_所有平台返回Tier2Capsule() {
        for family in PlatformDeviceFamily.allCases {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            XCTAssertEqual(registry.resolveRadius(.capsule, in: context),
                          DesignSystem.Tier2.Radius.capsule)
        }
    }

    // MARK: - resolveTouchTarget 触控热区

    func testResolveTouchTarget_touchOptimized非watch返回44pt() {
        for family in [PlatformDeviceFamily.phone, .pad] {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            XCTAssertEqual(registry.resolveTouchTarget(in: context),
                          DesignSystem.Tier3.Action.minTouchTargetTouch,
                          "触控设备 \(family) 应返回 44pt 最小触控热区")
        }
    }

    func testResolveTouchTarget_watch返回Space32() {
        let context = PlatformContext(deviceFamily: .watch, isTouchOptimized: true)
        XCTAssertEqual(registry.resolveTouchTarget(in: context),
                      DesignSystem.Tier1.Spacing.space32,
                      "watch 触控热区应为 Tier1.space32")
    }

    func testResolveTouchTarget_pointer设备返回28pt() {
        let context = PlatformContext(deviceFamily: .mac, isTouchOptimized: false)
        XCTAssertEqual(registry.resolveTouchTarget(in: context),
                      DesignSystem.Tier3.Action.minTouchTargetPointer,
                      "指针设备应返回 28pt 最小触控热区")
    }

    // MARK: - resolveSidebarWidth 侧边栏宽度

    func testResolveSidebarWidth_mac返回240pt() {
        let context = PlatformContext(deviceFamily: .mac, isTouchOptimized: false)
        XCTAssertEqual(registry.resolveSidebarWidth(in: context),
                      DesignSystem.Tier3.Sidebar.widthMac,
                      "mac 侧边栏宽度应为 240pt")
    }

    func testResolveSidebarWidth_非mac返回280pt() {
        for family in [PlatformDeviceFamily.phone, .pad, .watch] {
            let context = PlatformContext(deviceFamily: family, isTouchOptimized: true)
            XCTAssertEqual(registry.resolveSidebarWidth(in: context),
                          DesignSystem.Tier3.Sidebar.widthPhone,
                          "非 mac 平台 \(family) 侧边栏宽度应为 280pt")
        }
    }

    // MARK: - 默认上下文

    func testResolveSpacing_默认上下文使用Current() {
        // 不传 context 时应使用 .current，不应崩溃
        let result = registry.resolveSpacing(.standard)
        XCTAssertGreaterThan(result, 0, "默认上下文解析 standard 应返回正值")
    }

    func testResolveRadius_默认上下文使用Current() {
        let result = registry.resolveRadius(.medium)
        XCTAssertGreaterThan(result, 0, "默认上下文解析 medium 应返回正值")
    }

    func testResolveTouchTarget_默认上下文使用Current() {
        let result = registry.resolveTouchTarget()
        XCTAssertGreaterThan(result, 0, "默认上下文解析触控热区应返回正值")
    }

    func testResolveSidebarWidth_默认上下文使用Current() {
        let result = registry.resolveSidebarWidth()
        XCTAssertGreaterThan(result, 0, "默认上下文解析侧边栏宽度应返回正值")
    }

    // MARK: - SemanticSpacingToken 完整性

    func testSemanticSpacingToken_所有case均可解析() {
        let context = PlatformContext(deviceFamily: .phone, isTouchOptimized: true)
        for token in [SemanticSpacingToken.atomic, .tight, .compact, .standard,
                      .cardPadding, .sectionPadding, .screenMargin] {
            let result = registry.resolveSpacing(token, in: context)
            XCTAssertGreaterThan(result, 0, "Token \(token) 应解析为正值")
        }
    }

    func testSemanticRadiusToken_所有case均可解析() {
        let context = PlatformContext(deviceFamily: .phone, isTouchOptimized: true)
        for token in [SemanticRadiusToken.small, .medium, .large, .card, .capsule] {
            let result = registry.resolveRadius(token, in: context)
            XCTAssertGreaterThan(result, 0, "Token \(token) 应解析为正值")
        }
    }
}
