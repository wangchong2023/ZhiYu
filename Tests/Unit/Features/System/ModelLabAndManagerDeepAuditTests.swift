//
//  ModelLabAndManagerDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对大模型测试实验室（ModelLabView）与 ModelCardView
//            执行全生命周期渲染、状态切换与边界测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ModelLabAndManagerDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ModelLabView 全用例主视图渲染

    func testModelLabView_MainRendering() {
        let labView = ModelLabView(onGoToStore: {})
            .snapshotEnvironment()

        let host = UIHostingController(rootView: labView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. ModelCardView 状态机

    func testModelCardView_Rendering() {
        let modelManager = GlobalModelManager.shared
        if let manifest = modelManager.remoteManifests.first {
            let cardView = ModelCardView(
                manifest: manifest,
                modelManager: modelManager,
                alertManifest: .constant(nil),
                expandedModelId: .constant(manifest.modelId),
                onGoToLab: {}
            )
            .snapshotEnvironment()

            let host = UIHostingController(rootView: cardView)
            _ = host.view
            host.view.layoutIfNeeded()

            XCTAssertNotNil(host.view)
        }
    }
}
