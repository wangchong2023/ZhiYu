//
//  LocalInferenceBackendProtocol.swift
//  ZhiYuAICore
//
//  系统层级：[L1] 基础设施层 / 端侧推理协议抽象
//  核心职责：定义统一的端侧大模型推理后端契约（对齐 LiteRT-LM / Apple FoundationModels），
//           支持硬件加速器选择、思考模式 (Thinking Mode) 流式分离输出与多模态输入。
//

import Foundation

/// 端侧硬件加速后端选项（对齐 Google AI Edge Gallery CPU / GPU / NPU 选择）
public enum LocalInferenceAccelerator: String, Codable, CaseIterable, Sendable {
    case auto = "AUTO"
    case cpu = "CPU"
    case gpu = "GPU"
    case npu = "NPU"
}

/// 端侧单次推理采样与运行时配置
public struct LocalInferenceOptions: Sendable, Equatable {
    public enum Defaults {
        public static let temperature: Double = 0.7
        public static let topP: Double = 0.9
        public static let topK: Int = 40
        public static let maxTokens: Int = 1024
    }

    public var temperature: Double
    public var topP: Double
    public var topK: Int
    public var maxTokens: Int
    public var enableThinking: Bool
    public var accelerator: LocalInferenceAccelerator

    public init(
        temperature: Double = Defaults.temperature,
        topP: Double = Defaults.topP,
        topK: Int = Defaults.topK,
        maxTokens: Int = Defaults.maxTokens,
        enableThinking: Bool = false,
        accelerator: LocalInferenceAccelerator = .auto
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
        self.enableThinking = enableThinking
        self.accelerator = accelerator
    }
}

/// 端侧流式推理产出片段（支持思考链与最终回答分离渲染）
public enum LocalInferenceChunk: Sendable, Equatable {
    /// Thinking Mode 推理过程片段（`<thought>`）
    case thought(String)
    /// 最终回答正文片段
    case text(String)
    /// 推理完成及真实硬件性能指标
    case completed(ttftMilliseconds: Double, decodeTokensPerSecond: Double)
}

/// 统一端侧大模型推理后端协议
/// 由具体开源运行时实现（如 LiteRT-LM 适配器、Apple FoundationModels 适配器）
public protocol LocalInferenceBackendProtocol: Sendable {
    /// 后端标识符（如 "litert-lm"、"apple-foundation-models"）
    var backendIdentifier: String { get }

    /// 加载指定本地权重文件至指定加速器
    func loadModel(at url: URL?, accelerator: LocalInferenceAccelerator) async throws

    /// 卸载当前已加载权重以释放统一内存
    func unloadModel() async

    /// 执行流式推理（支持可选图像与音频二进制数据多模态输入）
    func generateStream(
        prompt: String,
        imageData: [Data],
        audioData: Data?,
        options: LocalInferenceOptions
    ) -> AsyncThrowingStream<LocalInferenceChunk, Error>

    /// 立即中止当前推理生成
    func cancelGeneration() async
}
