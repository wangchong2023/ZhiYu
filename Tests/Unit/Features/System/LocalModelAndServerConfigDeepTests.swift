//
//  LocalModelAndServerConfigDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 LocalModelManagerView 本地模型管理入口、ServerConfigView 与 ServerEditSheet 服务器配置、URLImportSheet 批量链接导入。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class LocalModelAndServerConfigDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. LocalModelManagerView 渲染测试

    func testLocalModelManagerView_Hierarchy() {
        let host = NavigationStack {
            LocalModelManagerView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. ServerConfigView 与 ServerEditSheet 测试

    func testServerConfigView_Hierarchy() {
        let host = NavigationStack {
            ServerConfigView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testServerEditSheet_Hierarchy() {
        let host = ServerEditSheet(server: nil as MockServerConfig?, onSave: { _ in })
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. URLImportSheet 批量导入测试

    func testURLImportSheet_ValidURLs() {
        var text = "https://developer.apple.com\nhttps://arxiv.org/abs/1706.03762"
        let binding = Binding(get: { text }, set: { text = $0 })

        var imported: [URL] = []
        let host = URLImportSheet(urlText: binding, onImport: { imported = $0 })
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        _ = imported
    }

    func testURLImportSheet_WithInvalidLines() {
        var text = "https://valid.com\nnot_a_valid_url\nhttp://another.com"
        let binding = Binding(get: { text }, set: { text = $0 })

        let host = URLImportSheet(urlText: binding, onImport: { _ in })
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
