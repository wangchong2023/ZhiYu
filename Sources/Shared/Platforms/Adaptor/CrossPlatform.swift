//
//  CrossPlatform.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：跨平台适配器：统一不同平台的类型别名与 API 差异。
//
import Foundation
import UFPCore

/// 跨平台剪贴板包装器
@MainActor
enum AppPasteboard {
    /// 获取或设置系统剪贴板文本
    static var string: String? {
        get { service.string }
        set { 
            let s = service
            s.string = newValue 
        }
    }
    
    /// 内部持有的具体实现
    private static var service: any PasteboardProtocol {
        ServiceContainer.shared.resolve((any PasteboardProtocol).self)
    }
}

/// 跨平台图片类型别名
#if os(iOS)
import UIKit
public typealias AppImage = UIImage
#elseif os(macOS)
import AppKit
public typealias AppImage = NSImage
#elseif os(watchOS)
import WatchKit
public struct AppImage: Sendable {}
#else
public struct AppImage: Sendable {}
#endif

// MARK: - 跨平台屏幕工具

/// 跨平台屏幕尺寸适配工具
/// 封装 UIScreen / WKInterfaceDevice 差异，避免 Features 层直接依赖平台 API
public enum AppScreen {
    /// AI 对话气泡最大宽度（屏幕宽度的 85%，watchOS 为 90%）
    @MainActor
    public static var bubbleMaxWidth: CGFloat {
        #if os(watchOS)
        return WKInterfaceDevice.current().screenBounds.width * 0.9
        #else
        return UIScreen.main.bounds.width * 0.85
        #endif
    }
}
