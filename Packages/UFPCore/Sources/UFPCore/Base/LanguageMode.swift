//
//  LanguageMode.swift
//  UFPCore
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：系统支持的语言模式枚举（与业务无关）。
//           displayName 等依赖业务 L10n 词条的属性由 App 层扩展补充。
//

import Foundation

/// 系统支持的语言模式定义。
public enum LanguageMode: String, CaseIterable, Identifiable, Sendable {
    /// 自动随系统首选语言环境。
    case auto = "auto"

    /// 强制英文环境。
    case english = "en"

    /// 强制简体中文环境。
    case chinese = "zh-Hans"

    /// 强制繁体中文环境。
    case traditionalChinese = "zh-Hant"

    /// 强制西班牙语环境。
    case spanish = "es"

    /// 强制法语环境。
    case french = "fr"

    /// 强制阿拉伯语环境。
    case arabic = "ar"

    /// 强制俄语环境。
    case russian = "ru"

    /// 强制韩语环境。
    case korean = "ko"

    /// 强制日语环境。
    case japanese = "ja"

    /// 强制葡萄牙语环境。
    case portuguese = "pt"

    /// 遵循 Identifiable 协议的唯一识别码。
    public var id: String { self.rawValue }
}