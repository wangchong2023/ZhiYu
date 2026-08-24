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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
        scnView.scene = scene
        // 关键：关闭系统默认的自带相机操作，以接管高清晰阻尼平滑计算
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .clear
        
        // 关键：如果场景中有指定的相机节点，则将其设为观察点
        if let scene = scene, let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            scnView.pointOfView = cameraNode
            context.coordinator.syncCameraState(from: cameraNode)
        }
        
        // 1. 点击手势检测节点命中
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        // 2. 拖拽手势：绕 Y 轴/X 轴进行平滑旋转
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        // 3. 捏合手势：调整 position.z 实现变焦
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        scnView.addGestureRecognizer(pinchGesture)
        
        return scnView
    }

    /// 更新UIView
    /// - Parameter uiView: uiView
    /// - Parameter context: context
    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
        // 持续同步观察点，确保外部控制（缩放/重置）能生效
        if let scene = scene, let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            if uiView.pointOfView != cameraNode {
                uiView.pointOfView = cameraNode
            }
            // 每次同步同步内部坐标系
            context.coordinator.syncCameraState(from: cameraNode)
        }
    }

    /// 创建Coordinator
    /// - Returns: 返回值
    func makeCoordinator() -> Coordinator { Coordinator(onNodeTap: onNodeTap) }

    @MainActor class Coordinator: NSObject {
        let onNodeTap: (UUID?) -> Void
        
        // ── 临时手势积分状态 ──
        var currentAngleX: Float = 0
        var currentAngleY: Float = 0
        var cameraZ: Float = 60.0
        
        init(onNodeTap: @escaping (UUID?) -> Void) {
            self.onNodeTap = onNodeTap
        }
        
        /// 同步当前物理相机的几何空间参数
        func syncCameraState(from cameraNode: SCNNode) {
            currentAngleX = cameraNode.eulerAngles.x
            currentAngleY = cameraNode.eulerAngles.y
            cameraZ = cameraNode.position.z
        }

        /// 处理Tap
        /// - Parameter gesture: gesture
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  scnView.scene != nil else { return }
            let location = gesture.location(in: scnView)
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
        
        /// 处理Pan
        /// - Parameter gesture: gesture
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  let cameraNode = scnView.scene?.rootNode.childNode(withName: "mainCamera", recursively: true) else { return }
            
            let translation = gesture.translation(in: scnView)
            // 0.005 极其平滑的阻尼系数，防止大节点量手势过于敏感瞬间飞出画布
            let dampening: Float = 0.005
            
            if gesture.state == .changed {
                let deltaY = Float(translation.x) * dampening
                let deltaX = Float(translation.y) * dampening
                
                // 将位移积分转换为相机的 Euler 空间旋转
                cameraNode.eulerAngles.y = currentAngleY - deltaY
                cameraNode.eulerAngles.x = currentAngleX - deltaX
            } else if gesture.state == .ended {
                currentAngleY = cameraNode.eulerAngles.y
                currentAngleX = cameraNode.eulerAngles.x
            }
        }
        
        /// 处理Pinch
        /// - Parameter gesture: gesture
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  let cameraNode = scnView.scene?.rootNode.childNode(withName: "mainCamera", recursively: true) else { return }
            
            if gesture.state == .changed {
                let factor = Float(gesture.scale)
                let newZ = cameraZ / factor
                // 约束限制防极端穿透飞出
                cameraNode.position.z = max(5.0, min(newZ, 300.0))
            } else if gesture.state == .ended {
                cameraZ = cameraNode.position.z
            }
        }
    }
}
#elseif canImport(AppKit)
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
        scnView.scene = scene
        // 关键：关闭系统默认的相机操作，以接管高清晰阻尼平滑计算
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .clear
        
        // 关键：如果场景中有指定的相机节点，则将其设为观察点
        if let scene = scene, let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            scnView.pointOfView = cameraNode
            context.coordinator.syncCameraState(from: cameraNode)
        }
        
        // 1. 点击手势检测节点命中
        let tapGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        // 2. 拖拽手势 (旋转相机)
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        // 3. 捏合/缩放手势 (变焦)
        let magnifyGesture = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnify(_:)))
        scnView.addGestureRecognizer(magnifyGesture)
        
        return scnView
    }

    /// 更新NSView
    /// - Parameter nsView: nsView
    /// - Parameter context: context
    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = scene
        // 持续同步观察点，确保外部控制（缩放/重置）能生效
        if let scene = scene, let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            if nsView.pointOfView != cameraNode {
                nsView.pointOfView = cameraNode
            }
            // 同步内部参数与实际相机参数一致
            context.coordinator.syncCameraState(from: cameraNode)
        }
    }

    /// 创建Coordinator
    /// - Returns: 返回值
    func makeCoordinator() -> Coordinator { Coordinator(onNodeTap: onNodeTap) }

    class Coordinator: NSObject {
        let onNodeTap: (UUID?) -> Void
        
        // ── 临时手势积分状态 ──
        var currentAngleX: Float = 0
        var currentAngleY: Float = 0
        var cameraZ: Float = 60.0
        
        init(onNodeTap: @escaping (UUID?) -> Void) {
            self.onNodeTap = onNodeTap
        }
        
        /// 同步当前物理相机的几何空间参数
        func syncCameraState(from cameraNode: SCNNode) {
            currentAngleX = cameraNode.eulerAngles.x
            currentAngleY = cameraNode.eulerAngles.y
            cameraZ = cameraNode.position.z
        }

        /// 处理Tap
        /// - Parameter gesture: gesture
        @objc func handleTap(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  scnView.scene != nil else { return }
            let location = gesture.location(in: scnView)
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
        
        /// 处理Pan
        /// - Parameter gesture: gesture
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  let cameraNode = scnView.scene?.rootNode.childNode(withName: "mainCamera", recursively: true) else { return }
            
            let translation = gesture.translation(in: scnView)
            // 0.005 极其平滑的阻尼系数，防止大节点量手势过于敏感瞬间飞出画布
            let dampening: Float = 0.005
            
            if gesture.state == .changed {
                let deltaY = Float(translation.x) * dampening
                let deltaX = Float(translation.y) * dampening
                
                // 将位移积分转换为相机的 Euler 空间旋转
                cameraNode.eulerAngles.y = currentAngleY - deltaY
                cameraNode.eulerAngles.x = currentAngleX - deltaX
            } else if gesture.state == .ended {
                currentAngleY = cameraNode.eulerAngles.y
                currentAngleX = cameraNode.eulerAngles.x
            }
        }
        
        /// 处理Magnify
        /// - Parameter gesture: gesture
        @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView,
                  let cameraNode = scnView.scene?.rootNode.childNode(withName: "mainCamera", recursively: true) else { return }
            
            if gesture.state == .changed {
                let factor = Float(1.0 + gesture.magnification)
                let newZ = cameraZ / factor
                // 约束限制防极端穿透飞出
                cameraNode.position.z = max(5.0, min(newZ, 300.0))
            } else if gesture.state == .ended {
                cameraZ = cameraNode.position.z
            }
        }
    }
}
#endif

