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

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage(AppConstants.Keys.Storage.colorSchemeMode) var colorSchemeModeRaw: String = ColorSchemeMode.dark.rawValue

    /// Factory 风格：属性类型标注为可选（T?），@Inject 自动使用 resolveOptional
    @Inject nonisolated private var keyStore: (any KeyStoreProtocol)?

    var accentColorRaw: String {
        get {
            keyStore?.string(forKey: AppConstants.Keys.Storage.accentColor) ?? "blue"
        }
    }

    /// Migrate legacy isDarkMode key on first access
    private nonisolated(unsafe) static var didMigrate = false

    var colorSchemeMode: ColorSchemeMode {
        get {
            if !Self.didMigrate {
                Self.didMigrate = true
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
            objectWillChange.send()
        }
    }

    /// Live color: reads from UserDefaults on every access (no cache).
    /// @AppStorage already handles observation via Combine.
    var accentColor: Color {
        ThemeManager.colorForName(accentColorRaw)
    }

    /// Maps a color name string (stored in UserDefaults) to a system Color.
    nonisolated static func colorForName(_ name: String) -> Color {
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

extension ThemeManager: @unchecked Sendable {}
