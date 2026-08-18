//
//  URLOpenerProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 URL 打开的跨平台协议，屏蔽 UIApplication.shared.open / NSWorkspace.shared.open 的 API 差异。

import Foundation
import Dependencies
import UFPCore

/// URL 打开器协议
@MainActor
public protocol URLOpenerProtocol: Sendable {
    /// 异步打开指定 URL
    func open(_ url: URL) async
}

// MARK: - DependencyKey 注册

/// URLOpenerProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum URLOpenerKey: DependencyKey {
    @MainActor
    public static var liveValue: any URLOpenerProtocol {
        ServiceContainer.shared.resolve((any URLOpenerProtocol).self)
    }
}

extension DependencyValues {
    /// URL 打开器服务依赖
    public var urlOpener: any URLOpenerProtocol {
        get { self[URLOpenerKey.self] }
        set { self[URLOpenerKey.self] = newValue }
    }
}
