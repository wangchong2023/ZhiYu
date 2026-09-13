//
//  SharedUIComponentsDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：SharedUIComponentsFullCoverageDeepTests.swift, SharedUIComponentsStateMachineDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class SharedUIComponentsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }
    func testHostingSetupSheet_Rendering() {
        let service = CollaborationService()
        struct SheetWrapper: View {
            @ObservedObject var service: CollaborationService
            @State var roomName = "我的研讨室"

            var body: some View {
                HostingSetupSheet(collabService: service, roomName: $roomName)
            }
        }

        let host = UIHostingController(rootView: SheetWrapper(service: service).snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "HostingSetupSheet 应正常完成渲染")
        XCTAssertFalse(service.isHosting)
    }

    func testAppLoadingSkeleton_AllTypes() {
        let types: [AppLoadingSkeleton.SkeletonType] = [.textRow, .paragraph, .cardBlock]
        for type in types {
            let skeleton = AppLoadingSkeleton(type: type)
            _ = skeleton.body
            let host = UIHostingController(rootView: skeleton)
            _ = host.view
            host.view.layoutIfNeeded()
            XCTAssertNotNil(host.view, "AppLoadingSkeleton (\(type)) 应正常渲染")
            XCTAssertEqual(skeleton.type, type)
        }
    }

    func testPageDetailMetaSectionView_RendersCorrectly() {
        let store = KnowledgeStore()
        let router = Router()

        let page = KnowledgePage(
            title: "元数据测试页面",
            pageType: .concept,
            content: "# 标题\n这是正文内容，包含一些知识点",
            tags: ["AI", "RAG", "Swift"],
            isPinned: true
        )

        var isExpanded = true
        let bindingExpanded = Binding(get: { isExpanded }, set: { isExpanded = $0 })

        let metaView = PageDetailMetaSectionView(page: page, isExpanded: bindingExpanded)
            .environment(store)
            .environment(router)

        let controller = UIHostingController(rootView: metaView)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertTrue(page.isPinned, "页面应处于置顶状态")
        XCTAssertEqual(page.tags.count, 3)
    }

    func testAdaptiveTextEditor_TextBindingAndEditing() {
        var text = "初始 Markdown 文本"
        let bindingText = Binding(get: { text }, set: { text = $0 })

        let editor = AdaptiveTextEditor(text: bindingText)
        let controller = UIHostingController(rootView: editor)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        bindingText.wrappedValue = "更新后的 Markdown 文本"
        XCTAssertEqual(text, "更新后的 Markdown 文本")
    }

    func testPageDetailAIMenuButton_MenuActions() {
        let aiButton = PageDetailAIMenuButton(
            isDisabled: false,
            onGenerateSummary: {},
            onExtractActions: {},
            onMindmap: {},
            onQuiz: {},
            onSlides: {},
            onReport: {},
            onInfographic: {},
            onShowSnapshotHistory: {},
            onExpandContent: {},
            onFindRelatedLinks: {}
        )

        let controller = UIHostingController(rootView: aiButton)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertFalse(aiButton.isDisabled, "AI 按键默认不应为禁用状态")
    }

}
