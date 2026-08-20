//
//  RAGGovernanceModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：RAG 全链路质量治理数据模型（Token、调用日志、评估结果）。
//
import Foundation
import UFPStorage

// MARK: - Token 使用量模型
/// 用于统计 AI 模型消耗的 Token 数据
public struct TokenUsage: Identifiable, Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.tokenUsage
    
    public var id: Int64?
    public var model: String
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int
    public var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case model
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case createdAt = "created_at"
    }
    
    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let model = Column(CodingKeys.model)
        static let promptTokens = Column(CodingKeys.promptTokens)
        static let completionTokens = Column(CodingKeys.completionTokens)
        static let totalTokens = Column(CodingKeys.totalTokens)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    public init(id: Int64? = nil, model: String, promptTokens: Int, completionTokens: Int, createdAt: Date = Date()) {
        self.id = id
        self.model = model
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = promptTokens + completionTokens
        self.createdAt = createdAt
    }

    /// 自定义解码：强制 totalTokens = promptTokens + completionTokens，防止外部 JSON 数据不一致
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int64.self, forKey: .id)
        self.model = try container.decode(String.self, forKey: .model)
        self.promptTokens = try container.decode(Int.self, forKey: .promptTokens)
        self.completionTokens = try container.decode(Int.self, forKey: .completionTokens)
        self.totalTokens = promptTokens + completionTokens
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - RAG 质量评估模型
/// 用于存储 LLM-as-a-Judge 对回答质量的自动评估结果
public struct RAGEvaluation: Identifiable, Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.ragEvaluations
    
    public var id: Int64?
    public var query: String
    public var answer: String
    public var faithfulness: Double
    public var relevance: Double
    public var precision: Double
    /// 幻觉率 (0-1)，AI 生成内容中无上下文支撑的比例。越高越差。
    public var hallucinationRate: Double
    /// 引用准确度 (0-1)，引用是否真实指向原文对应位置。越高越好。
    public var citationAccuracy: Double
    /// 答案正确性 (0-1)，基于黄金标准答案或 LLM 判定的事实性评估。越高越好。
    public var answerCorrectness: Double
    /// 上下文充分性 (0-1)，检索到的上下文文档是否足以支撑回答。越高越好。
    public var contextSufficiency: Double
    /// 用户满意度评分（nil=未评价，1=差评，2=好评）
    public var userRating: Int?
    public var evaluatorModel: String
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case query
        case answer
        case faithfulness = "faithfulness_score"
        case relevance = "relevance_score"
        case precision = "context_precision"
        case hallucinationRate = "hallucination_rate"
        case citationAccuracy = "citation_accuracy"
        case answerCorrectness = "answer_correctness"
        case contextSufficiency = "context_sufficiency"
        case userRating = "user_rating"
        case evaluatorModel = "evaluator_model"
        case createdAt = "created_at"
    }

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let query = Column(CodingKeys.query)
        static let answer = Column(CodingKeys.answer)
        static let faithfulness = Column(CodingKeys.faithfulness)
        static let relevance = Column(CodingKeys.relevance)
        static let precision = Column(CodingKeys.precision)
        static let hallucinationRate = Column(CodingKeys.hallucinationRate)
        static let citationAccuracy = Column(CodingKeys.citationAccuracy)
        static let answerCorrectness = Column(CodingKeys.answerCorrectness)
        static let contextSufficiency = Column(CodingKeys.contextSufficiency)
        static let userRating = Column(CodingKeys.userRating)
        static let evaluatorModel = Column(CodingKeys.evaluatorModel)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    public init(
        id: Int64? = nil,
        query: String,
        answer: String,
        faithfulness: Double,
        relevance: Double,
        precision: Double,
        hallucinationRate: Double = 0.0,
        citationAccuracy: Double = 0.0,
        answerCorrectness: Double = 0.0,
        contextSufficiency: Double = 0.0,
        userRating: Int? = nil,
        evaluatorModel: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.answer = answer
        self.faithfulness = faithfulness
        self.relevance = relevance
        self.precision = precision
        self.hallucinationRate = hallucinationRate
        self.citationAccuracy = citationAccuracy
        self.answerCorrectness = answerCorrectness
        self.contextSufficiency = contextSufficiency
        self.userRating = userRating
        self.evaluatorModel = evaluatorModel
        self.createdAt = createdAt
    }
}

