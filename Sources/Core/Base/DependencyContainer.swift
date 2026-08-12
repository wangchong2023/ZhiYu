// 系统层级：[L0 基础设施层]
// 核心职责：DependencyContainer — 集中持有 21 个服务依赖，替代分散的 ServiceContainer.shared + @Inject。
//           迁移期间为骨架占位，P2-P6 阶段逐步将 Any? 替换为具体服务协议类型 + 注册 DependencyKey。
//           终态：View/Store 层通过 @Environment(DependencyContainer.self) 获取服务，
//                或通过 @Dependency(\.xxxService) 直接注入。

import Foundation

// MARK: - DependencyContainer

/// DependencyContainer — 集中持有 21 个服务依赖。
///
/// 设计原则：
/// - **状态 vs 服务分离**：AppModel 持有 UI 可观察状态，DependencyContainer 持有服务依赖
/// - **协议类型**：每个服务属性声明为协议类型（如 `any VaultServiceProtocol`），便于 mock
/// - **mock() 工厂**：测试一行构造全 mock 环境，零手动重置
///
/// 迁移路径：
/// - P1：骨架占位，21 个 `Any?` 服务属性（当前）
/// - P2-P6：逐步替换为具体协议类型 + 注册 DependencyKey + 启用 @Dependency
/// - P7：终态，ServiceContainer / @Inject / testOverride 全部删除
@MainActor
@Observable
public final class DependencyContainer {
    // MARK: - L3 表现层服务

    /// 路由服务（原 Router.shared）
    public var routerService: Any?
    /// 引导服务（原 OnboardingService.shared）
    public var onboardingService: Any?
    /// 主题服务（原 ThemeManager.shared）
    public var themeService: Any?
    /// 本地化服务（原 Localized 静态属性）
    public var localizationService: Any?
    /// Tooltip 服务（原 TooltipManager.shared）
    public var tooltipService: Any?
    /// Toast 服务（原 ToastManager.shared）
    public var toastService: Any?
    /// Pencil 服务（原 PencilManager.shared）
    public var pencilService: Any?
    /// 语音服务（原 VoiceSpeechManager.shared）
    public var voiceSpeechService: Any?

    // MARK: - L2 业务层服务

    /// Vault 服务（原 VaultService.shared）
    public var vaultService: Any?
    /// 任务中心服务（原 TaskCenter.shared）
    public var taskCenterService: Any?
    /// 勋章服务（原 MedalService.shared）
    public var medalService: Any?
    /// 活动服务（原 ActivityManager.shared）
    public var activityService: Any?
    /// 认证服务（原 AuthService.shared）
    public var authService: Any?
    /// StoreKit 服务（原 StoreKitManager.shared）
    public var storeKitService: Any?

    // MARK: - L1 服务层服务

    /// 全局模型管理（原 GlobalModelManager.shared）
    public var globalModelService: Any?
    /// LLM 配置服务（原 LLMConfigStore / LLMService.shared）
    public var llmConfigService: Any?
    /// 数据源服务（原 SourceManager.shared）
    public var sourceService: Any?
    /// Schema 服务（原 SchemaManager.shared）
    public var schemaService: Any?
    /// IngestQueue 服务（原 IngestQueue.shared）
    public var ingestQueueService: Any?
    /// 插件服务（原 PluginRegistry.shared / PluginEnginePool.shared）
    public var pluginService: Any?
    /// 数据库服务（原 DatabaseManager.shared，基础设施层例外保留单例）
    public var databaseService: Any?

    // MARK: - 初始化

    public init() {}

    // MARK: - Mock 工厂

    /// 测试用的全 mock 依赖工厂。
    /// P1 阶段返回空容器，P2-P6 阶段逐步填充 mock 服务实例。
    public static func mock() -> DependencyContainer {
        DependencyContainer()
    }
}
