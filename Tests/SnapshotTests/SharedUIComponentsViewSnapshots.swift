//
//  SharedUIComponentsViewSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：Shared/UIComponents 纯数据驱动 View 快照测试，覆盖 Cards/Buttons/Chips/Lists/
//           Banners/Feedback/Badges/Navigation/Decorators/Inputs 等低覆盖率组件，
//           验证视觉一致性并暴露源码潜在问题。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SharedUIComponentsViewSnapshots: XCTestCase {

    /// 保存原始语言模式，在 tearDown 中恢复
    private var originalLanguageMode: LanguageMode?

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func tearDown() async throws {
        if let original = originalLanguageMode {
            Localized.languageMode = original
        }
        try await super.tearDown()
    }

    /// 统一配置 Mock 测试环境
    private func setupMockEnvironment() {
        setupFullMockEnvironment()
        if originalLanguageMode == nil {
            originalLanguageMode = Localized.languageMode
        }
        Localized.languageMode = .chinese
    }

    // MARK: - 1. Cards

    /// 测试 AppCard 标准卡片容器默认样式的视觉一致性
    func testAppCardDefault() {
        setupMockEnvironment()

        let view = AppCard {
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                Text(L10n.Common.unknown)
                    .font(.headline)
                Text(L10n.Common.unknown)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppCard 自定义圆角与内边距令牌的视觉一致性
    func testAppCardCustomTokens() {
        setupMockEnvironment()

        let view = AppCard(cornerRadiusToken: .large, paddingToken: .giant) {
            Text(L10n.Common.unknown)
                .font(.title3.weight(.semibold))
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 StatCard 统计指标卡片默认样式的视觉一致性
    func testStatCardDefault() {
        setupMockEnvironment()

        let view = StatCard(
            title: L10n.Common.Stats.newPages,
            value: "128",
            icon: DesignSystem.Icons.docBadgePlus,
            color: .blue
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.6)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.6)))
    }

    /// 测试 AppMetricCard 指标卡片默认样式的视觉一致性
    func testAppMetricCardDefault() {
        setupMockEnvironment()

        let view = AppMetricCard(
            title: L10n.Common.Stats.newPages,
            value: "42",
            icon: DesignSystem.Icons.sparkles,
            color: .purple
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.6)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.6)))
    }

    // MARK: - 2. Buttons

    /// 测试 AppPrimaryButton 主操作按钮默认样式的视觉一致性
    func testAppPrimaryButtonDefault() {
        setupMockEnvironment()

        let view = AppPrimaryButton(title: L10n.Common.confirm, icon: DesignSystem.Icons.check) {}
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppPrimaryButton 加载态的视觉一致性
    func testAppPrimaryButtonLoading() {
        setupMockEnvironment()

        let view = AppPrimaryButton(title: L10n.Common.confirm, isLoading: true) {}
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppBorderedButton 边框按钮默认样式的视觉一致性
    func testAppBorderedButtonDefault() {
        setupMockEnvironment()

        let view = AppBorderedButton(title: L10n.Common.cancel, icon: DesignSystem.Icons.xmark, color: .appAccent) {}
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppCapsuleButton 主色胶囊按钮的视觉一致性
    func testAppCapsuleButtonPrimary() {
        setupMockEnvironment()

        let view = AppCapsuleButton(title: L10n.Common.confirm, icon: DesignSystem.Icons.check, isPrimary: true) {}
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }

    /// 测试 AppCapsuleButton 次色（纯展示）胶囊标签的视觉一致性
    func testAppCapsuleButtonSecondaryDisplay() {
        setupMockEnvironment()

        let view = AppCapsuleButton(title: L10n.Common.unknown, isPrimary: false, color: .appSecondary)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }

    // MARK: - 3. Chips

    /// 测试 AppChip 胶囊标签默认样式的视觉一致性
    func testAppChipDefault() {
        setupMockEnvironment()

        let view = AppChip(text: L10n.CoreModels.type.concept, color: .appAccent)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }

    /// 测试 AppIconChip 未选中态的视觉一致性
    func testAppIconChipUnselected() {
        setupMockEnvironment()

        let view = AppIconChip(icon: DesignSystem.Icons.sparkles, text: L10n.Common.unknown, color: .appAccent, isSelected: false)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }

    /// 测试 AppIconChip 选中态的视觉一致性
    func testAppIconChipSelected() {
        setupMockEnvironment()

        let view = AppIconChip(icon: DesignSystem.Icons.sparkles, text: L10n.Common.unknown, color: .appAccent, isSelected: true)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }

    /// 测试 AppBadge 胶囊形徽章的视觉一致性
    func testAppBadgePill() {
        setupMockEnvironment()

        let view = AppBadge(text: "99+", color: .red, isPill: true)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)))
    }

    /// 测试 AppBadge 圆形徽章的视觉一致性
    func testAppBadgeCircle() {
        setupMockEnvironment()

        let view = AppBadge(text: "5", color: .appAccent, isPill: false)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)))
    }

    // MARK: - 4. Lists

    /// 测试 GuideStepRow 引导步骤行的视觉一致性
    func testGuideStepRowDefault() {
        setupMockEnvironment()

        let view = GuideStepRow(number: 1, text: L10n.Common.unknown, icon: DesignSystem.Icons.sparkles)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 QuickActionRow 快速操作行的视觉一致性
    func testQuickActionRowDefault() {
        setupMockEnvironment()

        let view = QuickActionRow(
            icon: DesignSystem.Icons.sparkles,
            title: L10n.Common.unknown,
            subtitle: L10n.Common.unknown,
            color: .appAccent,
            action: {}
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 PageRowView 标准模式（含类型标签、更新时间、标签预览）的视觉一致性
    func testPageRowViewStandard() {
        setupMockEnvironment()

        let page = KnowledgePage(
            title: L10n.Common.unknown,
            pageType: .concept,
            tags: [L10n.CoreModels.type.concept, L10n.CoreModels.type.entity],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = PageRowView(page: page, compact: false)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 PageRowView 紧凑模式（隐藏辅助信息）的视觉一致性
    func testPageRowViewCompact() {
        setupMockEnvironment()

        let page = KnowledgePage(
            title: L10n.Common.unknown,
            pageType: .entity,
            tags: [L10n.CoreModels.type.entity]
        )

        let view = PageRowView(page: page, compact: true)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 5. Banners

    /// 测试 AIProcessingStatusBanner 无活跃任务（EmptyView 分支）的视觉一致性
    func testAIProcessingStatusBannerEmpty() {
        setupMockEnvironment()

        let view = AIProcessingStatusBanner()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 6. Feedback

    /// 测试 AppEmptyState 简单空状态（仅图标+标题+描述）的视觉一致性
    func testAppEmptyStateSimple() {
        setupMockEnvironment()

        let view = AppEmptyState.simple(
            icon: DesignSystem.Icons.document,
            title: L10n.Common.unknown,
            description: L10n.Common.unknown
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)))
    }

    /// 测试 AppEmptyState 带主操作按钮空状态的视觉一致性
    func testAppEmptyStateWithPrimaryAction() {
        setupMockEnvironment()

        let view = AppEmptyState.withAction(
            icon: DesignSystem.Icons.document,
            title: L10n.Common.unknown,
            description: L10n.Common.unknown,
            hint: L10n.Common.unknown,
            actionLabel: L10n.Common.confirm,
            actionIcon: DesignSystem.Icons.plus,
            actionRole: .primary,
            actionHandler: {}
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)))
    }

    /// 测试 AppErrorView 带重试按钮的视觉一致性
    func testAppErrorViewWithRetry() {
        setupMockEnvironment()

        let view = AppErrorView(
            message: L10n.Common.unknown,
            retryAction: {}
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)))
    }

    /// 测试 AppErrorView 无重试按钮的视觉一致性
    func testAppErrorViewWithoutRetry() {
        setupMockEnvironment()

        let view = AppErrorView(message: L10n.Common.unknown)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight / 2)))
    }

    /// 测试 DownloadProgressRing 下载中状态的视觉一致性
    func testDownloadProgressRingDownloading() {
        setupMockEnvironment()

        let view = DownloadProgressRing(state: .downloading(progress: 0.65, bytesPerSecond: 1024))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 DownloadProgressRing 暂停状态的视觉一致性
    func testDownloadProgressRingPaused() {
        setupMockEnvironment()

        let view = DownloadProgressRing(state: .paused)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 DownloadProgressRing 失败状态的视觉一致性
    func testDownloadProgressRingFailed() {
        setupMockEnvironment()

        let view = DownloadProgressRing(state: .failed(error: L10n.Common.unknown))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppAILoadingSkeleton 合成阶段骨架屏的视觉一致性
    func testAppAILoadingSkeletonSynthesis() {
        setupMockEnvironment()

        let view = AppAILoadingSkeleton(stage: .synthesis)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.5)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.5)))
    }

    /// 测试 AppAILoadingSkeleton 默认（通用）阶段骨架屏的视觉一致性
    func testAppAILoadingSkeletonGeneral() {
        setupMockEnvironment()

        let view = AppAILoadingSkeleton(stage: .general)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.5)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 1.5)))
    }

    // MARK: - 7. Badges

    /// 测试 AIRainbowGlowBadge 默认状态（无下载、无云端提权）的视觉一致性
    func testAIRainbowGlowBadgeDefault() {
        setupMockEnvironment()

        let view = AIRainbowGlowBadge()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 8. Navigation

    /// 测试 BreadcrumbView 空历史（仅首页节点）的视觉一致性
    func testBreadcrumbViewEmptyHistory() {
        setupMockEnvironment()

        let view = BreadcrumbView(history: [], onNavigate: { _ in }, onGoHome: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)))
    }

    /// 测试 BreadcrumbView 含多级历史节点的视觉一致性
    func testBreadcrumbViewWithHistory() {
        setupMockEnvironment()

        let pages: [KnowledgePage] = [
            KnowledgePage(title: L10n.Common.unknown, pageType: .concept),
            KnowledgePage(title: L10n.Common.unknown, pageType: .entity),
            KnowledgePage(title: L10n.Common.unknown, pageType: .source)
        ]

        let view = BreadcrumbView(history: pages, onNavigate: { _ in }, onGoHome: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)))
    }

    /// 测试 FloatingContextCapsule 无当前 Vault（hubIndicator 分支）的视觉一致性
    func testFloatingContextCapsuleHubIndicator() {
        setupMockEnvironment()

        let view = FloatingContextCapsule()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 9. Decorators

    /// 测试 AppDotPattern 工业级点阵背景默认样式的视觉一致性
    func testAppDotPatternDefault() {
        setupMockEnvironment()

        let view = AppDotPattern()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppDotPattern 自定义颜色与间距的视觉一致性
    func testAppDotPatternCustom() {
        setupMockEnvironment()

        let view = AppDotPattern(dotColor: .appAccent, spacing: DesignSystem.medium, dotSize: DesignSystem.small)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 10. Inputs

    /// 测试 AppTextField 空文本状态的视觉一致性
    func testAppTextFieldEmpty() {
        setupMockEnvironment()

        let view = AppTextField(placeholder: L10n.Common.unknown, text: .constant(""))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppTextField 含文本状态的视觉一致性
    func testAppTextFieldWithText() {
        setupMockEnvironment()

        let view = AppTextField(placeholder: L10n.Common.unknown, text: .constant(L10n.Common.unknown))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppTagField 空标签状态的视觉一致性
    func testAppTagFieldEmpty() {
        setupMockEnvironment()

        let view = AppTagField(placeholder: L10n.Common.unknown, tags: .constant([]))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试 AppTagField 含多个标签状态的视觉一致性
    func testAppTagFieldWithTags() {
        setupMockEnvironment()

        let view = AppTagField(
            placeholder: L10n.Common.unknown,
            tags: .constant([L10n.CoreModels.type.concept, L10n.CoreModels.type.entity, L10n.CoreModels.type.source])
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }
}
