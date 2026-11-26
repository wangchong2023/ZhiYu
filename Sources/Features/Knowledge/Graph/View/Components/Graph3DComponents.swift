//
//  Graph3DComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识图谱：3D 可视化、社区发现、力导向布局。
//
import SwiftUI
import SceneKit
import UFPDesignSystem
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 3D 图谱组件私有常量
enum Graph3DUIConstants {
    static let controlPadding: CGFloat = DesignTokens.SystemSpacing.contentMedium
    static let filterOffsetX: CGFloat = -50
    static let filterOffsetY: CGFloat = -20
    static let filterShadowRadius: CGFloat = DesignTokens.SystemSpacing.element
    static let filterShadowX: CGFloat = -4
    static let filterShadowY: CGFloat = DesignTokens.SystemSpacing.tiny
    static let filterPopupScale: CGFloat = CGFloat(DesignTokens.SystemOpacity.textSecondary)
    static let cameraZMin: Float = Float(DesignTokens.SystemSpacing.extraSmall)
}

// MARK: - 3D 图谱场景配置（非 UI 语境）
enum Graph3DSceneConfig {
    static let filterSpringResponse: CGFloat = 0.35
    static let panDampening: Float = 0.005
    static let cameraZDefault: Float = 60
    static let cameraZMax: Float = 300
}

// MARK: - SCNView 配置共享逻辑
/// 从场景中查找主相机节点，消除 configureSceneView 与 syncSceneViewPointOfView 的重复 childNode 查询
private func mainCameraNode(in scene: SCNScene?) -> SCNNode? {
    scene?.rootNode.childNode(withName: FeatureConstants.SceneNode.mainCamera, recursively: true)
}

/// 消除 iOS makeUIView 与 macOS makeNSView 的重复 SCNView 配置
@MainActor
private func configureSceneView<C: AnyObject>(_ scnView: SCNView, scene: SCNScene?, coordinator: C, syncCamera: (C, SCNNode) -> Void) {
    scnView.scene = scene
    // 关键：关闭系统默认的自带相机操作，以接管高清晰阻尼平滑计算
    scnView.allowsCameraControl = false
    scnView.autoenablesDefaultLighting = true
    scnView.backgroundColor = .clear

    // 关键：如果场景中有指定的相机节点，则将其设为观察点
    if let cameraNode = mainCameraNode(in: scene) {
        scnView.pointOfView = cameraNode
        syncCamera(coordinator, cameraNode)
    }
}
/// 消除 iOS/macOS handleTap 的重复逻辑，接收点击位置并执行命中检测
@MainActor
private func performTapHitTest(location: CGPoint, in scnView: SCNView, onNodeTap: (UUID?) -> Void) {
    let hitResults = scnView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
    for result in hitResults {
        if let name = result.node.name, let uuid = UUID(uuidString: name) {
            onNodeTap(uuid); return
        }
        if let parentName = result.node.parent?.name, let uuid = UUID(uuidString: parentName) {
            onNodeTap(uuid); return
        }
    }
    onNodeTap(nil)
}

// MARK: - Pinch/Magnify 手势共享逻辑
/// 消除 iOS handlePinch 与 macOS handleMagnify 的重复缩放逻辑
private func applyZoomScale(
    factor: Float,
    isChanged: Bool,
    isEnded: Bool,
    cameraNode: SCNNode,
    cameraZ: inout Float
) {
    if isChanged {
        let newZ = cameraZ / factor
        // 约束限制防极端穿透飞出（iOS 相机分量为 Float，macOS 为 CGFloat，走跨平台桥接）
        cameraNode.position = AppSceneKitVector3.withZ(max(Graph3DUIConstants.cameraZMin, min(newZ, Graph3DSceneConfig.cameraZMax)), in: cameraNode.position)
    } else if isEnded {
        cameraZ = AppSceneKitVector3.z(cameraNode.position)
    }
}
/// 消除 iOS/macOS handlePan 的重复逻辑，接收原始 translation 与状态标志
private func applyPanRotation(
    translationX: CGFloat,
    translationY: CGFloat,
    isChanged: Bool,
    isEnded: Bool,
    cameraNode: SCNNode,
    currentAngleX: inout Float,
    currentAngleY: inout Float
) {
    let dampening: Float = Graph3DSceneConfig.panDampening

    if isChanged {
        let deltaY = Float(translationX) * dampening
        let deltaX = Float(translationY) * dampening

        // 将位移积分转换为相机的 Euler 空间旋转（iOS 分量为 Float，macOS 为 CGFloat，走跨平台桥接）
        cameraNode.eulerAngles = AppSceneKitVector3.withY(currentAngleY - deltaY, in: cameraNode.eulerAngles)
        cameraNode.eulerAngles = AppSceneKitVector3.withX(currentAngleX - deltaX, in: cameraNode.eulerAngles)
    } else if isEnded {
        currentAngleY = AppSceneKitVector3.y(cameraNode.eulerAngles)
        currentAngleX = AppSceneKitVector3.x(cameraNode.eulerAngles)
    }
}

