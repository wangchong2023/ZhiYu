//
//  ThemeManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI
import UFPCore
import Dependencies

// MARK: - Theme Manager
@MainActor
@Observable
public final class ThemeManager: @unchecked Sendable {
    @ObservationIgnored private var keyStore: (any KeyStoreProtocol)?

    /// 色彩方案模式原始值（替代 @AppStorage，手动读写 KeyStore）
    public var colorSchemeModeRaw: String

    /// 迁移标记（从 static var 改为实例属性，避免全局可变状态）
    @ObservationIgnored private var didMigrate = false

    public init(keyStore: (any KeyStoreProtocol)? = nil) {
        self.keyStore = keyStore
        // 初始化时从 KeyStore 读取 colorSchemeModeRaw
        if let ks = keyStore,
           let saved = ks.string(forKey: AppConstants.Keys.Storage.colorSchemeMode) {
            self.colorSchemeModeRaw = saved
        } else {
            self.colorSchemeModeRaw = ColorSchemeMode.dark.rawValue
        }
    }

    public var accentColorRaw: String {
        keyStore?.string(forKey: AppConstants.Keys.Storage.accentColor) ?? "blue"
    }

    var colorSchemeMode: ColorSchemeMode {
        get {
            if !didMigrate {
                didMigrate = true
                // Migrate: if old key exists and new key is default
                if keyStore?.object(forKey: AppConstants.Keys.Storage.Legacy.isDarkMode) != nil,
                   keyStore?.string(forKey: AppConstants.Keys.Storage.colorSchemeMode) == nil {
                    let wasDark = keyStore?.bool(forKey: AppConstants.Keys.Storage.Legacy.isDarkMode) ?? false
                    colorSchemeModeRaw = wasDark ? ColorSchemeMode.dark.rawValue : ColorSchemeMode.light.rawValue
                    keyStore?.removeObject(forKey: AppConstants.Keys.Storage.Legacy.isDarkMode)
                }

                // 额外迁移：处理从 colorSchemeMode 到 app_color_scheme_mode 的重命名
                if let oldMode = keyStore?.string(forKey: AppConstants.Keys.Storage.Legacy.colorSchemeMode),
                   keyStore?.string(forKey: AppConstants.Keys.Storage.colorSchemeMode) == nil {
                    colorSchemeModeRaw = oldMode
                    keyStore?.removeObject(forKey: AppConstants.Keys.Storage.Legacy.colorSchemeMode)
                }

                if let oldAccent = keyStore?.string(forKey: AppConstants.Keys.Storage.Legacy.accentColor),
                   keyStore?.string(forKey: AppConstants.Keys.Storage.accentColor) == nil {
                    keyStore?.set(oldAccent, forKey: AppConstants.Keys.Storage.accentColor)
                    keyStore?.removeObject(forKey: AppConstants.Keys.Storage.Legacy.accentColor)
                }
            }
            return ColorSchemeMode(rawValue: colorSchemeModeRaw) ?? .dark
        }
        set {
            colorSchemeModeRaw = newValue.rawValue
            // 持久化到 KeyStore
            keyStore?.set(newValue.rawValue, forKey: AppConstants.Keys.Storage.colorSchemeMode)
        }
    }

    /// Live color: reads from UserDefaults on every access (no cache).
    var accentColor: Color {
        ThemeManager.colorForName(accentColorRaw)
    }

    /// Maps a color name string (stored in UserDefaults) to a system Color.
    nonisolated public static func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .blue
        }
    }

    /// Instance method wrapper for convenience.
    nonisolated func colorForName(_ name: String) -> Color {
        Self.colorForName(name)
    }

    /// 提供统一的背景渲染入口
    @MainActor

    /// pageBackground
    func pageBackground() -> some View {
        PageBackgroundView(accentColor: accentColor)
    }
}

// MARK: - ThemeManager DependencyKey

private enum ThemeManagerKey: DependencyKey {
    @MainActor
    static var liveValue: ThemeManager {
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        return ThemeManager(keyStore: keyStore)
    }
    @MainActor
    static let testValue: ThemeManager = {
        guard let defaults = UserDefaults(suiteName: "test") else {
            return ThemeManager(keyStore: nil)
        }
        return ThemeManager(keyStore: UserDefaultsKeyStore(defaults: defaults))
    }()
    @MainActor
    static let previewValue: ThemeManager = ThemeManager(keyStore: nil)
}

extension DependencyValues {
    /// 主题服务依赖（原 ThemeManager.shared）
    var themeService: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }

    /// KeyStore 服务依赖（用于 ThemeManager 注入 KeyStoreProtocol）
    var keyStoreService: (any KeyStoreProtocol)? {
        get { self[KeyStoreServiceKey.self] }
        set { self[KeyStoreServiceKey.self] = newValue }
    }
}

private enum KeyStoreServiceKey: DependencyKey {
    @MainActor
    static var liveValue: (any KeyStoreProtocol)? {
        ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
    }
    @MainActor
    static let testValue: (any KeyStoreProtocol)? = {
        guard let defaults = UserDefaults(suiteName: "test") else {
            return nil as (any KeyStoreProtocol)?
        }
        return UserDefaultsKeyStore(defaults: defaults)
    }()
    @MainActor
    static let previewValue: (any KeyStoreProtocol)? = nil
}
