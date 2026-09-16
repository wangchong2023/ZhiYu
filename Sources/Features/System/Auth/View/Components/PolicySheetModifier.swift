//
//  PolicySheetModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：政策弹窗 ViewModifier，消除 AuthView 与 OverseasLoginCardView 中重复的 .sheet(isPresented:) { PolicySheetContent(...) } 链。
//

import SwiftUI

/// 政策弹窗修饰符
///
/// 消除 `AuthView` 与 `OverseasLoginCardView` 中重复的
/// `.sheet(isPresented: $showXxxSheet) { PolicySheetContent(title:content:isPresented:) }` 模式。
struct PolicySheetModifier: ViewModifier {
    let isPresented: Binding<Bool>
    let title: String
    let content: String

    func body(content: Content) -> some View {
        content.sheet(isPresented: isPresented) {
            PolicySheetContent(
                title: title,
                content: self.content,
                isPresented: isPresented
            )
        }
    }
}

extension View {
    /// 附加政策弹窗（隐私政策 / 服务条款）
    func policySheet(isPresented: Binding<Bool>, title: String, content: String) -> some View {
        modifier(PolicySheetModifier(isPresented: isPresented, title: title, content: content))
    }
}