// MARK: - 共享 Coordinator（消除 iOS/macOS 手势处理重复）
/// 跨平台 Coordinator 基类，封装相机状态同步与 Tap/Pan/Zoom 手势处理
@MainActor
class Graph3DCoordinatorBase: NSObject {
    let onNodeTap: (UUID?) -> Void

    // ── 临时手势积分状态 ──
    var currentAngleX: Float = 0
    var currentAngleY: Float = 0
    var cameraZ: Float = Graph3DSceneConfig.cameraZDefault

    init(onNodeTap: @escaping (UUID?) -> Void) {
        self.onNodeTap = onNodeTap
    }

    /// 同步当前物理相机的几何空间参数
    func syncCameraState(from cameraNode: SCNNode) {
        currentAngleX = AppSceneKitVector3.x(cameraNode.eulerAngles)
        currentAngleY = AppSceneKitVector3.y(cameraNode.eulerAngles)
        cameraZ = AppSceneKitVector3.z(cameraNode.position)
    }

    /// 提取相机节点，消除 handlePan/handlePinch/handleMagnify 的重复 guard
    func cameraNode(in scnView: SCNView) -> SCNNode? {
        scnView.scene?.rootNode.childNode(withName: FeatureConstants.SceneNode.mainCamera, recursively: true)
    }

    /// 统一执行 Tap 命中检测，消除 iOS/macOS handleTap 的重复 guard + hitTest 调用。
    func performTap(in scnView: SCNView, location: CGPoint) {
        performTapHitTest(location: location, in: scnView, onNodeTap: onNodeTap)
    }

    /// 统一执行 Pan 旋转，消除 iOS/macOS handlePan 的重复 guard + translation 提取。
    func performPan(in scnView: SCNView, translationX: CGFloat, translationY: CGFloat, isChanged: Bool, isEnded: Bool) {
        guard let cameraNode = cameraNode(in: scnView) else { return }
        applyPanRotation(
            translationX: translationX,
            translationY: translationY,
            isChanged: isChanged,
            isEnded: isEnded,
            cameraNode: cameraNode,
            currentAngleX: &currentAngleX,
            currentAngleY: &currentAngleY
        )
    }

    /// 统一执行 Zoom 缩放，消除 iOS handlePinch / macOS handleMagnify 的重复 guard + scale 提取。
    func performZoom(in scnView: SCNView, factor: Float, isChanged: Bool, isEnded: Bool) {
        guard let cameraNode = cameraNode(in: scnView) else { return }
        applyZoomScale(
            factor: factor,
            isChanged: isChanged,
            isEnded: isEnded,
            cameraNode: cameraNode,
            cameraZ: &cameraZ
        )
    }
}

// MARK: - iOS Coordinator
#if canImport(UIKit)
@MainActor
/// iOS 平台 Coordinator，基于 Graph3DCoordinatorBase 处理 UIKit 手势
final class Graph3DiOSCoordinator: Graph3DCoordinatorBase {

    /// 处理Tap
    /// - Parameter gesture: gesture
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView,
              scnView.scene != nil else { return }
        performTap(in: scnView, location: gesture.location(in: scnView))
    }

    /// 处理Pan
    /// - Parameter gesture: gesture
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView else { return }
        let translation = gesture.translation(in: scnView)
        performPan(
            in: scnView,
            translationX: translation.x,
            translationY: translation.y,
            isChanged: gesture.state == .changed,
            isEnded: gesture.state == .ended
        )
    }

    /// 处理Pinch
    /// - Parameter gesture: gesture
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView else { return }
        performZoom(
            in: scnView,
            factor: Float(gesture.scale),
            isChanged: gesture.state == .changed,
            isEnded: gesture.state == .ended
        )
    }
}
#endif

// MARK: - macOS Coordinator
#if canImport(AppKit) && !canImport(UIKit)
/// macOS 平台 Coordinator，基于 Graph3DCoordinatorBase 处理 AppKit 手势
final class Graph3DmacOSCoordinator: Graph3DCoordinatorBase {

    /// 处理Tap
    /// - Parameter gesture: gesture
    @objc func handleTap(_ gesture: NSClickGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView,
              scnView.scene != nil else { return }
        performTap(in: scnView, location: gesture.location(in: scnView))
    }

