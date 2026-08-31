//
//  HexSpiralCalculator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层辅助工具
//  核心职责：提供六角蜂窝网格（Hexagonal Honeycomb Grid）轴向螺旋排布算法，支持将高频标签定位在画布中心，低频标签呈螺旋向四周辐射排列，并转换为物理平面坐标点。
//

import Foundation
import CoreGraphics

/// 六角蜂窝轴向坐标结构，支持 Sendable 并发安全及 Hashable 集合去重
public struct HexCoordinate: Hashable, Sendable {
    /// 轴向网格 q 轴 (重命名为 axialQ 规避 SwiftLint 命名长度警告)
    public let axialQ: Int
    /// 轴向网格 r 轴 (重命名为 axialR 规避 SwiftLint 命名长度警告)
    public let axialR: Int
    
    /// 初始化轴向蜂窝坐标点
    /// - Parameters:
    ///   - axialQ: 轴向 q 坐标
    ///   - axialR: 轴向 r 坐标
    public init(axialQ: Int, axialR: Int) {
        self.axialQ = axialQ
        self.axialR = axialR
    }
}

/// 六角网格螺旋排布生成与映射计算器
public struct HexSpiralCalculator {
    
    /// 蜂窝六边形六个环绕行进向量（顺时针）
    private static let hexDirections = [
        HexCoordinate(axialQ: 1, axialR: -1), // 东北
        HexCoordinate(axialQ: 1, axialR: 0),  // 东
        HexCoordinate(axialQ: 0, axialR: 1),  // 东南
        HexCoordinate(axialQ: -1, axialR: 1), // 西南
        HexCoordinate(axialQ: -1, axialR: 0), // 西
        HexCoordinate(axialQ: 0, axialR: -1)  // 西北
    ]
    
    /// 根据期望坐标数，由内而外生成六角蜂窝螺旋环绕坐标序列
    /// - Parameter count: 需要生成的标签气泡坐标总数
    /// - Returns: 排布好的轴向坐标数组
    public static func generateSpiralCoordinates(count: Int) -> [HexCoordinate] {
        guard count > 0 else { return [] }
        
        var results: [HexCoordinate] = []
        results.reserveCapacity(count)
        
        // 核心第 0 层：几何物理中心点
        results.append(HexCoordinate(axialQ: 0, axialR: 0))
        if results.count >= count { return results }
        
        var ring = 1
        while results.count < count {
            // 每圈螺旋从偏西方向（行走 ring 步）作为该环绕圈的起始点
            var currentQ = HexSpiralCalculator.hexDirections[4].axialQ * ring
            var currentR = HexSpiralCalculator.hexDirections[4].axialR * ring
            
            // 沿 6 个方向逐个环绕平铺
            for directionIndex in 0..<FeatureConstants.HexSpiral.directionCount {
                for _ in 0..<ring {
                    if results.count >= count { return results }
                    results.append(HexCoordinate(axialQ: currentQ, axialR: currentR))
                    
                    // 向当前边方向前进一步
                    currentQ += HexSpiralCalculator.hexDirections[directionIndex].axialQ
                    currentR += HexSpiralCalculator.hexDirections[directionIndex].axialR
                }
            }
            // 环绕半径外扩
            ring += 1
        }
        
        return results
    }
    
    /// 将蜂窝网格轴向坐标转换映射为二维物理平面点
    /// - Parameters:
    ///   - coord: 轴向坐标
    ///   - stepSize: 蜂窝网格基础步长（即 气泡半径+间距）
    /// - Returns: CGPoint 物理平面坐标点
    public static func convertToPhysicalPoint(coord: HexCoordinate, stepSize: CGFloat) -> CGPoint {
        // 使用标准六角网格的物理坐标转换公式
        let x = stepSize * (sqrt(3.0) * CGFloat(coord.axialQ) + (sqrt(3.0) / FeatureConstants.HexSpiral.physicalXRDivisor) * CGFloat(coord.axialR))
        let y = stepSize * (CGFloat(FeatureConstants.HexSpiral.physicalYScale) * CGFloat(coord.axialR))
        return CGPoint(x: x, y: y)
    }
}
