//
//  TestMocks.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：为单元测试提供 TestMocks 仿真服务占位。
//
import Foundation
import UFPCore
import XCTest
import Combine
import UFPStorage
import LocalAuthentication
#if os(watchOS)
@testable import ZhiYuWatch
#else
@testable import ZhiYu
#endif

// MARK: - Mock Logger
final class MockLogger: LoggerProtocol, @unchecked Sendable {
    var logEntries: [LogEntry] = []
    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> { Just([]).eraseToAnyPublisher() }
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?, status: LogStatus?, failureReason: String?) {}
    func debug(_ message: String, file: String, function: String, line: Int) {}
    func info(_ message: String, file: String, function: String, line: Int) {}
    func warning(_ message: String, file: String, function: String, line: Int) {}
    func error(_ message: String, error: Error?, file: String, function: String, line: Int) {}
    func saveToDisk() async {}
    func loadFromDisk() async {}
    func clearAllLogs() async {}
    func logTimed<T>(action: LogAction, target: String, module: String?, details: String, operation: () throws -> T) rethrows -> T { try operation() }
    func getLogEntries() async -> [LogEntry] { [] }
}

// MARK: - Mock LLM Service
@MainActor
final class MockLLMService: LLMService, @unchecked Sendable {
    override var isEnabled: Bool { get { _isEnabled } set { _isEnabled = newValue     }
}
    private var _isEnabled = true
    
    var generateHandler: (@Sendable (String, String) async throws -> String)?
    var chatStreamHandler: (@Sendable (String, [ChatMessageDTO], [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error>)?
    
    override func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO { ChatMessageDTO(role: .assistant, content: "") }
    
    override func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        if let handler = chatStreamHandler {
            return handler(query, history, pages)
        }
        return AsyncThrowingStream { $0.finish() }
    }
    
    override func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        if let handler = generateHandler {
            return try await handler(prompt, systemPrompt)
        }
        if systemPrompt.contains("Mermaid") || prompt.contains("思维导图") || prompt.contains("mindmap") {
            return """
            # UI测试思维导图

            ```mermaid
            mindmap
              root((UI测试思维导图))
                核心功能
                  语义检索
                  双向链接
                架构设计
                  L0-L3分层
            ```
            """
        } else if prompt.contains("信息图表") || prompt.contains("infographic") {
            return """
            # UI测试信息图表

            ```mermaid
            graph TD
              A[核心数据] --> B[存储层]
              A --> C[展现层]
            ```
            """
        } else if prompt.contains("演示文稿") || prompt.contains("slides") || prompt.contains("幻灯片") {
            return """
            # 幻灯片 1：项目概述
            欢迎使用智宇 AI 知识管理系统。

            ---
            # 幻灯片 2：核心能力
            - 混合向量检索
            - 深度合成实验室
            """
        } else if prompt.contains("知识测验") || prompt.contains("quiz") {
            return """
            [
              {
                "question": "智宇系统的存储架构依赖什么框架？",
                "options": ["GRDB.swift", "CoreData", "Realm", "MongoDB"],
                "answerIndex": 0,
                "explanation": "智宇底层采用 GRDB.swift 驱动 SQLite + FTS5 全文检索。"
              }
            ]
            """
        }
        return "智宇是一款优秀的基于 RAG 的知识管理应用，具备双向链接功能。"
    }
    override func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        SmartIngestResultDTO(title: title, compiledContent: "", suggestedTags: [], suggestedType: "", relatedTitles: [], summary: "")
    }
    override func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] { [] }
    override func foldContent(existingContent: String, newContent: String, title: String) async throws -> String { "" }
    override func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] { [] }
    override func rewriteQuery(_ query: String) async -> String { query }
    override func expandQuery(_ query: String) async -> [String] { [query] }
    override func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] { candidates }
    override func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] { chunks }
    override func generateHypotheticalDocument(query: String) async -> String { query }
}

// MARK: - Mock LLM 对话服务
/// 单元测试专用的模拟对话推理服务类，实现 LLMChatServiceProtocol 协议，配合测试环境下的服务依赖注入。
@MainActor
final class MockLLMChatService: LLMChatServiceProtocol, @unchecked Sendable {
    /// 模拟服务是否启用
    var isEnabled = true
    var provider: LLMProvider = .deepSeek
    var apiKey: String = "mock_key"
    var baseURL: String = "https://api.deepseek.com/v1"
    var model: String = "gpt-4o"
    var autoScan: Bool = true
    var autoRefactor: Bool = true
    
