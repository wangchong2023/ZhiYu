//
//  LLMServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 LLMService 模块的抽象契约接口。
//
import Foundation
import Combine
import Dependencies
import UFPCore

// MARK: - LLM 对话服务协议 (核心推理与对话)

/// 大语言模型对话与生成的核心抽象协议。
///
/// 封装了单次对话、流式会话以及通用内容生成的底层抽象契约。
@MainActor
protocol LLMChatServiceProtocol: AnyObject, Sendable {
    /// LLM 服务当前是否已启用且配置正确。
    var isEnabled: Bool { get }

    // MARK: - 核心对话与推理
    
    /// 执行单次多轮对话并基于上下文合成引用回复。
    ///
    /// - Parameters:
    ///   - query: 用户当前输入的对话内容或提问。
    ///   - history: 历史会话消息列表，用于保持上下文连贯性。
    ///   - pages: 召回的相关知识页面列表，供 LLM 进行检索增强生成 (RAG)。
    /// - Returns: 返回 LLM 组织并带有引用的回复消息模型。
    /// - Throws: `LLMError` 执行推理出错或网络超时时抛出。
    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO
    
    /// 开启流式会话，实时接收分块文本。
    ///
    /// - Parameters:
    ///   - query: 用户当前输入的对话内容或提问。
    ///   - history: 历史会话消息列表。
    ///   - pages: 召回的相关知识页面列表，供 RAG 引用。
    /// - Returns: 返回流式字符串数据流的异步 Throwing Stream。
    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error>

    /// 通用文本内容生成接口，不带会话上下文。
    ///
    /// - Parameters:
    ///   - prompt: 生成任务的提示词。
    ///   - systemPrompt: 系统的角色设定或运行指令约束。
    /// - Returns: 返回生成的纯文本内容。
    /// - Throws: `LLMError` 生成出错或配置缺失时抛出。
    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String
}

// MARK: - LLM 知识维护服务协议

/// 负责知识清洗、双向链接发现及库重构分析的 LLM 业务协议。
@MainActor
protocol LLMKnowledgeServiceProtocol: AnyObject, Sendable {
    /// 智能语义分析、分块并提取核心实体导入到知识库。
    ///
    /// - Parameters:
    ///   - title: 文档或文章的标题。
    ///   - rawContent: 未经处理的原始富文本或 Markdown 文本。
    ///   - pages: 当前库中已有的知识页面列表，用于防重和实体对齐。
    /// - Returns: 返回包含分块、关联实体及分类标签的导入结果模型。
    /// - Throws: 异常于处理失败。
    func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO
    
    /// 根据当前正文分析并发现可能存在双向关联的已有页面标题。
    ///
    /// - Parameters:
    ///   - content: 待扫描分析的页面正文内容。
    ///   - existingTitles: 当前知识库中所有可用的页面标题列表。
    /// - Returns: 返回建议建立关联的页面标题列表。
    /// - Throws: 异常于模型调用失败。
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String]
    
    /// 将重叠的或新旧内容进行语义合并，保留最大化有效信息。
    ///
    /// - Parameters:
    ///   - existingContent: 数据库中已有的旧版本正文。
    ///   - newContent: 新抓取或输入待合并的正文内容。
    ///   - title: 页面标题，用于对齐上下文语义。
    /// - Returns: 合并并整理排版后的完整 Markdown 正文。
    /// - Throws: 异常于合并算法调用失败。
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String
    
    /// 对整个知识库的实体分布与内容进行体检，提供合理的归纳、重构与合并建议。
    ///
    /// - Parameter pages: 待评估审计的全局页面列表。
    /// - Returns: 返回重构重组的建议方案列表。
    /// - Throws: 异常于体检分析失败。
    func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO]
}

// MARK: - LLM 检索增强服务协议

/// 检索增强生成 (RAG) 管道中的高级重构与重排服务协议。
@MainActor
protocol LLMRetrievalServiceProtocol: AnyObject, Sendable {
    /// 对原始查询（Query）进行语义重写，以便更契合向量空间检索。
    ///
    /// - Parameter query: 用户输入的原始非结构化检索句。
    /// - Returns: 改写后更适合检索的提示语句。
    func rewriteQuery(_ query: String) async -> String
    
