//
//  OnDeviceLLMService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 OnDeviceLLM 模块的核心业务逻辑服务。
//
@preconcurrency import Foundation
@preconcurrency import CoreML
#if canImport(FoundationModels)
import FoundationModels
#endif
import Combine
import UFPCore
import ZhiYuAICore
import Dependencies

// MARK: - On-Device LLM Service
/// 智宇端侧本地大模型推理服务中枢
/// 负责扫描并加载 Bundle 内置、Documents 目录下载的 `.mlmodelc` 格式大语言模型，并结合 Neural Engine (端侧神经网络引擎) 进行高速文本合成及评估。
@MainActor
public final class OnDeviceLLMService: OnDeviceLLMServiceProtocol {
    /// 全局单例持有者
    public static let shared = OnDeviceLLMService()

    /// 指示本地 Core ML 推理是否在当前硬件与 iOS 版本上可用（要求 iOS 17.0+）
    @Published public var isAvailable: Bool = false
    
    /// 指示当前大模型是否已完全成功载入内存
    @Published public var isModelLoaded: Bool = false

    /// 端侧硬件加速偏好（AUTO / CPU / GPU / NPU）
    public var preferredAccelerator: LocalInferenceAccelerator = .auto

    /// Google LiteRT-LM 开源端侧推理后端实例（支持 .litertlm / .task 真实多模态推理，可注入替身用于测试）
    let liteRTBackend: any LocalInferenceBackendProtocol
    var isLiteRTLoaded: Bool = false
    
    /// 指示模型当前是否正处于推理生成（Inference）阻塞状态
    @Published public var isGenerating: Bool = false
    
    /// 当前已载入内存的模型友好名称
    @Published public var loadedModelName: String = ""
    
    /// 全局扫描发现的可用本地/系统模型列表
    @Published public var availableModels: [OnDeviceModel] = []
    
    /// 当前偏好选中的本地模型 ID
    @Published public var selectedModelID: String = ""
    
    /// 文本生成过程的估计进度百分比 (0.0 ~ 1.0)
    @Published public var generationProgress: Double = 0
    
    /// 已生成文本的实时累积结果
    @Published public var generatedText: String = ""
    
    /// 当前推理生成速率（单位：tokens/秒）
    @Published public var inferenceSpeed: Double = 0
    
    /// 常驻的 Core ML 预测模型实例
    var currentModel: AnyObject?

    /// 当前推理任务引用（用于取消）
    var generationTask: Task<String?, Error>?
    
    /// 本地选型偏好持久化 Key
    private let configKey = LLMConstants.OnDeviceStorage.configKey
    
    /// 注入的模型编译器，用于处理平台差异化编译与沙盒物理转换
    @ObservationIgnored @Dependency(\.modelCompiler) var compiler: any MLModelCompilerProtocol

    /// 键值存储抽象（DI 注入，替代 UserDefaults.standard 直接访问）
    @ObservationIgnored @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?

    /// 用户沙盒 Documents/MLModels 目录 URL，回退至临时目录
    var mlModelsDirectory: URL {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docsDir.appendingPathComponent("MLModels")
    }

    // MARK: - 常量参数定义
    nonisolated public enum Config {
        public static let defaultMaxTokens: Int = 256
        public static let generationTemperature: Double = 0.7
        public static let smartIngestMaxTokens: Int = 500
        public static let chatMaxTokens: Int = 300
        public static let liteRTExtension: String = "litertlm"
        public static let taskExtension: String = "task"
        public static let thoughtOpenTag: String = "<thought>"
        public static let thoughtCloseTag: String = "</thought>\n"
        public static let contextPageLimit: Int = 5
        public static let contentPreviewChars: Int = 200
        public static let titleHitWeight: Int = 3
        public static let tagHitWeight: Int = 2
        public static let contentHitWeight: Int = 1
        public static let minTokenLength: Int = 2
        public static let minElapsedSeconds: TimeInterval = 0.001
    }

