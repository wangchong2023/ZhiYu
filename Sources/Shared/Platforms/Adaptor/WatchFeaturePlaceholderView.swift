//
//  WatchFeaturePlaceholderView.swift
//  ZhiYu
//
//  系统层级：[L0] 基础设施层（平台适配）
//  核心职责：watchOS 端功能占位通用 View，替代 Features 层 #if os(watchOS) 占位代码。
//
//  - Note: 跨平台可见（无 #if os(watchOS) 包裹）。View 本身可在所有平台编译，
//    但仅在运行时 `interfaceIdiom == .watch` 时被 Features 层渲染分发。
//

import SwiftUI

/// watchOS 功能占位通用 View
///
/// 当某功能在 watchOS 不支持时，显示引导用户在 iPhone 上使用的占位界面。
/// 替代 Features 层散落的 `#if os(watchOS)` 占位代码。
@MainActor
struct WatchFeaturePlaceholderView: View {
    /// 占位提示文案（通过 L10n 强类型访问）
    let placeholderMessage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.standardPadding) {
                Image(systemName: "iphone")
                    .font(.system(size: DesignSystem.largeIconSize))
                    .foregroundStyle(Color.theme.purple)

                Text(placeholderMessage)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.theme.secondaryText)
            }
            .padding(DesignSystem.standardPadding)
        }
    }
}
