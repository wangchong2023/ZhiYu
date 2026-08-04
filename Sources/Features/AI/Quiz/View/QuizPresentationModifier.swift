//
//  QuizPresentationModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：AI 测验功能：自动生成与交互式答题。
//
import SwiftUI

/// 测验展示修饰符
/// 针对 iPad 提供 Sheet 展示，针对 iPhone 提供全屏覆盖展示。
struct QuizPresentationModifier: ViewModifier {
    @Binding var activeQuiz: QuizModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.interfaceIdiom) private var idiom

    init(activeQuiz: Binding<QuizModel?>) {
        self._activeQuiz = activeQuiz
    }

    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    public func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .sheet(item: $activeQuiz) { quiz in
                    QuizView(quiz: quiz)
                        .frame(minWidth: Spacing.Decorator.desktopSheetMinWidth, minHeight: Spacing.Decorator.desktopSheetMinHeight)
                }
        } else {
            if idiom == .iPhone || idiom == .iPad {
                content
                    .fullScreenCover(item: $activeQuiz) { quiz in
                        QuizView(quiz: quiz)
                    }
            } else {
                content
                    .sheet(item: $activeQuiz) { quiz in
                        QuizView(quiz: quiz)
                    }
            }
        }
    }
}

extension View {
    /// 应用测验展示模态
    func quizPresentation(activeQuiz: Binding<QuizModel?>) -> some View {
        modifier(QuizPresentationModifier(activeQuiz: activeQuiz))
    }
}