    /// 对检索词进行多维度同义扩展，生成多个扩展查询语句提升召回率。
    ///
    /// - Parameter query: 用户的检索原句。
    /// - Returns: 扩展后的多个检索子句列表。
    func expandQuery(_ query: String) async -> [String]
    
    /// 对初次召回的知识页面候选集进行二次精排重排列（Rerank）。
    ///
    /// - Parameters:
    ///   - query: 用户的原始检索需求。
    ///   - candidates: 粗排召回的初始页面候选集。
    /// - Returns: 按语义相关度降序排列后的页面候选列表。
    /// - Throws: 异常于重排算法失败。
    func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable]
    
    /// 对颗粒度更细的 PageChunk 进行重排，筛选出最优质的前 N 个 Chunks。
    ///
    /// - Parameters:
    ///   - query: 检索需求。
    ///   - chunks: 粗排所得的 PageChunk 候选列表。
    /// - Returns: 重排后高相关的 Chunks 列表。
    func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk]
    
    /// 预生成当前提问的假想文档（HyDE - Hypothetical Document Embeddings），用于在向量空间做更好的匹配。
    ///
    /// - Parameter query: 用户提问的检索句。
    /// - Returns: 假想生成的短文，用以作为向量索引的靶标。
    func generateHypotheticalDocument(query: String) async -> String
}

// MARK: - LLM 服务组合协议

/// 继承了对话、知识管理与检索重构子协议的 LLM 综合服务协议，保持向后兼容。
@MainActor
protocol LLMServiceProtocol: ObservableObject, LLMChatServiceProtocol, LLMKnowledgeServiceProtocol, LLMRetrievalServiceProtocol {
    /// 当前所选的模型服务提供商。
    var provider: LLMProvider { get set }
    
    /// 安全的访问密钥 API Key。
    var apiKey: String { get set }
    
    /// API 调用的基础网关地址。
    var baseURL: String { get set }
    
    /// 大语言模型的具体代号规格。
    var model: String { get set }
    
    /// 是否开启后台自动化知识扫描与标签提取。
    var autoScan: Bool { get set }
    
    /// 是否使能后台智能重构分析与自动化双链链接发现。
    var autoRefactor: Bool { get set }
}

// MARK: - LLMChatServiceProtocol 默认参数

extension LLMChatServiceProtocol {
    /// generate() 的 maxTokens 默认值，所有调用方无需显式传参
    func generate(prompt: String, systemPrompt: String) async throws -> String {
        try await generate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: PromptConstants.TokenLimits.defaultMaxOutputTokens)
    }
}

// MARK: - DependencyKey 注册

/// LLMChatServiceProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum LLMChatServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any LLMChatServiceProtocol {
        ServiceContainer.shared.resolve((any LLMChatServiceProtocol).self)
    }

    @MainActor
    public static var testValue: any LLMChatServiceProtocol {
        ServiceContainer.shared.resolveOptional((any LLMChatServiceProtocol).self) ?? NoOpLLMChatService()
    }
    @MainActor
    static var previewValue: any LLMChatServiceProtocol { testValue }
}

/// LLMKnowledgeServiceProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum LLMKnowledgeServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any LLMKnowledgeServiceProtocol {
        ServiceContainer.shared.resolve((any LLMKnowledgeServiceProtocol).self)
    }

    @MainActor
    public static var testValue: any LLMKnowledgeServiceProtocol {
        ServiceContainer.shared.resolveOptional((any LLMKnowledgeServiceProtocol).self) ?? NoOpLLMKnowledgeService()
    }
    @MainActor
    static var previewValue: any LLMKnowledgeServiceProtocol { testValue }
}

/// LLMRetrievalServiceProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum LLMRetrievalServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any LLMRetrievalServiceProtocol {
        ServiceContainer.shared.resolve((any LLMRetrievalServiceProtocol).self)
    }

    @MainActor
    public static var testValue: any LLMRetrievalServiceProtocol {
        ServiceContainer.shared.resolveOptional((any LLMRetrievalServiceProtocol).self) ?? NoOpLLMRetrievalService()
    }
    @MainActor
    static var previewValue: any LLMRetrievalServiceProtocol { testValue }
}

