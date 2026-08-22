//
//  ShareSheetProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义系统分享面板的跨平台协议，屏蔽 UIActivityViewController / NSSharingServicePicker 的 API 差异。

import Foundation
import Dependencies
import UFPCore

/// 系统分享面板协议
@MainActor
public protocol ShareSheetProtocol: Sendable {
    /// 展示系统分享面板
    /// - Parameter items: 要分享的项目（URL/Data/String 等）
    func presentShareSheet(items: [Any]) async
}

// MARK: - NoOp 实现

/// ShareSheetProtocol 的空操作实现，用于测试环境安全降级
@MainActor
public final class NoOpShareSheet: ShareSheetProtocol, @unchecked Sendable {
    public init() {}
    public func presentShareSheet(items: [Any]) async {}
}

// MARK: - DependencyKey 注册

/// ShareSheetProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum ShareSheetKey: DependencyKey {
    @MainActor
    public static var liveValue: any ShareSheetProtocol {
        ServiceContainer.shared.resolve((any ShareSheetProtocol).self)
    }
    @MainActor
    public static var testValue: any ShareSheetProtocol {
        ServiceContainer.shared.resolveOptional((any ShareSheetProtocol).self) ?? NoOpShareSheet()
    }
    @MainActor
    public static var previewValue: any ShareSheetProtocol { NoOpShareSheet() }
}

extension DependencyValues {
    /// 系统分享面板依赖
    public var shareSheet: any ShareSheetProtocol {
        get { self[ShareSheetKey.self] }
        set { self[ShareSheetKey.self] = newValue }
    }
}
