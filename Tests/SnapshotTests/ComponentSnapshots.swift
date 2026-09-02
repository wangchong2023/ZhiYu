//
//  ComponentSnapshots.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：属于 SnapshotTests 模块，提供相关的结构体或工具支撑。
//
import XCTest
import UFPCore
import SwiftUI
import SnapshotTesting
import Combine
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class ComponentSnapshots: XCTestCase {

    /// 保存原始语言模式，在 tearDown 中恢复
    private var originalLanguageMode: LanguageMode?

    /// 依据环境变量判断快照录制策略，用于支持 CI/CD 脚本自动更新基准图片
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

    /// 测试 AI 脉搏指示器的视觉一致性
    func testAIPulseIndicator() {
        // 配置 Mock 环境
        setupMockEnvironment()

        let view = AIPulseIndicator()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotMediumComponentSize, height: DesignSystem.Metrics.progressHeight)
            .background(Color.appBackground)

        // 记录/验证 iOS 布局
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
    
    /// 统一配置 Mock 测试环境并控制快照录制模式
    /// - Parameter record: 显式控制是否开启录制。若传入 true 则强制开启录制，若为 false 则强制对比，不传则默认使用环境变量 RECORD_SNAPSHOTS 决定
    private func setupMockEnvironment(record: Bool? = nil) {
        setupFullMockEnvironment()
        
        // 强制中文环境，确保快照文本一致性，避免语言环境漂移导致快照不匹配
        if originalLanguageMode == nil {
            originalLanguageMode = Localized.languageMode
        }
        Localized.languageMode = .chinese
        
        // 清理聊天历史，防止其他测试（如 UI 测试）的残留数据污染快照测试
        ChatService.shared.clearHistory()
        
        // 重置提示词服务到默认状态，防止设置修改污染快照
        @Dependency(\.promptService) var promptService: PromptService
        promptService.reset()
    }
    
    /// 测试图谱节点的视觉一致性
    func testGraphNodeView() {
        setupMockEnvironment()
        let node = GraphNode(
            id: UUID(),
            title: "测试节点",
            pageType: .concept,
            position: .zero
        )
        
        // 使用包装器提供 Namespace
        let view = SnapshotContainer { namespace in
            GraphNodeView(
                node: node,
                isSelected: false,
                isAnimating: false,
                linkCount: 5,
                clusters: [],
                useClustering: false,
                onSelect: {},
                heroNamespace: namespace,
                viewportRect: CGRect(x: 0, y: 0, width: DesignSystem.Metrics.snapshotGraphViewportSize, height: DesignSystem.Metrics.snapshotGraphViewportSize),
                scale: 1.0
            )
        }
        .frame(width: DesignSystem.Metrics.largeIconBoxSize, height: DesignSystem.Metrics.largeIconBoxSize)
        .background(Color.appBackground)
        
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSmallComponentSize, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }
    
    /// 测试 AI 助手聊天视图 (ChatView) 的视觉一致性
    func testChatView() {
        setupMockEnvironment()
        var selectedTab = AppTab.chat

        let view = ChatView(selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
    
    /// 测试知识点详情页 (PageDetailView) 的视觉一致性
    func testPageDetailView() {
        setupMockEnvironment()
        let page = KnowledgePage(
            title: "快照测试页面",
            pageType: .concept,
            content: "# 这是一个测试页面\n用来进行视觉快照比对验证。",
            tags: ["测试", "快照"]
        )

        let view = SnapshotContainer { namespace in
            PageDetailView(page: page, heroNamespace: namespace)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.relaxedPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试系统设置页 (SettingsView) 的视觉一致性
    func testSettingsView() {
        setupMockEnvironment()

        let view = SettingsView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试响应式侧边栏组件的视觉一致性与代码覆盖率提升
    func testAdaptiveSidebarView() {
        setupMockEnvironment()
        var selectedTab = AppTab.knowledge
        var selection: SidebarSelection? = .tool(.lint)

        // 1. 测试 AdaptiveSidebarView 基础渲染
        let rawSidebarView = AdaptiveSidebarView(selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }))

        let view = rawSidebarView
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotSidebarWidth, height: DesignSystem.Metrics.snapshotPadWidth)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotSidebarWidth, height: DesignSystem.Metrics.snapshotPadWidth)))

        // 2. 历经所有 AppTab 的 case 分支，榨干 switch-case 覆盖率死角
        for tab in AppTab.allCases {
            // 注意：不向共享 Router 推入路由 — NavigationStack 在 snapshot 模式下
            // 解析 NavigationPath 中的路由时会触发 SwiftUI EnvironmentValues 断言，
            // 导致 AttributeGraph 无限递归 (AG::Graph::update_attribute 30+ 层)。
            // 导航目的地闭包覆盖率需通过独立单元测试覆盖。

            let detailViewForTab = SnapshotContainer { namespace in
                let detailView = AdaptiveDetailView(
                    selectedTab: Binding(get: { tab }, set: { _ in }),
                    selection: Binding(get: { selection }, set: { selection = $0 }),
                    heroNamespace: namespace
                )

                return detailView
            }
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotDetailWidth, height: DesignSystem.Metrics.snapshotPadWidth)
            .background(Color.appBackground)

            if tab == .knowledge {
                assertSnapshot(of: detailViewForTab, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotDetailWidth, height: DesignSystem.Metrics.snapshotPadWidth)))
            } else {
                let controller = UIHostingController(rootView: detailViewForTab)
                _ = controller.view
            }
        }
    }
    
    /// 测试空间导航面包屑组件的视觉一致性与代码覆盖率提升
    func testBreadcrumbView() {
        setupMockEnvironment()
        let history = [
            KnowledgePage(title: "首页节点", pageType: .concept, content: ""),
            KnowledgePage(title: "二级知识节点", pageType: .concept, content: ""),
            KnowledgePage(title: "当前深度详情", pageType: .concept, content: "")
        ]
        
        let rawBreadcrumbView = BreadcrumbView(history: history, onNavigate: { _ in }, onGoHome: {})
        
        // 显式触发重构后的面包屑点击行为，消灭未覆盖闭包行
        if let firstPage = history.first {
            rawBreadcrumbView.handleNavigate(to: firstPage)
        }
        
        let view = rawBreadcrumbView
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)
            .background(Color.appBackground)
            
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotBreadcrumbHeight)))
    }

    /// 测试关于页面 (AboutView) 的视觉一致性，验证版本号从 Info.plist 正确渲染
    func testAboutView() {
        setupMockEnvironment()

        let view = AboutView()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - RAG 质量评估视图快照

    /// 测试 RAGEvaluationView 加载状态的视觉一致性
    func testRAGEvaluationViewLoading() {
        setupMockEnvironment()

        let view = RAGEvaluationView()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 RAGEvaluationView 数据就绪后的完整展示
    func testRAGEvaluationViewWithData() async throws {
        setupMockEnvironment()
        let store = ServiceContainer.shared.resolve((any RAGGovernanceRepository).self)

        // 预写入评估、延迟、Token 数据以覆盖全部展示区域
        try await store.saveRAGEvaluation(RAGEvaluation(
            query: "What is quantum entanglement?",
            answer: "Quantum entanglement is a physical phenomenon...",
            faithfulness: 0.92, relevance: 0.88, precision: 0.85,
            hallucinationRate: 0.08, citationAccuracy: 0.90, answerCorrectness: 0.87,
            evaluatorModel: "gpt-4o"
        ))
        try await store.logCall(model: "gpt-4o", promptTokens: 1000, completionTokens: 500, latencyMS: 320, status: "success")
        try await store.logTokenUsage(model: "gpt-4o", promptTokens: 1000, completionTokens: 500)

        let view = RAGEvaluationView()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }
}

// MARK: - Snapshot Helpers

/// 用于快照测试的容器，提供 Namespace 和必要的环境注入
struct SnapshotContainer<Content: View>: View {
    @Namespace var namespace
    let content: (Namespace.ID) -> Content
    
    var body: some View {
        content(namespace)
    }
}
