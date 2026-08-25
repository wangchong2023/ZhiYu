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
    @State private var scene: SCNScene?
    @State private var cameraDistance: Float = GraphConstants.ThreeD.defaultCameraDistance
    @State private var autoRotate = false
    @State private var filterType: PageType?
    @State private var showNodeInfo = false
    @State private var infoPage: KnowledgePage?
    @State private var cameraNode: SCNNode?
    @Binding var selectedNodeID: UUID?
    @Binding var isFullScreen: Bool
    
    // FPS Monitor State
    @State private var fps: Double = 0
    @State private var lastFrameTime: TimeInterval = 0
    @State private var frameCount: Int = 0
    @State private var fpsUpdateTimer: Timer?
    @State private var hideControls = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TappableSceneView(scene: scene) { uuid in
                handleNodeTap(uuid)
            }
            .onChange(of: selectedNodeID) { _, _ in
                buildScene()
            }
            
            if !isFullScreen {
                headerOverlay
                    .padding(.top, DesignSystem.standardPadding)
                    .padding(.leading, DesignSystem.widePadding)
            }
            
            // FPS Indicator (Bottom Left, Subtle)
            fpsIndicator
        }
        .overlay(alignment: .topTrailing) {
            if !hideControls {
                controlsOverlay
                    .padding(.top, isFullScreen ? ComponentSpacing.ultra : DesignSystem.tightPadding)
                    .padding(.trailing, DesignSystem.standardPadding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let page = infoPage {
                nodeInfoBar(page: page)
                    .padding(.bottom, isFullScreen ? DesignSystem.widePadding : DesignSystem.tightPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .ignoresSafeArea(edges: isFullScreen ? .all : [])
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
                HStack(spacing: DesignSystem.tiny) {
                    Circle()
                        .fill(fps > GraphConstants.ThreeD.fpsGoodThreshold ? Color.theme.green : (fps > GraphConstants.ThreeD.fpsWarnThreshold ? Color.theme.orange : Color.theme.red))
                        .frame(width: SystemSpacing.small, height: SystemSpacing.small)
                    Text(L10n.Graph.ThreeD.fpsFormat(Int(fps)))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
                .padding(.horizontal, DesignSystem.tightPadding)
                .padding(.vertical, DesignSystem.tiny)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .opacity(DesignSystem.translucentOpacity)
                Spacer()
            }
            .padding(.leading, DesignSystem.standardPadding)
            .padding(.bottom, isFullScreen ? ComponentSpacing.ultra : DesignSystem.standardPadding)
        }
        .allowsHitTesting(false)
    }

    private var headerOverlay: some View {
        VStack(alignment: isFullScreen ? .center : .leading, spacing: DesignSystem.tiny) {
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
        .padding(.top, isFullScreen ? DesignSystem.wide : 0)
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
        newScene.background.contents = isFullScreen ? UIColor.theme.black : nil
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
        starGeometry.firstMaterial?.emission.contents = UIColor(Color.appAccent).withAlphaComponent(DesignSystem.surfaceOpacity)
        starGeometry.firstMaterial?.diffuse.contents = UIColor(Color.appAccent).withAlphaComponent(SystemOpacity.faint)
        
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
        ambientLight.light?.color = UIColor.theme.black
        scene.rootNode.addChildNode(ambientLight)

        let omniLight = SCNNode()
        omniLight.light = SCNLight()
        omniLight.light?.type = .omni
        omniLight.light?.color = UIColor.theme.white
        omniLight.position = SCNVector3(GraphConstants.ThreeD.lightPositionX, GraphConstants.ThreeD.lightPositionY, GraphConstants.ThreeD.lightPositionZ)
        scene.rootNode.addChildNode(omniLight)
    }

    private func setupCamera(scene: SCNScene) {
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = GraphConstants.ThreeD.cameraZNear
        camera.camera?.zFar = GraphConstants.ThreeD.cameraZFar 
        camera.position = SCNVector3(0, GraphConstants.ThreeD.cameraYOffset, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
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
            }.filter { $0.0 == selectedID || $0.1 == selectedID }
            return Set(connectedEdges.flatMap { [$0.0, $0.1] })
        }()

        for (index, page) in pages.enumerated() {
            let nodeSize = calculateNodeSize(for: page)
            let geometry = createNodeGeometry(for: page.pageType, size: nodeSize)
            
            let isSelected = selectedNodeID == page.id
            let isNeighbor = neighborIDs.contains(page.id)
            let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
            
            let uiColor = UIColor(Color.fromModelColorName(page.pageType.colorName))
            let opacity: CGFloat = isDimmed ? DesignSystem.dimmedOpacity : DesignSystem.fullOpacity
            
            geometry.firstMaterial?.diffuse.contents = uiColor.withAlphaComponent(opacity)
            geometry.firstMaterial?.specular.contents = UIColor.theme.white.withAlphaComponent(opacity)
            geometry.firstMaterial?.emission.contents = isDimmed ? uiColor.withAlphaComponent(SystemOpacity.faint) : uiColor.withAlphaComponent(SystemOpacity.faint)

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
        let text = SCNText(string: title, extrusionDepth: CGFloat(GraphConstants.ThreeD.labelExtrusionDepth))
        text.font = UIFont.boldSystemFont(ofSize: CGFloat(GraphConstants.ThreeD.labelFontSize))
        text.flatness = CGFloat(GraphConstants.ThreeD.labelFlatness)
        text.isWrapped = false

        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(Float(nodeSize + CGFloat(DesignSystem.Graph.ThreeD.labelOffset)), 0, 0)
        let labelScale = DesignSystem.Graph.ThreeD.labelScale
        textNode.scale = SCNVector3(labelScale, labelScale, labelScale)
        textNode.geometry?.firstMaterial?.diffuse.contents = UIColor.theme.white
        textNode.geometry?.firstMaterial?.emission.contents = UIColor.theme.white.withAlphaComponent(CGFloat(GraphConstants.ThreeD.labelEmissionIntensity))

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]

        return textNode
    }

    private func addPulseAnimation(to node: SCNNode) {
        let pulseAction = SCNAction.customAction(duration: GraphConstants.ThreeD.pulseAnimationDuration) { node, elapsedTime in
            let scale = 1.0 + GraphConstants.ThreeD.pulseScaleAmplitude * sin(elapsedTime * .pi)
            node.scale = SCNVector3(scale, scale, scale)
        }
        node.runAction(SCNAction.repeatForever(pulseAction))
    }

    private func createEdgeNodes(pages: [KnowledgePage], nodeMap: [UUID: SCNNode], scene: SCNScene) {
        var processedEdges = Set<String>()
        // 性能优化：建立标题到页面的映射表，将查找复杂度从 O(N) 降至 O(1)
        let pageTitleMap = Dictionary(uniqueKeysWithValues: store.pages.map { ($0.title, $0) })
        
        for page in pages {
            for linkTitle in page.outgoingLinks {
                if let linkedPage = pageTitleMap[linkTitle],
                   let sourceNode = nodeMap[page.id],
                   let targetNode = nodeMap[linkedPage.id] {
                    let edgeKey = [page.id.uuidString, linkedPage.id.uuidString].sorted().joined(separator: "-")
                    if !processedEdges.contains(edgeKey) && page.id != linkedPage.id {
                        let edge = createEdgeNode(from: sourceNode.position, to: targetNode.position, sourceID: page.id, targetID: linkedPage.id)
                        scene.rootNode.addChildNode(edge)
                        processedEdges.insert(edgeKey)
                    }
                }
            }
            for relatedID in page.relatedPageIDs {
                if let targetNode = nodeMap[relatedID],
                   let sourceNode = nodeMap[page.id] {
                    let edgeKey = [page.id.uuidString, relatedID.uuidString].sorted().joined(separator: "-")
                    if !processedEdges.contains(edgeKey) && page.id != relatedID {
                        let edge = createEdgeNode(from: sourceNode.position, to: targetNode.position, sourceID: page.id, targetID: relatedID)
                        scene.rootNode.addChildNode(edge)
                        processedEdges.insert(edgeKey)
                    }
                }
            }
        }
    }

    private func addGridFloor(scene: SCNScene) {
        let gridNode = createGridNode(size: GraphConstants.ThreeD.gridFloorSize, divisions: GraphConstants.ThreeD.gridFloorDivisions)
        gridNode.position = SCNVector3(0, GraphConstants.ThreeD.gridFloorYOffset, 0)
        scene.rootNode.addChildNode(gridNode)
    }
    
    private func generateSpherePositions(count: Int, radius: CGFloat) -> [CGPoint3D] {
        var positions: [CGPoint3D] = []
        let goldenRatio = (1 + sqrt(5)) / 2
        for i in 0..<count {
            let theta = 2 * .pi * CGFloat(i) / goldenRatio
            let phi = acos(1 - 2 * (CGFloat(i) + 0.5) / CGFloat(count))
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            positions.append(CGPoint3D(x: x, y: y, z: z))
        }
        return positions
    }
    
    private func createEdgeNode(from: SCNVector3, to: SCNVector3, sourceID: UUID, targetID: UUID) -> SCNNode {
        let source = SCNVector3(from.x, from.y, from.z)
        let target = SCNVector3(to.x, to.y, to.z)
        let vector = SCNVector3(target.x - source.x, target.y - source.y, target.z - source.z)
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let isHighlighted = selectedNodeID == sourceID || selectedNodeID == targetID
        let radius: CGFloat = isHighlighted ? DesignSystem.Graph.ThreeD.edgeRadiusHighlighted : DesignSystem.Graph.ThreeD.edgeRadius
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        let baseColor = UIColor(Color.appAccent)
        let opacity: CGFloat = isHighlighted ? CGFloat(GraphConstants.ThreeD.edgeHighlightedOpacity) : CGFloat(GraphConstants.ThreeD.edgeDefaultOpacity)
        cylinder.firstMaterial?.diffuse.contents = baseColor.withAlphaComponent(opacity)
        cylinder.firstMaterial?.emission.contents = isHighlighted ? baseColor.withAlphaComponent(CGFloat(GraphConstants.ThreeD.edgeHighlightedEmission)) : baseColor.withAlphaComponent(CGFloat(GraphConstants.ThreeD.edgeDefaultEmission))
        let node = SCNNode(geometry: cylinder)
        node.name = "edge_\(sourceID.uuidString)_\(targetID.uuidString)"
        node.position = SCNVector3((source.x + target.x) / 2, (source.y + target.y) / 2, (source.z + target.z) / 2)
        let direction = SCNVector3(vector.x / length, vector.y / length, vector.z / length)
        let up = SCNVector3(0, 1, 0)
        let cross = SCNVector3(up.y * direction.z - up.z * direction.y, up.z * direction.x - up.x * direction.z, up.x * direction.y - up.y * direction.x)
        let dot = up.x * direction.x + up.y * direction.y + up.z * direction.z
        let crossLength = sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z)
        if crossLength > Float(GraphConstants.ThreeD.rotationEpsilon) {
            node.rotation = SCNVector4(cross.x / crossLength, cross.y / crossLength, cross.z / crossLength, acos(dot))
        }
        return node
    }
    
    private func createGridNode(size: Float, divisions: Int) -> SCNNode {
        let gridSize = CGFloat(size)
        let step = gridSize / CGFloat(divisions)
        var vertices: [SCNVector3] = []
        for i in 0...divisions {
            let offset = -gridSize / 2 + step * CGFloat(i)
            vertices.append(SCNVector3(Float(offset), 0, -size / 2))
            vertices.append(SCNVector3(Float(offset), 0, size / 2))
            vertices.append(SCNVector3(-size / 2, 0, Float(offset)))
            vertices.append(SCNVector3(size / 2, 0, Float(offset)))
        }
        let source = SCNGeometrySource(vertices: vertices)
        var indices: [Int32] = []
        for i in 0..<(vertices.count / 2) {
            indices.append(Int32(i * 2))
            indices.append(Int32(i * 2 + 1))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = UIColor(Color.appAccent).withAlphaComponent(CGFloat(GraphConstants.ThreeD.gridOpacity))
        return SCNNode(geometry: geometry)
    }
    
    private func resetCamera() {
        guard let camera = cameraNode else { return }
        HapticFeedback.shared.trigger(.selection)
        cameraDistance = GraphConstants.ThreeD.defaultCameraDistance
        SCNTransaction.begin()
        SCNTransaction.animationDuration = GraphConstants.ThreeD.cameraAnimationDuration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        camera.position = SCNVector3(0, GraphConstants.ThreeD.cameraYOffset, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
        SCNTransaction.commit()
    }

    private func zoom(in zoomingIn: Bool) {
        guard let camera = cameraNode else { return }
        let factor: Float = zoomingIn ? GraphConstants.ThreeD.zoomOutFactor : GraphConstants.ThreeD.zoomInFactor
        cameraDistance = max(GraphConstants.ThreeD.zoomMinDistance, min(GraphConstants.ThreeD.zoomMaxDistance, cameraDistance * factor))
        SCNTransaction.begin()
        SCNTransaction.animationDuration = GraphConstants.ThreeD.zoomAnimationDuration
        camera.position = SCNVector3(0, GraphConstants.ThreeD.cameraYOffset, Float(cameraDistance))
        SCNTransaction.commit()
    }
    
    private func handleNodeTap(_ uuid: UUID?) {
        if hideControls {
            withAnimation(.spring()) {
                hideControls = false
            }
            if uuid == nil { return } // 如果只是为了显示按钮，点击空白处不执行后续逻辑
        }
        
        if let uuid = uuid, let page = store.pages.first(where: { $0.id == uuid }) {
            selectedNodeID = uuid
            infoPage = page
            if let scene = scene, let targetNode = scene.rootNode.childNode(withName: uuid.uuidString, recursively: true), let camera = cameraNode {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = GraphConstants.ThreeD.nodeTapAnimationDuration
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                let pos = targetNode.position
                let direction = SCNVector3(pos.x, pos.y + GraphConstants.ThreeD.nodeTapCameraOffsetY, pos.z + GraphConstants.ThreeD.nodeTapCameraOffsetZ)
                camera.position = direction
                camera.look(at: pos)
                SCNTransaction.commit()
            }
            withAnimation(.spring()) { showNodeInfo = true }
        } else {
            selectedNodeID = nil
            infoPage = nil
            resetCamera()
            withAnimation(.spring()) { showNodeInfo = false }
        }
    }

    private func updateAutoRotation(isRotating: Bool) {
        guard let scene = scene else { return }
        scene.rootNode.removeAction(forKey: "autoRotate")
        if isRotating {
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat(GraphConstants.ThreeD.autoRotateSpeed), z: 0, duration: GraphConstants.ThreeD.cameraAnimationDuration)
            rotate.timingMode = .linear
            scene.rootNode.runAction(SCNAction.repeatForever(rotate), forKey: "autoRotate")
        }
    }
    
    private func startFPSMonitor() {
        fpsUpdateTimer = Timer.scheduledTimer(withTimeInterval: GraphConstants.ThreeD.fpsUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                updateFPSFromScene()
            }
        }
    }
    
    private func stopFPSMonitor() {
        fpsUpdateTimer?.invalidate()
        fpsUpdateTimer = nil
    }
    
    private func updateFPSFromScene() {
        let baseFPS: Double = GraphConstants.ThreeD.baseFPS
        let nodeComplexity = Double(store.pages.count) / GraphConstants.ThreeD.nodeComplexityDivisor
        let newFPS = max(GraphConstants.ThreeD.minFPS, baseFPS - (nodeComplexity * GraphConstants.ThreeD.nodeComplexityMultiplier) - (autoRotate ? GraphConstants.ThreeD.autoRotateFPSDeduction : 0))
        withAnimation(.linear(duration: GraphConstants.ThreeD.fpsUpdateInterval)) {
            fps = newFPS
        }
    }
}
