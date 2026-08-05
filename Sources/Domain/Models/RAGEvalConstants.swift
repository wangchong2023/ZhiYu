//
//  RAGEvalConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：RAG 评估 (RAGEvaluationService) 专有常量集。
//           含相关性标注阈值、忠实度状态判定阈值、Prompt 构建截断长度等。
//

import Foundation

/// RAG 评估服务专有常量
public enum RAGEvalConstants {

    // MARK: - 检索快照 (Retrieval Snapshot) 截断长度
    /// 检索快照中保留的 snippet 前缀长度
    public static let snapshotSnippetPrefix: Int = 200

    // MARK: - 启发式相关性标注 (Heuristic Relevance Judgment) 阈值
    public struct HeuristicRelevance {
        /// 高相关性分数门槛（>= 此值判定为 level 2）
        public static let highThreshold: Double = 0.8
        /// 中相关性分数门槛（>= 此值判定为 level 1）
        public static let mediumThreshold: Double = 0.5
    }

    // MARK: - 忠实度状态判定 (Faithfulness Status) 阈值
    public struct FaithfulnessStatus {
        /// 忠实度低于此值判定为 fail
        public static let failThreshold: Double = 0.5
        /// 忠实度低于此值判定为 warning
        public static let warningThreshold: Double = 0.7
    }

    // MARK: - 评判 Prompt 构建 (Judge Prompt Building) 截断长度
    public struct JudgePrompt {
        /// 评判 Prompt 中展示的检索源最大数量
        public static let maxSources: Int = 20
        /// 评判 Prompt 中每个检索源 snippet 的前缀长度
        public static let sourceSnippetPrefix: Int = 150
        /// 评判 Prompt 中合并上下文的前缀长度
        public static let contextPrefix: Int = 3000
    }
}
