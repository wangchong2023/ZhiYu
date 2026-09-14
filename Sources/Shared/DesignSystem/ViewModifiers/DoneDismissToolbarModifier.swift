//
//  DoneDismissToolbarModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：统一二级页面顶栏「完成」按钮 + inline 标题模式，消除 AISettingsView /
//  DeveloperSettingsView / SystemStatsView / FeedbackView 等重复的 toolbar 链。
//

import SwiftUI

/// 二级页面统一的「完成」关闭按钮 + inline 导航标题工具栏修饰符
struct DoneDismissToolbarModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                    .bold()
                }
            }
    }
}

extension View {
    /// 应用统一的「完成」关闭按钮 + inline 导航标题工具栏
    func doneDismissToolbar() -> some View {
        modifier(DoneDismissToolbarModifier())
    }
}