// MARK: - LLM 调用日志模型（完整 ORM 支持版）
/// LLM 调用详细日志模型，迁移自协议定义文件
public struct LLMCallLog: Identifiable, Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.llmCallLogs
    
    public var id: Int64?
    public let model: String
    public let promptTokens: Int
    public let completionTokens: Int
    public let latencyMS: Int
    public let status: String
    public let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case model
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case latencyMS = "latency_ms"
        case status
        case createdAt = "created_at"
    }
    
    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let model = Column(CodingKeys.model)
        static let promptTokens = Column(CodingKeys.promptTokens)
        static let completionTokens = Column(CodingKeys.completionTokens)
        static let latencyMS = Column(CodingKeys.latencyMS)
        static let status = Column(CodingKeys.status)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    public init(
        id: Int64? = nil,
        model: String,
        promptTokens: Int,
        completionTokens: Int,
        latencyMS: Int,
        status: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.model = model
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.latencyMS = latencyMS
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - 检索快照模型
/// 记录每次 RAG 评估时的完整检索排序结果，用于计算 Hit Rate / MRR / NDCG
public struct RetrievalSnapshot: Identifiable, Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.retrievalSnapshots

    public var id: Int64?
    public var evaluationID: Int64          // FK → rag_evaluations.id
    public var rank: Int                    // 排序位置 (1-based)
    public var sourceID: String             // KnowledgeSource.id (UUID 字符串)
    public var pageTitle: String            // 页面标题
    public var snippet: String              // 文本片段 (截断至 200 字符)
    public var score: Double                // Rerank 相似度
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case evaluationID = "evaluation_id"
        case rank
        case sourceID = "source_id"
        case pageTitle = "page_title"
        case snippet
        case score
        case createdAt = "created_at"
    }

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let evaluationID = Column(CodingKeys.evaluationID)
        static let rank = Column(CodingKeys.rank)
        static let sourceID = Column(CodingKeys.sourceID)
        static let pageTitle = Column(CodingKeys.pageTitle)
        static let snippet = Column(CodingKeys.snippet)
        static let score = Column(CodingKeys.score)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    public init(
        id: Int64? = nil,
        evaluationID: Int64,
        rank: Int,
        sourceID: String,
        pageTitle: String,
        snippet: String,
        score: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.evaluationID = evaluationID
        self.rank = rank
        self.sourceID = sourceID
        self.pageTitle = pageTitle
        self.snippet = snippet
        self.score = score
        self.createdAt = createdAt
    }
}

// MARK: - 检索相关性标注模型
/// 记录 query 与检索结果的相关性标签（LLM 自动标注），用于计算检索质量基准
public struct RelevanceJudgment: Identifiable, Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.relevanceJudgments

    public var id: Int64?
    public var queryHash: String             // SHA256(query) 去重
    public var query: String                 // 原始查询文本
    public var sourceID: String              // KnowledgeSource.id
    public var relevanceLevel: Int           // 0=irrelevant, 1=partially, 2=highly relevant
    public var judgeSource: String           // "llm-auto" | "manual"
    public var evaluationID: Int64?          // FK → rag_evaluations.id (可为空)
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case queryHash = "query_hash"
        case query
        case sourceID = "source_id"
        case relevanceLevel = "relevance_level"
        case judgeSource = "judge_source"
        case evaluationID = "evaluation_id"
        case createdAt = "created_at"
    }

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let queryHash = Column(CodingKeys.queryHash)
        static let query = Column(CodingKeys.query)
        static let sourceID = Column(CodingKeys.sourceID)
        static let relevanceLevel = Column(CodingKeys.relevanceLevel)
        static let judgeSource = Column(CodingKeys.judgeSource)
        static let evaluationID = Column(CodingKeys.evaluationID)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    public init(
        id: Int64? = nil,
        queryHash: String,
        query: String,
        sourceID: String,
        relevanceLevel: Int,
        judgeSource: String = "llm-auto",
        evaluationID: Int64? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.queryHash = queryHash
        self.query = query
        self.sourceID = sourceID
        self.relevanceLevel = relevanceLevel
        self.judgeSource = judgeSource
        self.evaluationID = evaluationID
        self.createdAt = createdAt
    }
}
