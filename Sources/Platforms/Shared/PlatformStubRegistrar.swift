//
//  PlatformStubRegistrar.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/15.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：抽取 macOS / watchOS 平台 Registrar 中完全相同的 Stub / Unsupported 服务注册行，
//           消除跨平台注册器中的重复代码。
//

import Foundation
import UFPCore

/// 跨平台共享的 Stub 服务注册器
/// 封装 macOS 与 watchOS 中完全相同的 5 项 Stub / Unsupported 服务注册，
/// 消除 MacPlatformRegistrar 与 WatchPlatformRegistrar 中的重复注册行。
@MainActor
enum PlatformStubRegistrar {

    /// 注册所有平台共享的 Stub / Unsupported 服务
    /// - Parameter container: DI 容器
    static func registerSharedStubs(in container: ServiceContainer) {
        // 后台任务占位（macOS / watchOS 均不支持后台任务）
        container.register(StubBackgroundTaskProvider(), for: (any BackgroundTaskProtocol).self)
        // 协作功能占位
        container.register(StubCollaborationProvider(), for: (any CollaborationProviderProtocol).self)
        // Live Activity 占位
        container.register(DummyActivityService() as any LiveActivityProtocol, for: (any LiveActivityProtocol).self)
        // 导出功能占位
        container.register(UnsupportedExportService(), for: (any ExportServiceProtocol).self)
        // 搜索索引占位
        container.register(UnsupportedSearchIndexer(), for: (any SearchIndexerProtocol).self)
    }

    /// 注册 iOS / macOS 共享的 AI 服务（CoreML + OCR + Speech），
    /// 消除 iOSPlatformRegistrar 与 MacPlatformRegistrar 中重复的 3 行注册。
    /// - Parameter container: DI 容器
    static func registerSharedAIServices(in container: ServiceContainer) {
        container.register(CoreMLModelCompiler(), for: MLModelCompilerProtocol.self)
        container.register(iOSOCRService(), for: (any OCRServiceProtocol).self)
        container.register(iOSSpeechService(), for: (any SpeechServiceProtocol).self)
    }
}
