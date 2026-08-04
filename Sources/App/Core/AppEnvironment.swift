//
//  AppEnvironment.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：App 模块的 AppEnvironment 实现。
//
import SwiftUI
import Observation
import UFPStorage
/// 应用程序全局环境
/// 负责协调服务初始化、生命周期管理及全局状态（Stores）持有
@Observable
@MainActor
final class AppEnvironment {
    /// 全局单例
    static let shared = AppEnvironment()
    
    // ── 核心业务状态 ──
    // 注意：Store 改为 var，延迟到 DI 注册完成后赋值。
    // 原因：Store 的 @Inject 属性首次访问时解析 DI 容器，
    //       必须保证 DI 在 Store 实例化前就绪。
    private(set) var store: AppStore!
    private(set) var ingestStore: IngestStore!
    private(set) var synthesisStore: SynthesisStore!
    let router: Router

    // ── 系统级状态 ──
    let themeManager: ThemeManager
    /// 延迟计算：LLMService.shared 内部 @Inject 依赖 DI 容器，
    /// 必须在 registerDIModules() 之后才能首次访问，故用计算属性。
    var llmService: LLMService { LLMService.shared }
    var llmConfig: LLMConfigManager   // var：init 中先赋初值，DI 就绪后重新解析

    private init() {
        // ── 0. 仅初始化不依赖 DI 的 stored properties（Swift 要求在调用 self 方法前完成）──
        self.router = Router.shared
        self.themeManager = ThemeManager.shared
        self.llmConfig = LLMConfigManager()

        Logger.shared.info("[AppEnvironment] Starting initialization...")

        // 🧪 检测是否运行于 XCTest (Unit Test) 环境 — 避免污染测试 DI 状态
        let isRunningInUnitTests = NSClassFromString("XCTestCase") != nil && !CommandLine.arguments.contains("-UITest_MockData")
        #if DEBUG
        if CommandLine.arguments.contains("-UITest_MockData") {
            Logger.shared.info("[AppEnvironment] Detected UI Test environment, using ephemeral setup")
        } else if isRunningInUnitTests {
            Logger.shared.info("[AppEnvironment] Detected XCTest unit test environment, using lightweight test setup")
        }
        #endif

        // 1. 准备底层物理存储 (@P0: 确保护航数据库在注册前就绪)
        prepareDatabase()

        // 2. 执行模块化注册 (L0 - L3) — 必须在 Store 实例化前完成
        //    Store 的 @Inject 属性首次访问时会解析 DI 容器，故 DI 必须先就绪
        registerDIModules()

        // 2.1 DI 就绪断言：验证 Store 依赖的关键服务已全部注册
        //     若断言失败，说明 ModuleRegistrar 注册顺序有误，需立即暴露而非延后到 Store 崩溃
        ServiceContainer.shared.assertRegistered(
            [
                (any LoggerProtocol).self,
                (any AnyPageStoreCapabilities).self,
                (any LLMServiceProtocol).self,
                (any EmbeddingProvider).self,
                KnowledgePageManager.self,
                LinkService.self,
                IngestService.self,
                BackupService.self,
                UndoService.self,
                TagStore.self,
                PerformanceService.self,
                SettingsStore.self,
                SnapshotService.self,
                VaultStorageSecurityService.self
            ],
            context: "Before Store instantiation"
        )

        // 2.2 DI 就绪后立即加载本地化语言偏好缓存（避免后续跨 actor 访问 keyStore）
        Localized.loadCachedLanguageMode()

        // 🧪 Unit Test 环境：注册所有服务但不锁定 DI 容器，允许测试 reset() 后重新注册 Mock
        if isRunningInUnitTests {
            // 测试环境仍需实例化 Store（测试可能访问），DI 已就绪
            self.ingestStore = IngestStore()
            self.synthesisStore = SynthesisStore()
            self.store = AppStore()
            Logger.shared.info("[AppEnvironment] DI services registered (test mode, chain NOT locked).")
            return
        }

        // 🔒 生产路径：锁定 DI 容器，禁止 reset() 清空
        ServiceContainer.shared.markProductionChainComplete()

        // 2.5 DI 就绪后重新解析需要容器注入的属性
        self.llmConfig = ServiceContainer.shared.resolve(LLMConfigManager.self)

        // 3. DI 就绪后实例化核心 Store（@Inject 首次访问安全）
        //    AppStore.init 内部会自注册到 DI 容器
        self.ingestStore = IngestStore()
        self.synthesisStore = SynthesisStore()
        self.store = AppStore()

        // 3.1 补充注册 AppStore.init 未覆盖的 Store（IngestStore/SynthesisStore）
        registerStoresToContainer()

        // 4. 配置全局 UI 样式与数据种子化及同步
        setupGlobalStylesAndSync()

        // 5. 审查修复 MED-6: 启动安全检查 — 越狱检测
        performSecurityCheck()

        Logger.shared.info("[AppEnvironment] Initialization completed.")
    }

