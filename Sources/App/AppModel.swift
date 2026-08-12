// 系统层级：[L3 表现层]
// 核心职责：ZhiYuAppModel — 集中持有 21 个单例的 UI 可观察状态，替代分散的 .shared 可变全局状态。
//           迁移期间为骨架占位，P2-P6 阶段逐步填充各 State 字段。
//           终态：View 层通过 @Environment(ZhiYuAppModel.self) 读取 UI 状态，
//                Service 层通过 @Dependency(\.xxxService) 调用业务方法。
//
// 命名说明：所有 State 结构体加 `App` 前缀（如 AppRouterState），避免与现有类型冲突
//          （如 DatabaseManager.DatabaseState / VoiceAudioPlayerView.VoiceSpeechState / AppConstants.AppModel）。

import SwiftUI

// MARK: - State 占位结构体

// P1 阶段：全部为空占位 State，P2-P6 阶段逐步填充字段
// 每个 State 对应一个原 @MainActor 有状态单例的可观察数据

/// L3 表现层状态
public struct AppRouterState: Sendable {
    public init() {}
}

public struct AppOnboardingState: Sendable {
    public init() {}
}

public struct AppThemeState: Sendable {
    public init() {}
}

public struct AppLocalizationState: Sendable {
    public init() {}
}

public struct AppTooltipState: Sendable {
    public init() {}
}

public struct AppToastState: Sendable {
    public init() {}
}

public struct AppPencilState: Sendable {
    public init() {}
}

public struct AppVoiceSpeechState: Sendable {
    public init() {}
}

/// L2 业务层状态
public struct AppVaultState: Sendable {
    public init() {}
}

public struct AppTaskCenterState: Sendable {
    public init() {}
}

public struct AppMedalState: Sendable {
    public init() {}
}

public struct AppCompatActivity: Sendable {
    public init() {}
}

public struct AppAuthState: Sendable {
    public init() {}
}

public struct AppStoreKitState: Sendable {
    public init() {}
}

/// L1 服务层状态（仅 UI 可观察部分）
public struct AppGlobalModelState: Sendable {
    public init() {}
}

public struct AppLLMConfigState: Sendable {
    public init() {}
}

public struct AppSourceState: Sendable {
    public init() {}
}

public struct AppSchemaState: Sendable {
    public init() {}
}

public struct AppIngestQueueState: Sendable {
    public init() {}
}

public struct AppPluginState: Sendable {
    public init() {}
}

public struct AppDatabaseState: Sendable {
    public init() {}
}

// MARK: - ZhiYuAppModel

/// ZhiYuAppModel — 集中持有 21 个单例的 UI 可观察状态。
///
/// 设计原则：
/// - **状态 vs 服务分离**：ZhiYuAppModel 只持有 UI 可观察状态，服务方法走 @Dependency
/// - **State 结构体**：每个单例拆为 AppState（数据）+ Service（方法）
/// - **preview() 工厂**：快照测试一行构造确定性状态
///
/// 迁移路径：
/// - P1：骨架占位（当前）
/// - P2-P6：逐步填充各 State 字段，替换对应单例的 .shared 引用
/// - P7：终态，所有单例状态迁移完成
@MainActor
@Observable
public final class ZhiYuAppModel {
    // MARK: - L3 表现层状态

    public var router: AppRouterState
    public var onboarding: AppOnboardingState
    public var theme: AppThemeState
    public var localization: AppLocalizationState
    public var tooltip: AppTooltipState
    public var toast: AppToastState
    public var pencil: AppPencilState
    public var voiceSpeech: AppVoiceSpeechState

    // MARK: - L2 业务层状态

    public var vault: AppVaultState
    public var taskCenter: AppTaskCenterState
    public var medals: AppMedalState
    public var activity: AppCompatActivity
    public var auth: AppAuthState
    public var storeKit: AppStoreKitState

    // MARK: - L1 服务层状态（仅 UI 可观察部分）

    public var globalModel: AppGlobalModelState
    public var llmConfig: AppLLMConfigState
    public var source: AppSourceState
    public var schema: AppSchemaState
    public var ingestQueue: AppIngestQueueState
    public var plugin: AppPluginState
    public var database: AppDatabaseState

    // MARK: - 初始化

    public init() {
        self.router = .init()
        self.onboarding = .init()
        self.theme = .init()
        self.localization = .init()
        self.tooltip = .init()
        self.toast = .init()
        self.pencil = .init()
        self.voiceSpeech = .init()
        self.vault = .init()
        self.taskCenter = .init()
        self.medals = .init()
        self.activity = .init()
        self.auth = .init()
        self.storeKit = .init()
        self.globalModel = .init()
        self.llmConfig = .init()
        self.source = .init()
        self.schema = .init()
        self.ingestQueue = .init()
        self.plugin = .init()
        self.database = .init()
    }

    // MARK: - 预览工厂

    /// 快照测试 / SwiftUI Preview 用的确定性状态工厂。
    /// P1 阶段返回默认空状态，P2-P6 阶段逐步填充各 State 的预览数据。
    public static func preview() -> ZhiYuAppModel {
        ZhiYuAppModel()
    }
}
