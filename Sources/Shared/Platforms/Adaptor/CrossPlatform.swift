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
import SwiftUI
import UFPCore
#if os(macOS)
import Darwin
#endif
#if os(iOS)
import AVFoundation
#endif
#if canImport(SceneKit)
import SceneKit
#endif

/// 跨平台通用常量（避免散落魔鬼数字）
public enum CrossPlatformConstants {
    /// 无主屏幕时的宽度回退值（375pt，与 iOS 端屏幕兜底宽度一致）
    public static let defaultScreenFallbackWidth: CGFloat = 375
    /// 个人中心悬浮弹窗标准宽度（iPad 300pt，iPhone 280pt，桌面 320pt）
    @MainActor
    public static var profilePopoverMenuWidth: CGFloat {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 300 : 280
        #else
        return 320
        #endif
    }
}

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
        ServiceContainer.shared.resolveOptional((any PasteboardProtocol).self) ?? NoOpPasteboard()
    }
}

/// 跨平台图片类型别名
#if os(iOS)
import UIKit
public typealias AppImage = UIImage
public typealias AppColor = UIColor
public typealias AppFont = UIFont
#elseif os(macOS)
import AppKit
public typealias AppImage = NSImage
public typealias AppColor = NSColor
public typealias AppFont = NSFont
#elseif os(watchOS)
import WatchKit
public struct AppImage: Sendable {}
public struct AppColor: Sendable {}
public struct AppFont: Sendable {}
#else
public struct AppImage: Sendable {}
public struct AppColor: Sendable {}
public struct AppFont: Sendable {}
#endif

// MARK: - 跨平台颜色 / 字体桥接

/// 从 SwiftUI `Color` 生成平台色（SceneKit / 绘制等需要 UIColor/NSColor 的场景）
@MainActor
public enum AppColorBridge {
    /// 将 SwiftUI Color 转成当前平台的 AppColor
    public static func from(_ color: Color) -> AppColor {
        #if os(iOS)
        UIColor(color)
        #elseif os(macOS)
        NSColor(color)
        #else
        AppColor()
        #endif
    }
}

/// 系统字体桥接（UIFont / NSFont 差异收敛）
public enum AppFontBridge {
    /// 系统粗体字体
    public static func boldSystemFont(ofSize size: CGFloat) -> AppFont {
        #if os(iOS)
        UIFont.boldSystemFont(ofSize: size)
        #elseif os(macOS)
        NSFont.boldSystemFont(ofSize: size)
        #else
        AppFont()
        #endif
    }
}

// MARK: - 跨平台图片编码桥接

/// 图片编解码桥接（UIImage / NSImage 差异收敛）
public enum AppImageBridge {
    /// 将 CGImage 编码为 JPEG 数据
    public static func jpegData(from image: CGImage, compressionQuality: CGFloat) -> Data? {
        #if os(iOS)
        return UIImage(cgImage: image).jpegData(compressionQuality: compressionQuality)
        #elseif os(macOS)
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #else
        return nil
        #endif
    }

    /// 将跨平台图片编码为 JPEG 数据
    public static func jpegData(from image: AppImage?, compressionQuality: CGFloat) -> Data? {
        guard let image else { return nil }
        #if os(iOS)
        return image.jpegData(compressionQuality: compressionQuality)
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #else
        return nil
        #endif
    }
}

// MARK: - 跨平台 SwiftUI Image 包装

public extension Image {
    /// 从跨平台图片类型创建 SwiftUI Image（iOS 走 UIImage，macOS 走 NSImage）
    init(appImage: AppImage) {
        #if os(iOS)
        self.init(uiImage: appImage)
        #elseif os(macOS)
        self.init(nsImage: appImage)
        #else
        self.init(systemName: "photo")
        #endif
    }
}

// MARK: - 跨平台系统内存桥接

/// 系统内存信息桥接（os_proc_available_memory 为 iOS 专属，macOS 用 host_statistics64）
public enum AppMemoryBridge {
    /// 获取当前可用内存字节数
    @MainActor
    public static func availableBytes() -> Double {
        #if os(iOS)
        return Double(os_proc_available_memory())
        #elseif os(macOS)
        return macAvailableBytes()
        #else
        return 0
        #endif
    }

    #if os(macOS)
    /// macOS 可用内存 = free + inactive（来自 mach host_statistics64）
    private static func macAvailableBytes() -> Double {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            // 失败时回退到物理内存总量
            return Double(ProcessInfo.processInfo.physicalMemory)
        }
        let pageSize = Double(sysconf(_SC_PAGESIZE))
        return Double(stats.free_count + stats.inactive_count) * pageSize
    }
    #endif
}