extension DependencyValues {
    /// LLM 对话服务依赖
    var llmChatService: any LLMChatServiceProtocol {
        get { self[LLMChatServiceKey.self] }
        set { self[LLMChatServiceKey.self] = newValue }
    }

    /// LLM 知识处理服务依赖
    var llmKnowledgeService: any LLMKnowledgeServiceProtocol {
        get { self[LLMKnowledgeServiceKey.self] }
        set { self[LLMKnowledgeServiceKey.self] = newValue }
    }

    /// LLM 检索增强服务依赖
    var llmRetrievalService: any LLMRetrievalServiceProtocol {
        get { self[LLMRetrievalServiceKey.self] }
        set { self[LLMRetrievalServiceKey.self] = newValue }
    }

    /// LLM 综合服务依赖
    var llmService: any LLMServiceProtocol {
        get { self[LLMServiceKey.self] }
        set { self[LLMServiceKey.self] = newValue }
    }
}

/// LLMServiceProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum LLMServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any LLMServiceProtocol {
        ServiceContainer.shared.resolve((any LLMServiceProtocol).self)
    }

    @MainActor
    public static var testValue: any LLMServiceProtocol {
        ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) ?? NoOpLLMService()
    }
    @MainActor
    static var previewValue: any LLMServiceProtocol { testValue }
}

// MARK: - NoOp LLM 服务实现（测试/预览占位，DI 未就绪时降级）

/// 无操作 LLM 对话服务（测试/预览占位，DI 未就绪时降级）
@MainActor
public final class NoOpLLMChatService: LLMChatServiceProtocol {
    public var isEnabled: Bool { false }
    public init() {}
    public func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: "")
    }
    public func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }
    public func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String { "" }
}

/// 无操作 LLM 知识维护服务（测试/预览占位，DI 未就绪时降级）
@MainActor
public final class NoOpLLMKnowledgeService: LLMKnowledgeServiceProtocol {
    public init() {}
    public func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        SmartIngestResultDTO(title: title, compiledContent: "", suggestedTags: [], suggestedType: PageType.concept.rawValue, relatedTitles: [], summary: "")
    }
    public func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] { [] }
    public func foldContent(existingContent: String, newContent: String, title: String) async throws -> String { existingContent }
    public func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] { [] }
}

/// 无操作 LLM 检索增强服务（测试/预览占位，DI 未就绪时降级）
@MainActor
public final class NoOpLLMRetrievalService: LLMRetrievalServiceProtocol {
    public init() {}
    public func rewriteQuery(_ query: String) async -> String { query }
    public func expandQuery(_ query: String) async -> [String] { [] }
    /// NoOp 占位实现：直接返回原候选列表，永不抛错（`throws` 仅为满足协议契约）
    public func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] { candidates }
    public func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] { chunks }
    public func generateHypotheticalDocument(query: String) async -> String { "" }
}

/// 无操作 LLM 综合服务（ObservableObject 占位）
@MainActor
public final class NoOpLLMService: LLMServiceProtocol {
    public var provider: LLMProvider = .custom
    public var apiKey: String = ""
    public var baseURL: String = ""
    public var model: String = ""
    public var autoScan: Bool = false
    public var autoRefactor: Bool = false
    public var isEnabled: Bool { false }
    public init() {}
    public func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: "")
    }
    public func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }
    public func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String { "" }
    public func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        SmartIngestResultDTO(title: title, compiledContent: "", suggestedTags: [], suggestedType: PageType.concept.rawValue, relatedTitles: [], summary: "")
    }
    public func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] { [] }
    public func foldContent(existingContent: String, newContent: String, title: String) async throws -> String { existingContent }
    public func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] { [] }
    public func rewriteQuery(_ query: String) async -> String { query }
    public func expandQuery(_ query: String) async -> [String] { [] }
    /// NoOp 占位实现：直接返回原候选列表，永不抛错（`throws` 仅为满足协议契约）
    public func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] { candidates }
    public func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] { chunks }
    public func generateHypotheticalDocument(query: String) async -> String { "" }
}
