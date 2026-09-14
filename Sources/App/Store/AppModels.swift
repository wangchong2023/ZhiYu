//
//  AppModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：全局状态管理（AppStore），持有应用级 @Observable 状态树。
//
import Foundation

// MARK: - 应用层共享模型命名空间

/// 应用层共享模型命名空间，供 AppStore 通过 typealias 引用，消除重复定义。
public enum AppModels {
    // MARK: - 引导层类型

    /// 用户引导层 (Coach Mark) 类型枚举
    /// 标识需要向用户展示的一次性引导提示类型
    public enum CoachMarkType: String, Sendable {
        /// 图谱探索引导
        case graphDiscovery = "graph_discovery"
    }

    // MARK: - 知识增长趋势数据点

    /// 知识库增长趋势数据点
    /// 用于仪表盘折线图展示知识页面历史增长趋势
    public struct KnowledgeGrowthPoint: Identifiable {
        /// 唯一标识符
        public let id = UUID()
        /// 该数据点对应的日期
        public let date: Date
        /// 截至该日期的知识页面累计数量
        public let count: Int

        public init(date: Date, count: Int) {
            self.date = date
            self.count = count
        }
    }
}

// MARK: - 顶级类型别名（供 AppStoreProtocol 等跨层协议引用，无需 AppStore. 前缀）

/// 引导层类型顶级别名，供 Domain 层协议直接引用
public typealias CoachMarkType = AppModels.CoachMarkType

/// 知识增长点顶级别名，供 Domain 层协议直接引用
public typealias KnowledgeGrowthPoint = AppModels.KnowledgeGrowthPoint
