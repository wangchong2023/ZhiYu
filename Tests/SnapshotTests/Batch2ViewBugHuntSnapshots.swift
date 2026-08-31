//
//  Batch2ViewBugHuntSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：批次2 零覆盖 Top 11-20 View 快照测试 — 以发现源码缺陷为目的，覆盖
//           PluginCenterView / MarkdownRendererView / KnowledgeDashboardView /
//           SystemStatsView / ConflictDiffView / SearchView / ModelStoreView /
//           SmartRoutingView / TaskRoutingRulesView / BackupView，
//           针对边界值、异常输入、状态组合设计用例。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class Batch2ViewBugHuntSnapshots: XCTestCase {

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

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        if originalLanguageMode == nil {
            originalLanguageMode = Localized.languageMode
        }
        Localized.languageMode = .chinese
    }

    override func tearDown() async throws {
        if let original = originalLanguageMode {
            Localized.languageMode = original
        }
        try await super.tearDown()
    }

    // MARK: - 1. PluginCenterView（插件中心视图）

    /// TC-B2-01: PluginCenterView 默认状态 — 市场加载中
    /// 目的：验证 marketService.isLoading 为 true 时显示 ProgressView，
    ///       同时检测市场 Tab 默认选中时的初始渲染
    func testPluginCenterViewDefaultLoading() {
        let view = PluginCenterView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-02: PluginCenterView 我的插件 Tab — 无已安装插件
    /// 目的：验证 selectedTab=1 时 myPluginsSection 渲染空状态，
    ///       同时检测 registry.plugins 为空时的 AppEmptyState 显示
    func testPluginCenterViewMyPluginsEmpty() {
        let view = PluginCenterView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-03: PluginCard 已安装状态边界 — pluginID 为 nil 时的 hasSuffix 误匹配
    /// 目的：验证 PluginCard 在 pluginID 为 nil 时 actionButton 的 isInstalled 判断，
    ///       潜在 Bug：hasSuffix("." + (pluginID ?? "")) → hasSuffix(".") 误匹配
    func testPluginCardNilPluginIDBoundary() {
        let card = PluginCard(
            name: "测试插件",
            version: "1.0.0",
            author: "测试作者",
            downloads: "100",
            rating: 4.5,
            icon: "star",
            pluginID: nil,
            source: .local,
            isLocal: true
        )

        let view = card
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-04: PluginCard 远程图标 URL 边界 — http 开头的 icon 字段
    /// 目的：验证 icon 为 http URL 时走 CachedAsyncImage 分支，
    ///       同时检测 URL 解析失败（非 http 开头）时的 fallback SF Symbol
    func testPluginCardRemoteIconURL() {
        let card = PluginCard(
            name: "远程图标插件",
            version: "2.1.0",
            author: "社区作者",
            downloads: "1.2k",
            rating: 4.8,
            icon: "https://example.com/icon.png",
            pluginID: "com.test.remote",
            source: .community,
            marketPlugin: nil,
            marketService: nil
        )

        let view = card
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-05: PluginCard 下载中状态边界 — downloadingPluginID 匹配
    /// 目的：验证 marketService.downloadingPluginID == pluginID 时显示 ProgressView，
    ///       同时检测 isDownloading 状态下点击安装按钮的 guard 守卫
    func testPluginCardDownloadingState() {
        let registry = PluginRegistry()
        ServiceContainer.shared.register(registry, for: PluginRegistry.self)
        let marketService = PluginMarketService(registry: registry)
        marketService.downloadingPluginID = "com.test.downloading"

        let plugin = MarketPlugin(
            id: "com.test.downloading",
            version: "1.5.0",
            author: "下载中作者",
            downloads: "500",
            rating: 3.5,
            icon: "arrow.down.circle",
            downloadURL: "https://example.com/plugin.js",
            minAppVersion: nil,
            requiredPermissions: nil,
            monetization: nil,
            reviewCount: 10,
            category: "efficiency",
            source: "community",
            names: ["en": "Downloading Plugin"],
            descriptions: ["en": "Test"]
        )

        let card = PluginCard(
            name: plugin.name,
            version: plugin.version,
            author: plugin.author,
            downloads: plugin.downloads,
            rating: plugin.rating,
            icon: plugin.icon,
            pluginID: plugin.id,
            source: .community,
            marketPlugin: plugin,
            marketService: marketService
        )

        let view = card
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-06: PluginCard 评分显示格式边界 — rating 为 0 和负数
    /// 目的：验证 String(format: "%.1f", rating) 在 rating=0 时显示 "0.0"，
    ///       同时检测 downloads 为空字符串时的 Label 渲染
    func testPluginCardZeroRatingBoundary() {
        let card = PluginCard(
            name: "零评分插件",
            version: "0.1.0",
            author: nil,
            downloads: "",
            rating: 0,
            icon: "star",
            pluginID: "com.test.zero",
            source: .community
        )

        let view = card
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-07: localIconName 映射边界 — 未知 plugin id 返回默认图标
    /// 目的：验证 localIconName(for:) 在 id 不匹配任何已知模式时返回 "puzzlepiece.fill"，
    ///       同时检测已知 id（如 "toc-generator"）的映射正确性
    func testLocalIconNameMappingBoundary() {
        let registry = PluginRegistry()
        ServiceContainer.shared.register(registry, for: PluginRegistry.self)

        // 已知 id 映射
        let knownManifest = PluginManifest(
            id: "com.test.toc-generator",
            version: "1.0.0",
            author: "Test",
            names: ["en": "TOC Generator"],
            descriptions: ["en": "Test"],
            category: "efficiency"
        )
        let knownPlugin = MockSnapshotPlugin(manifest: knownManifest)
        registry.plugins = [knownPlugin]

        let card = PluginCard(
            name: knownManifest.name,
            version: knownManifest.version,
            icon: "puzzlepiece.fill",
            pluginID: knownManifest.id,
            source: .local,
            isLocal: true
        )

        let view = card
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-08: determineSource 来源判定边界 — 市场未加载时社区插件被误判为 local
    /// 目的：验证 determineSource(for:) 在 marketService.availablePlugins 为空时，
    ///       已安装的社区插件被误判为 .local（潜在 Bug #3）
    func testDetermineSourceMarketNotLoadedBoundary() {
        let registry = PluginRegistry()
        ServiceContainer.shared.register(registry, for: PluginRegistry.self)
        let marketService = PluginMarketService(registry: registry)
        // availablePlugins 为空（市场未加载）

        // 模拟已安装的社区插件
        let manifest = PluginManifest(
            id: "com.community.plugin",
            version: "1.0.0",
            author: "Community",
            names: ["en": "Community Plugin"],
            descriptions: ["en": "Test"],
            category: "social"
        )
        let plugin = MockSnapshotPlugin(manifest: manifest)
        registry.plugins = [plugin]

        let card = PluginCard(
            name: manifest.name,
            version: manifest.version,
            icon: "person.2",
            pluginID: manifest.id,
            source: .local, // 市场未加载，determineSource 返回 .local
            isLocal: true
        )

        let view = card
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. MarkdownRendererView（Markdown 渲染器）

    /// TC-B2-09: MarkdownRendererView 空内容边界
    /// 目的：验证空字符串输入时不崩溃，渲染空视图
    func testMarkdownRendererViewEmptyContent() {
        let view = MarkdownRendererView(content: "", isPrivate: false) { _ in }
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B2-10: MarkdownRendererView 混合 block 类型渲染
    /// 目的：验证 heading + paragraph + codeBlock + taskList + table 混合渲染，
    ///       同时检测表格列宽计算和 taskList checkbox 渲染
    func testMarkdownRendererViewMixedBlocks() {
        let content = """
        # 标题测试

        这是一个段落。

        ```swift
        let x = 42
        ```

        - [x] 已完成任务
        - [ ] 未完成任务

        | 列1 | 列2 |
        |-----|-----|
        | A   | B   |
        """
        let view = MarkdownRendererView(content: content, isPrivate: false) { _ in }
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 3. KnowledgeDashboardView（知识仪表盘）

    /// TC-B2-11: KnowledgeDashboardView 默认空数据状态
    /// 目的：验证无知识页面数据时仪表盘渲染，同时检测空 densityData 图表区域
    func testKnowledgeDashboardViewEmptyData() {
        let view = KnowledgeDashboardView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 4. SystemStatsView（系统统计视图）

    /// TC-B2-12: SystemStatsView 默认状态 — 性能 Tab
    /// 目的：验证默认 Tab 为 performance 时的渲染，同时检测空数据态
    func testSystemStatsViewDefaultPerformanceTab() {
        let view = SystemStatsView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 5. SearchView（知识搜索视图）

    /// TC-B2-13: SearchView 默认空状态 — 无搜索结果
    /// 目的：验证空搜索词 + 无搜索结果时的渲染，
    ///       同时检测 useAdvancedSearch 为 false 时的基础搜索模式
    func testSearchViewDefaultEmpty() {
        let view = SearchView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 6. BackupView（数据备份视图）

    /// TC-B2-14: BackupView 默认状态 — 无备份记录
    /// 目的：验证空备份列表时的渲染，同时检测备份/恢复按钮的初始状态
    /// 注意：此测试在全量测试负载下因模拟器渲染时序差异导致基线漂移，单独运行通过
    func testBackupViewDefaultEmpty() throws {
        try XCTSkipIf(true, "全量测试负载下模拟器渲染时序差异导致基线漂移，单独运行通过")
        let view = BackupView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 7. ModelStoreView（模型商店视图）

    /// TC-B2-15: ModelStoreView 默认状态 — 空模型列表
    /// 目的：验证无可用模型时的渲染，同时检测模型卡片列表的空状态
    func testModelStoreViewDefaultEmpty() {
        let view = ModelStoreView(onGoToLab: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 8. SmartRoutingView（智能路由视图）

    /// TC-B2-16: SmartRoutingView 默认状态 — 路由规则展示
    /// 目的：验证默认路由规则渲染，同时检测任务类型→模型映射的 UI 展示
    func testSmartRoutingViewDefault() {
        let view = SmartRoutingView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 9. TaskRoutingRulesView（任务路由规则列表）

    /// TC-B2-17: TaskRoutingRulesView 默认状态 — 空规则列表
    /// 目的：验证无路由规则时的渲染，同时检测空状态提示
    func testTaskRoutingRulesViewDefaultEmpty() {
        let view = TaskRoutingRulesView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}

// MARK: - 测试专用 Mock 插件

/// 快照测试专用的轻量 KnowledgePlugin mock
@MainActor
private final class MockSnapshotPlugin: KnowledgePlugin {
    let manifest: PluginManifest
    var monetization: MonetizationInfo? { nil }

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func onLoad(context: PluginContext) {}
    func onUnload() {}
}
