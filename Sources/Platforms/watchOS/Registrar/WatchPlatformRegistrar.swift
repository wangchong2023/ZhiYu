//
//  WatchPlatformRegistrar.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：watchOS 平台实现：语音听写、健康数据同步、紧凑 UI。
//
#if os(watchOS)
import Foundation
import UFPCore

/// watchOS 平台专用服务注册器
@MainActor
struct WatchPlatformRegistrar: PlatformRegistrar {
    
    /// 注册 watchOS 特有能力
    static func registerServices(in container: ServiceContainer) {
        // 1. 基础任务与粘贴板
        container.register(StubBackgroundTaskProvider(), for: (any BackgroundTaskProtocol).self)
        container.register(WatchPasteboardService(), for: (any PasteboardProtocol).self)
        
        // 2. 协作与存储
        container.register(StubCollaborationProvider(), for: (any CollaborationProviderProtocol).self)
        container.register(WatchPDFService(), for: (any PDFServiceProtocol).self)
        container.register(WatchSecurityScopedStorage(), for: SecurityScopedStorageProtocol.self)
        
        // 3. AI 与生物识别
        container.register(WatchModelCompiler(), for: MLModelCompilerProtocol.self)
        container.register(WatchBiometricAuthProvider(), for: BiometricAuthProviderProtocol.self)
        container.register(WatchOCRService(), for: (any OCRServiceProtocol).self)
        container.register(WatchSpeechService(), for: (any SpeechServiceProtocol).self)
        
        // 4. watchOS 系统环境与专属同步
        container.register(WatchAppEnvironment(), for: (any AppEnvironmentProtocol).self)
        container.register(WatchHapticService(), for: (any HapticFeedbackProtocol).self)
        container.register(WatchWatchSyncService(), for: (any WatchSyncProtocol).self)
        container.register(WatchAccessibilityService(), for: (any AccessibilityServiceProtocol).self)

        // 5. 独立手表端占位与未支持能力
        container.register(DummyActivityService() as any LiveActivityProtocol, for: (any LiveActivityProtocol).self)
        container.register(UnsupportedFileArchiver(), for: (any FileArchiverProtocol).self)
        container.register(UnsupportedReminderService(), for: (any ReminderServiceProtocol).self)
        container.register(UnsupportedExportService(), for: (any ExportServiceProtocol).self)
        container.register(UnsupportedSearchIndexer(), for: (any SearchIndexerProtocol).self)

        // 6. 手表端设备信息与 URL 打开
        container.register(WatchDeviceInfoService(), for: (any DeviceInfoProtocol).self)
        container.register(WatchURLOpenerService(), for: (any URLOpenerProtocol).self)
        container.register(WatchShareSheetService(), for: (any ShareSheetProtocol).self)
    }
}
#endif
