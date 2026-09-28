//
//  ViewProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 跨层共享层
//  核心职责：视图工厂协议，建立 L2 功能层与 L3 表现层之间的视图创建契约。
//  迁移说明：原位于 L0 Core/Base/Protocols/，因依赖 SwiftUI AnyView 违反 L0 纯净性，
//           迁移至 Shared 层（L2/L3 共享依赖，无反向依赖风险）。
//
import SwiftUI

/// 视图提供者协议
/// 每个业务领域 (Sub-Domain) 实现此协议，负责构建其内部模块的视图。
/// 使用 AnyHashable 作为路由参数类型，使本协议保持平台无关性，
/// 避免对 App 层（L3）类型 AppRoute 的跨层依赖。
public protocol ViewProvider: Sendable {
    /// 根据路由构建对应的视图
    /// - Parameter route: 目标路由，使用 AnyHashable 保持平台无关性
    /// - Returns: 抹除类型后的视图，如果不属于该提供者范畴则返回 nil
    @MainActor

    /// 创建View
    func makeView(for route: AnyHashable) -> AnyView?
}
