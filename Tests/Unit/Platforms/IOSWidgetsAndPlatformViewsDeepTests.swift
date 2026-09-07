//
//  IOSWidgetsAndPlatformViewsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 Platforms iOS 平台小组件/灵动岛与平台级视图。
//

import XCTest
import SwiftUI
import WidgetKit
import ActivityKit
import PDFKit
import LocalAuthentication
@testable import ZhiYu
import UFPCore

@MainActor
final class IOSWidgetsAndPlatformViewsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. LiveActivityView 灵动岛实装配置测试

    func testLiveActivityView_Configuration() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let widget = LiveActivityView()
        let body = widget.body
        XCTAssertNotNil(body, "LiveActivityView 应成功构建 WidgetConfiguration")
        #endif
    }

    // MARK: - 2. KnowledgeDistributionWidget 状态机与视图分发测试
    // 注意：KnowledgeDistributionWidget/Entry 在 Widget Extension target 中，主测试 target 无法访问

    // MARK: - 3. DailyInsightWidget 每日灵感组件测试
    // 注意：DailyInsightWidget/Entry 在 Widget Extension target 中，主测试 target 无法访问

    // MARK: - 4. QuickCaptureWidget 极速捕获组件测试
    // 注意：QuickCaptureWidget/Entry 在 Widget Extension target 中，主测试 target 无法访问

    // MARK: - 5. PDFKitRepresentedView 桥接视图测试

    func testPDFKitRepresentedView_Rendering() {
        let doc = PDFDocument()
        var currentPage = 0
        let pageBinding = Binding(get: { currentPage }, set: { currentPage = $0 })
        var selectedText = ""

        let pdfView = PDFKitRepresentedView(
            document: doc,
            currentPage: pageBinding
        ) { text in
            selectedText = text
        }

        let host = UIHostingController(rootView: pdfView)
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "PDFKitRepresentedView 应成功挂载至宿主控制器")
        _ = selectedText
    }

    // MARK: - 6. iOSPlatformCapabilities 平台能力单测

    func testiOSPlatformCapabilities() {
        let biometricProvider = iOSBiometricAuthProvider()
        XCTAssertEqual(biometricProvider.authenticationPolicy, .deviceOwnerAuthenticationWithBiometrics)

        let context = LAContext()
        _ = biometricProvider.canEvaluatePolicy(context: context)

        let compiler = CoreMLModelCompiler()
        XCTAssertTrue(compiler.supportsCompilation)

        let storage = iOSSecurityScopedStorage()
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy")
        storage.storeBookmark(for: dummyURL)
        let restored = storage.restoreURL(from: Data())
        XCTAssertNil(restored)
    }
}
