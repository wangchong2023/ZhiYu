//
//  LLMContextBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：大语言模型客户端：多提供商适配、流式响应解析、端侧推理。
//
import Foundation
import NaturalLanguage

// MARK: - LLM Context Builder
/// 构建系统提示词并为 LLM 查询检索相关知识库上下文。
final class LLMContextBuilder: Sendable {

    // MARK: - Configuration Constants
    /// Max entities listed in the system prompt overview.
    private static let maxEntityOverview = PromptConstants.RAGPrompt.maxEntityOverview
    /// Max concepts listed in the system prompt overview.
    private static let maxConceptOverview = PromptConstants.RAGPrompt.maxConceptOverview
    /// Max sources listed in the system prompt overview.
    private static let maxSourceOverview = PromptConstants.RAGPrompt.maxSourceOverview
    /// Max recent pages shown in the system prompt overview.
    private static let maxRecentOverview = PromptConstants.RAGPrompt.maxRecentOverview
    /// Content preview length per page in system prompt.
    private static let contentPreviewLength = PromptConstants.RAGPrompt.contentPreviewLength
    /// Max pages included in the relevant context for a query.
    private static let maxContextPages = PromptConstants.RAGPrompt.maxContextPages
    /// Content preview length per page in query context.
    private static let contextPreviewLength = PromptConstants.RAGPrompt.contextPreviewLength

    private let sanitizer = PromptSecuritySanitizer()
    private let reranker = ContextReranker()

    // MARK: - System Prompt
    /// 构建SystemPrompt
    /// - Parameter pages: pages
    /// - Returns: 字符串
    func buildSystemPrompt(pages: [any KnowledgePageRepresentable]) -> String {
        var prompt = """
        \(L10n.AI.LLM.Prompt.role)

        \(L10n.Chat.welcomeDesc)
        \(L10n.AI.LLM.Prompt.duty1)
        \(L10n.AI.LLM.Prompt.duty2)
        \(L10n.AI.LLM.Prompt.duty3)
        \(L10n.AI.LLM.Prompt.duty4)

        \(L10n.AI.LLM.Ingest.compileRules)
        \(L10n.AI.LLM.Prompt.rule1)
        \(L10n.AI.LLM.Prompt.rule2)
        \(L10n.AI.LLM.Prompt.rule3)
        \(L10n.AI.LLM.Prompt.rule4)
        \(L10n.AI.LLM.Prompt.rule5)

        \(L10n.AI.LLM.Prompt.overview)
        """

        // 总结知识库内容作为上下文
        let concretePages = pages.compactMap { $0 as? KnowledgePage }
        let activePages = concretePages.filter { $0.status == .active || $0.status == .stub }
        let totalPages = activePages.count
        let entities = activePages.filter { $0.pageType == .entity }
        let concepts = activePages.filter { $0.pageType == .concept }
        let sources = activePages.filter { $0.pageType == .source }

        prompt += "\n- \(L10n.AI.LLM.Prompt.totalPages): \(totalPages)"
        prompt += "\n- \(L10n.AI.LLM.Prompt.entityCount): \(entities.count), \(L10n.AI.LLM.Prompt.conceptCount): \(concepts.count), \(L10n.AI.LLM.Prompt.sourceCount): \(sources.count)"
        prompt += "\n\n\(L10n.AI.LLM.Prompt.entityList)"
        for entity in entities.prefix(Self.maxEntityOverview) {
            prompt += "\n- [[\(entity.title)]]: \(String(entity.content.prefix(Self.contentPreviewLength)))"
        }
        prompt += "\n\n\(L10n.AI.LLM.Prompt.conceptList)"
        for concept in concepts.prefix(Self.maxConceptOverview) {
            prompt += "\n- [[\(concept.title)]]: \(String(concept.content.prefix(Self.contentPreviewLength)))"
        }
        prompt += "\n\n\(L10n.AI.LLM.Prompt.sourceList)"
        for source in sources.prefix(Self.maxSourceOverview) {
            prompt += "\n- [[\(source.title)]]"
        }

        // Add recent changes
        let recent = activePages.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.maxRecentOverview)
        if !recent.isEmpty {
            prompt += "\n\n\(L10n.AI.LLM.Prompt.recentUpdates)"
            for page in recent {
                prompt += "\n- \(page.title) (\(page.updatedAt.formatted(.dateTime.month().day())))"
            }
        }

