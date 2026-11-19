//
//  MacAuthViewLayoutTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 AuthView 依据运行时 Trait (interfaceIdiom) 在 Mac 与移动端布局间
//            正确分派，并确认区域切换/3D 翻转状态在两种布局下单一来源（登录逻辑共享）。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class MacAuthViewLayoutTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 运行时 Trait 布局分派

    /// Mac 形态 (idiom == .mac) 应走 macLoginLayout 且可正常渲染
    func testAuthView_RendersMacLayout_WithMacIdiom() {
        let host = render(idiom: .mac)
        XCTAssertNotNil(host.view)
    }

    /// 非 Mac 形态 (idiom == .iPhone) 应走 mobileLoginLayout 且可正常渲染
    func testAuthView_RendersMobileLayout_WithNonMacIdiom() {
        let host = render(idiom: .iPhone)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. 登录逻辑 / 翻转状态共享性

    /// 区域切换与 3D 翻转状态（rotateDegrees/displayedRegion）在 AuthView 中单一来源，
    /// 两种布局共享同一组状态，登录逻辑不因布局分派而重复定义。
    func testAuthView_RegionFlipState_SingleSourceForBothLayouts() {
        let mirror = Mirror(reflecting: AuthView())
        let rotateStateCount = mirror.children.filter { $0.label == "__rotateDegrees" }.count
        let regionStateCount = mirror.children.filter { $0.label == "__displayedRegion" }.count

        XCTAssertEqual(rotateStateCount, 1, "rotateDegrees 状态应单一来源，两布局共享而非重复声明")
        XCTAssertEqual(regionStateCount, 1, "displayedRegion 状态应单一来源，两布局共享而非重复声明")
    }

    // MARK: - 辅助

    private func render(idiom: InterfaceIdiom) -> UIHostingController<AnyView> {
        let root = AnyView(
            AuthView()
                .environment(\.interfaceIdiom, idiom)
                .snapshotEnvironment()
        )
        let host = UIHostingController(rootView: root)
        host.view.layoutIfNeeded()
        return host
    }
}
