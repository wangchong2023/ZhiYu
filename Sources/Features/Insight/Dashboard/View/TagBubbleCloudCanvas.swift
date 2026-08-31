//
//  TagBubbleCloudCanvas.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层容器
//  核心职责：渲染双向拖拽的 2D 画布，按螺旋坐标平铺气泡，并实时执行视口几何欧氏距离计算以驱动余弦鱼眼缩放和边缘裁切。全文件符合零 SwiftLint 禁用指令的高品质规范。
//

import SwiftUI

/// 二维错位蜂窝鱼眼气泡云画布容器
struct TagBubbleCloudCanvas: View {
    // ── 外部依赖状态 ──
    /// 视图协调器
    @Bindable var coordinator: TagCloudCoordinator
    
    // ── 物理交互与拖拽状态 ──
    /// 当前手势拖拽的临时偏移量
    @State private var dragOffset: CGSize = .zero
    /// 历史累计的滑动位移量
    @State private var totalOffset: CGSize = .zero
    
    // ── 物理与鱼眼算法标准常量 (杜绝魔鬼数字) ──
    /// 蜂窝网格基础步长 (步长值 = (气泡直径 + 间距) / 2)
    private let gridStepSize: CGFloat = 64.0
    /// 鱼眼形变引擎的最大生效物理半径 (像素)
    private let maxFisheyeDistance: CGFloat = 260.0
    /// 视口外元素渲染裁剪截断距离 (像素，超过该值则执行 culling 优化)
    private let cullingDistance: CGFloat = 320.0
    
    /// 鱼眼交互的缩放底限
    private let minFisheyeScale: CGFloat = 0.55
    /// 鱼眼交互的缩放上限
    private let maxFisheyeScale: CGFloat = 1.25
    /// 鱼眼交互的透明度底限
    private let minFisheyeOpacity: Double = 0.2
    /// 鱼眼交互的透明度上限
    private let maxFisheyeOpacity: Double = 1.0
    
    /// 弹簧动画刚度系数 (Stiffness)
    private let dragSpringStiffness: Double = 60.0
    /// 弹簧动画阻尼系数 (Damping)
    private let dragSpringDamping: Double = 15.0
    /// 气泡放置的安全包围框直径 (106.0pt)
    private let bubbleFrameDiameter: CGFloat = 106.0
    /// 气泡物理中心点偏移量 (53.0pt，等于直径的一半)
    private let bubbleCenterOffset: CGFloat = 53.0
    /// 边界最大拖动限制系数，随标签总数成比例增长
    private let boundaryFactor: CGFloat = 8.0
    /// 边界基础安全安全缓冲区
    private let boundaryBuffer: CGFloat = 200.0
    /// 词频数据未就绪时的默认比例
    private let defaultBubbleRatio = 0.5
    
    /// 词频插值比例映射
    /// - Parameters:
    ///   - count: 标签词频
    ///   - tags: 经过过滤的全部标签集合
    /// - Returns: 归一化比例值 (0.0 到 1.0)
    private func bubbleRatio(for count: Int, tags: [(tag: String, count: Int)]) -> Double {
        let counts = tags.map { $0.count }
        guard let maxVal = counts.max(), let minVal = counts.min() else { return 0.0 }
        let diff = maxVal - minVal
        guard diff > 0 else { return defaultBubbleRatio }
        return Double(count - minVal) / Double(diff)
    }
    