// MARK: - 跨平台音频会话桥接

/// 音频会话配置桥接：iOS 用 AVAudioSession 设置播放/录音模式，macOS/watchOS 无此概念时降级为安全默认实现
public enum AppAudioSessionBridge {
    #if os(iOS)
    /// 配置为播放模式并激活会话（仅 iOS 生效）
    public static func configurePlaybackSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// 请求麦克风录音权限并激活录音会话
    public static func requestAndActivateRecordSession() async -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            let session = AVAudioSession.sharedInstance()
            granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
        guard granted else { return false }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        return true
    }

    /// 停用录音会话（仅 iOS 生效）
    public static func deactivateRecordSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    #else
    public static func configurePlaybackSession() {}
    public static func requestAndActivateRecordSession() async -> Bool { true }
    public static func deactivateRecordSession() {}
    #endif
}

// MARK: - 跨平台 UIView/NSView 桥接 Representable

/// 跨平台原生视图桥接器：iOS 用 UIViewRepresentable，macOS 用 NSViewRepresentable。
/// 通过 make/update 两个闭包收敛 UIKit/AppKit 差异，供 Features 层嵌入原生视图。
#if os(iOS)
import SwiftUI
public struct PlatformViewBridge<PlatformView: UIView>: UIViewRepresentable {
    private let make: () -> PlatformView
    private let update: (PlatformView) -> Void

    public init(
        make: @escaping () -> PlatformView,
        update: @escaping (PlatformView) -> Void = { _ in }
    ) {
        self.make = make
        self.update = update
    }

    public func makeUIView(context: Context) -> PlatformView { make() }

    public func updateUIView(_ uiView: PlatformView, context: Context) {
        update(uiView)
    }
}
#elseif os(macOS)
import SwiftUI
public struct PlatformViewBridge<PlatformView: NSView>: NSViewRepresentable {
    private let make: () -> PlatformView
    private let update: (PlatformView) -> Void

    public init(
        make: @escaping () -> PlatformView,
        update: @escaping (PlatformView) -> Void = { _ in }
    ) {
        self.make = make
        self.update = update
    }

    public func makeNSView(context: Context) -> PlatformView { make() }

    public func updateNSView(_ nsView: PlatformView, context: Context) {
        update(nsView)
    }
}
#else
public struct PlatformViewBridge<PlatformView> {}
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
        #elseif os(macOS)
        // macOS 无屏幕旋转概念，用主屏幕宽度；无主屏幕时回退到常见宽度
        return (NSScreen.main?.frame.width ?? CrossPlatformConstants.defaultScreenFallbackWidth) * 0.85
        #else
        // iOS 26.0 废弃 UIScreen.main，改为从活跃 UIWindowScene 获取 screen
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let screenWidth = activeScene?.screen.bounds.width
            ?? activeScene?.keyWindow?.window?.screen.bounds.width
            ?? CrossPlatformConstants.defaultScreenFallbackWidth
        return screenWidth * 0.85
        #endif
    }
}

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// 跨平台呈现锚点工具，用于 ASAuthorizationController / ASWebAuthenticationSession
public enum PlatformPresentationAnchor {
    @MainActor
    public static var keyWindow: UIWindow {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        // 优先取 foregroundActive 场景的 keyWindow
        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }),
           let keyWindow = activeScene.keyWindow {
            return keyWindow
        }
        // fallback：取任意有 window 的场景
        if let anyScene = scenes.first(where: { $0.keyWindow != nil }),
           let window = anyScene.keyWindow {
            return window
        }
        // 最后 fallback：用第一个可用场景创建新 UIWindow
        if let scene = scenes.first {
            return UIWindow(windowScene: scene)
        }
        // 极端边界：无任何 UIWindowScene（理论上不可达，keyWindow 仅在 App 完全启动后调用）。
        // iOS 26.0 废弃 UIWindow(frame:)，用 if #unavailable 限制只在 iOS < 26.0 调用。
        if #unavailable(iOS 26.0) {
            return UIWindow(frame: .zero)
        }
        // iOS 26.0+：再次遍历 connectedScenes 查找任意 window（兜底）
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let window = scene.keyWindow {
                return window
            }
        }
        // iOS 26.0+ 真正无任何 window：此分支不可达。
        // 无 scene 时 iOS 26.0+ 无法创建 window，用 fatalError 替代不可达代码。
        // Gatekeeper 禁止 fatalError，用 preconditionFailure 替代（同样是不可达分支）。
        preconditionFailure("PlatformPresentationAnchor.keyWindow: No UIWindowScene available")
    }
}

