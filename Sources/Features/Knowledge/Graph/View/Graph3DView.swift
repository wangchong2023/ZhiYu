//
//  Graph3DView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Graph3D 界面的 UI 视图层组件。
//
import SwiftUI
import SceneKit
import Dependencies
import UFPDesignSystem

// MARK: - 3D 图谱组件常量（组件特定尺寸，无对应命名 token）
private enum Graph3DViewConstants {
    /// 3D 图谱描述文本最大宽度 (240pt)
    static let descriptionMaxWidth: CGFloat = 240
}

// MARK: - 3D 图谱容器
/// 3D 知识图谱视图
/// 负责在 3D 空间（SceneKit）中渲染知识节点与关联线条，提供力导向布局、自动旋转及空间交互体验
@MainActor
struct Graph3DView: View {
    @Dependency(\.toastService) private var toastManager
    @Environment(KnowledgeStore.self) var store
    @Environment(Router.self) var router
    @Environment(\.interfaceIdiom) private var idiom
    @State var scene: SCNScene?
    @State var cameraDistance: Float = GraphConstants.ThreeD.defaultCameraDistance
    @State var autoRotate = false
    @State private var filterType: PageType?
    @State var showNodeInfo = false
    @State var infoPage: KnowledgePage?
    @State var cameraNode: SCNNode?
    @Binding var selectedNodeID: UUID?
    @Binding var isFullScreen: Bool
    
    // FPS Monitor State
    @State var fps: Double = 0
    @State private var lastFrameTime: TimeInterval = 0
    @State private var frameCount: Int = 0
    @State var fpsUpdateTimer: Timer?
    @State var hideControls = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TappableSceneView(scene: scene) { uuid in
                handleNodeTap(uuid)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: isFullScreen ? .all : [])
            .onChange(of: selectedNodeID) { _, _ in
                buildScene()
            }
            
            if !isFullScreen {
                headerOverlay
                    .padding(.top, DesignTokens.Spacing.standardPadding)
                    .padding(.leading, DesignTokens.Spacing.widePadding)
            }
            
