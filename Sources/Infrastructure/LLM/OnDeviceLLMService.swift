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
import Combine
import UFPCore

// MARK: - On-Device LLM Service
/// 智宇端侧本地大模型推理服务中枢
/// 负责扫描并加载 Bundle 内置、Documents 目录下载的 `.mlmodelc` 格式大语言模型，并结合 Neural Engine (端侧神经网络引擎) 进行高速文本合成及评估。
@MainActor
public final class OnDeviceLLMService: OnDeviceLLMServiceProtocol {
    /// 指示本地 Core ML 推理是否在当前硬件与 iOS 版本上可用（要求 iOS 17.0+）
    @Published public var isAvailable: Bool = false
    
    /// 指示当前大模型是否已完全成功载入内存
    @Published public var isModelLoaded: Bool = false
    
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
    private var currentModel: AnyObject?
    
    /// 本地选型偏好持久化 Key
    private let configKey = LLMConstants.OnDeviceStorage.configKey
    
    /// 注入的模型编译器，用于处理平台差异化编译与沙盒物理转换
    @ObservationIgnored @Inject var compiler: MLModelCompilerProtocol

    // MARK: - 常量参数定义
    nonisolated public enum Config {
        public static let defaultMaxTokens: Int = 256
        public static let generationTemperature: Double = 0.7
        public static let smartIngestMaxTokens: Int = 500
        public static let chatMaxTokens: Int = 300
        public static let contextPageLimit: Int = 5
        public static let contentPreviewChars: Int = 200
        public static let titleHitWeight: Int = 3
        public static let tagHitWeight: Int = 2
        public static let contentHitWeight: Int = 1
        public static let minTokenLength: Int = 2
    }

    // MARK: - 初始化
    public init() {
        checkAvailability()
        discoverModels()
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
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsDir.appendingPathComponent("MLModels")

        if let enumerator = FileManager.default.enumerator(at: modelsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == SystemConstants.FileExtension.mlmodelC {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    models.append(OnDeviceModel(
                        id: "\(LLMConstants.ModelIDPrefix.downloaded)\(name)",
                        name: name,
                        url: fileURL,
                        size: estimateModelSize(url: fileURL),
                        type: .downloaded
                    ))
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
        let savedID = UserDefaults.standard.string(forKey: configKey)
        if let saved = savedID, models.contains(where: { $0.id == saved }) {
            selectedModelID = saved
        } else if let first = models.first {
            selectedModelID = first.id
        }
    }

    /// 估算模型文件夹的总物理大小
    private func estimateModelSize(url: URL) -> Int64 {
        let fm = FileManager.default
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

            // 执行模型编译，若已是编译后的 mlmodelc 则直接读取
            let compiledURL: URL
            if url.pathExtension == SystemConstants.FileExtension.mlmodelC {
                compiledURL = url
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

        isGenerating = false
        generationProgress = 1.0

        // 保存本次成功载入的本地模型偏好
        UserDefaults.standard.set(selectedModelID, forKey: configKey)
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

        // 核心 Core ML 推理预测过程
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
                
                let generatedTextResult = try await Task.detached(priority: .userInitiated) {
                    guard let model = modelToPredict else { throw LLMError.apiError("Model not loaded") }
                    let prediction = try model.prediction(from: provider)
                    return prediction.featureValue(for: LLMConstants.MLFeature.generatedText)?.stringValue
                }.value

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
    /// 取消Generation
    public func cancelGeneration() {
        isGenerating = false
        generatedText = ""
        generationProgress = 0
    }

    // MARK: - 卸载内存模型
    /// unloadModel
    public func unloadModel() {
        currentModel = nil
        isModelLoaded = false
        loadedModelName = ""
        inferenceSpeed = 0
    }

    // MARK: - 标签自动分析器
    func extractTags(from text: String) -> [String] {
        let pattern = "#(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }

    // MARK: - 动态模型导入
    /// 将用户在外部文件沙盒选中的 `.mlmodel` 或 `.mlmodelc` 模型无缝拷贝并挂接至内部存储器中
    public func importModel(from url: URL) async throws {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsDir.appendingPathComponent("MLModels")
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
            try FileManager.default.moveItem(at: compiledURL, to: destURL.appendingPathExtension("mlmodelc"))
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

// MARK: - On-Device Model DTO
/// 设备端本地大语言模型元数据结构
public struct OnDeviceModel: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: URL?
    public let size: Int64
    public let type: ModelType

    public enum ModelType: Sendable {
        /// 应用预装打包内置模型
        case bundled
        /// 用户后续导入下载的自定义模型
        case downloaded
        /// 系统内置 Apple Intelligence 基础大模型
        case system
    }

    public var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var icon: String {
        switch type {
        case .bundled: return LLMConstants.OnDeviceIcon.bundled
        case .downloaded: return LLMConstants.OnDeviceIcon.downloaded
        case .system: return LLMConstants.OnDeviceIcon.system
        }
    }
}

// MARK: - On-Device LLM 专属本地化错误类型
public enum OnDeviceError: LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case notSupported
    case inferenceFailed(String)
    case compilationFailed
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return L10n.AI.OnDevice.Error.modelNotFound
        case .modelNotLoaded:
            return L10n.AI.OnDevice.Error.modelNotLoaded
        case .notSupported:
            return L10n.AI.OnDevice.Error.notSupported
        case .inferenceFailed(let msg):
            return "\(L10n.AI.OnDevice.Error.inferenceFailed): \(msg)"
        case .compilationFailed:
            return L10n.AI.OnDevice.Error.compilationFailed
        case .emptyResponse:
            return L10n.AI.OnDevice.Error.emptyResponse
        }
    }
}
