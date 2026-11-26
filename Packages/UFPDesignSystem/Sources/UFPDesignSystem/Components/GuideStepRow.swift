//
//  GuideStepRow.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：引导步骤行通用组件，提供带数字序号的渐变圆圈和描述文本。
//

import SwiftUI

/// 引导步骤行组件
/// 提供带数字序号的渐变圆圈和描述文本。
public struct GuideStepRow: View {
    // MARK: - Properties

    public let number: Int
    public let text: String
    public let icon: String

    // MARK: - Initialization

    public init(number: Int, text: String, icon: String) {
        self.number = number
        self.text = text
        self.icon = icon
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: DesignTokens.SystemSpacing.contentMedium) {
            // 带数字序号的渐变圆
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.appAccent, .appAccent.opacity(DesignTokens.Colors.secondaryOpacity)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DesignTokens.Spacing.largeIconSize, height: DesignTokens.Spacing.largeIconSize)
                    .shadow(
                        color: .appAccent.opacity(DesignTokens.Colors.disabledOpacity),
                        radius: DesignTokens.SystemSpacing.tiny,
                        x: 0,
                        y: DesignTokens.SystemSpacing.atomic
                    )

                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.appText)

            Spacer()
        }
    }
}
