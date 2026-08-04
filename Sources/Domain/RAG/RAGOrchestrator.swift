//
//  RAGOrchestrator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：RAG 检索增强生成管道：语义搜索、链接发现、内容增强、评估。
//
import Foundation
import UFPCore
import Observation

/// RAG 业务编排器 (L1.5-Domain)
/// 负责将“检索”与“生成”逻辑串联，实现高阶 AI 业务。
@MainActor
public final class RAGOrchestrator {
    
    @ObservationIgnored @Inject private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Inject private var analytics: AIAnalyticsService
    @ObservationIgnored @Inject private var perf: PerformanceService
    
    private let contextBuilder = LLMContextBuilder()
    
    public init() {}

    /// 执行增强对话 (RAG Chat)
    public func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        return try await perf.measureAsync("ragChain") {
            // 1. 任务注册
            let taskID = TaskCenter.shared.addTask(type: .ai, name: "AI Chat", target: query)
            
            // 2. 构建 RAG 上下文
            TaskCenter.shared.updateTask(taskID, status: .running(progress: 0.2, stage: .embedding))
            let (context, sources) = await contextBuilder.buildRelevantContext(query: query)
            SourceStore.shared.updateSources(sources)
            
            // 3. 语义重排
            TaskCenter.shared.updateTask(taskID, status: .running(progress: 0.5, stage: .retrieval))
            let rankedPages = (try? await llmService.rerank(query: query, candidates: pages)) ?? pages
            let systemPrompt = contextBuilder.buildSystemPrompt(pages: rankedPages) + "\n\n" + context
 
            // 4. 调用生成 (Synthesis)
            TaskCenter.shared.updateTask(taskID, status: .running(progress: 0.8, stage: .synthesis))
            let startTime = Date()
            
            // 注意：此处直接调用底层 LLMService 的 generate 接口或 chat 接口（剥离了 RAG 逻辑后的版本）
            let response = try await llmService.generate(prompt: query, systemPrompt: systemPrompt)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
 
            // 5. 异步指标记录（传入检索源以触发检索质量标注）
            let capturedSources = SourceStore.shared.activeSources
            analytics.recordRAGMetrics(query: query, response: response, context: context, sources: capturedSources, systemPrompt: systemPrompt, modelName: AppConfig.AI.defaultModel, latency: latency)
            
            TaskCenter.shared.completeTask(id: taskID)
            return ChatMessageDTO(role: .assistant, content: response)
        }
    }
 
    /// 执行流式增强对话（RAG Chat Stream），通过 AsyncThrowingStream 逐 chunk 返回生成内容。
    /// 流程：任务注册 → 上下文构建 → 语义重排 → 流式生成 → 指标记录 → 任务完成。
    public func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                // Step 1: 任务注册
                let taskID = TaskCenter.shared.addTask(type: .ai, name: "AI Chat Stream", target: query)
                
                do {
                    // Step 2: 构建 RAG 上下文（上下文检索 + 语义重排）
                    let (context, _) = await contextBuilder.buildRelevantContext(query: query)
                    let rankedPages = (try? await llmService.rerank(query: query, candidates: pages)) ?? pages
                    let systemPrompt = contextBuilder.buildSystemPrompt(pages: rankedPages) + "\n\n" + context
 
                    // Step 3: 流式生成，逐 chunk 产出; 下层已解耦出 LLM 流式输出
                    var fullResponse = ""
                    for try await chunk in llmService.chatStream(query: query, history: history, pages: rankedPages) {
                        fullResponse += chunk
                        continuation.yield(chunk)
                    }
 
                    // Step 4: 异步指标记录（含检索源，触发检索质量标注）
                    let capturedSources = SourceStore.shared.activeSources
                    analytics.recordRAGMetrics(query: query, response: fullResponse, context: context, sources: capturedSources, systemPrompt: systemPrompt, modelName: AppConfig.AI.defaultModel, latency: 0)
                    TaskCenter.shared.completeTask(id: taskID)
                    continuation.finish()
                } catch {
                    // Step 5: 异常路径 — 标记任务失败并向上游抛出错误
                    TaskCenter.shared.failTask(id: taskID, error: error.localizedDescription)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