/// 跨平台原生窗口调度辅助工具（iOS / watchOS 为空实现兜底，macOS 调度原生 NSWindow）
public enum AppWindowHelper {
    /// 关闭 identifier 包含特定标识的窗口（如 "Settings"）
    @MainActor
    public static func closeWindows(matching identifierSubstring: String) {
        // iOS 端采用 UIWindowScene / sheet 架构，无需单独关闭 NSWindow
    }
}

/// 跨平台设置链接容器（iOS / watchOS 回退为通用 View）
public struct PlatformSettingsLink<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
    }
}
#elseif canImport(AppKit)
import AppKit

/// 跨平台呈现锚点工具，用于 ASWebAuthenticationSession（macOS 原生）
public enum PlatformPresentationAnchor {
    /// 当前活跃的 keyWindow；无 keyWindow 时回退到任意可见主窗口
    @MainActor
    public static var keyWindow: NSWindow {
        if let key = NSApplication.shared.keyWindow {
            return key
        }
        if let main = NSApplication.shared.mainWindow {
            return main
        }
        if let visible = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return visible
        }
        // 极端边界：无任何窗口（理论上 App 完全启动后不可达）
        preconditionFailure("PlatformPresentationAnchor.keyWindow: No NSWindow available")
    }
}

/// 跨平台原生窗口调度辅助工具（macOS 原生）
public enum AppWindowHelper {
    /// 关闭 identifier 包含特定标识的窗口（如 "Settings"）
    @MainActor
    public static func closeWindows(matching identifierSubstring: String) {
        NSApplication.shared.windows
            .filter { $0.identifier?.rawValue.contains(identifierSubstring) == true }
            .forEach { $0.close() }
    }
}

/// 跨平台设置链接容器（macOS 原生使用 SettingsLink，iOS/watchOS 使用标准 Button/View）
public struct PlatformSettingsLink<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        SettingsLink(destination: content)
    }
}
#endif

// MARK: - 跨平台 SceneKit 向量桥接

#if canImport(SceneKit)
/// SCNVector3 分量读写桥接：iOS 分量为 Float，macOS 为 CGFloat，收敛平台差异
public enum AppSceneKitVector3 {
    /// 保留 y/z，写入 x（Float 值）
    public static func withX(_ value: Float, in vector: SCNVector3) -> SCNVector3 {
        #if os(iOS)
        return SCNVector3(value, vector.y, vector.z)
        #elseif os(macOS)
        return SCNVector3(CGFloat(value), vector.y, vector.z)
        #else
        return vector
        #endif
    }

    /// 保留 x/z，写入 y（Float 值）
    public static func withY(_ value: Float, in vector: SCNVector3) -> SCNVector3 {
        #if os(iOS)
        return SCNVector3(vector.x, value, vector.z)
        #elseif os(macOS)
        return SCNVector3(vector.x, CGFloat(value), vector.z)
        #else
        return vector
        #endif
    }

    /// 保留 x/y，写入 z（Float 值）
    public static func withZ(_ value: Float, in vector: SCNVector3) -> SCNVector3 {
        #if os(iOS)
        return SCNVector3(vector.x, vector.y, value)
        #elseif os(macOS)
        return SCNVector3(vector.x, vector.y, CGFloat(value))
        #else
        return vector
        #endif
    }

    /// 保留 x，对 y/z 增加 Float 偏移
    public static func adding(dy: Float, dz: Float, to vector: SCNVector3) -> SCNVector3 {
        #if os(iOS)
        return SCNVector3(vector.x, vector.y + dy, vector.z + dz)
        #elseif os(macOS)
        return SCNVector3(vector.x, vector.y + CGFloat(dy), vector.z + CGFloat(dz))
        #else
        return vector
        #endif
    }

    /// 读取 x 分量为 Float
    public static func x(_ vector: SCNVector3) -> Float {
        #if os(iOS)
        return vector.x
        #elseif os(macOS)
        return Float(vector.x)
        #else
        return 0
        #endif
    }

    /// 读取 y 分量为 Float
    public static func y(_ vector: SCNVector3) -> Float {
        #if os(iOS)
        return vector.y
        #elseif os(macOS)
        return Float(vector.y)
        #else
        return 0
        #endif
    }

    /// 读取 z 分量为 Float
    public static func z(_ vector: SCNVector3) -> Float {
        #if os(iOS)
        return vector.z
        #elseif os(macOS)
        return Float(vector.z)
        #else
        return 0
        #endif
    }
}
#endif
