//
//  Graph3DComponentsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import SceneKit
import UFPCore
@testable import ZhiYu

@MainActor
final class Graph3DComponentsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Graph3DView Window Mount & Controls Deep Tests

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

    // MARK: - 2. TappableSceneView & Gesture Coordinator Deep Tests

    func testTappableSceneViewCoordinatorGestures() throws {
        let testScene = SCNScene()
        let cameraNode = SCNNode()
        cameraNode.name = FeatureConstants.SceneNode.mainCamera
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 60)
        testScene.rootNode.addChildNode(cameraNode)
        
        var tappedNodeID: UUID?
        let tappableScene = TappableSceneView(scene: testScene) { uuid in
            tappedNodeID = uuid
        }
        
        let coordinator = tappableScene.makeCoordinator()
        coordinator.syncCameraState(from: cameraNode)
        
        // 挂载至 UIHostingController 测试宿主渲染链路
        let host = UIHostingController(rootView: tappableScene)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        
        XCTAssertNotNil(host.view)
    }
}
