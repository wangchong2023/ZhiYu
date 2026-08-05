//
//  KnowledgeIngestPipeline.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：RAG 检索增强生成管道：语义搜索、链接发现、内容增强、评估。
//
import Foundation

/// 知识摄入管道 - RAG 流程的统一入口
actor KnowledgeIngestPipeline {

    /// 共享实例
    static let shared = KnowledgeIngestPipeline()

    private let enricher = AIContentEnricher.shared
    private let chunker = TextChunkerProcessor()

    private init() {}

    /// 执行完整的 Advanced RAG 摄入流程
    /// 包含：语义增强 -> 全局摘要 -> 父子块切分 -> 反向提问 (Q&A) -> 向量化
    func process(
        content: String,
        pageID: UUID,
        llm: (any LLMServiceProtocol)?,
        embeddingProvider: any EmbeddingProvider
    ) async throws -> String {
        
        // 0. 提取阶段
        await updateProgress(stage: .extraction, progress: 0.05, log: L10n.Ingest.Status.starting)

        // 1. 语义增强阶段
        let enrichedContent = try await performEnrichment(content: content, llm: llm)
        
        // 2. 切分及反向提问等任务 (并发)
        let allEnrichedChunks = try await performConcurrentProcessing(content: enrichedContent, pageID: pageID, llm: llm)
        
        // 3. 向量索引阶段
        try await performEmbedding(chunks: allEnrichedChunks, pageID: pageID, embeddingProvider: embeddingProvider)
        
        return enrichedContent
    }

    // MARK: - Pipeline Steps

    /// Step 1: 语义增强 — 由 AIContentEnricher 对表格和图片进行深度语义丰富化。
    /// 若未配置 LLM 服务则直接返回原始内容，不走增强流程。
    private func performEnrichment(content: String, llm: (any LLMServiceProtocol)?) async throws -> String {
        guard let llm = llm else { return content }
        
        try Task.checkCancellation()
        await updateProgress(stage: .enrichment, progress: 0.15, log: L10n.Ingest.Status.aiEnriching)
        return await enricher.enrich(content, llm: llm)
    }

    /// Step 2: 并发处理 — 同时执行摘要生成、父子块切分、反向 Q&A 生成。
    /// 使用 withTaskGroup 实现结构化并发，各父块独立并行处理。
    private func performConcurrentProcessing(content: String, pageID: UUID, llm: (any LLMServiceProtocol)?) async throws -> [PageChunk] {
        try Task.checkCancellation()
        
        return await withTaskGroup(of: [PageChunk].self) { group in
            
            // 摘要任务
            if let llm = llm {
                group.addTask {
                    return await self.generateSummaryChunk(content: content, pageID: pageID, llm: llm)
                }
            }
            
            // 分块与 Q&A
            await self.updateProgress(stage: .chunking, progress: 0.40, log: L10n.Ingest.Status.chunking)
            
            let parentConfig = TextChunkerProcessor.Config(chunkSize: 1000, chunkOverlap: 200, separators: TextChunkerProcessor.default.separators)
            let parentChunks = self.chunker.split(text: content, config: parentConfig)
            
            for (pIndex, pChunk) in parentChunks.enumerated() {
                group.addTask {
                    do {
                        try Task.checkCancellation()
                        await TaskCenter.shared.addIngestSubLog(L10n.Ingest.Status.processingChunk)
                        return try await self.processParentChunk(pChunk, pIndex: pIndex, pageID: pageID, llm: llm)
                    } catch {
                        return []
                    }
                }
            }
            
            var finalChunks: [PageChunk] = []
            for await batch in group {
                finalChunks.append(contentsOf: batch)
            }
            return finalChunks
        }
    }

    /// 生成全局摘要块：取正文前 2000 字符发送给 LLM 生成概括性摘要。
    /// 摘要块类型标记为 "summary"，用于后续检索时区分常规块。
    private func generateSummaryChunk(content: String, pageID: UUID, llm: any LLMServiceProtocol) async -> [PageChunk] {
        do {
            try Task.checkCancellation()
            await TaskCenter.shared.addIngestSubLog(L10n.Ingest.Status.generatingSummary)
            let summaryPrompt = PromptRegistry.Ingest.summary(content: String(content.prefix(PromptConstants.IngestPipeline.summaryChunkCharLimit)))
            if let summary = try? await llm.generate(prompt: summaryPrompt, systemPrompt: L10n.AI.Prompt.ingestManagementAssistant) {
                try Task.checkCancellation()
                return [PageChunk(
                    id: "sum_\(pageID.uuidString)",
                    pageID: pageID,
                    parentID: nil,
                    chunkType: .summary,
                    content: summary,
                    index: 0,
                    startIndex: 0,
                    embedding: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )]
            }
        } catch {}
        return []
    }

    /// Step 3: 向量索引 — 将已产生的所有 PageChunk 批量送入 VectorIndexer 嵌入并持久化。
    private func performEmbedding(chunks: [PageChunk], pageID: UUID, embeddingProvider: any EmbeddingProvider) async throws {
        try Task.checkCancellation()
        await updateProgress(stage: .embedding, progress: 0.75, log: L10n.Ingest.Status.vectorizing)
        
        let indexer = VectorIndexer(embeddingProvider: embeddingProvider)
        await indexer.index(pageID: pageID, chunks: chunks)
        
        await updateProgress(stage: .embedding, progress: 1.0, log: L10n.Ingest.Status.completed)
    }

    // MARK: - Private Helpers

    /// 更新任务中心的进度条与子日志，保持 UI 流水线进度视图实时同步。
    private func updateProgress(stage: TaskStage, progress: Double, log: String) async {
        if let task = await TaskCenter.shared.tasks.first(where: { $0.type == .ingest }) {
            await TaskCenter.shared.updateTask(task.id, status: .running(progress: progress, stage: stage))
        }
        await TaskCenter.shared.addIngestSubLog(log)
    }

    /// 处理单个父分块，生成子分块与反向 Q&A 块
    private func processParentChunk(
        _ pChunk: TextChunkerProcessor.Chunk, 
        pIndex: Int, 
        pageID: UUID, 
        llm: (any LLMServiceProtocol)?
    ) async throws -> [PageChunk] {
        var chunkBatch: [PageChunk] = []
        let parentChunkID = "p_\(pageID.uuidString)_\(pIndex)"
        let childConfig = TextChunkerProcessor.Config(chunkSize: 300, chunkOverlap: 50, separators: TextChunkerProcessor.default.separators)

        // 1. 保存父块
        let parentRecord = PageChunk(
            id: parentChunkID,
            pageID: pageID,
            parentID: nil,
            chunkType: .regular,
            content: pChunk.text,
            anchorPath: pChunk.anchorPath,
            index: pIndex,
            startIndex: pChunk.startIndex,
            embedding: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        chunkBatch.append(parentRecord)

        // 2. 生成子块
        let children = self.chunker.split(text: pChunk.text, config: childConfig)
        for (cIndex, cChunk) in children.enumerated() {
            let childRecord = PageChunk(
                id: "\(parentChunkID)_c\(cIndex)",
                pageID: pageID,
                parentID: parentChunkID,
                chunkType: .child,
                content: cChunk.text,
                anchorPath: pChunk.anchorPath,
                index: cIndex,
                startIndex: cChunk.startIndex,
                embedding: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            chunkBatch.append(childRecord)
        }

        // 3. 反向提问 (Reverse Q&A)
        await appendReverseQA(to: &chunkBatch, parentChunkID: parentChunkID, pageID: pageID, pChunk: pChunk, llm: llm)

        return chunkBatch
    }

    /// 为父块生成反向 Q&A 子块，追加到 chunkBatch 中
    private func appendReverseQA(
        to chunkBatch: inout [PageChunk],
        parentChunkID: String,
        pageID: UUID,
        pChunk: TextChunkerProcessor.Chunk,
        llm: (any LLMServiceProtocol)?
    ) async {
        guard let llm = llm, !Task.isCancelled else { return }
        let qaPrompt = PromptRegistry.Ingest.reverseQA(content: pChunk.text)
        guard let qaResponse = try? await llm.generate(
            prompt: qaPrompt, systemPrompt: L10n.AI.Prompt.ingestDiscoveryAssistant
        ), !Task.isCancelled else { return }
        let questions = qaResponse.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        for (qIndex, question) in questions.prefix(PromptConstants.IngestPipeline.maxQAPairsPerChunk).enumerated() {
            chunkBatch.append(PageChunk(
                id: "qa_\(parentChunkID)_\(qIndex)",
                pageID: pageID,
                parentID: parentChunkID,
                chunkType: .qaPair,
                content: question,
                index: qIndex,
                startIndex: pChunk.startIndex,
                embedding: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
    }
}
