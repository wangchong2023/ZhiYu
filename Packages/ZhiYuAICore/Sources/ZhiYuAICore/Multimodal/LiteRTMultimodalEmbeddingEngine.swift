//
//  LiteRTMultimodalEmbeddingEngine.swift
//  ZhiYuAICore
//
//  系统层级：[ZhiYuAICore] 基础设施层 / 多模态真实向量引擎
//  核心职责：封装 Google LiteRT-LM EmbeddingEngine，加载 EmbeddingGemma-2-740M (.litertlm)
//           执行真实跨模态图文向量推理；未加载模型时优雅降级至 MultimodalEmbeddingEngine。
//

import CoreGraphics
import Foundation
#if canImport(LiteRTLM)
import LiteRTLM
#endif

/// 基于 Google LiteRT-LM 的真实多模态跨模态向量引擎（对齐 EmbeddingGemma-2-740M）
public actor LiteRTMultimodalEmbeddingEngine: MultimodalEmbeddingProtocol {
    public nonisolated let dimension: Int
    private let fallbackEngine: MultimodalEmbeddingProtocol
    #if canImport(LiteRTLM)
    private var embeddingEngine: EmbeddingEngine?
    #endif
    private var loadedModelURL: URL?

    public init(
        dimension: Int = MultimodalEmbeddingEngine.Constants.defaultDimension,
        fallbackEngine: MultimodalEmbeddingProtocol = MultimodalEmbeddingEngine.shared
    ) {
        self.dimension = dimension
        self.fallbackEngine = fallbackEngine
    }

    /// 当前是否已加载真实 LiteRT-LM 向量模型
    public var isNativeModelLoaded: Bool {
        loadedModelURL != nil
    }

    /// 加载本地 EmbeddingGemma-2 `.litertlm` 权重
    public func loadModel(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LiteRTBackendError.missingModelFile(url.path)
        }
        #if canImport(LiteRTLM)
        await unloadModel()
        let config = EmbeddingEngineConfig(
            modelPath: url.path,
            backend: .gpu,
            visionBackend: .gpu,
            cacheDir: FileManager.default.temporaryDirectory.path
        )
        let newEngine = EmbeddingEngine(config: config)
        try await newEngine.initialize()
        self.embeddingEngine = newEngine
        self.loadedModelURL = url
        #else
        throw LiteRTBackendError.runtimeUnavailable
        #endif
    }

    /// 卸载原生向量引擎释放显存
    public func unloadModel() async {
        #if canImport(LiteRTLM)
        embeddingEngine = nil
        #endif
        loadedModelURL = nil
    }

    public func embedText(_ text: String) async throws -> [Float] {
        #if canImport(LiteRTLM)
        if let embeddingEngine {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return [Float](repeating: 0.0, count: dimension)
            }
            let response = try await embeddingEngine.computeEmbedding(
                contents: [.text(trimmed)],
                options: EmbeddingOptions(normalize: true)
            )
            if !response.embedding.isEmpty {
                return response.embedding
            }
        }
        #endif
        return try await fallbackEngine.embedText(text)
    }

    public func embedImage(_ image: CGImage) async throws -> [Float] {
        #if canImport(LiteRTLM)
        if let embeddingEngine,
           let jpegData = MediaSearchIndexer.extractThumbnailData(from: image) {
            let response = try await embeddingEngine.computeEmbedding(
                contents: [.imageData(jpegData)],
                options: EmbeddingOptions(normalize: true)
            )
            if !response.embedding.isEmpty {
                return response.embedding
            }
        }
        #endif
        return try await fallbackEngine.embedImage(image)
    }

    public nonisolated func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        fallbackEngine.cosineSimilarity(a, b)
    }
}
