//
//  AccentIconBox.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：Accent 图标块组件，消除 Features 中重复的 Image + font + foregroundStyle + frame + background + clipShape 链。
//

import SwiftUI

/// Accent 图标块组件
///
/// 消除 `SourceDetailBodyView` 与 `RawStorageListView` 中重复的
/// `Image(systemName:).font(.system(size: DesignSystem.large)).foregroundStyle(.appAccent).frame(width:height:).background(Color.appAccent.opacity(DesignSystem.glassOpacity)).clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))` 模式。
public struct AccentIconBox: View {
    public let iconName: String
    public var fontSize: CGFloat
    public var boxSize: CGFloat
    public var cornerRadius: CGFloat
    public var backgroundOpacity: Double

    public init(
        iconName: String,
        fontSize: CGFloat = DesignSystem.large,
        boxSize: CGFloat = DesignSystem.Metrics.largeIconBoxSize,
        cornerRadius: CGFloat = DesignSystem.smallRadius,
        backgroundOpacity: Double = DesignSystem.glassOpacity
    ) {
        self.iconName = iconName
        self.fontSize = fontSize
        self.boxSize = boxSize
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
    }

    public var body: some View {
        Image(systemName: iconName)
            .font(.system(size: fontSize))
            .foregroundStyle(.appAccent)
            .frame(width: boxSize, height: boxSize)
            .background(Color.appAccent.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
