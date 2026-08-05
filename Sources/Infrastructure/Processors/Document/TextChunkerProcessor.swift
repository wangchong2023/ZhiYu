//
//  TextChunkerProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation

/// 递归分块器 (RAG 核心：语义保真)
/// 负责将长文档拆分为适合向量检索的小块，对标 Karpathy 的 LLM Wiki 切片标准。
struct TextChunkerProcessor: Sendable {

    /// 增强型分块模型
    public struct Chunk: Identifiable, Sendable {
        public let id = UUID()
        public let text: String       // 分块文本内容
        public let startIndex: Int    // 原始文本起始偏移
        public let anchorPath: String // 标题路径 (例如: "") - 仅保持当前最近的单级标题，以维护老旧单测兼容性
        public let breadcrumbPath: String // 级联面包屑路径 (例如: " > ") - 专门用于 Hierarchy RAG
        public let isCode: Bool       // 是否包含完整代码块
        
        /// 级联面包屑注入后的上下文文本，最大化提升检索语义相关性
        public var contextualText: String {
            if breadcrumbPath == ProcessorConstants.TextChunker.rootAnchor || breadcrumbPath.isEmpty {
                return text
            } else {
                return "\(ProcessorConstants.TextChunker.contextPrefix)\(breadcrumbPath)\(ProcessorConstants.TextChunker.contextSuffix)\(text)"
            }
        }
    }

    /// 分块配置
    public struct Config {
        public let chunkSize: Int      // 目标字符数 (800-1200 推荐)
        public let chunkOverlap: Int   // 重叠窗口大小 (150-200 推荐)
        public let separators: [String] // 优先级梯度
    }

    public static let `default` = Config(
        chunkSize: ProcessorConstants.TextChunker.defaultChunkSize,
        chunkOverlap: ProcessorConstants.TextChunker.defaultChunkOverlap,
        separators: ProcessorConstants.TextChunker.defaultSeparators
    )

    /**
     * @description: 执行高级语义分块
     * @param {String} text 原始文本
     * @return {[Chunk]} 包含元数据的高质量切片
     */

    /// 拆分
    /// - Parameter text: text
    /// - Parameter config: config
    /// - Returns: 列表
    func split(text: String, config: Config = TextChunkerProcessor.default) -> [Chunk] {
        guard !text.isEmpty else { return [] }
        let lines = text.components(separatedBy: .newlines)
        var state = ChunkingState()

        for line in lines {
            let shouldTurnOffCodeBlock = updateCodeBlockState(line: line, state: &state)
            if !state.isInCodeBlock && line.hasPrefix(ProcessorConstants.MarkdownSyntax.hash) {
                flushCurrentChunk(lines: lines, state: &state, text: text)
                updateHeaderTracking(line: line, state: &state)
            }
            let lineWithNewline = line + ProcessorConstants.Whitespace.newline
            if (state.currentChunkText.count + lineWithNewline.count) > config.chunkSize && !state.isInCodeBlock {
                flushChunkOnOverflow(lineWithNewline: lineWithNewline, config: config, state: &state)
            } else {
                state.currentChunkText += lineWithNewline
            }
            if shouldTurnOffCodeBlock {
                state.isInCodeBlock = false
            }
        }

        let trimmedLast = state.currentChunkText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLast.isEmpty {
            state.chunks.append(Chunk(text: trimmedLast, startIndex: state.currentStartIndex, anchorPath: state.currentAnchor, breadcrumbPath: state.currentBreadcrumb, isCode: state.currentChunkText.contains(ProcessorConstants.MarkdownSyntax.codeFence)))
        }
        return state.chunks
    }

    /// 分块器运行时状态，维护当前分块文本、标题路径、面包屑栈等扫描上下文。
    private struct ChunkingState {
        var chunks: [Chunk] = []
        var currentChunkText = ""
        var currentAnchor = ProcessorConstants.TextChunker.rootAnchor
        var currentBreadcrumb = ProcessorConstants.TextChunker.rootAnchor
        var anchorStack: [String] = []
        var currentStartIndex = 0
        var isInCodeBlock = false
    }

