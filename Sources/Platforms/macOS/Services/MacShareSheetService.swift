//
//  MacShareSheetService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：macOS 平台系统分享面板实现，使用 NSSharingServicePicker。

#if os(macOS)
import AppKit

/// macOS 系统分享面板服务
@MainActor
final class MacShareSheetService: ShareSheetProtocol {
    func presentShareSheet(items: [Any]) async {
        let picker = NSSharingServicePicker(items: items)
        // 从当前 key window 的 contentView 展示
        if let window = NSApp.keyWindow ?? NSApp.mainWindow,
           let contentView = window.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }
}
#endif
