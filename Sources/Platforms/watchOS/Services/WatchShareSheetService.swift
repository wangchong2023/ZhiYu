//
//  WatchShareSheetService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：watchOS 平台系统分享面板实现（watchOS 无系统分享面板，no-op 空实现）。

#if os(watchOS)
import Foundation
/// watchOS 系统分享面板服务（no-op，watchOS 无系统分享面板）
@MainActor
final class WatchShareSheetService: ShareSheetProtocol {
    func presentShareSheet(items: [Any]) async {
        Logger.shared.warning("[WatchShareSheet] 系统分享面板在 watchOS 上不可用，已忽略请求。items 数量: \(items.count)")
    }
}
#endif
