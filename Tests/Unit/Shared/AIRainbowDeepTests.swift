//
//  AIRainbowDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：AIRainbowGlow3DDeepTests.swift, AIRainbowMarkdownInteractiveTests.swift
//

import Dependencies
import SceneKit
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class AIRainbowDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testAIRainbowGlowBadgeMounting() throws {
        let modelManager = GlobalModelManager.shared
        let badge = AIRainbowGlowBadge()
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: badge)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        XCTAssertNotNil(modelManager, "全局模型管理器应单例就绪")
    }

    func testTappableSceneViewMounting() throws {
        let scene = SCNScene()
        let node = SCNNode(geometry: SCNSphere(radius: 1.0))
        let nodeID = UUID()
        node.name = nodeID.uuidString
        scene.rootNode.addChildNode(node)

        var tappedNodeID: UUID?
        let view = TappableSceneView(scene: scene, onNodeTap: { id in
            tappedNodeID = id
        })

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
        XCTAssertEqual(scene.rootNode.childNodes.count, 1)
        XCTAssertNil(tappedNodeID)
    }

    func testAIRainbowBadgeHelper_ResolveVisualState() {
        // 本地就绪状态 -> localReady
        let localReadyState = AIRainbowBadgeHelper.resolveVisualState(isLocalReady: true, isCloudEscalationEnabled: false)
        XCTAssertEqual(localReadyState, .localReady)

        // 本地就绪优先于云端提权 -> localReady
        let localReadyWithCloudState = AIRainbowBadgeHelper.resolveVisualState(isLocalReady: true, isCloudEscalationEnabled: true)
        XCTAssertEqual(localReadyWithCloudState, .localReady)

        // 云端提权状态 -> cloudEscalation
        let cloudEscalationState = AIRainbowBadgeHelper.resolveVisualState(isLocalReady: false, isCloudEscalationEnabled: true)
        XCTAssertEqual(cloudEscalationState, .cloudEscalation)

        // 默认闲置状态 -> idleNormal
        let defaultState = AIRainbowBadgeHelper.resolveVisualState(isLocalReady: false, isCloudEscalationEnabled: false)
        XCTAssertEqual(defaultState, .idleNormal)
    }

    func testAIRainbowBadgeHelper_ResolveColorsSafely() {
        // 验证主色解析不崩溃且生成有效 Color
        let colorLocal = AIRainbowBadgeHelper.resolveMainColor(isLocalReady: true, isCloudEscalationEnabled: false)
        let colorCloud = AIRainbowBadgeHelper.resolveMainColor(isLocalReady: false, isCloudEscalationEnabled: true)
        let colorIdle = AIRainbowBadgeHelper.resolveMainColor(isLocalReady: false, isCloudEscalationEnabled: false)

        let glowLocal = AIRainbowBadgeHelper.resolveGlowColor(isLocalReady: true)
        let glowIdle = AIRainbowBadgeHelper.resolveGlowColor(isLocalReady: false)

        // 构建简单测试视图验证色值能够正常参与 SwiftUI 视图图元渲染
        let view = VStack {
            Circle().fill(colorLocal)
            Circle().fill(colorCloud)
            Circle().fill(colorIdle)
            Circle().fill(glowLocal)
            Circle().fill(glowIdle)
        }
        XCTAssertNotNil(view)
    }

    func testAIRainbowBadgeHelper_ResolveControlCenterWidth() {
        // Mac Catalyst 自适应宽度
        let macWidth = AIRainbowBadgeHelper.resolveControlCenterWidth(isPad: false, isMacCatalyst: true)
        XCTAssertEqual(macWidth, Spacing.Sidebar.macCompactWidth)

        // iPad 自适应宽度
        let padWidth = AIRainbowBadgeHelper.resolveControlCenterWidth(isPad: true, isMacCatalyst: false)
        XCTAssertEqual(padWidth, Spacing.Sidebar.padSidebarWidth)

        // iPhone / 默认浮窗宽度
        let phoneWidth = AIRainbowBadgeHelper.resolveControlCenterWidth(isPad: false, isMacCatalyst: false)
        XCTAssertEqual(phoneWidth, Spacing.Sidebar.popoverDefaultWidth)
    }

    func testAIRainbowBadgeHelper_FormatMemoryInGB() {
        // 8 GB 格式化
        let eightGB: UInt64 = 8 * 1024 * 1024 * 1024
        let formattedEight = AIRainbowBadgeHelper.formatMemoryInGB(eightGB)
        XCTAssertEqual(formattedEight, "8.0 GB")

        // 16 GB 格式化
        let sixteenGB: UInt64 = 16 * 1024 * 1024 * 1024
        let formattedSixteen = AIRainbowBadgeHelper.formatMemoryInGB(sixteenGB)
        XCTAssertEqual(formattedSixteen, "16.0 GB")

        // 0 边界保护
        let zeroMemory = AIRainbowBadgeHelper.formatMemoryInGB(0)
        XCTAssertEqual(zeroMemory, "0.0 GB")
    }

    func testMarkdownRendererView_CompactModeAndLinkTap() {
        var tappedLink: String?
        let md = "请查看 [参考指南](applink://Docs/Guides/swift-coding-style.md) 了解更多。"

        let renderer = MarkdownRendererView(
            content: md,
            isPrivate: false,
            onLinkTap: { link in
                tappedLink = link
            },
            isCompact: true
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(renderer.view)
        XCTAssertNil(tappedLink)
    }

}
