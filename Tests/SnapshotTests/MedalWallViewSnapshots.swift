//
//  MedalWallViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：MedalWall 组件快照测试，覆盖 MedalCard 已解锁/未解锁状态与 MedalRewardPopup 弹窗。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class MedalWallViewSnapshots: XCTestCase {

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

    /// 构造已解锁奖章
    private func makeEarnedMedal() -> MedalService.Medal {
        MedalService.Medal(
            id: "first_page",
            titleKey: "medal.first_page.title",
            descKey: "medal.first_page.desc",
            icon: "sparkles",
            colorHex: "#FFD700",
            threshold: 1,
            category: .explore
        )
    }

    /// 构造未解锁奖章
    private func makeLockedMedal() -> MedalService.Medal {
        MedalService.Medal(
            id: "nodes_100",
            titleKey: "medal.nodes_100.title",
            descKey: "medal.nodes_100.desc",
            icon: "archivebox.fill",
            colorHex: "#A8EDEA",
            threshold: 100,
            category: .accumulation
        )
    }

    /// 构造连接类奖章
    private func makeConnectionMedal() -> MedalService.Medal {
        MedalService.Medal(
            id: "links_10",
            titleKey: "medal.links_10.title",
            descKey: "medal.links_10.desc",
            icon: "link.badge.plus",
            colorHex: "#F5576C",
            threshold: 10,
            category: .connection
        )
    }

    // MARK: - MedalCard 快照测试

    /// 测试已解锁奖章卡片 — 展示彩色图标与完整描述
    func testMedalCard_Earned() {
        let view = MedalCard(medal: makeEarnedMedal(), isEarned: true)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotMediumComponentSize, height: DesignSystem.Metrics.snapshotMediumComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotMediumComponentSize, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    /// 测试未解锁奖章卡片 — 展示锁定状态与灰色图标
    func testMedalCard_Locked() {
        let view = MedalCard(medal: makeLockedMedal(), isEarned: false)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotMediumComponentSize, height: DesignSystem.Metrics.snapshotMediumComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotMediumComponentSize, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    /// 测试连接类已解锁奖章 — 验证不同颜色主题渲染
    func testMedalCard_ConnectionEarned() {
        let view = MedalCard(medal: makeConnectionMedal(), isEarned: true)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotMediumComponentSize, height: DesignSystem.Metrics.snapshotMediumComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotMediumComponentSize, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    // MARK: - MedalRewardPopup 快照测试

    /// 测试奖章解锁弹窗 — 展示祝贺动画初始帧
    func testMedalRewardPopup_Default() {
        let view = MedalRewardPopup(medal: makeEarnedMedal(), onDismiss: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试连接类奖章弹窗 — 验证不同颜色主题
    func testMedalRewardPopup_ConnectionMedal() {
        let view = MedalRewardPopup(medal: makeConnectionMedal(), onDismiss: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
