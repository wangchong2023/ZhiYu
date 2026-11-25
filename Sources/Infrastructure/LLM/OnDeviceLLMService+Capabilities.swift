//
//  OnDeviceLLMService+Capabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / 端侧推理能力扩展
//  核心职责：承载 OnDeviceLLMService 的端侧智能导入、离线 RAG 问答、生成取消/模型卸载、
//           标签提取与模型文件导入/清除能力，按单一职责与核心加载推理逻辑分离。
//

@preconcurrency import Foundation
import UFPCore
import ZhiYuAICore

extension OnDeviceLLMService {

    // MARK: - 端侧智能导入 (Smart Ingest)

    /// 借助本地大模型对原始碎片内容进行概念提取、标签归类与自动化格式对齐
    func smartIngestOnDevice(title: String, content: String, pages: [KnowledgePage]) async throws -> SmartIngestResult {
        let existingTitles = pages.map(\.title).prefix(LLMConstants.SmartIngest.existingTitlesCount).joined(separator: ", ")

        let prompt = """
        \(L10n.AI.OnDevice.Ingest.compileToKnowledge):\(existingTitles)

        \(L10n.AI.OnDevice.Ingest.titleLabel):\(title)
        \(L10n.AI.OnDevice.Ingest.contentLabel):\(content)

        \(L10n.AI.OnDevice.Ingest.retainLinks)
        """

        let generated = try await generate(prompt: prompt, maxTokens: Config.smartIngestMaxTokens)

        return SmartIngestResult(
            title: title,
            compiledContent: generated,
            suggestedTags: extractTags(from: generated),
            suggestedType: PageType.concept.rawValue,
            relatedTitles: [],
            summary: String(generated.prefix(LLMConstants.LogPreview.smartIngestSummaryLength))
        )
    }

    // MARK: - 端侧对话智能问答 (Chat On-Device)

    /// 在完全离线环境下，基于当前知识库关联内容提供 RAG 语义解答
    public func chatOnDevice(query: String, pages: [KnowledgePage]) async throws -> String {
        var context = "Chat_Context"

        // 提取与 query 相关性最强的知识库内容作为端侧 Context
        let relevant = Self.selectRelevantPages(query: query, from: pages, limit: Config.contextPageLimit)

        for page in relevant {
            context += "\n\n## \(page.title)\n\(String(page.content.prefix(Config.contentPreviewChars)))"
        }

        let prompt = "\(context)\n\n\(LLMConstants.PromptInstruction.questionLabel): \(query)"
        return try await generate(prompt: prompt, maxTokens: Config.chatMaxTokens)
    }

    /// 基于关键词重叠度对知识库页面进行评分排序，返回相关性最高的若干页
    /// 评分维度：标题命中 > 标签命中 > 内容片段命中
    private static func selectRelevantPages(query: String, from pages: [KnowledgePage], limit: Int) -> [KnowledgePage] {
        let queryTokens = Self.tokenize(query.lowercased())
        guard !queryTokens.isEmpty else {
            return Array(pages.prefix(limit))
        }

        let scored: [(page: KnowledgePage, score: Int)] = pages.map { page in
            let titleTokens = Set(Self.tokenize(page.title.lowercased()))
            let tagTokens = Set(page.tags.map { $0.lowercased() })
            let contentLower = page.content.lowercased()

            var score = 0
            // 标题命中权重最高
            for token in queryTokens where titleTokens.contains(token) {
                score += Config.titleHitWeight
            }
            // 标签命中权重中等
            for token in queryTokens where tagTokens.contains(token) {
                score += Config.tagHitWeight
            }
            // 内容片段命中权重最低（子串匹配，覆盖未分词的复合词）
            for token in queryTokens where contentLower.contains(token) {
                score += Config.contentHitWeight
            }
            return (page, score)
        }

        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.page }
    }

    /// 将文本按空白与标点切分为小写 token，过滤空串与单字符噪声
    private static func tokenize(_ text: String) -> [String] {
        text
            .unicodeScalars
            .map { scalar -> Character in
                if CharacterSet.alphanumerics.contains(scalar) {
                    return Character(scalar)
                }
                return " "
            }
            .reduce(into: "") { $0.append($1) }
            .split { $0.isWhitespace }
            .map { String($0).lowercased() }
            .filter { $0.count >= Config.minTokenLength }
    }

    // MARK: - 强行取消生成

    /// 取消当前正在进行的端侧推理生成（同时取消 CoreML Task 与 LiteRT-LM 原生生成流）
    public func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        if isLiteRTLoaded {
            let backend = liteRTBackend
            Task { await backend.cancelGeneration() }
        }
        isGenerating = false
        generatedText = ""
        generationProgress = 0
    }

    // MARK: - 卸载内存模型

    /// 卸载当前常驻模型并释放 CoreML / LiteRT-LM 原生权重与 GPU 缓冲区
    public func unloadModel() {
        currentModel = nil
        if isLiteRTLoaded {
            isLiteRTLoaded = false
            let backend = liteRTBackend
            Task { await backend.unloadModel() }
        }
        isModelLoaded = false
        loadedModelName = ""
        inferenceSpeed = 0
    }

    // MARK: - 标签自动分析器

    /// 从文本中提取 `#标签` 形式的标签
    /// - 注意：`\w` 在 NSRegularExpression 中是 Unicode aware，会匹配中文字母
    /// - 排除 URL 中的 `#fragment`（如 `https://example.com/page#section`）
    func extractTags(from text: String) -> [String] {
        // 先移除 URL（http/https 开头的非空白序列），避免误提取 `#fragment`
        let urlPattern = "https?://\\S+"
        let cleanedText: String
        if let urlRegex = try? NSRegularExpression(pattern: urlPattern) {
            let nsText = text as NSString
            cleanedText = urlRegex.stringByReplacingMatches(
                in: text,
                range: NSRange(location: 0, length: nsText.length),
                withTemplate: " "
            )
        } else {
            cleanedText = text
        }

        let pattern = "#(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsCleaned = cleanedText as NSString
        let matches = regex.matches(in: cleanedText, range: NSRange(location: 0, length: nsCleaned.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsCleaned.substring(with: match.range(at: 1))
        }
    }

    // MARK: - 动态模型导入

    /// 将用户在外部文件沙盒选中的 `.mlmodel` 或 `.mlmodelc` 模型无缝拷贝并挂接至内部存储器中
    public func importModel(from url: URL) async throws {
        let modelsDir = mlModelsDirectory
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let destURL = modelsDir.appendingPathComponent(url.lastPathComponent)

        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: url, to: destURL)
        } else {
            try FileManager.default.copyItem(at: url, to: destURL)
        }

        // 如果传入的是未编译的 mlmodel 源文件，自动启动端侧编译器
        if destURL.pathExtension == SystemConstants.FileExtension.mlmodel {
            let compiledURL = try await compiler.compileModel(at: destURL)
            try FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: compiledURL, to: destURL.deletingPathExtension().appendingPathExtension(SystemConstants.FileExtension.mlmodelC))
        }

        discoverModels()
    }

    // MARK: - 模型文件物理清除

    /// 删除Model
    /// - Parameter model: model
    public func deleteModel(_ model: OnDeviceModel) throws {
        if let url = model.url {
            try FileManager.default.removeItem(at: url)
        }
        if model.id == selectedModelID {
            unloadModel()
        }
        discoverModels()
    }
}