// MARK: - CGPoint3D
/// 3D 坐标点
/// 3D 坐标空间点模型
/// 负责定义节点在 SceneKit 笛卡尔坐标系中的 X/Y/Z 位置
struct CGPoint3D {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

// MARK: - Graph3D Controls Overlay
/// 3D 图谱控制面板：自动旋转/重置相机/筛选按钮
/// 3D 图谱控制面板组件
/// 负责提供相机对焦、全屏切换、自动旋转及页面类型过滤等空间导航控制功能
struct Graph3DControlsOverlay: View {
    @Binding var autoRotate: Bool
    @Binding var filterType: PageType?
    @Binding var isFullScreen: Bool
    @Binding var hideControls: Bool

    let onAutoRotateToggle: () -> Void
    let onResetCamera: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        let iconColor: Color = isFullScreen ? .white : .appText
        
        VStack(spacing: DesignSystem.small) {
            // Fullscreen toggle
            Button(action: { 
                withAnimation(.spring()) { 
                    isFullScreen.toggle() 
                    showFilterPopup = false // 切换模式时自动折叠菜单
                    if !isFullScreen { hideControls = false } // 退出全屏时强制显示
                } 
            }) {
                Image(systemName: isFullScreen ? DesignSystem.Icons.fullscreenExit : DesignSystem.Icons.fullscreenEnter)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(DesignSystem.small + DesignSystem.atomic)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-fullscreen")

            // Hide controls toggle - 仅在全屏模式下显示
            if isFullScreen {
                Button(action: {
                    withAnimation(.spring()) {
                        hideControls = true
                    }
                }) {
                    Image(systemName: DesignSystem.Icons.eyeSlashOutline)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                        .padding(DesignSystem.small + DesignSystem.atomic)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("graph3d-hide-controls")
            }

            // Auto-rotate toggle - 仅在全屏模式下显示
            if isFullScreen {
                Button(action: onAutoRotateToggle) {
                    Image(systemName: autoRotate ? DesignSystem.Icons.refreshCircleFill : DesignSystem.Icons.refreshCircle)
                        .font(.title3)
                        .foregroundStyle(autoRotate ? Color.appAccent : iconColor)
                        .padding(DesignSystem.small + DesignSystem.atomic)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("graph3d-auto-rotate")
            }

            // Reset camera
            Button(action: onResetCamera) {
                Image(systemName: DesignSystem.Icons.scope)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(DesignSystem.small + DesignSystem.atomic)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-reset-camera")
            
            // Zoom In
            Button(action: onZoomIn) {
                Image(systemName: DesignSystem.Icons.plusMagnifyingglass)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(DesignSystem.small + DesignSystem.atomic)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-zoom-in")
            
            // Zoom Out
            Button(action: onZoomOut) {
                Image(systemName: DesignSystem.Icons.minusMagnifyingglass)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .padding(DesignSystem.small + DesignSystem.atomic)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("graph3d-zoom-out")

            // Filter - 全屏模式下根据用户要求隐藏
            if !isFullScreen {
                Button(action: { withAnimation(.spring(response: 0.35)) { showFilterPopup.toggle() } }) {
                    Image(systemName: DesignSystem.Icons.filterCircle)
                        .font(.title3)
                        .foregroundStyle(filterType == nil ? iconColor : Color.appAccent)
                        .padding(DesignSystem.small + DesignSystem.atomic)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(filterType == nil ? 0 : DesignSystem.dimmedOpacity), radius: DesignSystem.tiny)
                }
                .overlay(alignment: .bottomTrailing) {
                    if showFilterPopup {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(L10n.Graph.filter)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.appSecondary)
                                .padding(.horizontal, DesignSystem.medium)
                                .padding(.top, SystemSpacing.tight)
                                .padding(.bottom, DesignSystem.tightPadding)
                            
                            Divider().background(Color.appBorder.opacity(DesignSystem.Opacity.shadow))
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    Button(action: { filterType = nil; showFilterPopup = false }) {
                                        HStack {
                                            Image(systemName: DesignSystem.Icons.gridOutline)
                                                .font(.caption)
                                            Text(L10n.Graph.all)
                                                .font(.footnote)
                                            Spacer()
                                            if filterType == nil {
                                                Image(systemName: DesignSystem.Icons.check)
                                                    .font(.caption2.weight(.bold))
                                            }
                                        }
                                        .padding(.horizontal, DesignSystem.medium)
                                        .padding(.vertical, SystemSpacing.tight)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(filterType == nil ? Color.appAccent : .appText)
                                    
                                    // 遍历用户可见页面类型，屏蔽 raw 选项
                                    ForEach(PageType.allVisibleCases) { type in
                                        Button(action: { filterType = type; showFilterPopup = false }) {
                                            HStack {
                                                Image(systemName: type.icon)
                                                    .font(.caption)
                                                Text(type.displayName)
                                                    .font(.footnote)
                                                Spacer()
                                                if filterType == type {
                                                    Image(systemName: DesignSystem.Icons.check)
                                                        .font(.caption2.weight(.bold))
                                                }
                                            }
                                            .padding(.horizontal, DesignSystem.medium)
                                            .padding(.vertical, SystemSpacing.tight)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(filterType == type ? Color.appAccent : .appText)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxHeight: Spacing.Grid.emptyStateHeight) 
                        }
                        .frame(width: DesignSystem.Metrics.graphControlWidth)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(DesignSystem.Opacity.glass), radius: 8, x: -4, y: 4)
                        )
                        .offset(x: -50, y: -20)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .accessibilityIdentifier("graph3d-filter")
            }
        }
        .onChange(of: isFullScreen) { _, _ in
            showFilterPopup = false
        }
    }
    
    @State private var showFilterPopup = false
}

// MARK: - Graph3D Node Info Bar
/// 3D 图谱节点信息栏：显示选中节点的类型、标题和""按钮
/// 3D 节点详情浮栏组件
/// 负责在选中 3D 节点时提供轻量级的信息摘要及进入详情页的快速入口
struct Graph3DNodeInfoBar: View {
    let page: KnowledgePage
    let onViewPage: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Circle()
                .fill(Color.fromModelColorName(page.pageType.colorName))
                .frame(width: DesignSystem.Timeline.indicatorSize, height: DesignSystem.Timeline.indicatorSize)
                .overlay {
                    Image(systemName: page.displayIcon)
                        .font(.caption)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(page.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)
                Text(page.pageType.displayName)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }

            Spacer()

            Button(action: onViewPage) {
                Text(L10n.Graph.viewDetail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appAccent)
                    .padding(.horizontal, DesignSystem.medium)
                    .padding(.vertical, DesignSystem.tightPadding)
                    .background(Color.appAccent.opacity(DesignSystem.Opacity.glass))
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("graph3d-view-page")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeRadius))
        .padding(.horizontal)
        .padding(.bottom, DesignSystem.small)
    }
}
