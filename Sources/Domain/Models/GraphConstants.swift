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
        /// 图谱画布边缘留白 padding
        public static let layoutPadding: CGFloat = 40.0
        /// 社区聚类引力系数
        public static let clusterAttraction: CGFloat = 0.05
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
        /// 节点点击时的缩放倍数
        public static let nodeTapScale: CGFloat = 1.2
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
        /// 节点数降级阈值（超出时降级至 2D 拓扑）
        public static let nodeCountDegradeThreshold: Int = 2000
        /// FPS 良好阈值（高于此值显示绿色）
        public static let fpsGoodThreshold: Double = 30
        /// FPS 警告阈值（高于此值显示橙色，低于显示红色）
        public static let fpsWarnThreshold: Double = 15
        /// 相机距离倍数（基于球体半径计算目标距离）
        public static let cameraDistanceMultiplier: Float = 2.2
        /// 相机距离最小值
        public static let minCameraDistance: Float = 60
        /// 相机距离最大值
        public static let maxCameraDistance: Float = 400
        /// 星空球体半径
        public static let starfieldRadius: Float = 150
        /// 光源 X 坐标
        public static let lightPositionX: Float = 20
        /// 光源 Y 坐标
        public static let lightPositionY: Float = 30
        /// 光源 Z 坐标
        public static let lightPositionZ: Float = 20
        /// 相机 Y 偏移
        public static let cameraYOffset: Float = 15
        /// 节点标签显示阈值（低于此数量的节点显示标签）
        public static let labelDisplayThreshold: Int = 50
        /// 网格地板尺寸
        public static let gridFloorSize: Float = 100
        /// 网格地板分割数
        public static let gridFloorDivisions: Int = 50
        /// 网格地板 Y 偏移
        public static let gridFloorYOffset: Float = -30
        /// 缩放最小距离
        public static let zoomMinDistance: Float = 20
        /// 缩放最大距离
        public static let zoomMaxDistance: Float = 300
        /// 缩小因子
        public static let zoomOutFactor: Float = 0.8
        /// 放大因子
        public static let zoomInFactor: Float = 1.25
        /// 自动旋转速度
        public static let autoRotateSpeed: Float = 0.2
        /// 相机动画时长
        public static let cameraAnimationDuration: Double = 0.8
        /// 缩放动画时长
        public static let zoomAnimationDuration: Double = 0.5
        /// 节点点击动画时长
        public static let nodeTapAnimationDuration: Double = 1.0
        /// 脉冲动画时长
        public static let pulseAnimationDuration: Double = 2.0
        /// 脉冲缩放幅度
        public static let pulseScaleAmplitude: Double = 0.2
        /// 标签字体大小
        public static let labelFontSize: CGFloat = 1.2
        /// 标签扁平度
        public static let labelFlatness: CGFloat = 0.2
        /// 标签文字深度
        public static let labelExtrusionDepth: CGFloat = 0.1
        /// 标签发射强度
        public static let labelEmissionIntensity: Double = 0.3
        /// 边高亮不透明度
        public static let edgeHighlightedOpacity: Double = 1.0
        /// 边默认不透明度
        public static let edgeDefaultOpacity: Double = 0.2
        /// 边高亮发射强度
        public static let edgeHighlightedEmission: Double = 0.8
        /// 边默认发射强度
        public static let edgeDefaultEmission: Double = 0.1
        /// 网格不透明度
        public static let gridOpacity: Double = 0.2
        /// 节点点击相机偏移 Y
        public static let nodeTapCameraOffsetY: Float = 5
        /// 节点点击相机偏移 Z
        public static let nodeTapCameraOffsetZ: Float = 15
        /// 旋转角度微小阈值
        public static let rotationEpsilon: Double = 0.001
        /// 基础 FPS
        public static let baseFPS: Double = 60.0
        /// FPS 最低值
        public static let minFPS: Double = 10.0
        /// 节点复杂度除数
        public static let nodeComplexityDivisor: Double = 100.0
        /// 节点复杂度乘数
        public static let nodeComplexityMultiplier: Double = 5.0
        /// 自动旋转 FPS 扣减
        public static let autoRotateFPSDeduction: Double = 2.0
        /// FPS 更新间隔（秒）
        public static let fpsUpdateInterval: TimeInterval = 1.0
        /// 节点几何体 entity 宽高倍数
        public static let entitySizeMultiplier: Double = 1.6
        /// 节点几何体 entity 倒角半径比例
        public static let entityChamferRatio: Double = 0.2
        /// 节点几何体 source 高度倍数
        public static let sourceHeightMultiplier: Double = 2.5
        /// 节点几何体 comparison 宽高倍数
        public static let comparisonSizeMultiplier: Double = 2.0
        /// 节点几何体 raw 宽高倍数
        public static let rawWidthMultiplier: Double = 2.0
        /// 节点几何体 raw 高度比例
        public static let rawHeightRatio: Double = 0.2
        /// 节点几何体 raw 长度倍数
        public static let rawLengthMultiplier: Double = 1.5
        /// 节点几何体 raw 倒角半径
        public static let rawChamferRadius: Double = 0.05
        /// 节点标签不透明度（dimmed 状态）
        public static let labelDimmedOpacity: Double = 0.4
        /// 节点标签不透明度（正常状态）
        public static let labelNormalOpacity: Double = 1.0
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
