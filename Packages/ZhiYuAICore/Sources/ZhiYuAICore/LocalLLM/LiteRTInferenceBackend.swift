//
//  LiteRTInferenceBackend.swift
//  ZhiYuAICore
//
//  系统层级：[L1] 基础设施层 / Google LiteRT-LM 端侧推理适配器
//  核心职责：封装 Google 官方开源 LiteRT-LM (v0.20.0) Swift 运行时，实现 LocalInferenceBackendProtocol，
//           支持 .litertlm/.task 多模态（文本+图像+音频）、Metal GPU/CPU 加速、原生 Thinking Mode 与流式取消。
//

import Foundation
#if canImport(LiteRTLM)
import LiteRTLM
#endif

/// LiteRT-LM 端侧推理适配器错误
public enum LiteRTBackendError: LocalizedError, Equatable, Sendable {
    case runtimeUnavailable
    case missingModelFile(String)
    case modelNotLoaded
    case emptyPrompt

    public var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "LiteRT-LM runtime is unavailable on this platform."
        case .missingModelFile(let path):
            return "LiteRT-LM model file not found: \(path)"
        case .modelNotLoaded:
            return "LiteRT-LM engine is not loaded."
        case .emptyPrompt:
            return "Prompt must not be empty."
        }
    }
}

/// Google LiteRT-LM 端侧推理后端实现（隔离在 ZhiYuAICore 物理包内）
public actor LiteRTInferenceBackend: LocalInferenceBackendProtocol {
    public enum Config {
        public static let backendId = "litert-lm"
        public static let thoughtChannelKey = "thought"
        public static let nanosecondsPerMillisecond: Double = 1_000_000.0
        public static let nanosecondsPerSecond: Double = 1_000_000_000.0
        public static let minElapsedSeconds: Double = 0.001
        public static let estimatedCharsPerToken: Int = 4
    }

    public nonisolated let backendIdentifier: String = Config.backendId

    #if canImport(LiteRTLM)
    private var engine: Engine?
    private var activeConversation: Conversation?
    #endif
    private var loadedModelURL: URL?

    public init() {}

    /// 校验当前平台是否已链接真实 LiteRT-LM 二进制运行时
    public static var isRuntimeLinked: Bool {
        #if canImport(LiteRTLM)
        return true
        #else
        return false
        #endif
    }

    public func loadModel(at url: URL?, accelerator: LocalInferenceAccelerator) async throws {
        guard let url else {
            throw LiteRTBackendError.missingModelFile("")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LiteRTBackendError.missingModelFile(url.path)
        }

        #if canImport(LiteRTLM)
        await unloadModel()
        let selectedBackend = Self.mapBackend(for: accelerator)
        let cacheDirectory = FileManager.default.temporaryDirectory.path
        let engineConfig = try EngineConfig(
            modelPath: url.path,
            backend: selectedBackend,
            visionBackend: selectedBackend,
            audioBackend: .cpu(),
            cacheDir: cacheDirectory
        )
        let newEngine = Engine(engineConfig: engineConfig)
        try await newEngine.initialize()
        self.engine = newEngine
        self.loadedModelURL = url
        #else
        throw LiteRTBackendError.runtimeUnavailable
        #endif
    }

    public func unloadModel() async {
        #if canImport(LiteRTLM)
        try? activeConversation?.cancel()
        activeConversation = nil
        engine = nil
        #endif
        loadedModelURL = nil
    }

    public nonisolated func generateStream(
        prompt: String,
        imageData: [Data],
        audioData: Data?,
        options: LocalInferenceOptions
    ) -> AsyncThrowingStream<LocalInferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.executeStream(
                        prompt: prompt,
                        imageData: imageData,
                        audioData: audioData,
                        options: options,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.cancelGeneration() }
            }
        }
    }

    public func cancelGeneration() async {
        #if canImport(LiteRTLM)
        try? activeConversation?.cancel()
        #endif
    }

    // MARK: - 内部推理调度

    private func executeStream(
        prompt: String,
        imageData: [Data],
        audioData: Data?,
        options: LocalInferenceOptions,
        continuation: AsyncThrowingStream<LocalInferenceChunk, Error>.Continuation
    ) async throws {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw LiteRTBackendError.emptyPrompt
        }

        #if canImport(LiteRTLM)
        guard let engine else {
            throw LiteRTBackendError.modelNotLoaded
        }

        let sampler = try SamplerConfig(
            topK: options.topK,
            topP: Float(options.topP),
            temperature: Float(options.temperature)
        )
        let conversationConfig = ConversationConfig(samplerConfig: sampler)
        let conversation = try await engine.createConversation(with: conversationConfig)
        self.activeConversation = conversation

        var contents: [Content] = []
        for img in imageData where !img.isEmpty {
            contents.append(.imageData(img))
        }
        if let audio = audioData, !audio.isEmpty {
            contents.append(.audioData(audio))
        }
        contents.append(.text(trimmedPrompt))
        let message = Message(contents: contents)
        let thinking = ThinkingConfig(enableThinking: options.enableThinking)

        let startNano = DispatchTime.now().uptimeNanoseconds
        var firstTokenNano: UInt64?
        var generatedChars = 0

        for try await chunk in conversation.sendMessageStream(
            message,
            maxOutputTokens: options.maxTokens,
            thinkingConfig: thinking
        ) {
            if Task.isCancelled { break }
            if let thought = chunk.channels[Config.thoughtChannelKey], !thought.isEmpty {
                if firstTokenNano == nil {
                    firstTokenNano = DispatchTime.now().uptimeNanoseconds
                }
                generatedChars += thought.count
                continuation.yield(.thought(thought))
            }
            let text = chunk.toString
            if !text.isEmpty {
                if firstTokenNano == nil {
                    firstTokenNano = DispatchTime.now().uptimeNanoseconds
                }
                generatedChars += text.count
                continuation.yield(.text(text))
            }
        }

        let endNano = DispatchTime.now().uptimeNanoseconds
        let ttftMs = Double((firstTokenNano ?? endNano) - startNano) / Config.nanosecondsPerMillisecond
        let elapsedSeconds = max(Double(endNano - startNano) / Config.nanosecondsPerSecond, Config.minElapsedSeconds)
        let estimatedTokens = max(generatedChars / Config.estimatedCharsPerToken, 1)
        let decodeTPS = Double(estimatedTokens) / elapsedSeconds

        continuation.yield(.completed(ttftMilliseconds: ttftMs, decodeTokensPerSecond: decodeTPS))
        continuation.finish()
        #else
        throw LiteRTBackendError.runtimeUnavailable
        #endif
    }

    #if canImport(LiteRTLM)
    internal static func mapBackend(for accelerator: LocalInferenceAccelerator) -> Backend {
        switch accelerator {
        case .cpu:
            return .cpu()
        case .gpu, .npu, .auto:
            return .gpu
        }
    }
    #endif
}
