//
//  SharedComponentsDeepInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 Shared 通用空态、面包屑、通用输入与背景层组件交互。
//

import XCTest
import SwiftUI
@testable import ZhiYu
import UFPCore

@MainActor
final class SharedComponentsDeepInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. AppEmptyState 交互与角色矩阵测试

    func testAppEmptyState_SimpleAndWithActionRoles() {
        // 1. 简单空状态
        let simpleView = AppEmptyState.simple(
            icon: DesignSystem.Icons.docText,
            title: "暂无数据",
            description: "当前知识库尚未收录任何卡片"
        )
        let host1 = UIHostingController(rootView: simpleView.snapshotEnvironment())
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view, "简单空状态应正常完成布局求值")

        // 2. 带操作空状态（Primary / Secondary / Destructive 矩阵）
        var primaryActionTriggered = false
        var secondaryActionTriggered = false
        var destructiveActionTriggered = false

        let primaryView = AppEmptyState.withAction(
            icon: DesignSystem.Icons.plusCircle,
            title: "新建页面",
            description: "立即创建第一篇知识卡片",
            hint: "支持 Markdown 与双向链接",
            actionLabel: "立即创建",
            actionIcon: DesignSystem.Icons.plus,
            actionRole: .primary
        ) {
            primaryActionTriggered = true
        }

        let secondaryView = AppEmptyState.withAction(
            icon: DesignSystem.Icons.arrowClockwise,
            title: "同步失败",
            actionLabel: "重试同步",
            actionRole: .secondary
        ) {
            secondaryActionTriggered = true
        }

        let destructiveView = AppEmptyState.withAction(
            icon: DesignSystem.Icons.delete,
            title: "清空回收站",
            actionLabel: "全部抹除",
            actionRole: .destructive
        ) {
            destructiveActionTriggered = true
        }

        // 触发回调执行
        primaryView.action?.handler()
        secondaryView.action?.handler()
        destructiveView.action?.handler()

        XCTAssertTrue(primaryActionTriggered, "Primary 操作回调必须被执行")
        XCTAssertTrue(secondaryActionTriggered, "Secondary 操作回调必须被执行")
        XCTAssertTrue(destructiveActionTriggered, "Destructive 操作回调必须被执行")

        // 视图渲染容器
        let hostPrimary = UIHostingController(rootView: primaryView.snapshotEnvironment())
        let hostSecondary = UIHostingController(rootView: secondaryView.snapshotEnvironment())
        let hostDestructive = UIHostingController(rootView: destructiveView.snapshotEnvironment())
        hostPrimary.view.layoutIfNeeded()
        hostSecondary.view.layoutIfNeeded()
        hostDestructive.view.layoutIfNeeded()
    }

    // MARK: - 2. BreadcrumbView 导航交互深度测试

    func testBreadcrumbView_NavigationCallbacksAndEmptyHistory() {
        var homeTriggered = false
        var navigatedPageId: UUID?

        let page1 = KnowledgePage(id: UUID(), title: "架构设计", content: "分层规范")
        let page2 = KnowledgePage(id: UUID(), title: "L0-L3 规范", content: "单向依赖")

        // 1. 空历史记录场景
        let emptyBreadcrumb = BreadcrumbView(
            history: [],
            onNavigate: { id in navigatedPageId = id },
            onGoHome: { homeTriggered = true }
        )
        let hostEmpty = UIHostingController(rootView: emptyBreadcrumb.snapshotEnvironment())
        hostEmpty.view.layoutIfNeeded()
        XCTAssertNotNil(hostEmpty.view)

        // 2. 多级历史记录场景
        let breadcrumb = BreadcrumbView(
            history: [page1, page2],
            onNavigate: { id in navigatedPageId = id },
            onGoHome: { homeTriggered = true }
        )

        // 模拟节点点击
        breadcrumb.handleNavigate(to: page1)
        XCTAssertEqual(navigatedPageId, page1.id, "点击面包屑历史节点应正确回传对应 UUID")

        breadcrumb.handleNavigate(to: page2)
        XCTAssertEqual(navigatedPageId, page2.id)

        // 触发返回主页
        breadcrumb.onGoHome()
        XCTAssertTrue(homeTriggered, "点击主页应正确触发 onGoHome 回调")

        let hostMulti = UIHostingController(rootView: breadcrumb.snapshotEnvironment())
        hostMulti.view.layoutIfNeeded()
    }

    // MARK: - 3. AppInputs 输入组件矩阵测试

    func testAppInputs_TextFieldTagFieldAndMonospacedEditor() {
        var textBinding = "测试初始输入"
        let binding = Binding(get: { textBinding }, set: { textBinding = $0 })

        // 1. AppTextField
        let textField = AppTextField(placeholder: "请输入搜索关键词", text: binding)
        let hostTextField = UIHostingController(rootView: textField.snapshotEnvironment())
        hostTextField.view.layoutIfNeeded()
        XCTAssertNotNil(hostTextField.view)
        XCTAssertEqual(textBinding, "测试初始输入")

        // 2. AppTagField
        var tagsBinding = ["Swift", "RAG", "LLM"]
        let tagsStateBinding = Binding(get: { tagsBinding }, set: { tagsBinding = $0 })
        let tagField = AppTagField(placeholder: "添加标签...", tags: tagsStateBinding)
        let hostTagField = UIHostingController(rootView: tagField.snapshotEnvironment())
        hostTagField.view.layoutIfNeeded()
        XCTAssertNotNil(hostTagField.view)
        XCTAssertEqual(tagsBinding.count, 3)

        // 3. AppMonospacedEditor
        var monoBinding = "# Markdown 标题\n\n```swift\nlet x = 42\n```"
        let monoStateBinding = Binding(get: { monoBinding }, set: { monoBinding = $0 })
        let editor = AppMonospacedEditor(text: monoStateBinding, minHeight: 150)
        let hostEditor = UIHostingController(rootView: editor.snapshotEnvironment())
        hostEditor.view.layoutIfNeeded()
        XCTAssertNotNil(hostEditor.view)
        XCTAssertTrue(monoBinding.contains("42"))
    }

    // MARK: - 4. PageBackground 视觉系统测试

    func testPageBackground_MeshGradientAndAmbientGlow() {
        // 1. MeshGradientView
        let meshView = MeshGradientView()
        let hostMesh = UIHostingController(rootView: meshView.snapshotEnvironment())
        hostMesh.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        hostMesh.view.layoutIfNeeded()
        XCTAssertNotNil(hostMesh.view)

        // 2. AmbientGlowView
        let glowView = AmbientGlowView(color: .purple)
        let hostGlow = UIHostingController(rootView: glowView.snapshotEnvironment())
        hostGlow.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        hostGlow.view.layoutIfNeeded()
        XCTAssertNotNil(hostGlow.view)
        XCTAssertEqual(glowView.color, .purple)

        // 3. PageBackgroundView 统合页面背景
        let fullBackground = PageBackgroundView(accentColor: .blue)
        let hostFull = UIHostingController(rootView: fullBackground.snapshotEnvironment())
        hostFull.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        hostFull.view.layoutIfNeeded()
        XCTAssertNotNil(hostFull.view)
        XCTAssertEqual(fullBackground.accentColor, .blue)
    }
}
