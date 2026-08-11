//
//  DashboardComponentsSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：Dashboard 组件快照测试，覆盖 BacklinksView 反向链接视图与 CreatePageView 新建页面表单。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class DashboardComponentsSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 测试数据工厂

    /// 构造测试用 KnowledgePage
    private func makePage(
        title: String = "Swift 并发编程",
        type: PageType = .concept,
        tags: [String] = ["编程", "Swift"],
        content: String = "## async/await\n\nSwift 并发编程核心内容，包含 [[actor]] 与 [[async/await]] 两个核心概念。"
    ) -> KnowledgePage {
        KnowledgePage(
            title: title,
            pageType: type,
            content: content,
            tags: tags
        )
    }

    // MARK: - BacklinksView 快照测试

    /// 测试反向链接视图 — 有出链的页面
    func testBacklinksView_WithOutgoingLinks() {
        let view = BacklinksView(page: makePage())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试反向链接视图 — 无出链的页面（边界情况）
    func testBacklinksView_NoOutgoingLinks() {
        let view = BacklinksView(page: makePage(content: "纯文本内容无双向链接"))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - CreatePageView 快照测试

    /// 测试新建页面表单 — 默认 concept 类型
    func testCreatePageView_Default() {
        let view = CreatePageView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