    /// 模拟核心单次对话推理方法
    /// - Parameters:
    ///   - query: 用户的提问输入
    ///   - history: 历史对话消息数组
    ///   - pages: 相关引用知识页面
    /// - Returns: 模拟的助理回复消息
    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        return ChatMessageDTO(role: .assistant, content: "Mock Chat Content")
    }
    
    /// 模拟流式对话推送方法
    /// - Parameters:
    ///   - query: 用户的提问输入
    ///   - history: 历史对话消息数组
    ///   - pages: 相关引用知识页面
    /// - Returns: 包含模拟增量文本推送的异步流
    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield("Mock Stream Content")
            continuation.finish()
        }
    }
    
    /// 模拟通用文本内容生成接口
    /// - Parameters:
    ///   - prompt: 提示词
    ///   - systemPrompt: 系统角色设定提示词
    /// - Returns: 生成的模拟文本段落
    func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        return "Mock Generated Content"
    }
}

#if !os(watchOS)
// MARK: - Mock On-Device LLM Service
@MainActor
final class MockOnDeviceLLMService: OnDeviceLLMServiceProtocol, @unchecked Sendable {
    @Published var isAvailable: Bool = true
    @Published var isModelLoaded: Bool = true
    @Published var isGenerating: Bool = false
    @Published var loadedModelName: String = "MockLocalModel"
    @Published var availableModels: [OnDeviceModel] = []
    @Published var selectedModelID: String = "mock_local_model"
    @Published var generationProgress: Double = 1.0
    @Published var generatedText: String = ""
    @Published var inferenceSpeed: Double = 15.0
    
    init() {}

    func discoverModels() {}
    func loadModel() async throws {
        isModelLoaded = true
    }
    func generate(prompt: String, maxTokens: Int) async throws -> String {
        return "Mock Local Generated Content"
    }
    func chatOnDevice(query: String, pages: [KnowledgePage]) async throws -> String {
        return "Mock Local Chat Content"
    }
    func cancelGeneration() {
        isGenerating = false
    }
    func unloadModel() {
        isModelLoaded = false
    }
    func importModel(from url: URL) async throws {}
    func deleteModel(_ model: OnDeviceModel) throws {}
}
#endif

// MARK: - Mock Biometric Auth Provider

/// 模拟的生物识别提供商，用于测试环境下的认证操作
@MainActor
final class MockBiometricAuthProvider: BiometricAuthProviderProtocol, @unchecked Sendable {
    /// 鉴权策略，默认使用设备所有者生物识别鉴权
    var authenticationPolicy: LAPolicy {
        #if os(watchOS)
        .deviceOwnerAuthentication
        #else
        .deviceOwnerAuthenticationWithBiometrics
        #endif
    }
    
    /// 检查生物识别是否可用，测试环境默认返回 false
    /// - Parameter context: 本地鉴权上下文
    /// - Returns: 是否可用
    func canEvaluatePolicy(context: LAContext) -> Bool {
        return false
    }
    
    /// 执行生物识别鉴权，测试环境默认返回 false
    /// - Parameters:
    ///   - context: 本地鉴权上下文
    ///   - reason: 鉴权原因
    /// - Returns: 是否鉴权成功
    func evaluatePolicy(context: LAContext, reason: String) async -> Bool {
        return false
    }
}

/// Mock 向量索引存储，用于测试环境 DI 容器注册
final class MockVectorIndexableStore: VectorIndexableStore, @unchecked Sendable {
    let embeddingProvider: any EmbeddingProvider

    init(embeddingProvider: any EmbeddingProvider) {
        self.embeddingProvider = embeddingProvider
    }
}

/// Mock Vault 数据库切换器，用于测试环境 DI 容器注册（避免 VaultService.init() 时 @Inject 解析失败）
final class MockVaultDatabaseSwitcher: VaultDatabaseSwitcher, @unchecked Sendable {
    func switchDatabase(to vaultID: UUID, at url: URL) async throws {}
    func releaseDatabaseConnection() {}
    func countPagesInCurrentVault() async throws -> Int { 0 }
    func countPages(at url: URL) async throws -> Int { 0 }
}

/// Mock 后台任务协议，用于测试环境 DI 容器注册
@MainActor
final class MockBackgroundTask: BackgroundTaskProtocol, @unchecked Sendable {
    func register(handler: @escaping @Sendable @MainActor () -> Void) {}
    func schedule() {}
}

/// Mock 提醒服务协议，用于测试环境 DI 容器注册
@MainActor
final class MockReminderService: ReminderServiceProtocol, @unchecked Sendable {
    var requestAccessResult: Bool = false
    var createReminderShouldThrow: Bool = false
    var createReminderCallCount: Int = 0
    var lastCreatedTitle: String?
    var lastCreatedNotes: String?

    func requestAccess() async -> Bool {
        requestAccessResult
    }

    func createReminder(title: String, notes: String) async throws {
        createReminderCallCount += 1
        lastCreatedTitle = title
        lastCreatedNotes = notes
        if createReminderShouldThrow {
            throw NSError(domain: "MockReminderService", code: 1)
        }
    }
}

