//
//  iOSPlatformRegistrar.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
#if os(iOS) && !os(watchOS)
import Foundation
import UFPCore
import WebKit
import CoreSpotlight

/// iOS 平台专用服务注册器
@MainActor
struct iOSPlatformRegistrar: PlatformRegistrar {
    
    /// 注册 iOS 特有能力
    static func registerServices(in container: ServiceContainer) {
        // 1. 基础任务与粘贴板
        container.register(iOSBackgroundTaskProvider(), for: (any BackgroundTaskProtocol).self)
        container.register(iOSPasteboardService(), for: (any PasteboardProtocol).self)
        
        // 2. 协作与文档
        #if targetEnvironment(simulator)
        container.register(StubCollaborationProvider(), for: (any CollaborationProviderProtocol).self)
        #else
        container.register(MultipeerCollaborationProvider(), for: (any CollaborationProviderProtocol).self)
        #endif
        
        container.register(iOSPDFService(), for: (any PDFServiceProtocol).self)
        container.register(iOSSecurityScopedStorage(), for: SecurityScopedStorageProtocol.self)
        
        // 3. AI 与生物识别
        container.register(CoreMLModelCompiler(), for: MLModelCompilerProtocol.self)
        container.register(iOSBiometricAuthProvider(), for: BiometricAuthProviderProtocol.self)
        container.register(iOSOCRService(), for: (any OCRServiceProtocol).self)
        container.register(iOSSpeechService(), for: (any SpeechServiceProtocol).self)
        
        // 4. 实时活动与系统集成
        #if !targetEnvironment(macCatalyst)
        container.register(ActivityService.shared as any LiveActivityProtocol, for: (any LiveActivityProtocol).self)
        #else
        container.register(DummyActivityService() as any LiveActivityProtocol, for: (any LiveActivityProtocol).self)
        #endif
        container.register(ZIPFoundationArchiver(), for: (any FileArchiverProtocol).self)
        container.register(iOSAccessibilityService(), for: (any AccessibilityServiceProtocol).self)

        container.register(iOSAppEnvironment(), for: (any AppEnvironmentProtocol).self)
        container.register(iOSHapticService(), for: (any HapticFeedbackProtocol).self)
        container.register(iOSWatchSyncService(), for: (any WatchSyncProtocol).self)
        container.register(iOSReminderService(), for: (any ReminderServiceProtocol).self)
        container.register(iOSExportService(), for: (any ExportServiceProtocol).self)
        
        // 5. 搜索索引
        container.register(iOSSpotlightIndexer(), for: (any SearchIndexerProtocol).self)

        // 6. 设备信息 / URL 打开 / 分享面板
        container.register(iOSDeviceInfoService(), for: (any DeviceInfoProtocol).self)
        container.register(iOSURLOpenerService(), for: (any URLOpenerProtocol).self)
        container.register(iOSShareSheetService(), for: (any ShareSheetProtocol).self)
    }
}
#endif
