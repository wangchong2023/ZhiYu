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

// MARK: - DependencyKey 注册

/// ShareSheetProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum ShareSheetKey: DependencyKey {
    @MainActor
    public static var liveValue: any ShareSheetProtocol {
        ServiceContainer.shared.resolve((any ShareSheetProtocol).self)
    }
}

extension DependencyValues {
    /// 系统分享面板依赖
    public var shareSheet: any ShareSheetProtocol {
        get { self[ShareSheetKey.self] }
        set { self[ShareSheetKey.self] = newValue }
    }
}
