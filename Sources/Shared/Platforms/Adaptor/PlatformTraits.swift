//
//  PlatformTraits.swift
//  ZhiYu
//
//  系统层级：[L0] 基础设施层
//  核心职责：跨平台运行时 Trait，把 platform idiom 暴露为 EnvironmentValue，
//           替代业务层编译时 #if os() 宏。
//

import SwiftUI

// MARK: - InterfaceIdiom 枚举

/// 当前设备形态（运行时读取，替代编译时 #if os()）
///
/// - Note: 保留 `macCatalyst` case 以精确区分原生 macOS 与 Mac Catalyst，
///   消除 `#if targetEnvironment(macCatalyst)` 宏。
public enum InterfaceIdiom: Sendable, Equatable {
    case iPhone
    case iPad
    case mac
    case macCatalyst
    case watch
}

// MARK: - interfaceIdiom Trait（静态 defaultValue）

/// 设备形态 Trait Key
///
/// - Note: 设备形态在 App 运行期间不会变化（iPhone 不会变成 iPad），
///   故用静态 `defaultValue` 而非 `UITraitBridgedEnvironmentKey`。
internal struct InterfaceIdiomKey: EnvironmentKey {
    static let defaultValue: InterfaceIdiom = {
        #if os(watchOS)
        return .watch
        #elseif os(macOS)
        return .mac
        #else
        #if targetEnvironment(macCatalyst)
        return .macCatalyst
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #endif
        #endif
    }()
}

extension EnvironmentValues {
    /// 当前设备形态（运行时读取）
    public var interfaceIdiom: InterfaceIdiom {
        get { self[InterfaceIdiomKey.self] }
        set { self[InterfaceIdiomKey.self] = newValue }
    }
}

// MARK: - prefersTabNavigation Trait（响应运行时变化）

/// Tab 导航偏好 Trait Key
///
/// - Note: iPad 旋转屏幕时 `horizontalSizeClass` 变化，该值需自动更新。
///   - iOS/macOS：用 `UITraitBridgedEnvironmentKey` 从 `UITraitCollection` 读取，
///     仅 iOS 17+ / macOS 14+ 可用（ZhiYu 部署目标满足）。
///   - watchOS：`UITraitBridgedEnvironmentKey` 不可用，且 watch 无横竖屏旋转概念，
///     退化为静态 `EnvironmentKey`，默认值 `false`。
#if os(iOS) || os(macOS)
internal struct PrefersTabNavigationKey: UITraitBridgedEnvironmentKey {
    static let defaultValue: Bool = false

    static func read(from traitCollection: UITraitCollection) -> Bool {
        traitCollection.userInterfaceIdiom == .pad && traitCollection.horizontalSizeClass != .compact
    }

    static func write(to mutableTraits: inout any UIMutableTraits, value: Bool) {
        // 只读 Trait，不回写 UITraitCollection
    }
}
#else
internal struct PrefersTabNavigationKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
#endif

extension EnvironmentValues {
    /// 是否偏好 Tab 导航（iPad 横屏 true，竖屏 false；iPhone/Mac/watch false）
    ///
    /// 对齐 Apple Backyard Birds `prefersTabNavigation` 模式。
    public var prefersTabNavigation: Bool {
        get { self[PrefersTabNavigationKey.self] }
        set { self[PrefersTabNavigationKey.self] = newValue }
    }
}

// MARK: - supportsTouch Trait（静态 defaultValue）

/// 触控支持 Trait Key
///
/// - Note: 硬件触控能力在 App 运行期间不会变化，故用静态 `defaultValue`。
internal struct SupportsTouchKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS) || os(watchOS)
        return true
        #else
        return false
        #endif
    }()
}

extension EnvironmentValues {
    /// 是否支持触控交互（iOS/watchOS true，macOS false）
    public var supportsTouch: Bool {
        get { self[SupportsTouchKey.self] }
        set { self[SupportsTouchKey.self] = newValue }
    }
}

// MARK: - supportsFullScreenImmersive Trait（静态 defaultValue）

/// 全屏沉浸支持 Trait Key
///
/// - Note: 平台 API 能力在 App 运行期间不会变化，故用静态 `defaultValue`。
internal struct SupportsFullScreenImmersiveKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }()
}

extension EnvironmentValues {
    /// 是否支持全屏沉浸模式（iOS/macOS true，watchOS false）
    public var supportsFullScreenImmersive: Bool {
        get { self[SupportsFullScreenImmersiveKey.self] }
        set { self[SupportsFullScreenImmersiveKey.self] = newValue }
    }
}
