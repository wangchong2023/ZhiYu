//
//  LLMMockResponder.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：UI 自动化测试模式下的 Mock 响应统一生成器，消除 ChatRunner/ChatLLMService 间的 Mock 分支重复。
//

import Foundation

/// UI 自动化测试 Mock 响应生成器
/// 集中管理 `--uitesting` 自愈分支的非流式、RAG 与流式 Mock 响应构造。
enum LLMMockResponder {
    /// 判断当前是否处于 UI 自动化测试模式
    static var isUITesting: Bool { // test_coupling_exempt: 委托 TestModeDetector，消除 launch argument 散布
        TestModeDetector.isUITesting
    }

    /// 生成非流式 Mock 延迟与回复
    /// - Returns: Mock 回复字符串（调用方需先 `try? await Task.sleep`）
    static func mockNonStreamReply() async throws -> String {
        try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockNonStreamDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))
        return LLMConstants.UITesting.mockNonStreamReply
    }

    /// 生成 Mock RAG 回复消息
    /// - Parameter pages: 关联的知识页面（用于填充 relatedPageIDs）
    /// - Returns: Mock 的 assistant ChatMessageDTO
    static func mockRAGReply(pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockNonStreamDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))
        return ChatMessageDTO(
            id: UUID(),
            role: .assistant,
            content: LLMConstants.UITesting.mockRAGReply,
            timestamp: Date(),
            relatedPageIDs: pages.map { $0.id }
        )
    }

    /// 生成 Mock 流式打字机回复流
    /// - Returns: 模拟流式吐字的 AsyncThrowingStream
    static func mockStream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // 模拟在发送大语言模型请求之前的 RAG 检索/思考状态，以留出时间给 UI 测试捕获骨架屏
                try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockStreamInitialDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))

                let mockChunks = LLMConstants.UITesting.mockStreamChunks
                for chunk in mockChunks {
                    if Task.isCancelled {
                        break
                    }
                    continuation.yield(chunk)
                    // 模拟字间吐字延迟
                    try? await Task.sleep(nanoseconds: UInt64(LLMConstants.UITesting.mockStreamChunkDelaySeconds * LLMConstants.UITesting.nanosecondsPerSecond))
                }
                continuation.finish()
            }
        }
    }
}