// MARK: - XCTestCase Extension
extension XCTestCase {
    @MainActor
    func setupFullMockEnvironment() {
        // 注意：不调用 ServiceContainer.shared.reset() — register() 本身会覆盖已有注册。
        // reset() 会清空 AppEnvironment.init() 建立的完整 DI 链，导致 @Inject 解析崩溃。
        // 不调用 DatabaseManager.shared.reset() — 生产 SQLiteStore 依赖已打开的数据库连接，
        // reset() 关闭数据库会导致 SQLiteStore 引用悬空，后续数据库操作全部失败。
        // 如需测试数据隔离，使用 setupForTesting() 建立独立内存数据库。

        // 1. Core Services (L0)
        let logger = MockLogger()
        ServiceContainer.shared.register(logger as any LoggerProtocol, for: (any LoggerProtocol).self)
        
        #if os(macOS)
        ServiceContainer.shared.register(MacHapticService() as any HapticFeedbackProtocol, for: (any HapticFeedbackProtocol).self)
        #elseif os(watchOS)
        ServiceContainer.shared.register(WatchHapticService() as any HapticFeedbackProtocol, for: (any HapticFeedbackProtocol).self)
        #else
        ServiceContainer.shared.register(iOSHapticService() as any HapticFeedbackProtocol, for: (any HapticFeedbackProtocol).self)
        #endif
        
        // KeyStore — 键值存储抽象（测试环境使用独立 UserDefaults 实例，避免 .standard 跨测试残留）
        // ⚠️ 必须在 Router.shared 之前注册：Router.init() 依赖 KeyStoreProtocol 恢复上次选中的 Tab。
        // P2-1 迁移：原 UserDefaultsKeyStore.shared 绑定 UserDefaults.standard，导致跨测试状态泄漏。
        //           改为每次创建独立 suiteName 实例，测试间完全隔离。
        guard let testDefaults = UserDefaults(suiteName: "ZhiYuTest-\(UUID().uuidString)") else {
            fatalError("无法创建测试用 UserDefaults")
        }
        let testKeyStore = UserDefaultsKeyStore(defaults: testDefaults)
        ServiceContainer.shared.register(testKeyStore as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)

        // KeychainService.testOverride — 统一注入 MockKeychainService
        // 绕过 CI 模拟器环境 errSecMissingEntitlement -34018 限制
        // 避免 LLMConfigStore.loadAPIKey / NetworkClient / PluginLoader 调用真实 Keychain 失败
        // 导致测试间状态污染（flaky test）
        if KeychainService.testOverride == nil {
            KeychainService.testOverride = MockKeychainService()
        }

        ServiceContainer.shared.register(HapticFeedback.shared, for: HapticFeedback.self)
        #if !os(watchOS)
        ServiceContainer.shared.register(Router.shared, for: Router.self)
        #endif
        ServiceContainer.shared.register(DeepLinkService(), for: DeepLinkService.self)
        ServiceContainer.shared.register(PerformanceService(), for: PerformanceService.self)
        ServiceContainer.shared.register(AccessibilityService(), for: AccessibilityService.self)
        ServiceContainer.shared.register(SnapshotService(), for: SnapshotService.self)
        ServiceContainer.shared.register(WorkflowService.shared, for: WorkflowService.self)
        
        ServiceContainer.shared.register(MockBiometricAuthProvider() as any BiometricAuthProviderProtocol, for: (any BiometricAuthProviderProtocol).self)
        ServiceContainer.shared.register(DummyActivityService() as any LiveActivityProtocol, for: (any LiveActivityProtocol).self)
        // 注册平台级不支持的搜索索引器，保障测试套件后台同步不崩溃 (@SRS-7.1)
        ServiceContainer.shared.register(UnsupportedSearchIndexer() as any SearchIndexerProtocol, for: (any SearchIndexerProtocol).self)
        
        // 注册协作提供商服务以支持协作测试和同步逻辑，避免测试运行时闪退
        #if targetEnvironment(simulator) || os(watchOS)
        ServiceContainer.shared.register(StubCollaborationProvider() as any CollaborationProviderProtocol, for: (any CollaborationProviderProtocol).self)
        #else
        ServiceContainer.shared.register(MultipeerCollaborationProvider() as any CollaborationProviderProtocol, for: (any CollaborationProviderProtocol).self)
        #endif
        
        #if os(macOS)
        ServiceContainer.shared.register(MacAppEnvironment() as any AppEnvironmentProtocol, for: (any AppEnvironmentProtocol).self)
        #elseif os(iOS)
        ServiceContainer.shared.register(iOSAppEnvironment() as any AppEnvironmentProtocol, for: (any AppEnvironmentProtocol).self)
        #endif
        
        // 2. Storage Services (L1)
        guard let dbQueue = try? DatabaseQueue() else { fatalError("TestMocks: 无法创建测试数据库") }
        // 绑定外部测试数据库写入器，并同步跑完所有 Schema 架构迁移以建立完整的物理表、虚拟表与触发器
        do { try DatabaseManager.shared.setupForTesting(with: dbQueue) } catch { fatalError("TestMocks: 迁移失败 \(error)") }
        // 注册 DatabaseManager 到 DI 容器，供 IngestService 等 L2 服务在摄入/清理时追踪活跃事务计数 (@DIP)
        ServiceContainer.shared.register(DatabaseManager.shared, for: DatabaseManager.self)
        
        let sqliteStore = SQLiteStore(dbWriter: dbQueue)
        ServiceContainer.shared.register(sqliteStore as any AnyPageStoreCapabilities, for: (any AnyPageStoreCapabilities).self)
        ServiceContainer.shared.register(sqliteStore as any AnyPageStore, for: (any AnyPageStore).self)
        ServiceContainer.shared.register(sqliteStore, for: SQLiteStore.self)
        
        ServiceContainer.shared.register(LLMConfigManager(), for: LLMConfigManager.self)
        ServiceContainer.shared.register(AIAnalyticsService(), for: AIAnalyticsService.self)
        
        // 注册测试环境下对话推理的 LLMChatServiceProtocol 实体，防范 @Inject 注入崩溃
        let mockChatLLM = MockLLMChatService()
        ServiceContainer.shared.register(mockChatLLM as any LLMChatServiceProtocol, for: (any LLMChatServiceProtocol).self)
        
        let llm = MockLLMService()
        ServiceContainer.shared.register(llm as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        ServiceContainer.shared.register(llm as LLMService, for: LLMService.self)
        // 注意：原先 AnyLLMService 已在之前的重构中移除，现全局已切为 protocols。
        
        #if !os(watchOS)
        let mockOnDevice = MockOnDeviceLLMService()
        ServiceContainer.shared.register(mockOnDevice as any OnDeviceLLMServiceProtocol, for: (any OnDeviceLLMServiceProtocol).self)
        #endif
        
        // LLMKnowledgeServiceProtocol 虽被 MockLLMService 重写覆盖，但注册确保 @Inject 后备方案安全
        let mockKnowledgeLLM = MockKnowledgeLLMService()
        ServiceContainer.shared.register(mockKnowledgeLLM as any LLMKnowledgeServiceProtocol, for: (any LLMKnowledgeServiceProtocol).self)

        ServiceContainer.shared.register(QueryReranker(), for: (any LLMRetrievalServiceProtocol).self)

        // 注册 Mock 环境下的 EmbeddingManager 和仓库，加固向量同步功能
        let vectorRepo = MockVectorRepository()
        let embeddingManager = EmbeddingManager(repository: vectorRepo)
        ServiceContainer.shared.register(embeddingManager as any EmbeddingProvider, for: (any EmbeddingProvider).self)
        ServiceContainer.shared.register(embeddingManager, for: EmbeddingManager.self)

        // 注册 Mock VectorIndexableStore（AIWorkflowStore 等 7 个 @Inject 依赖之一）
        let mockVectorStore = MockVectorIndexableStore(embeddingProvider: embeddingManager)
        ServiceContainer.shared.register(mockVectorStore as any VectorIndexableStore, for: (any VectorIndexableStore).self)

        guard let dbQueue = try? DatabaseQueue() else {
            fatalError("Failed to create database queue")
        }
        let knowledgeRepo = KnowledgePageRepository(dbWriter: dbQueue)
        ServiceContainer.shared.register(knowledgeRepo as any KnowledgeRepository, for: (any KnowledgeRepository).self)
        // LLMContextBuilder 通过具体类型解析，需注册双重绑定以覆盖 resolve(KnowledgePageRepository.self) (@DIP)
        ServiceContainer.shared.register(knowledgeRepo, for: KnowledgePageRepository.self)
        
        let governanceRepo = RAGGovernanceSQLiteStore()
        ServiceContainer.shared.register(governanceRepo as any RAGGovernanceRepository, for: (any RAGGovernanceRepository).self)

        if let globalWriter = DatabaseManager.shared.globalWriter {
            let vaultRepo = SQLiteVaultRepository(dbWriter: globalWriter)
            ServiceContainer.shared.register(vaultRepo as any VaultRepository, for: (any VaultRepository).self)
            
            let fileSigRepo = SQLiteFileSignatureRepository(dbWriter: globalWriter)
            ServiceContainer.shared.register(fileSigRepo as any FileSignatureRepository, for: (any FileSignatureRepository).self)
            
            // 注册插件数据库仓库服务，支持 PluginRegistry 的运行与加载操作
            let pluginRepo = SQLitePluginRepository(dbWriter: globalWriter)
            ServiceContainer.shared.register(pluginRepo as any PluginRepository, for: (any PluginRepository).self)
        }

        ServiceContainer.shared.register(BackupService(), for: BackupService.self)
        ServiceContainer.shared.register(VaultStorageSecurityService(), for: VaultStorageSecurityService.self)
        
        // 3. Domain Services (L2)
        ServiceContainer.shared.register(AuthService.shared as any AuthServiceProtocol, for: (any AuthServiceProtocol).self)
        ServiceContainer.shared.register(MockVaultDatabaseSwitcher() as any VaultDatabaseSwitcher, for: (any VaultDatabaseSwitcher).self)
        ServiceContainer.shared.register(VaultService.shared as any VaultServiceProtocol, for: (any VaultServiceProtocol).self)
        // 注册设置存储中心以供测试沙盒内需要注入 SettingsStore 的类能正常解析，避免测试时闪退
        ServiceContainer.shared.register(SettingsStore(), for: SettingsStore.self)
        
        ServiceContainer.shared.register(LinkService(), for: LinkService.self)
        ServiceContainer.shared.register(IngestService(), for: IngestService.self)
        ServiceContainer.shared.register(LintService(), for: LintService.self)
        ServiceContainer.shared.register(UndoService(), for: UndoService.self)
        ServiceContainer.shared.register(KnowledgeInsightService(), for: KnowledgeInsightService.self)
        // 注册知识页面核心管理器，供 AppStore 等服务 @Inject 注入，确保单测数据读写与修改流正常 (@DIP)
        ServiceContainer.shared.register(KnowledgePageManager(), for: KnowledgePageManager.self)
        // 注册系统维护服务，健全单测生命周期的全局重置与清理链路 (@DIP)
        ServiceContainer.shared.register(MaintenanceService(), for: MaintenanceService.self)
        ServiceContainer.shared.register(ChatService.shared as any ChatServiceProtocol, for: (any ChatServiceProtocol).self)
        #if !os(watchOS)
        ServiceContainer.shared.register(AISynthesisService.shared, for: AISynthesisService.self)
        #endif

        let evaluationService = RAGEvaluationService(llmService: llm, governanceStore: governanceRepo)
        ServiceContainer.shared.register(evaluationService, for: RAGEvaluationService.self)
        
        ServiceContainer.shared.register(PluginRegistry(), for: PluginRegistry.self)
        
        #if os(iOS)
        ServiceContainer.shared.register(iOSOCRService() as any OCRServiceProtocol, for: (any OCRServiceProtocol).self)
        ServiceContainer.shared.register(iOSSpeechService() as any SpeechServiceProtocol, for: (any SpeechServiceProtocol).self)
        ServiceContainer.shared.register(iOSWatchSyncService() as any WatchSyncProtocol, for: (any WatchSyncProtocol).self)
        #endif
        
        // 3.5. 后台任务 & 提醒服务 Mock（WorkflowService/IngestQueue 的 @Inject 依赖）
        ServiceContainer.shared.register(MockBackgroundTask() as any BackgroundTaskProtocol, for: (any BackgroundTaskProtocol).self)
        ServiceContainer.shared.register(MockReminderService() as any ReminderServiceProtocol, for: (any ReminderServiceProtocol).self)

        // 4. Data Sync Coordination (L1.5) & Sibling Stores - 必须在底层所有 Mock 物理仓储和 L1 基础设施就绪后注册，以防时序竞争崩溃
        ServiceContainer.shared.register(IngestStore(), for: IngestStore.self)
        #if !os(watchOS)
        ServiceContainer.shared.register(SynthesisStore(), for: SynthesisStore.self)
        #endif
        ServiceContainer.shared.register(DataCoordinator(), for: DataCoordinator.self)
        
        // 5. L2 Features & Sidebar Row Components Dependencies
        // 注册知识页面状态存储中心，防止插件卸载/加载等环节因获取不到 KnowledgeStore 导致测试崩溃 (@DIP)
        ServiceContainer.shared.register(KnowledgeStore(), for: KnowledgeStore.self)
        
        // 注册 RAG 编排器，供 UI 测试运行时解析，防止 DI Fatal Error (@DIP)
        ServiceContainer.shared.register(RAGOrchestrator(), for: RAGOrchestrator.self)
        
        // 注册 ModelDownloadCapabilities 和 RemoteConfigCapabilities 契约，支持 GlobalModelManager 的测试运行，消除依赖缺失导致的 @Inject 崩溃
        let fakeDownload = FakeModelDownloadManager()
        ServiceContainer.shared.register(fakeDownload as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        
        let mockRemoteConfig = MockRemoteConfigService()
        ServiceContainer.shared.register(mockRemoteConfig as any RemoteConfigCapabilities, for: (any RemoteConfigCapabilities).self)

        ServiceContainer.shared.register(MockFileArchiver() as any FileArchiverProtocol, for: (any FileArchiverProtocol).self)
        ServiceContainer.shared.register(MockExportService() as any ExportServiceProtocol, for: (any ExportServiceProtocol).self)
        ServiceContainer.shared.register(MockImportFileStore() as any ImportFileStore, for: (any ImportFileStore).self)
        ServiceContainer.shared.register(MockPDFService() as any PDFServiceProtocol, for: (any PDFServiceProtocol).self)
        ServiceContainer.shared.register(MockImportRecordRepository() as any ImportRecordRepository, for: (any ImportRecordRepository).self)
        // 注册 FeedbackRepository 和 DeviceInfoProtocol，防止 FeedbackView 等视图的 @Inject 解析崩溃
        ServiceContainer.shared.register(MockFeedbackRepository() as any FeedbackRepository, for: (any FeedbackRepository).self)
        ServiceContainer.shared.register(MockDeviceInfoService() as any DeviceInfoProtocol, for: (any DeviceInfoProtocol).self)
        ServiceContainer.shared.register(AISynthesisService.shared as any AISynthesisServiceProtocol, for: (any AISynthesisServiceProtocol).self)
    }
}

// MARK: - Mock Knowledge Page
public struct MockPage: KnowledgePageRepresentable, Hashable {
    public var id = UUID()
    public var title: String
    public var content: String
    public var tags: [String] = []
    public var pageType: PageType = .concept
    
    public init(id: UUID = UUID(), title: String, content: String, tags: [String] = [], pageType: PageType = .concept) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.pageType = pageType
    }
}

// MARK: - Mock URL Protocol
/// 单元测试专用：网络拦截服务协议，拦截全局 URLRequest 并返回自定义响应数据与 HTTP 状态码
public final class TestMockURLProtocol: URLProtocol {
    /// 模拟请求处理器，返回 HTTP 响应头与可选的 Body 载荷
    public static nonisolated(unsafe) var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
    
