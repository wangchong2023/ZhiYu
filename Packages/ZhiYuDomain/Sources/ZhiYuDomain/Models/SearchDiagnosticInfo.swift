//
//  SearchDiagnosticInfo.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：属于 Model 领域模型，提供搜索和混合检索 RRF 召回诊断的基础数据结构支撑，支持端侧与云侧多平台诊断消费。
//

import Foundation

/// 搜索诊断数据结构
public struct SearchDiagnosticInfo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let query: String
    public let rewrittenQuery: String
    public let ftsCount: Int
    public let vectorCount: Int
    public let rrfTopResults: [ResultScore]

    /// 搜索诊断信息初始化
    /// - Parameters:
    ///   - id: 诊断唯一标识 UUID
    ///   - query: 原始查询 Query 字符串
    ///   - rewrittenQuery: AI 重写后的 Query 字符串
    ///   - ftsCount: 全文检索召回数量
    ///   - vectorCount: 向量检索召回数量
    ///   - rrfTopResults: 混合 RRF 重排后的置信度得分结果列表
    public init(id: UUID = UUID(), query: String, rewrittenQuery: String, ftsCount: Int, vectorCount: Int, rrfTopResults: [ResultScore]) {
        self.id = id
        self.query = query
        self.rewrittenQuery = rewrittenQuery
        self.ftsCount = ftsCount
        self.vectorCount = vectorCount
        self.rrfTopResults = rrfTopResults
    }
    
    /// 检索结果打分模型
    public struct ResultScore: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let title: String
        public let ftsRank: Int
        public let vectorRank: Int
        public let finalScore: Double

        /// 结果评分单元初始化
        /// - Parameters:
        ///   - id: 页面节点 UUID
        ///   - title: 页面标题
        ///   - ftsRank: 全文检索排位
        ///   - vectorRank: 向量检索排位
        ///   - finalScore: 综合打分
        public init(id: UUID, title: String, ftsRank: Int, vectorRank: Int, finalScore: Double) {
            self.id = id
            self.title = title
            self.ftsRank = ftsRank
            self.vectorRank = vectorRank
            self.finalScore = finalScore
        }
    }
}
