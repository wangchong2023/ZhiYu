//
//  CommonPaddingModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：通用内边距 ViewModifier，消除 Features 中重复的 padding(.horizontal, DesignSystem.standardPadding) + padding(.vertical, ...) 链。
//

import SwiftUI

/// 通用内边距修饰符，消除重复的 horizontal+vertical padding 链
struct CommonPaddingModifier: ViewModifier {
    var horizontal: CGFloat = DesignSystem.standardPadding
    var vertical: CGFloat = SystemSpacing.elementLarge

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
    }
}

extension View {
    /// 标准内容内边距：horizontal=standardPadding, vertical=elementLarge
    func commonContentPadding(
        horizontal: CGFloat = DesignSystem.standardPadding,
        vertical: CGFloat = SystemSpacing.elementLarge
    ) -> some View {
        modifier(CommonPaddingModifier(horizontal: horizontal, vertical: vertical))
    }
}
