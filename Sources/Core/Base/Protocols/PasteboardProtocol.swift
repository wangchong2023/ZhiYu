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

// MARK: - NoOp 实现

/// PasteboardProtocol 的空操作实现，用于测试环境安全降级
@MainActor
public final class NoOpPasteboard: PasteboardProtocol, @unchecked Sendable {
    private var _string: String?
    public init() {}
    public var string: String? {
        get { _string }
        set { _string = newValue }
    }
}

// MARK: - DependencyKey 注册

/// PasteboardProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum PasteboardKey: DependencyKey {
    @MainActor
    public static var liveValue: any PasteboardProtocol {
        ServiceContainer.shared.resolve((any PasteboardProtocol).self)
    }
    @MainActor
    public static var testValue: any PasteboardProtocol {
        ServiceContainer.shared.resolveOptional((any PasteboardProtocol).self) ?? NoOpPasteboard()
    }
    @MainActor
    public static var previewValue: any PasteboardProtocol { NoOpPasteboard() }
}

extension DependencyValues {
    /// 剪贴板服务依赖
    public var pasteboard: any PasteboardProtocol {
        get { self[PasteboardKey.self] }
        set { self[PasteboardKey.self] = newValue }
    }
}
