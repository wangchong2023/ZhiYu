//
//  NotebookHubViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：NotebookHub 组件快照测试，覆盖 NotebookCard 卡片、NotebookListRow 列表行与 NotebookHubView 主视图。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class NotebookHubViewSnapshots: XCTestCase {

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
        // 重置共享单例状态，避免前序测试修改导致快照精度漂移
        VaultService.shared.vaults = []
        VaultService.shared.selectedVaultID = nil
        OnboardingService.shared.reset()
        // 重置本地化语言模式，避免 LocalizedTests/LocalizationTests 修改 languageMode
        // 导致 L10n 文本变化、快照与基准图不一致
        Localized.languageMode = .auto
    }

    // MARK: - 测试数据工厂

    /// 构造测试用 Vault
    private func makeVault(
        name: String = "个人知识库",
        icon: String? = "📚",
        description: String? = "日常学习笔记与项目文档",
        pageCount: Int = 42,
        updatedAt: Date = Date(timeIntervalSince1970: 1_725_000_000)
    ) -> Vault {
        Vault(
            name: name,
            updatedAt: updatedAt,
            pageCount: pageCount,
            icon: icon,
            description: description
        )
    }

    /// 构造无描述的 Vault（边界情况）
    private func makeMinimalVault() -> Vault {
        Vault(name: "最小笔记本", pageCount: 0)
    }

    // MARK: - NotebookCard 快照测试

    /// 测试笔记本卡片 — 完整数据
    func testNotebookCard_FullData() {
        let view = NotebookCard(notebook: makeVault(), action: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotNotebookCardWidth, height: DesignSystem.Metrics.snapshotNotebookCardHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotNotebookCardWidth, height: DesignSystem.Metrics.snapshotNotebookCardHeight)))
    }

    /// 测试笔记本卡片 — 最小数据（无图标无描述）
    func testNotebookCard_MinimalData() {
        let view = NotebookCard(notebook: makeMinimalVault(), action: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotNotebookCardWidth, height: DesignSystem.Metrics.snapshotNotebookCardHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotNotebookCardWidth, height: DesignSystem.Metrics.snapshotNotebookCardHeight)))
    }

    // MARK: - NotebookListRow 快照测试

    /// 测试笔记本列表行 — 完整数据
    func testNotebookListRow_FullData() {
        let view = NotebookListRow(notebook: makeVault(), action: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }

    /// 测试笔记本列表行 — 无描述
    func testNotebookListRow_NoDescription() {
        let view = NotebookListRow(notebook: makeMinimalVault(), action: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }

    // MARK: - NotebookHubView 快照测试

    /// 测试笔记本工作台主视图 — 默认状态
    func testNotebookHubView_Default() {
        let view = NotebookHubView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
