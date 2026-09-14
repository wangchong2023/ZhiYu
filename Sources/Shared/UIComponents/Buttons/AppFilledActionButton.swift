//
//  AppFilledActionButton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：品牌色填充主操作按钮，消除 Features 中重复的 Text/HStack + font(headline) + foregroundStyle(white) + frame(maxWidth) + padding + background(appAccent) + clipShape(RoundedRectangle) 链。
//

import SwiftUI

/// 品牌色填充主操作按钮
///
/// 消除 `VoiceNoteComponents`、`PageHistoryView`、`OCRScanView`、`CollaborationView` 中重复的
/// `Text/HStack.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding().background(Color.appAccent).clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))` 模式。
public struct AppFilledActionButton: View {
    public let title: String
    public var icon: String?
    public var action: () -> Void

    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let icon {
                HStack {
                    Image(systemName: icon)
                    Text(title)
                }
            } else {
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        }
        .buttonStyle(.plain)
    }
}
