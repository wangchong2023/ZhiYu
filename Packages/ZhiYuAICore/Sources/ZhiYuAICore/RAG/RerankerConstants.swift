//
//  RerankerConstants.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 (AI Core)
//  核心职责：RAG 召回两阶段重排序器专有常量集。
//

import Foundation

/// RAG 召回两阶段重排序器专有常量集
public enum RerankerConstants {
    /// 默认重排序 Top-K 截断上限 (5)
    public static let defaultTopK: Int = 5
    /// 候选块最低相关度阈值 (0.35)
    public static let defaultMinScore: Float = 0.35
    /// 初始检索向量分数权重 (0.7)
    public static let initialScoreWeight: Float = 0.7
    /// 跨编码交叉注意力/词重叠覆盖度权重 (0.3)
    public static let crossScoreWeight: Float = 0.3
}