    /// 决定当前 Protocol 是否可以处理指定的请求
    /// - Parameter request: 待决策的 URLRequest
    /// - Returns: 是否拦截
    public override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    /// 返回指定请求的规范版本，用于缓存识别等
    /// - Parameter request: 原 URLRequest
    /// - Returns: 规范 URLRequest
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    /// 开始加载请求
    public override func startLoading() {
        guard let handler = Self.requestHandler else {
            // 没有配置 handler 时，抛出错误
            client?.urlProtocol(self, didFailWithError: NSError(domain: "TestMockURLProtocol", code: -1, userInfo: [NSLocalizedDescriptionKey: "requestHandler is nil"]))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            // 1. 通知客户端接收了响应
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            // 2. 如果有 Body 数据，通知客户端加载数据
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            // 3. 标记加载完成
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            // 拦截发生异常，回调失败
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    /// 停止加载请求
    public override func stopLoading() {}
}

// MARK: - Mock 大模型下载与配置服务 (HIG Compliance & Inject Safeness)

/// 模拟大模型下载服务实现类
final class FakeModelDownloadManager: ModelDownloadCapabilities, @unchecked Sendable {
    var lastModelId: String?
    var lastRemoteURL: URL?
    
    func startDownload(modelId: String, remoteURL: URL) async throws {
        lastModelId = modelId
        lastRemoteURL = remoteURL
    }
    
    func pauseDownload(modelId: String) async throws {}
    func resumeDownload(modelId: String) async throws {}
    func cancelDownload(modelId: String) async throws {}
    
    func observeDownloadState(for modelId: String) async -> AsyncStream<DownloadState> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}

/// 模拟云端配置与 Manifest 服务实现类
final class MockRemoteConfigService: RemoteConfigCapabilities, @unchecked Sendable {
    var mockManifests: [LLMManifest] = []
    
    func fetchLLMManifests() async throws -> [LLMManifest] {
        return mockManifests
    }
    
    func fetchAgentSkills() async throws -> [AgentSkill] {
        return []
    }
}

final class MockFileArchiver: FileArchiverProtocol, @unchecked Sendable {
    func zip(directory sourceDir: URL, to destinationURL: URL) async throws {}
    func extractContents(from archiveURL: URL, to destinationURL: URL) throws {}
}

final class MockExportService: ExportServiceProtocol, @unchecked Sendable {
    func exportToPDF(markdown: String, fileName: String) async throws -> URL { URL(fileURLWithPath: "/tmp/\(fileName).pdf") }
    func exportMindmapToPDF(mermaidCode: String, fileName: String) async throws -> URL { URL(fileURLWithPath: "/tmp/\(fileName).pdf") }
    func exportToPPTX(markdown: String, fileName: String) async throws -> URL { URL(fileURLWithPath: "/tmp/\(fileName).pptx") }
}

// MARK: - Mock Security Services (P1: 单例 TestOverride 模式)

/// 内存字典实现的 Keychain Mock，绕过 errSecMissingEntitlement -34018 限制
final class MockKeychainService: KeychainService, @unchecked Sendable {
    /// 内部存储（internal 供测试隔离工具重置）
    private(set) var store: [String: String] = [:]

    override func store(key: String, value: String) throws {
        store[key] = value
    }

    override func retrieve(key: String) throws -> String? {
        store[key]
    }

    override func delete(key: String) throws {
        store[key] = nil
    }
}

/// No-op 加密的 SecureEnclave Mock，plaintext 直通，供测试中 API Key 持久化验证
final class MockSecureEnclaveCryptoService: SecureEnclaveCryptoService, @unchecked Sendable {
    override func encrypt(_ plainText: String) throws -> String {
        plainText
    }

    override func decrypt(_ cipherText: String) throws -> String {
        cipherText
    }
}

/// No-op 加密的 SecurityManager Mock，plaintext 直通，供测试环境替代真实 AES-GCM 加解密
final class MockSecurityManager: SecurityManager, @unchecked Sendable {
    override func encrypt(_ text: String) throws -> String {
        text
    }

    override func decrypt(_ base64Combined: String) throws -> String {
        base64Combined
    }
}

/// 内存版 ImportFileStore Mock，避免测试触碰真实文件系统
final class MockImportFileStore: ImportFileStore, @unchecked Sendable {
    /// copyFile 返回的固定路径前缀
    static let sandboxPrefix = "/tmp/mock_sandbox/"

    func saveContent(_ content: String, category: ImportCategory, ext: String) -> String? {
        "\(Self.sandboxPrefix)\(UUID().uuidString).\(ext)"
    }

    func saveData(_ data: Data, category: ImportCategory, ext: String) -> String? {
        "\(Self.sandboxPrefix)\(UUID().uuidString).\(ext)"
    }

    func copyFile(at url: URL, category: ImportCategory) -> String? {
        "\(Self.sandboxPrefix)\(url.lastPathComponent)"
    }
}

/// 内存版 PDFService Mock，避免测试触碰真实文件系统与 PDFKit
final class MockPDFService: PDFServiceProtocol, @unchecked Sendable {
    /// 内存元数据存储
    private var documentsInfo: [PDFDocumentInfo] = []
    /// 内存 PDF 文件名集合（模拟物理文件存在性）
    private var fileNames: Set<String> = []
    /// extractText 返回的固定文本
    var stubExtractedText: String = "stub pdf text"
    /// extractImages 返回的固定数据
    var stubExtractedImages: [Data] = []

    func savePDF(data: Data, fileName: String) async -> URL? {
        fileNames.insert(fileName)
        return URL(fileURLWithPath: "/tmp/mock_pdf/\(fileName)")
    }

    func deletePDF(fileName: String) async -> Bool {
        let existed = fileNames.remove(fileName) != nil
        return existed
    }

    func allPDFFilenames() async -> [String] {
        Array(fileNames)
    }

    func getPDFURL(fileName: String) -> URL? {
        guard fileNames.contains(fileName) else { return nil }
        return URL(fileURLWithPath: "/tmp/mock_pdf/\(fileName)")
    }

    func extractText(from url: URL) async -> String? {
        stubExtractedText
    }

    func extractText(from url: URL, pageRange: Range<Int>) async -> String? {
        guard !pageRange.isEmpty else { return nil }
        return stubExtractedText
    }

    func extractImages(from url: URL) async -> [Data] {
        stubExtractedImages
    }

    func saveDocumentsInfo(_ docs: [PDFDocumentInfo]) async {
        documentsInfo = docs
    }

    func loadDocumentsInfo() async -> [PDFDocumentInfo] {
        documentsInfo
    }
}

/// 内存版 FeedbackRepository Mock，避免测试触碰真实数据库
final class MockFeedbackRepository: FeedbackRepository, @unchecked Sendable {
    private var entries: [FeedbackEntry] = []

    func save(_ entry: FeedbackEntry) async throws {
        entries.append(entry)
    }

    func fetchAll(limit: Int) async throws -> [FeedbackEntry] {
        Array(entries.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func fetchByID(id: String) async throws -> FeedbackEntry? {
        entries.first { $0.id == id }
    }

    func updateStatus(id: String, status: FeedbackStatus) async throws {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].status = status
        }
    }
}

/// 内存版 ImportRecordRepository Mock，避免测试触碰真实数据库
final class MockImportRecordRepository: ImportRecordRepository, @unchecked Sendable {
    private var records: [ImportRecord] = []

    func save(_ record: ImportRecord) async throws {
        records.append(record)
    }

    func fetchAll(category: String?, limit: Int) async throws -> [ImportRecord] {
        let filtered = category.map { categoryValue in records.filter { $0.category == categoryValue } } ?? records
        return Array(filtered.prefix(limit))
    }

    func fetchByID(_ id: String) async throws -> ImportRecord? {
        records.first { $0.id == id }
    }

    func updateStatus(id: String, status: String, completedAt: Date?) async throws {
        if let idx = records.firstIndex(where: { $0.id == id }) {
            records[idx].status = status
            records[idx].completedAt = completedAt
        }
    }

    func updatePageID(id: String, pageID: String) async throws {
        if let idx = records.firstIndex(where: { $0.id == id }) {
            records[idx].pageID = pageID
        }
    }

    func updateRawText(id: String, rawText: String) async throws {
        if let idx = records.firstIndex(where: { $0.id == id }) {
            records[idx].rawText = rawText
        }
    }

    func updateTags(id: String, tags: String) async throws {
        if let idx = records.firstIndex(where: { $0.id == id }) {
            records[idx].tags = tags
        }
    }

    func fetchInProgress() async throws -> [ImportRecord] {
        records.filter { $0.status == "processing" || $0.status == "pending" }
    }

    func totalStorageSize() async throws -> Int64 {
        records.reduce(0) { $0 + ($1.fileSize ?? 0) }
    }
}

// MARK: - 测试状态隔离工具

/// 集中清理跨测试残留的持久化状态，确保每个测试在干净环境下运行。
///
/// 解决以下根因：
/// 1. `UserDefaultsKeyStore.shared` 使用 `UserDefaults.standard` 单例，跨测试残留
///    `activeModelId`/`activeCloudModelId`/`isCloudEscalationEnabled` 等值
/// 2. `LLMConfigStore` 硬编码 `UserDefaults.standard`，`zhiyu_llm_config` 残留
/// 3. `KeychainService.testOverride` 单例内部 store 残留 apiKey
extension XCTestCase {

    /// 清理所有跨测试残留的持久化状态（UserDefaults + Keychain mock）
    ///
    /// 应在 `setUp` 开头与 `tearDown` 结尾调用，确保测试隔离。
    @MainActor
    func resetPersistentTestState() {
        let defaults = UserDefaults.standard

        // 1. GlobalModelManager 持久化属性
        defaults.removeObject(forKey: AppConstants.Keys.Storage.activeModelId)
        defaults.removeObject(forKey: AppConstants.Keys.Storage.activeCloudModelId)
        defaults.removeObject(forKey: AppConstants.Keys.Storage.isCloudEscalationEnabled)

        // 2. GlobalModelManager 下载模型 ID 列表
        defaults.removeObject(forKey: "zhiyu_downloaded_model_ids")

        // 3. LLMConfigStore 配置块
        defaults.removeObject(forKey: "zhiyu_llm_config")

        // 4. LLMConfigStore 各提供商绑定的 baseURL / model（custom 提供商）
        //    官方提供商的 baseURL/model 由 provider.defaultBaseURL/defaultModel 计算，不持久化
        for providerKey in ["deepseek", "zhipu", "minimax", "qwen", "openai", "custom"] {
            defaults.removeObject(forKey: "llm_base_url_\(providerKey)")
            defaults.removeObject(forKey: "llm_model_\(providerKey)")
        }

        // 5. Localized.languageMode 持久化值
        //    setter 内部 Task { @MainActor } 异步写入 UserDefaults，defer 还原 _inMemoryFallback
        //    但 UserDefaults 残留的 portuguese/japanese 等值会被 loadCachedLanguageMode 读取
        defaults.removeObject(forKey: AppConstants.Keys.Storage.languageMode)

        // 6. 重置 KeychainService mock 内部 store，清除残留 apiKey
        //    testOverride 在 setupFullMockEnvironment 中首次设置后不再重建，
        //    需主动清理其内部存储，避免跨测试 apiKey 残留
        if let mock = KeychainService.testOverride as? MockKeychainService {
            mock.resetStore()
        }

        // 7. 重置 Localized._inMemoryFallback 跨测试残留
        //    某些测试会设置 Localized.languageMode（如 LocalizationTests.testLanguageSwitchingLogic），
        //    若未清理会污染后续测试的 locale 依赖行为
        Localized.resetForTesting()
    }
}

/// MockKeychainService 内部 store 重置能力
extension MockKeychainService {
    /// 清空内部 store，供测试隔离使用
    func resetStore() {
        store.removeAll()
    }
}
