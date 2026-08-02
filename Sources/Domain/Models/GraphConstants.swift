//
//  GraphConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：知识图谱物理仿真、布局算法及 2D/3D 渲染专有常量集。
//

import Foundation

/// 知识图谱布局与物理仿真专有领域常量
public enum GraphConstants {
    
    /// 图谱每节点最大显示连线数
    public static let maxEdgesPerNode: Int = 5

    /// 2D 图谱逻辑配置
    public struct TwoD {
        public static let virtualSizeMultiplier: CGFloat = 2.0
        public static let simulationIterations: Int = 100
        public static let baseExpansionOffset: CGFloat = 20.0
        public static let expansionFactor: CGFloat = 0.05
    }
    
    /// 3D 图谱逻辑配置
    public struct ThreeD {
        public static let defaultCameraDistance: Float = 140.0
        public static let cameraZNear: Double = 0.1
        public static let cameraZFar: Double = 1000.0
        public static let baseSphereRadiusMultiplier: Double = 18.0
        public static let minSphereRadius: CGFloat = 60.0
        public static let maxSphereRadius: CGFloat = 250.0
        public static let starCount: Int = 500
    }
    
    /// 力导向算法物理常数
    public struct Physics {
        public static let repulsionForce: CGFloat = 5000.0
        public static let attractionForce: CGFloat = 0.01
        public static let damping: CGFloat = 0.85
        public static let centerGravity: CGFloat = 0.005
        public static let friction: CGFloat = 0.9
        public static let gridSize: CGFloat = 120.0
        public static let collisionDistance: CGFloat = 20.0
        public static let collisionForce: CGFloat = 10000.0
        public static let maxRepulsionDistanceSq: CGFloat = 40000.0
        public static let minDistanceSq: CGFloat = 0.01
    }
}
