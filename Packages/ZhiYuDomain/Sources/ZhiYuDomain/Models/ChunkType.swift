//
//  ChunkType.swift
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义知识分块类型枚举 (ChunkType)，约束 PageChunk.chunkType 的合法取值。
//           消除散落在 Domain/Infrastructure/Tests 的 "summary"/"regular"/"child" 等魔鬼字符串。
//

import Foundation

/// 知识分块类型枚举
public enum ChunkType: String, Codable, CaseIterable, Sendable {
    /// 常规正文分块
    case regular
    /// 摘要分块（层级索引的概要）
    case summary
    /// 子分块（父块拆分后的细粒度块）
    case child
    /// 问答对分块
    case qaPair = "qa_pair"
    /// 段落分块
    case paragraph
    /// 纯文本分块（测试/兜底用）
    case text
}
