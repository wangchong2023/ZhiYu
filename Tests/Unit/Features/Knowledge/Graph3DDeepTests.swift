//
//  Graph3DDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：Graph3DComponentsDeepTests.swift, Graph3DFuzzAndFaultInjectionTests.swift, Graph3DViewInteractiveTests.swift
//

import Dependencies
import SceneKit
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class Graph3DDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testGraph3DViewMountAndSceneLifecycle() throws {
        var selectedNodeID: UUID?
        var isFullScreen: Bool = false
        
        let bindingSelected = Binding<UUID?>(
            get: { selectedNodeID },
            set: { selectedNodeID = $0 }
        )
        let bindingFullScreen = Binding<Bool>(
            get: { isFullScreen },
            set: { isFullScreen = $0 }
        )
        
        // 1. 标准模式挂载渲染
        let graph3DView = Graph3DView(
            selectedNodeID: bindingSelected,
            isFullScreen: bindingFullScreen
        )
        .snapshotEnvironment()
        
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: graph3DView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        
        // 2. 全屏沉浸模式切换
        isFullScreen = true
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertTrue(isFullScreen)
        
        // 3. 节点反选
        selectedNodeID = nil
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertNil(selectedNodeID)
    }

    func testGraph3D_FuzzMalformedPagesAndCyclicLinks() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()

        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let id4 = UUID()

        // 包含极端标题：超长字符、控制符、Unicode Emoji 串、空标题、环形闭环
        // 源头修复：Graph3DView.createLabelNode 会自动截断到 GraphConstants.ThreeD.labelMaxCharacterCount，
        // 防止 SceneKit C3DMeshCreateText 在超长文本上 SIGSEGV。此处恢复原始 fuzz 强度（2400 字符）。
        let malformedPages = [
            KnowledgePage(
                id: id1,
                title: String(repeating: "极端超长标题ABC", count: 200),
                pageType: .concept,
                content: "包含自引用 [[极端超长标题ABC]] 与不可见字符 \0\u{0001}\n\t",
                relatedPageIDs: [id1, id2],
                isPinned: true
            ),
            KnowledgePage(
                id: id2,
                title: "🚀🔥💥🧠⚡️ 特殊字符与纯表情",
                pageType: .entity,
                content: "双向引用 [[环形终点]]",
                relatedPageIDs: [id3]
            ),
            KnowledgePage(
                id: id3,
                title: "环形终点",
                pageType: .comparison,
                content: "闭环回指 [[极端超长标题ABC]]",
                relatedPageIDs: [id1]
            ),
            KnowledgePage(
                id: id4,
                title: "孤立节点 with Nil Content",
                pageType: .raw,
                content: ""
            )
        ]
        store.pages = malformedPages

        struct Host: View {
            @State var selectedNodeID: UUID?
            @State var isFullScreen = false

            var body: some View {
                Graph3DView(selectedNodeID: $selectedNodeID, isFullScreen: $isFullScreen)
            }
        }

        let host = Host()
            .snapshotEnvironment(knowledgeStore: store)
            .renderInWindow()

        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)

        // 推进事件循环，确保 SceneKit 场景构建容忍畸形数据
        for _ in 0..<5 {
            try? await Task.sleep(nanoseconds: 30_000_000)
            await MainActor.run {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
        }

        XCTAssertEqual(store.pages.count, 4)
    }

    func testGraph3DViewMountAndSceneBuilding() {
        let bindingSelectedNodeID = Binding<UUID?>(get: { nil }, set: { _ in })
        let bindingIsFullScreen = Binding<Bool>(get: { false }, set: { _ in })

        let graph3DView = Graph3DView(
            selectedNodeID: bindingSelectedNodeID,
            isFullScreen: bindingIsFullScreen
        ).snapshotEnvironment()

        let hostingController = UIHostingController(rootView: graph3DView)
        hostingController.loadViewIfNeeded()
        XCTAssertNotNil(hostingController.view, "Graph3DView 应该能够安全挂载并完成场景构建")
    }

}
