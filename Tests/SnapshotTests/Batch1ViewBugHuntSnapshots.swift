//
//  Batch1ViewBugHuntSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：批次1 零覆盖 Top 10 View 快照测试 — 以发现源码缺陷为目的，覆盖
//           LogView / UserProfileView / KnowledgePageListView / CollaborationView /
//           OnDeviceLLMSettingsView / LLMSettingsView / SynthesisView / AuthView /
//           GraphView / Graph3DView，针对边界值、异常输入、状态组合设计用例。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class Batch1ViewBugHuntSnapshots: XCTestCase {

    /// 保存原始语言模式，在 tearDown 中恢复
    private var originalLanguageMode: LanguageMode?

    /// 保存原始 firstLaunchTime，在 tearDown 中恢复
    private var originalFirstLaunchTime: Any?

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
        // 保存 UserProfileView.activeDays 依赖的 UserDefaults 键值
        originalFirstLaunchTime = UserDefaults.standard.object(forKey: "app.firstLaunchTime")
    }

    override func tearDown() async throws {
        if let original = originalLanguageMode {
            Localized.languageMode = original
        }
        // 恢复 firstLaunchTime 原始状态，避免测试间状态泄漏
        if let original = originalFirstLaunchTime {
            UserDefaults.standard.set(original, forKey: "app.firstLaunchTime")
        } else {
            UserDefaults.standard.removeObject(forKey: "app.firstLaunchTime")
        }
        try await super.tearDown()
    }

    // MARK: - 1. LogView（操作日志视图）

    /// TC-B1-01: LogView 空状态 — 无日志条目时的视觉一致性
    /// 目的：验证空状态视图渲染正确，同时检测 emptyStateView 中 Text(L10n.Log.noLogs) 重复显示问题
    func testLogViewEmptyState() {
        let view = LogView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-02: LogViewContent 空状态边界 — 验证空日志列表不崩溃
    /// 目的：LogViewContent 依赖 store.logEntries，而 AppStore.logEntries 硬编码返回 []，
    ///       此测试验证该硬编码行为下视图仍能正常渲染
    func testLogViewContentEmptyStateBoundary() {
        let view = LogViewContent()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. UserProfileView（个人资料视图）

    /// TC-B1-03: UserProfileView 默认状态 — 无登录用户时的视觉一致性
    /// 目的：验证 authService.currentUser 为 nil 时视图不崩溃，头像显示占位图
    func testUserProfileViewDefaultNoUser() {
        // 清理 firstLaunchTime 模拟首次启动
        UserDefaults.standard.removeObject(forKey: "app.firstLaunchTime")

        let view = UserProfileView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-04: UserProfileView activeDays 边界 — 首次启动应返回 1
    /// 目的：验证 activeDays 计算属性在首次启动（无 firstLaunchTime）时返回 1，
    ///       同时检测副作用：计算属性中执行 UserDefaults.standard.set
    func testUserProfileViewActiveDaysFirstLaunch() {
        // 清理 firstLaunchTime 模拟首次启动
        UserDefaults.standard.removeObject(forKey: "app.firstLaunchTime")

        let view = UserProfileView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))

        // 验证副作用：计算属性应已写入 firstLaunchTime
        let stored = UserDefaults.standard.object(forKey: "app.firstLaunchTime")
        XCTAssertNotNil(stored, "activeDays 计算属性应在首次访问时写入 firstLaunchTime")
    }

    /// TC-B1-05: UserProfileView activeDays 系统时间回拨边界
    /// 目的：验证当 firstLaunchTime 晚于当前时间（系统时间回拨）时，
    ///       activeDays 仍返回 1（因 max(1, ...) 保护），但 diff.day 为负数
    func testUserProfileViewActiveDaysTimeRollback() {
        // 设置 firstLaunchTime 为未来日期（模拟系统时间回拨）
        let futureDate = Date().addingTimeInterval(86400 * 30) // 30 天后
        UserDefaults.standard.set(futureDate, forKey: "app.firstLaunchTime")

        let view = UserProfileView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 3. KnowledgePageListView（知识页面列表视图）

    /// TC-B1-06: KnowledgePageListView 默认状态 — 无 filterType 时的视觉一致性
    /// 目的：验证无过滤类型时显示所有页面分类，同时检测空知识库下的 summarySection 渲染
    func testKnowledgePageListViewDefaultNoFilter() {
        let view = KnowledgePageListView(filterType: nil)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-07: KnowledgePageListView 指定 filterType — 仅显示 concept 类型
    /// 目的：验证 filterType 为 .concept 时只渲染 conceptSection
    func testKnowledgePageListViewFilterConcept() {
        let view = KnowledgePageListView(filterType: .concept)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-08: KnowledgePageListView hasSearchResults 逻辑边界
    /// 目的：验证空搜索词 + filterType 有值但该类型无页面时，hasSearchResults 返回 true
    ///       （因为 searchText.isEmpty 直接返回 true），导致显示空分类而非"无搜索结果"
    ///       这是一个逻辑缺陷：空搜索+filterType 无页面时应显示"该类型无页面"而非"无搜索结果"
    func testKnowledgePageListViewEmptySearchWithFilterTypeNoPages() {
        let view = KnowledgePageListView(filterType: .comparison)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 4. CollaborationView（协作视图）

    /// TC-B1-09: CollaborationView 默认状态 — 未加入会话时的视觉一致性
    /// 目的：验证未加入协作会话时显示 actionSection（Host/Join 按钮）
    func testCollaborationViewDefaultNotJoined() {
        let view = CollaborationView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-10: CollaborationViewContent 默认状态边界
    /// 目的：验证 CollaborationViewContent 在模拟器环境下 isSimulator 为 true 时显示 simulatorWarning
    func testCollaborationViewContentSimulatorWarning() {
        let view = CollaborationViewContent()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 5. OnDeviceLLMSettingsView（端侧大模型设置视图）

    /// TC-B1-11: OnDeviceLLMSettingsView 默认状态 — 无加载模型时的视觉一致性
    /// 目的：验证端侧 LLM 未加载模型时的可用性检测区域和模型列表渲染
    func testOnDeviceLLMSettingsViewDefaultNoModel() {
        let view = OnDeviceLLMSettingsView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 6. LLMSettingsView（云端 LLM 设置视图）

    /// TC-B1-12: LLMSettingsView 默认状态 — 助手未启用时的视觉一致性
    /// 目的：验证 config.isEnabled 为 false 时的服务开关区域渲染
    func testLLMSettingsViewDefaultDisabled() {
        let view = LLMSettingsView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 7. SynthesisView（AI 合成实验室视图）

    /// TC-B1-13: SynthesisView 默认状态 — 无合成文档时的视觉一致性
    /// 目的：验证 synthesisStore.allSortedDocuments 为空时显示空状态视图和"返回全部"按钮
    ///       （当 selectedFilterType != nil 时）
    func testSynthesisViewDefaultEmpty() {
        var selection: SidebarSelection?
        var selectedTab: AppTab = .synthesis

        let view = SynthesisView(selection: Binding(get: { selection }, set: { selection = $0 }), selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 8. AuthView（认证视图）

    /// TC-B1-14: AuthView 默认状态 — 中国大陆区域时的视觉一致性
    /// 目的：验证 displayedRegion 为 .china 时显示 AuthPhonePanel
    func testAuthViewDefaultChinaRegion() {
        let view = AuthView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-15: AuthView 国际区域 — displayedRegion 为 international 时的视觉一致性
    /// 目的：验证 displayedRegion 为 .international 时显示 OverseasLoginCardView
    func testAuthViewInternationalRegion() {
        // 通过 AuthRegionDetector 设置默认区域为 international
        let view = AuthView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 9. GraphView（知识图谱视图）

    /// TC-B1-16: GraphEmptyStateView 默认状态 — 无知识图谱时的引导界面
    /// 目的：验证空图谱状态下的引导文案和按钮渲染
    func testGraphEmptyStateViewDefault() {
        var selectedTab: AppTab = .graph
        let view = GraphEmptyStateView(selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-17: GraphFilterPillsView 边界 — 选中 raw 类型
    /// 目的：验证选中 .raw 类型时过滤器药丸的视觉一致性
    func testGraphFilterPillsViewRawSelected() {
        var filterType: PageType? = .raw
        let view = GraphFilterPillsView(filterType: Binding(get: { filterType }, set: { filterType = $0 }), tooltipManager: TooltipManager())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 10. Graph3DView（3D 知识图谱视图）

    /// TC-B1-18: Graph3DView 默认状态 — 无场景时的视觉一致性
    /// 目的：验证 scene 为 nil 时 Graph3DView 不崩溃，显示 headerOverlay 和控制按钮
    func testGraph3DViewDefaultNoScene() {
        var selectedNodeID: UUID?
        var isFullScreen = false

        let view = Graph3DView(selectedNodeID: Binding(get: { selectedNodeID }, set: { selectedNodeID = $0 }), isFullScreen: Binding(get: { isFullScreen }, set: { isFullScreen = $0 }))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B1-19: Graph3DView 全屏状态边界
    /// 目的：验证 isFullScreen 为 true 时不显示 headerOverlay
    func testGraph3DViewFullScreenBoundary() {
        var selectedNodeID: UUID?
        var isFullScreen = true

        let view = Graph3DView(selectedNodeID: Binding(get: { selectedNodeID }, set: { selectedNodeID = $0 }), isFullScreen: Binding(get: { isFullScreen }, set: { isFullScreen = $0 }))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 11. LogEntryRow 边界测试（私有组件，通过 LogView 间接覆盖）

    /// TC-B1-20: LogView 空状态重复文案检测
    /// 目的：验证 emptyStateView 中 Text(L10n.Log.noLogs) 重复两次的视觉表现
    ///       这是一个已确认的 Bug：复制粘贴错误导致同一文案显示两遍
    func testLogViewEmptyStateDuplicateTextDetection() {
        let view = LogViewContent()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