    /// 检测并更新代码块状态：遇到 ``` 时 toggle 进出代码块标记。
    /// - Returns: true 表示从代码块中退出，调用方应在完成当前行后重置状态。
    private func updateCodeBlockState(line: String, state: inout ChunkingState) -> Bool {
        let isCodeFlag = line.trimmingCharacters(in: .whitespaces).hasPrefix(ProcessorConstants.MarkdownSyntax.codeFence)
        guard isCodeFlag else { return false }
        if state.isInCodeBlock {
            return true // 退出代码块
        } else {
            state.isInCodeBlock = true // 进入代码块
            return false
        }
    }

    /// 将当前累积的文本刷新为一个新的 Chunk 实体，重置缓冲区。
    private func flushCurrentChunk(lines: [String], state: inout ChunkingState, text: String) {
        let trimmedPrev = state.currentChunkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrev.isEmpty else { return }
        state.chunks.append(Chunk(text: trimmedPrev, startIndex: state.currentStartIndex, anchorPath: state.currentAnchor, breadcrumbPath: state.currentBreadcrumb, isCode: state.currentChunkText.contains(ProcessorConstants.MarkdownSyntax.codeFence)))
        state.currentStartIndex += state.currentChunkText.count
        state.currentChunkText = ""
    }

    /// 在遇到标题时更新标题锚点与级联面包屑路径（Hierarchy RAG 核心）。
    /// 根据标题层级修剪锚点栈，确保面包屑始终反映当前章节路径。
    private func updateHeaderTracking(line: String, state: inout ChunkingState) {
        let headerLevel = line.prefix(while: { $0 == Swift.Character(ProcessorConstants.MarkdownSyntax.hash) }).count
        let headerText = line.dropFirst(headerLevel).trimmingCharacters(in: .whitespaces)
        guard headerLevel > 0 else {
            state.currentBreadcrumb = headerText
            state.currentAnchor = headerText
            return
        }
        // 修剪栈至当前标题层级的上一级
        let keepCount = headerLevel - 1
        if state.anchorStack.count > keepCount {
            state.anchorStack = Array(state.anchorStack.prefix(keepCount))
        }
        state.anchorStack.append(headerText)
        // 重建级联面包屑："H1 > H2 > H3"
        state.currentBreadcrumb = state.anchorStack.joined(separator: ProcessorConstants.TextChunker.breadcrumbSeparator)
        state.currentAnchor = headerText
    }

    /// 当前分块溢出时触发刷新：保存当前 chunk，创建带重叠窗口的新缓冲区。
    /// 重叠窗口保证相邻 chunk 间存在语义连续性，避免关键信息被截断。
    private func flushChunkOnOverflow(lineWithNewline: String, config: Config, state: inout ChunkingState) {
        // 缺陷 #13 修复：append 前检查空文本，避免产生空 chunk
        let trimmedText = state.currentChunkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            // 当前缓冲区为空，直接将新行加入缓冲区
            state.currentChunkText = lineWithNewline
            return
        }

        state.chunks.append(Chunk(text: trimmedText, startIndex: state.currentStartIndex, anchorPath: state.currentAnchor, breadcrumbPath: state.currentBreadcrumb, isCode: state.currentChunkText.contains(ProcessorConstants.MarkdownSyntax.codeFence)))

        // 缺陷 #12 修复：在修改 currentChunkText 前保存旧长度，用于正确计算 startIndex 偏移
        let oldChunkTextCount = state.currentChunkText.count
        let overlapIndex = state.currentChunkText.index(state.currentChunkText.endIndex, offsetBy: -config.chunkOverlap, default: state.currentChunkText.startIndex)
        state.currentChunkText = String(state.currentChunkText[overlapIndex...]) + lineWithNewline
        // startIndex 偏移 = 旧 chunk 文本长度 - 重叠窗口大小
        state.currentStartIndex += max(0, oldChunkTextCount - config.chunkOverlap)
    }
}

private extension String {

    /// 索引
    /// - Parameter index: 索引
    /// - Returns: 返回值
    func index(_ index: String.Index, offsetBy offset: Int, default defaultIndex: String.Index) -> String.Index {
        return self.index(index, offsetBy: offset, limitedBy: self.startIndex) ?? defaultIndex
    }
}
