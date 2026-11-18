//
//  ActivityView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：跨平台系统分享面板视图，iOS 封装 UIActivityViewController，macOS 封装 NSSharingServicePicker。
//

import SwiftUI

#if os(iOS)
import UIKit

/// 跨平台系统分享面板（iOS：UIActivityViewController）
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    /// 创建 UIViewController
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    /// 更新 UIViewController
    /// - Parameter uiViewController: uiViewController
    /// - Parameter context: context
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#elseif os(macOS)
import AppKit

/// 跨平台系统分享面板（macOS：NSSharingServicePicker）
struct ActivityView: NSViewRepresentable {
    let activityItems: [Any]

    /// 创建 NSView 并在视图出现后拉起系统分享面板
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeNSView(context: Context) -> NSView {
        let hostView = NSView()
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: activityItems)
            picker.show(relativeTo: .zero, of: hostView, preferredEdge: .minY)
        }
        return hostView
    }

    /// 更新 NSView
    /// - Parameter nsView: nsView
    /// - Parameter context: context
    func updateNSView(_ nsView: NSView, context: Context) {}
}

#else
/// 跨平台系统分享面板（watchOS 空实现）
struct ActivityView: View {
    let activityItems: [Any]
    var body: some View { EmptyView() }
}
#endif
