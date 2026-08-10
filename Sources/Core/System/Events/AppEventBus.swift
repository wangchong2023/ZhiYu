//
//  AppEventBus.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：应用内事件总线，支持发布-订阅模式的跨模块通信。
//
import Foundation
import Combine

/// 系统级事件总线 (Architect 视角：解耦服务间通信)
@MainActor
final class AppEventBus {
    static let shared = AppEventBus()
    private init() {}

    /// 定义系统关键事件
    enum AppEvent {
        case pageCreated(id: UUID, title: String, nodeCount: Int, linkCount: Int)
        case pageUpdated(id: UUID, nodeCount: Int, linkCount: Int)
        case pageDeleted(id: UUID)
        case pagesCleared
        case clearAllDataRequested // 新增：全局数据清理请求
        case graphRelayoutRequested
    }

    private let subject = PassthroughSubject<AppEvent, Never>()

    /// 发布事件
    func publish(_ event: AppEvent) {
        DispatchQueue.main.async {
            self.subject.send(event)
        }
    }

    /// 订阅事件
    func subscribe() -> AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }
}