    /// 处理Pan
    /// - Parameter gesture: gesture
    @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView else { return }
        let translation = gesture.translation(in: scnView)
        performPan(
            in: scnView,
            translationX: translation.x,
            translationY: translation.y,
            isChanged: gesture.state == .changed,
            isEnded: gesture.state == .ended
        )
    }

    /// 处理Magnify
    /// - Parameter gesture: gesture
    @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView else { return }
        performZoom(
            in: scnView,
            factor: Float(1.0 + gesture.magnification),
            isChanged: gesture.state == .changed,
            isEnded: gesture.state == .ended
        )
    }
}
#endif

// MARK: - 共享 updateView 逻辑（消除 iOS updateUIView / macOS updateNSView 重复）
/// 持续同步观察点，确保外部控制（缩放/重置）能生效
@MainActor
private func syncSceneViewPointOfView(_ scnView: SCNView, scene: SCNScene?, coordinator: Graph3DCoordinatorBase) {
    scnView.scene = scene
    if let cameraNode = mainCameraNode(in: scene) {
        if scnView.pointOfView != cameraNode {
            scnView.pointOfView = cameraNode
        }
        coordinator.syncCameraState(from: cameraNode)
    }
}

// MARK: - Tappable Scene View Representable
/// SceneKit 视图的可点击封装，支持节点点击检测
/// - Note: watchOS 不编译此文件（Features 层不在 watchOS target sources），
///   watchOS 端的 3D 图谱占位由调用方 Graph3DView 通过 WatchFeaturePlaceholderView 处理。
#if canImport(UIKit)
@MainActor
/// SceneKit 场景包装器组件
/// 负责在 SwiftUI 中嵌入 3D 渲染引擎，并实现基于点击位置的 3D 节点命中测试（Hit Test）以及附加 0.005 阻尼的自定义相机拖拽/缩放手势。
struct TappableSceneView: UIViewRepresentable {
    let scene: SCNScene?
    let onNodeTap: (UUID?) -> Void

    /// 创建UIView
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        configureSceneView(scnView, scene: scene, coordinator: context.coordinator) { coordinator, cameraNode in
            coordinator.syncCameraState(from: cameraNode)
        }

        // 1. 点击手势检测节点命中
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Graph3DiOSCoordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        // 2. 拖拽手势：绕 Y 轴/X 轴进行平滑旋转
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Graph3DiOSCoordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)

        // 3. 捏合手势：调整 position.z 实现变焦
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Graph3DiOSCoordinator.handlePinch(_:)))
        scnView.addGestureRecognizer(pinchGesture)

        return scnView
    }

    /// 更新UIView
    /// - Parameter uiView: uiView
    /// - Parameter context: context
    func updateUIView(_ uiView: SCNView, context: Context) {
        syncSceneViewPointOfView(uiView, scene: scene, coordinator: context.coordinator)
    }

    /// 创建Coordinator
    /// - Returns: 返回值
    func makeCoordinator() -> Graph3DiOSCoordinator { Graph3DiOSCoordinator(onNodeTap: onNodeTap) }
}
#elseif canImport(AppKit) && !canImport(UIKit)
/// SceneKit 场景包装器组件 (macOS)
/// 负责在 macOS SwiftUI 中嵌入 3D 渲染引擎，实现节点命中测试，以及附加 0.005 阻尼的自定义相机拖拽/缩放手势。
struct TappableSceneView: NSViewRepresentable {
    let scene: SCNScene?
    let onNodeTap: (UUID?) -> Void

    /// 创建NSView
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        configureSceneView(scnView, scene: scene, coordinator: context.coordinator) { coordinator, cameraNode in
            coordinator.syncCameraState(from: cameraNode)
        }

        // 1. 点击手势检测节点命中
        let tapGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Graph3DmacOSCoordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        // 2. 拖拽手势 (旋转相机)
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Graph3DmacOSCoordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)

        // 3. 捏合/缩放手势 (变焦)
        let magnifyGesture = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Graph3DmacOSCoordinator.handleMagnify(_:)))
        scnView.addGestureRecognizer(magnifyGesture)

        return scnView
    }

    /// 更新NSView
    /// - Parameter nsView: nsView
    /// - Parameter context: context
    func updateNSView(_ nsView: SCNView, context: Context) {
        syncSceneViewPointOfView(nsView, scene: scene, coordinator: context.coordinator)
    }

    /// 创建Coordinator
    /// - Returns: 返回值
    func makeCoordinator() -> Graph3DmacOSCoordinator { Graph3DmacOSCoordinator(onNodeTap: onNodeTap) }
}
#endif
