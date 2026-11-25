//
//  WatchURLOpenerService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：watchOS 平台 URL 打开实现（watchOS 不支持打开 URL，记录日志 no-op）。

#if os(watchOS)
import Foundation
/// watchOS URL 打开器服务（no-op，watchOS 不支持系统级 URL 跳转）
@MainActor
final class WatchURLOpenerService: URLOpenerProtocol {
    func open(_ url: URL) async {
        Logger.shared.warning("[WatchURLOpener] URL 打开在 watchOS 上不可用，已忽略: \(url.absoluteString)")
    }
}
#endif
