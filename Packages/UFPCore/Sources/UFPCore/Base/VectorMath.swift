//
//  VectorMath.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：提供基于 vDSP (Accelerate) 的高性能向量数学计算（如余弦相似度等）。
//

import Foundation
import Accelerate

/// 向量数学工具集
///
/// 封装了对 Accelerate 框架 (vDSP) 的调用，用于加速大规模向量相似度检索及相关计算。
public enum VectorMath {

    /// 计算两个单精度浮点向量的余弦相似度
    /// - Parameters:
    ///   - v1: 第一个向量
    ///   - v2: 第二个向量
    /// - Returns: 余弦相似度得分，如果长度不匹配或包含全0向量则返回 0
    public static func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        guard v1.count == v2.count, !v1.isEmpty else { return 0 }

        let length = vDSP_Length(v1.count)
        var dotProduct: Float = 0

        // 计算点积 (Dot Product)
        vDSP_dotpr(v1, 1, v2, 1, &dotProduct, length)

        // 计算各向量的平方和 (Sum of Squares)
        var v1SumSq: Float = 0
        var v2SumSq: Float = 0
        vDSP_svesq(v1, 1, &v1SumSq, length)
        vDSP_svesq(v2, 1, &v2SumSq, length)

        let denominator = sqrt(v1SumSq) * sqrt(v2SumSq)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}
