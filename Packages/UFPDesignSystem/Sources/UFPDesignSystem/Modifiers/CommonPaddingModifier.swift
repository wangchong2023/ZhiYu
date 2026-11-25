//
//  CommonPaddingModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：通用内边距 ViewModifier，消除 Features 中重复的 padding(.horizontal, DesignTokens.Spacing.standardPadding) + padding(.vertical, ...) 链。
//

import SwiftUI

/// 通用内边距修饰符，消除重复的 horizontal+vertical padding 链
public struct CommonPaddingModifier: ViewModifier {
    public var horizontal: CGFloat = DesignTokens.Spacing.standardPadding
    public var vertical: CGFloat = DesignTokens.SystemSpacing.elementLarge

    public init(
        horizontal: CGFloat = DesignTokens.Spacing.standardPadding,
        vertical: CGFloat = DesignTokens.SystemSpacing.elementLarge
    ) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
    }
}

public extension View {
    /// 标准内容内边距：horizontal=standardPadding, vertical=elementLarge
    func commonContentPadding(
        horizontal: CGFloat = DesignTokens.Spacing.standardPadding,
        vertical: CGFloat = DesignTokens.SystemSpacing.elementLarge
    ) -> some View {
        modifier(CommonPaddingModifier(horizontal: horizontal, vertical: vertical))
    }
}