            // FPS Indicator (Bottom Left, Subtle)
            fpsIndicator
        }
        .overlay(alignment: .topTrailing) {
            if !hideControls {
                controlsOverlay
                    .padding(.top, (isFullScreen && idiom != .mac) ? DesignTokens.ComponentSpacing.ultra : DesignTokens.Spacing.standardPadding)
                    .padding(.trailing, DesignTokens.Spacing.standardPadding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let page = infoPage {
                nodeInfoBar(page: page)
                    .padding(.bottom, isFullScreen ? DesignTokens.Spacing.widePadding : DesignTokens.Spacing.tightPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .ignoresSafeArea(edges: (isFullScreen && idiom != .mac) ? .all : [])
        .adaptiveFullScreenImmersive(isFullScreen)
        .preferredColorScheme(isFullScreen ? .dark : nil)
        .hideBackButtonIfIOS(isFullScreen)
        .hideNavigationBarIfIOS(isFullScreen)
        .onAppear { 
            // 节点数超出阈值时智能降级至 2D 拓扑
            if store.pages.count > GraphConstants.ThreeD.nodeCountDegradeThreshold {
                isFullScreen = false
                toastManager.show(type: .info, message: L10n.Graph.nodesLimitDegradeHint)
                return
            }
            
            selectedNodeID = nil
            infoPage = nil
            showNodeInfo = false
            buildScene() 
            startFPSMonitor()
        }
        .onDisappear {
            stopFPSMonitor()
        }
        .onChange(of: store.pages.count) { _, _ in buildScene() }
        .onChange(of: filterType) { _, _ in buildScene() }
    }
    
    private var fpsIndicator: some View {
        VStack {
            Spacer()
            HStack {
                HStack(spacing: DesignTokens.Spacing.tiny) {
                    Circle()
                        .fill(fps > GraphConstants.ThreeD.fpsGoodThreshold ? Color.theme.green : (fps > GraphConstants.ThreeD.fpsWarnThreshold ? Color.theme.orange : Color.theme.red))
                        .frame(width: DesignTokens.SystemSpacing.small, height: DesignTokens.SystemSpacing.small)
                    Text(L10n.Graph.ThreeD.fpsFormat(Int(fps)))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
                .padding(.horizontal, DesignTokens.Spacing.tightPadding)
                .padding(.vertical, DesignTokens.Spacing.tiny)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .opacity(DesignTokens.Colors.Opacity.translucentOpacity)
                Spacer()
            }
            .padding(.leading, DesignTokens.Spacing.standardPadding)
            .padding(.bottom, isFullScreen ? DesignTokens.ComponentSpacing.ultra : DesignTokens.Spacing.standardPadding)
        }
        .allowsHitTesting(false)
    }

    private var headerOverlay: some View {
        VStack(alignment: isFullScreen ? .center : .leading, spacing: DesignTokens.Spacing.tiny) {
            Text(L10n.Graph.ThreeD.title)
                .font(.subheadline.bold())
                .foregroundStyle(.appText)
            
            if isFullScreen {
                Text(L10n.Graph.ThreeD.description)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(isFullScreen ? .center : .leading)
                    .frame(maxWidth: Graph3DViewConstants.descriptionMaxWidth) // 240 组件特定尺寸
            }
        }
        .padding(.top, isFullScreen ? DesignTokens.Spacing.wide : 0)
        .allowsHitTesting(false)
    }

    private var controlsOverlay: some View {
        Graph3DControlsOverlay(
            autoRotate: $autoRotate,
            filterType: $filterType,
            isFullScreen: $isFullScreen,
            hideControls: $hideControls,
            onAutoRotateToggle: { 
                let newValue = !autoRotate
                autoRotate = newValue
                updateAutoRotation(isRotating: newValue) 
            },
            onResetCamera: { resetCamera() },
            onZoomIn: { zoom(in: true) },
            onZoomOut: { zoom(in: false) }
        )
    }

    private func nodeInfoBar(page: KnowledgePage) -> some View {
        Graph3DNodeInfoBar(page: page) {
            isFullScreen = false
            router.navigateToPage(id: page.id)
        }
    }
    
    private func buildScene() {
        let newScene = SCNScene()
        newScene.background.contents = isFullScreen ? AppColorBridge.from(Color.theme.black) : nil
        addStarfield(to: newScene)
        setupLighting(scene: newScene)
        setupCamera(scene: newScene)

        let pages = filterType == nil ? store.pages : store.pages.filter { $0.pageType == filterType }
        guard !pages.isEmpty else {
            scene = newScene
            return
        }

        // 优化 3D 布局空间：根据节点数量动态扩展球体半径，确保节点间距足够
        let baseRadius = sqrt(Double(pages.count)) * GraphConstants.ThreeD.baseSphereRadiusMultiplier
        let radius: CGFloat = CGFloat(max(GraphConstants.ThreeD.minSphereRadius, min(GraphConstants.ThreeD.maxSphereRadius, baseRadius)))
        let positions = generateSpherePositions(count: pages.count, radius: radius)

        let nodeMap = createPageNodes(pages: pages, positions: positions, scene: newScene)
        createEdgeNodes(pages: pages, nodeMap: nodeMap, scene: newScene)
        addGridFloor(scene: newScene)

        scene = newScene
        
        let targetDistance = Float(radius) * GraphConstants.ThreeD.cameraDistanceMultiplier
        cameraDistance = max(GraphConstants.ThreeD.minCameraDistance, min(GraphConstants.ThreeD.maxCameraDistance, targetDistance))
        resetCamera() 
        
        updateAutoRotation(isRotating: autoRotate)
    }

    private func addStarfield(to scene: SCNScene) {
        let starCount = GraphConstants.ThreeD.starCount
        let starGeometry = SCNSphere(radius: DesignSystem.Graph.ThreeD.starRadius)
        starGeometry.firstMaterial?.emission.contents = AppColorBridge.from(Color.appAccent).withAlphaComponent(DesignTokens.Colors.Opacity.surfaceOpacity)
        starGeometry.firstMaterial?.diffuse.contents = AppColorBridge.from(Color.appAccent).withAlphaComponent(DesignTokens.SystemOpacity.faint)
        
        for _ in 0..<starCount {
            let node = SCNNode(geometry: starGeometry)
            let r: Float = GraphConstants.ThreeD.starfieldRadius
            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: 0...(.pi))
            
            node.position = SCNVector3(
                r * sin(phi) * cos(theta),
                r * sin(phi) * sin(theta),
                r * cos(phi)
            )
            scene.rootNode.addChildNode(node)
        }
    }

    private func setupLighting(scene: SCNScene) {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = AppColorBridge.from(Color.theme.black)
        scene.rootNode.addChildNode(ambientLight)

        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.color = AppColorBridge.from(Color.theme.white)
        omniLight.position = SCNVector3(GraphConstants.ThreeD.lightPositionX, GraphConstants.ThreeD.lightPositionY, GraphConstants.ThreeD.lightPositionZ)
        scene.rootNode.addChildNode(omniLight)
    }

    private func setupCamera(scene: SCNScene) {
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = GraphConstants.ThreeD.cameraZNear
        camera.camera?.zFar = GraphConstants.ThreeD.cameraZFar 
        positionCameraAtOrigin(camera)
        camera.name = "mainCamera"
        scene.rootNode.addChildNode(camera)
        cameraNode = camera
    }

    private func createPageNodes(pages: [KnowledgePage], positions: [CGPoint3D], scene: SCNScene) -> [UUID: SCNNode] {
        var nodeMap: [UUID: SCNNode] = [:]
        let neighborIDs: Set<UUID> = {
            guard let selectedID = selectedNodeID else { return [] }
            let connectedEdges = store.pages.flatMap { page in
                page.outgoingLinks.compactMap { link -> (UUID, UUID)? in
                    if let target = store.pages.first(where: { $0.title == link }) {
                        return (page.id, target.id)
                    }
                    return nil
                }
            }.filter { sourceID, targetID in sourceID == selectedID || targetID == selectedID }
            return Set(connectedEdges.flatMap { sourceID, targetID in [sourceID, targetID] })
        }()

        for (index, page) in pages.enumerated() {
            let nodeSize = calculateNodeSize(for: page)
            let geometry = createNodeGeometry(for: page.pageType, size: nodeSize)
            
            let isSelected = selectedNodeID == page.id
            let isNeighbor = neighborIDs.contains(page.id)
            let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
            
            let uiColor = AppColorBridge.from(Color.fromModelColorName(page.pageType.colorName))
            let opacity: CGFloat = isDimmed ? DesignTokens.Colors.Opacity.dimmedOpacity : DesignTokens.Colors.Opacity.fullOpacity
            
            geometry.firstMaterial?.diffuse.contents = uiColor.withAlphaComponent(opacity)
            geometry.firstMaterial?.specular.contents = AppColorBridge.from(Color.theme.white).withAlphaComponent(opacity)
            geometry.firstMaterial?.emission.contents = isDimmed ? uiColor.withAlphaComponent(DesignTokens.SystemOpacity.faint) : uiColor.withAlphaComponent(DesignTokens.SystemOpacity.faint)

            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(
                Float(positions[index].x),
                Float(positions[index].y),
                Float(positions[index].z)
            )
            node.name = page.id.uuidString

            if !isDimmed || pages.count < GraphConstants.ThreeD.labelDisplayThreshold {
                let textNode = createLabelNode(title: page.title, nodeSize: nodeSize)
                textNode.opacity = isDimmed ? GraphConstants.ThreeD.labelDimmedOpacity : GraphConstants.ThreeD.labelNormalOpacity
                node.addChildNode(textNode)
            }

            if page.isPinned || isSelected {
                addPulseAnimation(to: node)
            }

            scene.rootNode.addChildNode(node)
            nodeMap[page.id] = node
        }

        return nodeMap
    }
    
    private func createNodeGeometry(for type: PageType, size: CGFloat) -> SCNGeometry {
        switch type {
        case .concept: return SCNSphere(radius: size)
        case .entity: return SCNBox(width: size * CGFloat(GraphConstants.ThreeD.entitySizeMultiplier), height: size * CGFloat(GraphConstants.ThreeD.entitySizeMultiplier), length: size * CGFloat(GraphConstants.ThreeD.entitySizeMultiplier), chamferRadius: size * CGFloat(GraphConstants.ThreeD.entityChamferRatio))
        case .source: return SCNCylinder(radius: size, height: size * CGFloat(GraphConstants.ThreeD.sourceHeightMultiplier))
        case .comparison: return SCNPyramid(width: size * CGFloat(GraphConstants.ThreeD.comparisonSizeMultiplier), height: size * CGFloat(GraphConstants.ThreeD.comparisonSizeMultiplier), length: size * CGFloat(GraphConstants.ThreeD.comparisonSizeMultiplier))
        case .raw: return SCNBox(width: size * CGFloat(GraphConstants.ThreeD.rawWidthMultiplier), height: size * CGFloat(GraphConstants.ThreeD.rawHeightRatio), length: size * CGFloat(GraphConstants.ThreeD.rawLengthMultiplier), chamferRadius: CGFloat(GraphConstants.ThreeD.rawChamferRadius))
        }
    }

    private func calculateNodeSize(for page: KnowledgePage) -> CGFloat {
        let backlinkCount = store.pages.filter { $0.outgoingLinks.contains(page.title) }.count
        let linkCount = page.outgoingLinks.count + backlinkCount
        // 增大节点基础尺寸与上限
        return CGFloat(max(
            DesignSystem.Graph.ThreeD.minNodeSize,
            min(DesignSystem.Graph.ThreeD.maxNodeSize, DesignSystem.Graph.ThreeD.baseNodeSize + Double(linkCount) * DesignSystem.Graph.ThreeD.nodeLinkWeight)
        ))
    }

    private func createLabelNode(title: String, nodeSize: CGFloat) -> SCNNode {
        // 防止 SceneKit C3DMeshCreateText 在超长文本上 SIGSEGV（模拟器尤其脆弱）
        let safeTitle: String
        if title.count > GraphConstants.ThreeD.labelMaxCharacterCount {
            let endIndex = title.index(title.startIndex, offsetBy: GraphConstants.ThreeD.labelMaxCharacterCount - 1)
            safeTitle = String(title[title.startIndex...endIndex]) + "…"
        } else {
            safeTitle = title
        }
        let text = SCNText(string: safeTitle, extrusionDepth: CGFloat(GraphConstants.ThreeD.labelExtrusionDepth))
        text.font = AppFontBridge.boldSystemFont(ofSize: CGFloat(GraphConstants.ThreeD.labelFontSize))
        text.flatness = CGFloat(GraphConstants.ThreeD.labelFlatness)
        text.isWrapped = false

        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(Float(nodeSize + CGFloat(DesignSystem.Graph.ThreeD.labelOffset)), 0, 0)
        let labelScale = DesignSystem.Graph.ThreeD.labelScale
        textNode.scale = SCNVector3(labelScale, labelScale, labelScale)
        textNode.geometry?.firstMaterial?.diffuse.contents = AppColorBridge.from(Color.theme.white)
        textNode.geometry?.firstMaterial?.emission.contents = AppColorBridge.from(Color.theme.white).withAlphaComponent(CGFloat(GraphConstants.ThreeD.labelEmissionIntensity))

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]

        return textNode
    }
}