    /// 启动安全检查：越狱检测（审查修复 MED-6）
    /// 检测到越狱设备时记录安全警报日志，不阻断运行但标记风险状态
    private func performSecurityCheck() {
        #if os(iOS) && !targetEnvironment(simulator)
        Task { @MainActor in
            if JailbreakDetector.shared.isJailbroken() {
                Logger.shared.addLog(
                    action: .error,
                    target: "SecurityCheck",
                    details: L10n.Security.jailbreakDetected,
                    module: "Security",
                    status: .failure,
                    failureReason: L10n.Security.jailbreakFailureReason
                )
            }
        }
        #endif
    }
    
    /// 准备底层物理存储与数据库热迁移
    private func prepareDatabase() {
        do {
            let fileManager = FileManager.default
            let appGroupIdentifier = "group.com.zhiyu.app"

            // 旧的沙盒独立路径
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "Insight", code: -1)
            }
            let oldDbURL = appSupport.appendingPathComponent(AppConstants.Storage.databaseName)
            
            // 新的 App Group 共享路径（若不可用，回退到沙盒路径）
            let dbURL: URL
            let baseGlobalURL: URL

            if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                dbURL = groupURL.appendingPathComponent(AppConstants.Storage.databaseName)
                baseGlobalURL = groupURL
            } else {
                Logger.shared.warning("[AppEnvironment] App Group unavailable, falling back to sandbox path")
                dbURL = oldDbURL
                baseGlobalURL = appSupport
            }

            // 数据无缝热迁移（如果旧库存在且新库不存在）
            if fileManager.fileExists(atPath: oldDbURL.path) && !fileManager.fileExists(atPath: dbURL.path) {
                Logger.shared.info("[AppEnvironment] Performing database App Group hot migration...")
                try fileManager.moveItem(at: oldDbURL, to: dbURL)

                // 迁移关联文件 (如 global.sqlite3)
                let oldGlobal = appSupport.appendingPathComponent(AppConstants.Storage.globalDatabaseName)
                let newGlobal = baseGlobalURL.appendingPathComponent(AppConstants.Storage.globalDatabaseName)
                if fileManager.fileExists(atPath: oldGlobal.path) && !fileManager.fileExists(atPath: newGlobal.path) {
                    try? fileManager.moveItem(at: oldGlobal, to: newGlobal)
                }
            }
            
            if CommandLine.arguments.contains("-UITest_MockData") {
                let memoryQueue = try DatabaseQueue()
                try DatabaseManager.shared.setupForTesting(with: memoryQueue)
                Logger.shared.info("[AppEnvironment] Core database ready (In-Memory Mock)")
            } else {
                try DatabaseManager.shared.setup(at: dbURL)
                Logger.shared.info("[AppEnvironment] Core database ready (App Group): \(dbURL.lastPathComponent)")
            }
        } catch {
            Logger.shared.error("[AppEnvironment] Critical: Database initialization failed", error: error)
        }
    }

    /// 注册核心依赖注入模块 (L0 - L3)
    private func registerDIModules() {
        CoreModuleRegistrar.register(in: ServiceContainer.shared)
        StorageModuleRegistrar.register(in: ServiceContainer.shared)

        // L1 插件系统
        ServiceContainer.shared.register(PluginRegistry.shared, for: PluginRegistry.self)

        // L2 领域模块 — 按依赖顺序：Auth → Knowledge → AI
        AuthModuleRegistrar.register(in: ServiceContainer.shared)
        KnowledgeModuleRegistrar.register(in: ServiceContainer.shared)
        AIModuleRegistrar.register(in: ServiceContainer.shared)

        // L3 应用模块
        AppModuleRegistrar.register(in: ServiceContainer.shared)
    }

    /// 补充注册 AppStore.init 未覆盖的核心 Store 到 DI 容器
    /// 注意：AppStore/SearchStore/AIWorkflowStore/AIInsightStore/TagStore/KnowledgeStore
    ///       已在 AppStore.init 内自注册，此处仅注册 IngestStore/SynthesisStore
    private func registerStoresToContainer() {
        let container = ServiceContainer.shared
        container.register(self.ingestStore, for: IngestStore.self)
        container.register(self.synthesisStore, for: SynthesisStore.self)
    }

    /// 配置全局样式与数据种子化及同步
    private func setupGlobalStylesAndSync() {
        // 配置全局 UI 样式 (iOS)
        #if os(iOS)
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.appAccent)
        #endif

        // 异步触发数据种子化 (确保所有 DI 注册已完成且主线程已释放)
        Task {
            // 启动 StoreKit 2 Transaction 持久监听（审核必须项）
            StoreKitService.shared.startListening()

            await self.store.seedDefaultContent()
            
            // 异步安全触发数据同步编排
            ServiceContainer.shared.resolve(DataCoordinator.self).sync()
        }
    }
    
    /// 获取平台环境信息
    var platformEnv: any AppEnvironmentProtocol {
        ServiceContainer.shared.resolve((any AppEnvironmentProtocol).self)
    }
}
