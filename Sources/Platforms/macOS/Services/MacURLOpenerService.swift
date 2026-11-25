//
//  MacURLOpenerService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：macOS 平台 URL 打开实现，封装 NSWorkspace.shared.open API。

#if os(macOS)
import AppKit

/// macOS URL 打开器服务
@MainActor
final class MacURLOpenerService: URLOpenerProtocol {
    func open(_ url: URL) async {
        NSWorkspace.shared.open(url)
    }
}
#endif
