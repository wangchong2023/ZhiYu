//
//  SearchConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：混合检索 (FTS5 + Vector)、RRF 融合重排与语义匹配阈值专有常量集。
//

import Foundation

/// 检索算法与向量比对专有领域常量
public enum SearchConstants {
    
    // MARK: - 混合检索与 RRF 融合重排算法参数
    /// Reciprocal Rank Fusion (RRF) 算法常数
    public static let rrfK: Int = 60
    
    /// 语义搜索的相似度动态门槛
    public static let semanticThresholdShort: Float = 0.85
    public static let semanticThresholdLong: Float = 0.75
    
    /// 短查询语义高信度门槛
    public static let semanticShortHighConfidence: Float = 0.88
    
    /// 短查询字符数判断阈值
    public static let shortQueryThreshold: Int = 4
}