    // MARK: - 初始化
    /// 仅做轻量字段初始化，不做重活。
    /// 原因：`static let shared` 为 `@MainActor` 惰性单例，由 `dispatch_once` 触发；
    /// 若在 init 内同步执行 `@MainActor` 隔离重活（discoverModels：文件遍历 + @Dependency 访问 +
    /// contains 闭包执行器检查），在 AppEnvironment 初始化链路的嵌套 MainActor 单例初始化中
    /// 会触发 Swift 6 执行器自死锁（isMainExecutor 循环等待）。
    /// 模型发现改为由设置页等使用方显式调用（见 OnDeviceLLMSettingsView），避免启动路径卡死。
    public init(liteRTBackend: any LocalInferenceBackendProtocol = LiteRTInferenceBackend()) {
        self.liteRTBackend = liteRTBackend
        checkAvailability()
    }

    // MARK: - 可用性物理检测
    /// 物理检测当前操作系统与硬件是否符合端侧大模型加载规范。要求 iOS 17.0+ 及以上。
    private func checkAvailability() {
        if #available(iOS 17.0, *) {
            isAvailable = true
        } else {
            isAvailable = false
        }
    }

    // MARK: - 模型发现与动态加载
    /// 扫描内置 Bundle 资源及应用沙盒 Documents/MLModels 文件夹中的所有可用本地模型。
    public func discoverModels() {
        var models: [OnDeviceModel] = []

        // 1. 扫描 App Bundle 中内置的专属 AppLLM.mlmodelc 模型
        if let modelURL = Bundle.main.url(forResource: LLMConstants.BundleResource.appLLM, withExtension: SystemConstants.FileExtension.mlmodelC) {
            models.append(OnDeviceModel(
                id: LLMConstants.OnDeviceModelID.bundledZhiyu,
                name: LLMConstants.OnDeviceModel.bundledName,
                url: modelURL,
                size: estimateModelSize(url: modelURL),
                type: .bundled
            ))
        }

        // 2. 扫描沙盒 Documents 目录中用户自主下载或导入的模型目录
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? mlModelsDirectory

        if let enumerator = FileManager.default.enumerator(at: docDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ext == Config.liteRTExtension
                    || ext == Config.taskExtension
                    || ext == SystemConstants.FileExtension.bin
                    || ext == SystemConstants.FileExtension.gguf
                    || ext == SystemConstants.FileExtension.mlmodelC {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    let modelId = "\(LLMConstants.ModelIDPrefix.downloaded)\(name)"
                    if !models.contains(where: { $0.id == modelId }) {
                        models.append(OnDeviceModel(
                            id: modelId,
                            name: name,
                            url: fileURL,
                            size: estimateModelSize(url: fileURL),
                            type: .downloaded
                        ))
                    }
                }
            }
        }

        // 3. 针对 iOS 18.1+ 设备，自动追加系统级 Apple Intelligence 支持标签
        if #available(iOS 18.1, *) {
            models.append(OnDeviceModel(
                id: LLMConstants.OnDeviceModelID.appleIntelligence,
                name: LLMConstants.OnDeviceModel.appleIntelligenceName,
                url: nil,
                size: 0,
                type: .system
            ))
        }

        self.availableModels = models

        // 自动还原用户上一次选定的模型偏好
        let savedID = keyStore?.string(forKey: configKey)
        if let saved = savedID, models.contains(where: { $0.id == saved }) {
            selectedModelID = saved
        } else if let first = models.first {
            selectedModelID = first.id
        }
    }

    /// 估算模型文件或模型目录的总物理大小（兼容单文件 `.litertlm`/`.task`/`.gguf` 与目录型 `.mlmodelc`）
    private func estimateModelSize(url: URL) -> Int64 {
        let fm = FileManager.default
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
           values.isDirectory != true,
           let size = values.fileSize {
            return Int64(size)
        }
        var totalSize: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }

    // MARK: - 加载模型
    /// 异步载入选定的本地大模型到 CPU/GPU/Neural Engine 协处理器空间
    public func loadModel() async throws {
        guard let model = availableModels.first(where: { $0.id == selectedModelID }) else {
            throw OnDeviceError.modelNotFound
        }

        isGenerating = true
        generationProgress = 0
        defer { isGenerating = false }

        switch model.type {
        case .system:
            // 针对 iOS 18.2+ 硬件加载 Foundation Models 框架
            if #available(iOS 18.2, *) {
                // 此处挂接 Apple 系统级大模型客户端
                isModelLoaded = true
                loadedModelName = model.name
            } else {
                throw OnDeviceError.notSupported
            }

        case .bundled, .downloaded:
            guard let url = model.url else {
                throw OnDeviceError.modelNotFound
            }

            // 执行模型编译或格式适配，若已是编译后的 mlmodelc 则直接读取
            let compiledURL: URL
            let ext = url.pathExtension.lowercased()
            if ext == SystemConstants.FileExtension.mlmodelC {
                compiledURL = url
            } else if ext == Config.liteRTExtension || ext == Config.taskExtension {
                // Google LiteRT-LM 原生 .litertlm / .task 权重：真实加载 C++/Metal 推理引擎
                try await liteRTBackend.loadModel(at: url, accelerator: preferredAccelerator)
                isLiteRTLoaded = true
                isModelLoaded = true
                loadedModelName = model.name
                generationProgress = 1.0
                keyStore?.set(selectedModelID, forKey: configKey)
                return
            } else if ext == SystemConstants.FileExtension.bin || ext == SystemConstants.FileExtension.gguf {
                // 存量 .bin / .gguf 权重兼容分支
                isLiteRTLoaded = false
                isModelLoaded = true
                loadedModelName = model.name
                generationProgress = 1.0
                keyStore?.set(selectedModelID, forKey: configKey)
                return
            } else {
                compiledURL = try await compiler.compileModel(at: url)
            }

            let config = MLModelConfiguration()
            config.computeUnits = .all // 开启神经网络芯片、GPU与CPU全能联合加速

            let mlModel = try MLModel(contentsOf: compiledURL, configuration: config)
            currentModel = mlModel
            isModelLoaded = true
            loadedModelName = model.name
        }

        generationProgress = 1.0

        // 保存本次成功载入的本地模型偏好
        keyStore?.set(selectedModelID, forKey: configKey)
    }

    // MARK: - 文本生成核心方法
    /// 执行端侧大模型文本生成推理
    /// - Parameters:
    ///   - prompt: 提示词输入
    ///   - maxTokens: 允许的最大 token 生成长度上限
    /// - Returns: 模型输出文本
    public func generate(prompt: String, maxTokens: Int = Config.defaultMaxTokens) async throws -> String {
        guard isModelLoaded else {
            throw OnDeviceError.modelNotLoaded
        }

        isGenerating = true
        generatedText = ""
        generationProgress = 0

        let startTime = Date()

        // 1. Apple FoundationModels 系统级端侧大模型真实推理（iOS 26 / macOS 26+，零下载即用）
        if let systemGenerated = try await generateWithFoundationModelsIfSelected(prompt: prompt, startTime: startTime) {
            return systemGenerated
        }

        // 2. Google LiteRT-LM 开源引擎真实推理（支持 .litertlm / .task 与 Thinking Mode 流式分离）
        if isLiteRTLoaded {
            return try await generateWithLiteRT(prompt: prompt, maxTokens: maxTokens, startTime: startTime)
        }

        // 3. 核心 Core ML 推理预测过程
        if currentModel is MLModel {
            // 动态从 InferenceParametersStore 中读取当前模型对应的调节参数
            let modelId = selectedModelID.replacingOccurrences(of: LLMConstants.ModelIDPrefix.downloaded, with: "")
                .replacingOccurrences(of: LLMConstants.ModelIDPrefix.bundled, with: "")
            
            let finalTemperature: Double
            let finalMaxTokens: Int
            if let config = InferenceParametersStore.shared.loadParameters(for: modelId) {
                finalTemperature = config.temperature
                finalMaxTokens = config.maxTokens
            } else {
                finalTemperature = Config.generationTemperature
                finalMaxTokens = maxTokens
            }

            let inputFeatures: [String: Any] = [
                "prompt": prompt,
                "max_tokens": finalMaxTokens,
                "temperature": finalTemperature
            ]

            do {
                let provider = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
                let modelToPredict = self.currentModel as? MLModel

                generationTask = Task.detached(priority: .userInitiated) {
                    guard let model = modelToPredict else { throw LLMError.apiError("Model not loaded") }
                    let prediction = try model.prediction(from: provider)
                    return prediction.featureValue(for: LLMConstants.MLFeature.generatedText)?.stringValue
                }

                let generatedTextResult = try await generationTask?.value
                generationTask = nil

                if let generated = generatedTextResult {
                    let elapsed = Date().timeIntervalSince(startTime)
                    // 按字符数估算 token（约 4 字符/Token），与 AIAnalyticsService 估算方式一致，
                    // 避免空格分割对中文/日文等无空格分隔语言的严重低估
                    let tokenCount = max(1, generated.count / PromptConstants.TokenLimits.charactersPerToken)
                    inferenceSpeed = Double(tokenCount) / elapsed

                    generatedText = generated
                    generationProgress = 1.0
                    isGenerating = false
                    return generated
                }
            } catch {
                isGenerating = false
                throw OnDeviceError.inferenceFailed(error.localizedDescription)
            }
        }

        isGenerating = false
        throw OnDeviceError.emptyResponse
    }

    /// 当选中系统内置 Apple Intelligence 模型时，使用 Apple FoundationModels 执行真实离线推理
    private func generateWithFoundationModelsIfSelected(prompt: String, startTime: Date) async throws -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *),
              selectedModelID == LLMConstants.OnDeviceModelID.appleIntelligence else {
            return nil
        }
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let generated = response.content
            let elapsed = max(Date().timeIntervalSince(startTime), Config.minElapsedSeconds)
            let tokenCount = max(1, generated.count / PromptConstants.TokenLimits.charactersPerToken)
            inferenceSpeed = Double(tokenCount) / elapsed
            generatedText = generated
            generationProgress = 1.0
            isGenerating = false
            return generated
        } catch {
            isGenerating = false
            throw OnDeviceError.inferenceFailed(error.localizedDescription)
        }
        #else
        _ = (prompt, startTime)
        return nil
        #endif
    }

    /// 使用 Google LiteRT-LM 开源后端执行真实端侧流式推理
    private func generateWithLiteRT(prompt: String, maxTokens: Int, startTime: Date) async throws -> String {
        defer { isGenerating = false }
        let modelId = selectedModelID
            .replacingOccurrences(of: LLMConstants.ModelIDPrefix.downloaded, with: "")
            .replacingOccurrences(of: LLMConstants.ModelIDPrefix.bundled, with: "")
        let storedParams = InferenceParametersStore.shared.loadParameters(for: modelId)
        let options = LocalInferenceOptions(
            temperature: storedParams?.temperature ?? Config.generationTemperature,
            topP: storedParams?.topP ?? LocalInferenceOptions.Defaults.topP,
            topK: storedParams?.topK ?? LocalInferenceOptions.Defaults.topK,
            maxTokens: storedParams?.maxTokens ?? maxTokens,
            enableThinking: false,
            accelerator: preferredAccelerator
        )

        var thoughtBuffer = ""
        var answerBuffer = ""
        var measuredTPS: Double = 0.0

        do {
            for try await chunk in liteRTBackend.generateStream(
                prompt: prompt,
                imageData: [],
                audioData: nil,
                options: options
            ) {
                switch chunk {
                case .thought(let delta):
                    thoughtBuffer += delta
                    generatedText = Config.thoughtOpenTag + thoughtBuffer + Config.thoughtCloseTag + answerBuffer
                case .text(let delta):
                    answerBuffer += delta
                    generatedText = thoughtBuffer.isEmpty
                        ? answerBuffer
                        : Config.thoughtOpenTag + thoughtBuffer + Config.thoughtCloseTag + answerBuffer
                case .completed(_, let decodeTPS):
                    measuredTPS = decodeTPS
                }
            }
        } catch {
            throw OnDeviceError.inferenceFailed(error.localizedDescription)
        }

        let elapsed = max(Date().timeIntervalSince(startTime), Config.minElapsedSeconds)
        if measuredTPS > 0 {
            inferenceSpeed = measuredTPS
        } else {
            let tokenCount = max(1, answerBuffer.count / PromptConstants.TokenLimits.charactersPerToken)
            inferenceSpeed = Double(tokenCount) / elapsed
        }
        generationProgress = 1.0
        return generatedText
    }
}
