//
//  Graph3DView+SceneLogic.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 3D 图谱场景交互与几何扩展
//  核心职责：承载 Graph3DView 的球面坐标布局、边与网格几何体构建、相机缩放复位、
//           节点点击聚焦、自动旋转与 FPS 监控逻辑。
//

import SwiftUI
import SceneKit
import UFPDesignSystem

extension Graph3DView {

    func addPulseAnimation(to node: SCNNode) {
        let pulseAction = SCNAction.customAction(duration: GraphConstants.ThreeD.pulseAnimationDuration) { node, elapsedTime in
            let scale = 1.0 + GraphConstants.ThreeD.pulseScaleAmplitude * sin(elapsedTime * .pi)
            node.scale = SCNVector3(scale, scale, scale)
        }
        node.runAction(SCNAction.repeatForever(pulseAction))
    }

    func createEdgeNodes(pages: [KnowledgePage], nodeMap: [UUID: SCNNode], scene: SCNScene) {
        var processedEdges = Set<String>()
        // 性能优化：建立标题到页面的映射表，将查找复杂度从 O(N) 降至 O(1)
        let pageTitleMap = Dictionary(uniqueKeysWithValues: store.pages.map { ($0.title, $0) })

        for page in pages {
            for linkTitle in page.outgoingLinks {
                if let linkedPage = pageTitleMap[linkTitle],
                   let sourceNode = nodeMap[page.id],
                   let targetNode = nodeMap[linkedPage.id] {
                    addEdgeIfUnique(
                        from: sourceNode.position,
                        to: targetNode.position,
                        sourceID: page.id,
                        targetID: linkedPage.id,
                        scene: scene,
                        processedEdges: &processedEdges
                    )
                }
            }
            for relatedID in page.relatedPageIDs {
                if let targetNode = nodeMap[relatedID],
                   let sourceNode = nodeMap[page.id] {
                    addEdgeIfUnique(
                        from: sourceNode.position,
                        to: targetNode.position,
                        sourceID: page.id,
                        targetID: relatedID,
                        scene: scene,
                        processedEdges: &processedEdges
                    )
                }
            }
        }
    }

    /// 添加去重边节点，消除 outgoingLinks 与 relatedPageIDs 循环中的重复逻辑
    private func addEdgeIfUnique(
        from: SCNVector3,
        to: SCNVector3,
        sourceID: UUID,
        targetID: UUID,
        scene: SCNScene,
        processedEdges: inout Set<String>
    ) {
        let edgeKey = [sourceID.uuidString, targetID.uuidString].sorted().joined(separator: "-")
        if !processedEdges.contains(edgeKey) && sourceID != targetID {
            let edge = createEdgeNode(from: from, to: to, sourceID: sourceID, targetID: targetID)
            scene.rootNode.addChildNode(edge)
            processedEdges.insert(edgeKey)
        }
    }

    func addGridFloor(scene: SCNScene) {
        let gridNode = createGridNode(size: GraphConstants.ThreeD.gridFloorSize, divisions: GraphConstants.ThreeD.gridFloorDivisions)
        gridNode.position = SCNVector3(0, GraphConstants.ThreeD.gridFloorYOffset, 0)
        scene.rootNode.addChildNode(gridNode)
    }

    func generateSpherePositions(count: Int, radius: CGFloat) -> [CGPoint3D] {
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
        let baseColor = AppColorBridge.from(Color.appAccent)
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
        if Double(crossLength) > GraphConstants.ThreeD.rotationEpsilon {
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
        geometry.firstMaterial?.diffuse.contents = AppColorBridge.from(Color.appAccent).withAlphaComponent(CGFloat(GraphConstants.ThreeD.gridOpacity))
        return SCNNode(geometry: geometry)
    }

    func resetCamera() {
        guard let camera = cameraNode else { return }
        HapticFeedback.shared.trigger(.selection)
        cameraDistance = GraphConstants.ThreeD.defaultCameraDistance
        SCNTransaction.begin()
        SCNTransaction.animationDuration = GraphConstants.ThreeD.cameraAnimationDuration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        positionCameraAtOrigin(camera)
        SCNTransaction.commit()
    }

    func zoom(in zoomingIn: Bool) {
        guard let camera = cameraNode else { return }
        let factor: Float = zoomingIn ? GraphConstants.ThreeD.zoomOutFactor : GraphConstants.ThreeD.zoomInFactor
        cameraDistance = max(GraphConstants.ThreeD.zoomMinDistance, min(GraphConstants.ThreeD.zoomMaxDistance, cameraDistance * factor))
        SCNTransaction.begin()
        SCNTransaction.animationDuration = GraphConstants.ThreeD.zoomAnimationDuration
        camera.position = SCNVector3(0, GraphConstants.ThreeD.cameraYOffset, Float(cameraDistance))
        SCNTransaction.commit()
    }

    /// 将相机定位至原点上方标准偏移位置，消除 setupCamera 与 resetCamera 的重复 position+look 调用
    func positionCameraAtOrigin(_ camera: SCNNode) {
        camera.position = SCNVector3(0, GraphConstants.ThreeD.cameraYOffset, Float(cameraDistance))
        camera.look(at: SCNVector3(0, 0, 0))
    }

    func handleNodeTap(_ uuid: UUID?) {
        if hideControls {
            withAnimation(.spring()) {
                hideControls = false
            }
            if uuid == nil { return }
        }

        if let uuid = uuid, let page = store.pages.first(where: { $0.id == uuid }) {
            selectedNodeID = uuid
            infoPage = page
            if let scene = scene, let targetNode = scene.rootNode.childNode(withName: uuid.uuidString, recursively: true), let camera = cameraNode {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = GraphConstants.ThreeD.nodeTapAnimationDuration
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                let pos = targetNode.position
                let direction = AppSceneKitVector3.adding(dy: GraphConstants.ThreeD.nodeTapCameraOffsetY, dz: GraphConstants.ThreeD.nodeTapCameraOffsetZ, to: pos)
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

    func updateAutoRotation(isRotating: Bool) {
        guard let scene = scene else { return }
        scene.rootNode.removeAction(forKey: "autoRotate")
        if isRotating {
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat(GraphConstants.ThreeD.autoRotateSpeed), z: 0, duration: GraphConstants.ThreeD.cameraAnimationDuration)
            rotate.timingMode = .linear
            scene.rootNode.runAction(SCNAction.repeatForever(rotate), forKey: "autoRotate")
        }
    }

    func startFPSMonitor() {
        fpsUpdateTimer?.invalidate()
        fpsUpdateTimer = Timer.scheduledTimer(withTimeInterval: GraphConstants.ThreeD.fpsUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                updateFPSFromScene()
            }
        }
    }

    func stopFPSMonitor() {
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
