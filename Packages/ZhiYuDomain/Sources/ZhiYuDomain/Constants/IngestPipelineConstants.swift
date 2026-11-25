//
//  IngestPipelineConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：知识摄入流水线专有强类型常量集。
//

import Foundation

/// 知识摄入流水线常量定义
public enum IngestPipelineConstants {
    /// 摄入阶段进度比例
    public enum StageProgress {
        public static let extraction: Double = 0.05
        public static let enrichment: Double = 0.15
        public static let chunking: Double = 0.40
        public static let embedding: Double = 0.75
    }
}
