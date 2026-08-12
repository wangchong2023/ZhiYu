//
//  PasteboardProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 Pasteboard 模块的抽象契约接口。
//
import Foundation
import Dependencies
import UFPCore

/// 剪贴板服务协议
@MainActor
public protocol PasteboardProtocol: AnyObject, Sendable {
    /// 获取或设置剪贴板文本
    var string: String? { get set }
}

// MARK: - DependencyKey 注册

/// PasteboardProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum PasteboardKey: DependencyKey {
    @MainActor
    public static var liveValue: any PasteboardProtocol {
        ServiceContainer.shared.resolve((any PasteboardProtocol).self)
    }
}

extension DependencyValues {
    /// 剪贴板服务依赖
    public var pasteboard: any PasteboardProtocol {
        get { self[PasteboardKey.self] }
        set { self[PasteboardKey.self] = newValue }
    }
}
