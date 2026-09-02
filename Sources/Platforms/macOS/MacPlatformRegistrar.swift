//
//  MacPlatformRegistrar.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：macOS 平台实现：菜单栏、文件归档、辅助功能。
//
#if os(macOS)
import Foundation
import UFPCore

/// macOS 平台专用服务注册器
@MainActor
struct MacPlatformRegistrar: PlatformRegistrar {
    
    /// 注册 macOS 特有能力
    static func registerServices(in container: ServiceContainer) {
        // 1. 基础任务与粘贴板
        container.register(StubBackgroundTaskProvider(), for: (any BackgroundTaskProtocol).self)
        container.register(MacPasteboardService(), for: (any PasteboardProtocol).self)
        
        // 2. 协作与存储
        container.register(StubCollaborationProvider(), for: (any CollaborationProviderProtocol).self)
        container.register(iOSPDFService(), for: (any PDFServiceProtocol).self) // macOS 使用兼容层
        container.register(MacOSSecurityScopedStorage(), for: SecurityScopedStorageProtocol.self)
        
        // 3. AI 与生物识别
        container.register(CoreMLModelCompiler(), for: MLModelCompilerProtocol.self)
        container.register(MacOSBiometricAuthProvider(), for: BiometricAuthProviderProtocol.self)
        container.register(iOSOCRService(), for: (any OCRServiceProtocol).self)
        container.register(iOSSpeechService(), for: (any SpeechServiceProtocol).self)
        
        // 4. macOS 桌面环境与无障碍
        container.register(MacAppEnvironment(), for: (any AppEnvironmentProtocol).self)
        container.register(MacAccessibilityService(), for: (any AccessibilityServiceProtocol).self)
        container.register(MacHapticService(), for: (any HapticFeedbackProtocol).self)
        container.register(MacFileArchiver(), for: (any FileArchiverProtocol).self)

        // 5. 跨端兼容与未支持功能占位
        container.register(DummyActivityService() as any LiveActivityProtocol, for: (any LiveActivityProtocol).self)
        container.register(StubWatchSyncService(), for: (any WatchSyncProtocol).self)
        container.register(iOSReminderService(), for: (any ReminderServiceProtocol).self)
        container.register(UnsupportedExportService(), for: (any ExportServiceProtocol).self)
        container.register(UnsupportedSearchIndexer(), for: (any SearchIndexerProtocol).self)

        // 6. 桌面外设与系统面板
        container.register(MacDeviceInfoService(), for: (any DeviceInfoProtocol).self)
        container.register(MacURLOpenerService(), for: (any URLOpenerProtocol).self)
        container.register(MacShareSheetService(), for: (any ShareSheetProtocol).self)
    }
}
#endif