    var body: some View {
        let filtered = coordinator.filteredTags
        let coordinates = HexSpiralCalculator.generateSpiralCoordinates(count: filtered.count)
        
        GeometryReader { viewportGeo in
            let viewportCenter = CGPoint(x: viewportGeo.size.width / FeatureConstants.TagBubbleCloud.canvasHalfDivisor, y: viewportGeo.size.height / FeatureConstants.TagBubbleCloud.canvasHalfDivisor)
            
            ZStack {
                // 大背景，作为拖拽手势的整体捕获层
                Color.clear
                    .contentShape(Rectangle())
                
                // 渲染气泡集合
                ForEach(Array(filtered.enumerated()), id: \.element.tag) { index, item in
                    let coord = coordinates[safe: index] ?? HexCoordinate(axialQ: 0, axialR: 0)
                    
                    // 获取离线计算的物理位置偏移点
                    let physicalPoint = HexSpiralCalculator.convertToPhysicalPoint(coord: coord, stepSize: gridStepSize)
                    
                    // 将螺旋坐标与拖拽滑动位移叠加，获得气泡在视口坐标系中的实时坐标
                    let currentX = physicalPoint.x + totalOffset.width + dragOffset.width
                    let currentY = physicalPoint.y + totalOffset.height + dragOffset.height
                    
                    GeometryReader { itemGeo in
                        let frame = itemGeo.frame(in: .global)
                        let itemCenter = CGPoint(x: frame.midX, y: frame.midY)
                        
                        // 获取屏幕/容器的全局几何中心
                        let viewportGlobalFrame = viewportGeo.frame(in: .global)
                        let viewportGlobalCenter = CGPoint(x: viewportGlobalFrame.midX, y: viewportGlobalFrame.midY)
                        
                        // 1. 计算当前气泡与全局中心的欧氏物理距离
                        let dx = itemCenter.x - viewportGlobalCenter.x
                        let dy = itemCenter.y - viewportGlobalCenter.y
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        // 2. 边缘剔除优化 (Frustum Culling)
                        if distance > cullingDistance {
                            // 划出剔除阈值范围，直接锁定为底限形态，不运行复杂的缩放动画与外发光阴影以保护能效
                            CircularTagBubbleView(
                                item: item,
                                coordinator: coordinator,
                                bubbleRatio: bubbleRatio(for: item.count, tags: filtered),
                                interactiveScale: minFisheyeScale,
                                interactiveOpacity: minFisheyeOpacity
                            )
                            .position(x: itemGeo.size.width / FeatureConstants.TagBubbleCloud.canvasHalfDivisor, y: itemGeo.size.height / FeatureConstants.TagBubbleCloud.canvasHalfDivisor)
                        } else {
                            // 3. 鱼眼引擎三维余弦过渡缩放计算
                            let normDist = min(distance / maxFisheyeDistance, 1.0)
                            let interpolator = (cos(normDist * .pi) + 1.0) / FeatureConstants.TagBubbleCloud.cosineInterpolatorDivisor
                            
                            let scale = minFisheyeScale + (maxFisheyeScale - minFisheyeScale) * interpolator
                            let opacity = minFisheyeOpacity + (maxFisheyeOpacity - minFisheyeOpacity) * interpolator
                            
                            CircularTagBubbleView(
                                item: item,
                                coordinator: coordinator,
                                bubbleRatio: bubbleRatio(for: item.count, tags: filtered),
                                interactiveScale: scale,
                                interactiveOpacity: opacity
                              )
                              .position(x: itemGeo.size.width / FeatureConstants.TagBubbleCloud.canvasHalfDivisor, y: itemGeo.size.height / FeatureConstants.TagBubbleCloud.canvasHalfDivisor)
                        }
                    }
                    .frame(width: bubbleFrameDiameter, height: bubbleFrameDiameter)
                    .offset(
                        x: currentX - bubbleCenterOffset + viewportCenter.x,
                        y: currentY - bubbleCenterOffset + viewportCenter.y
                    )
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        dragOffset = gesture.translation
                    }
                    .onEnded { gesture in
                        // 使用平滑的惯性物理反弹动效
                        withAnimation(.interpolatingSpring(mass: 1.0, stiffness: dragSpringStiffness, damping: dragSpringDamping, initialVelocity: 0)) {
                            totalOffset.width += gesture.translation.width
                            totalOffset.height += gesture.translation.height
                            dragOffset = .zero
                            
                            // 网格拖拽边缘物理限制保护，防止画布飞走
                            let maxBound: CGFloat = CGFloat(filtered.count) * boundaryFactor + boundaryBuffer
                            if abs(totalOffset.width) > maxBound {
                                totalOffset.width = totalOffset.width > 0 ? maxBound : -maxBound
                            }
                            if abs(totalOffset.height) > maxBound {
                                totalOffset.height = totalOffset.height > 0 ? maxBound : -maxBound
                            }
                        }
                    }
            )
        }
    }
}

extension Collection {
    /// 安全索引访问器，防止越界访问导致崩溃
    /// - Parameter index: 索引位置
    /// - Returns: 可选的元素值，若越界则返回 nil
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