        return prompt
    }

    /// 使用多路召回与二阶段重排序 (Two-Stage Rerank) 获取高度相关的知识片段，并完成 XML 沙箱化隔离。
    /// - Returns: (格式化后的 Prompt 字符串, 提取出的信源数据对象列表)
    func buildRelevantContext(query: String) async -> (context: String, sources: [KnowledgeSource]) {
        // 0. 越狱注入攻击扫描
        try? sanitizer.scanJailbreakAttempt(in: query)

        let embeddingProvider = ServiceContainer.shared.resolve((any EmbeddingProvider).self)

        // 1. 执行多路召回
        let rawResults = await embeddingProvider.multiQuerySearch(query: query, topK: AppConfig.AI.topKResults)

        guard !rawResults.isEmpty else {
            return ("\(L10n.AI.LLM.Prompt.relevantPages)\n\(L10n.Common.Global.noData)\n", [])
        }

        // 2. 执行二阶段重排序 (Two-Stage Rerank)
        let searchResults = reranker.rerank(query: query, candidates: rawResults, topK: PromptConstants.RAGPrompt.maxContextPages)

        // 3. 智能压缩逻辑 (Compression)
        let maxContextLength = AppConfig.AI.maxContextLength
        var currentLength = 0
        var compressedResults: [(chunk: PageChunk, score: Float)] = []

        for res in searchResults.sorted(by: { $0.score > $1.score }) {
            let chunkLen = res.chunk.content.count
            if currentLength + chunkLen > maxContextLength {
                if res.chunk.chunkType == "summary" || res.score > 0.8 {
                    compressedResults.append(res)
                    currentLength += chunkLen
                }
                if currentLength > maxContextLength + 500 { break } 
            } else {
                compressedResults.append(res)
                currentLength += chunkLen
            }
        }

        // 4. 聚合分块上下文并提取 Source 模型
        var rawContext = "\(L10n.AI.LLM.Prompt.relevantPages)\n"
        var sources: [KnowledgeSource] = []
        let groupedResults = Dictionary(grouping: compressedResults) { $0.chunk.pageID }

        for (pageID, results) in groupedResults {
            let store = ServiceContainer.shared.resolve(KnowledgePageRepository.self)
            if let page = try? await store.fetch(id: pageID) {
                rawContext += "\n---\n## \(page.title) [\(L10n.AI.LLM.Prompt.typeLabel): \(page.pageType.displayName)]\n"

                for (chunk, score) in results.sorted(by: { $0.score > $1.score }) {
                    let relevanceLabel = L10n.AI.Prompt.relevanceScore
                    let typeLabel = L10n.AI.Prompt.chunkType
                    rawContext += "\n> [\(relevanceLabel): \(String(format: "%.4f", score)) | \(typeLabel): \(chunk.chunkType)]\n"
                    rawContext += chunk.content
                    rawContext += "\n"
                    
                    // 构建 Source 模型
                    sources.append(KnowledgeSource(
                        pageID: page.id,
                        title: page.title,
                        snippet: chunk.content,
                        anchorPath: chunk.anchorPath,
                        score: Double(score)
                    ))
                }
            }
        }

        return (sanitizer.sanitizeContext(rawContext), sources)
    }

    // MARK: - Ingest Prompt Builder
    /// 构建导入摄取Prompt
    /// - Parameter title: title
    /// - Parameter rawContent: rawContent
    /// - Parameter pages: pages
    /// - Returns: 字符串
    func buildIngestPrompt(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) -> String {
        let existingTitles = pages.map(\.title).joined(separator: ", ")

        return """
        \(L10n.AI.LLM.Ingest.compileInstruction)

        \(L10n.AI.LLM.Ingest.compileRules)
        \(L10n.AI.LLM.Ingest.rule1)
        \(L10n.AI.LLM.Ingest.rule2)
        \(L10n.AI.LLM.Ingest.rule3)
        \(L10n.AI.LLM.Ingest.rule4)
        \(L10n.AI.LLM.Ingest.rule5)
        \(L10n.AI.LLM.Ingest.rule6)

        \(L10n.AI.LLM.Ingest.existingPages)\(existingTitles)

        \(L10n.AI.LLM.Ingest.rawTitle)\(title)

        \(L10n.AI.LLM.Ingest.rawContent)
        \(rawContent)

        ---
        ##  (Schema Rules)
        

        1. ** (entity)**: 
        2. ** (concept)**: 

         JSON 
        {
          "compiledContent": "\(L10n.AI.LLM.Ingest.jsonCompiledContent)",
          "suggestedTags": ["\(L10n.AI.LLM.Ingest.jsonSuggestedTags)1", "\(L10n.AI.LLM.Ingest.jsonSuggestedTags)2"],
          "suggestedType": "entity|concept|source|comparison|map",
          "relatedTitles": [],
          "summary": "\(L10n.AI.LLM.Ingest.jsonSummary)"
        }
        """
    }

    // MARK: - Query Rewrite Builder
    /// 构建RewritePrompt
    /// - Parameter query: query
    /// - Returns: 字符串
    func buildRewritePrompt(query: String) -> String {
        """
        \(L10n.AI.Prompt.QueryRewrite.instruction)
        \(L10n.AI.Prompt.QueryRewrite.rules)
        1. \(L10n.AI.Prompt.QueryRewrite.rule1)
        2. \(L10n.AI.Prompt.QueryRewrite.rule2)
        3. \(L10n.AI.Prompt.QueryRewrite.rule3)
        4. \(L10n.AI.Prompt.QueryRewrite.rule4)
        \(L10n.AI.Prompt.QueryRewrite.userQuery): \(query)
        \(L10n.AI.Prompt.QueryRewrite.footer)

        """
    }

    // MARK: - 端侧 NER 脱敏传输与还原 (SR-12)
    
    /// 将文本中的人名、地名、组织机构名等敏感专有名词哈希替换为占位符 [ENTITY_A] 等
    /// - Parameter text: 原始文本
    /// - Parameter existingMapping: 已有的哈希映射字典（用于多段文本脱敏时保持映射一致）
    /// - Returns: (脱敏后的文本, 哈希映射字典)
    func anonymize(_ text: String, existingMapping: [String: String] = [:]) -> (anonymizedText: String, mapping: [String: String]) {
        guard !text.isEmpty else { return (text, existingMapping) }
        
        // 局部实例化非 Sendable 的 NLTagger 以保证并发安全
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var mapping = existingMapping
        var reversedMapping: [String: String] = [:]
        
        // 反向映射以重用已有 placeholder
        for (placeholder, original) in existingMapping {
            reversedMapping[original] = placeholder
        }
        
        var count = mapping.count
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                // 筛选人名、地名及组织机构等专有名词实体
                if tag == .personalName || tag == .placeName || tag == .organizationName {
                    let original = String(text[tokenRange])
                    
                    // 仅对有效长度的敏感实体进行遮掩，避免过短噪音，且避免重复分配
                    if original.count >= 2 && reversedMapping[original] == nil {
                        let character = Character(UnicodeScalar(UInt8(65 + (count % 26))))
                        let suffix = count >= 26 ? "\(count / 26)" : ""
                        let placeholder = "[ENTITY_\(character)\(suffix)]"
                        
                        mapping[placeholder] = original
                        reversedMapping[original] = placeholder
                        count += 1
                    }
                }
            }
            return true
        }
        
        // 按照敏感词长度从长到短执行物理替换，规避前缀子串替换冲突 (例如“张三丰”优先于“张三”)
        var anonymizedText = text
        let sortedOriginals = reversedMapping.keys.sorted { $0.count > $1.count }
        for original in sortedOriginals {
            if let placeholder = reversedMapping[original] {
                anonymizedText = anonymizedText.replacingOccurrences(of: original, with: placeholder)
            }
        }
        
        return (anonymizedText, mapping)
    }
    
    /// 将文本中的 [ENTITY_A] 等占位符还原为原始的敏感机密信息
    /// - Parameter text: 带有占位符的脱敏文本
    /// - Parameter mapping: 映射字典
    /// - Returns: 还原后的原文
    func deanonymize(_ text: String, mapping: [String: String]) -> String {
        var result = text
        // 按照占位符长度降序替换，避免潜在哈希前缀相交引起重合错误
        let sortedPlaceholders = mapping.keys.sorted { $0.count > $1.count }
        for placeholder in sortedPlaceholders {
            if let original = mapping[placeholder] {
                result = result.replacingOccurrences(of: placeholder, with: original)
            }
        }
        return result
    }
}

// MARK: - Chat History Store
/// Manages chat message persistence with UserDefaults.
final class ChatHistoryStore: ObservableObject {
    var messages: [ChatMessageDTO] = []

    private let historyKey = "zhiyu_chat_history"

    init() {
        load()
    }

    /// 追加
    /// - Parameter message: message
    func append(_ message: ChatMessageDTO) {
        messages.append(message)
        persistToDisk()
    }

    /// 追加Batch
    /// - Parameter newMessages: newMessages
    func appendBatch(_ newMessages: [ChatMessageDTO]) {
        messages.append(contentsOf: newMessages)
        persistToDisk()
    }

    /// 清除
    func clear() {
        messages.removeAll()
        persistToDisk()
    }

    /// Explicitly persist current state to disk (public for external sync).
    func persistToDisk() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    /// Returns the last N messages (typically for LLM context window).
    func recent(_ count: Int) -> ArraySlice<ChatMessageDTO> {
        messages.suffix(count)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([ChatMessageDTO].self, from: data) {
            messages = history
        }
    }
}
