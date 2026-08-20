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

    /// 社区内聚力阈值
    public enum Community {
        /// 低内聚力社区默认阈值（低于此值视为低内聚力）
        public static let lowCohesionThreshold: Double = 0.15
    }

    /// 力导向布局算法系数
    public enum Layout {
        /// 温度基准值（仿真初始温度）
        public static let temperatureBaseline: CGFloat = 1.0
        /// 温度衰减系数（temperature = baseline - progress * decayFactor）
        public static let temperatureDecayFactor: CGFloat = 0.8
        /// 画布半径占短边比例
        public static let canvasRadiusRatio: CGFloat = 0.4
        /// 温度补偿引力系数
        public static let temperatureGravityCompensation: CGFloat = 0.01
        /// 空间网格哈希位移位数（将 gx 编码到高位）
        public static let gridHashShift: Int = 16
        /// 空间网格哈希低位掩码（gy 占低 16 位）
        public static let gridHashMask: Int = 0xFFFF
    }

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
