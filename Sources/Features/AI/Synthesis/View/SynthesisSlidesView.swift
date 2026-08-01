//
//  SynthesisSlidesView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：提供 AI 演示文稿（Slides / 幻灯片）卡片式翻页预览与沉浸展示。
//

import SwiftUI

/// 渲染演示文稿 / 幻灯片类型的合成文档
struct SynthesisSlidesView: View {
    let doc: SynthesisStore.SynthesisDocument
    @State private var currentSlideIndex = 0

    private var slides: [String] {
        let content = doc.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSlides = content.components(separatedBy: "\n---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if rawSlides.isEmpty {
            return [content]
        }
        return rawSlides
    }

    var body: some View {
        VStack(spacing: DesignSystem.medium) {
            // 页码与控制顶部栏
            HStack {
                Label(L10n.AI.Prompt.Expert.Slides.title, systemImage: "play.rectangle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.appAccent)

                Spacer()

                Text("\(currentSlideIndex + 1) / \(slides.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, DesignSystem.small)
                    .padding(.vertical, DesignSystem.tiny)
                    .background(Capsule().fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle)))
                    .foregroundStyle(.appAccent)
            }
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.top, DesignSystem.small)

            // 幻灯片TabView
            TabView(selection: $currentSlideIndex) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slideContent in
                    slideCard(content: slideContent, pageIndex: index + 1)
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .frame(maxHeight: .infinity)

            // 底部翻页控制器
            HStack(spacing: DesignSystem.loosePadding) {
                Button(action: {
                    if currentSlideIndex > 0 {
                        withAnimation { currentSlideIndex -= 1 }
                        HapticFeedback.shared.trigger(.selection)
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(currentSlideIndex > 0 ? Color.appAccent : Color.appSecondary.opacity(DesignSystem.Opacity.soft))
                }
                .disabled(currentSlideIndex == 0)

                Button(action: {
                    if currentSlideIndex < slides.count - 1 {
                        withAnimation { currentSlideIndex += 1 }
                        HapticFeedback.shared.trigger(.selection)
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(currentSlideIndex < slides.count - 1 ? Color.appAccent : Color.appSecondary.opacity(DesignSystem.Opacity.soft))
                }
                .disabled(currentSlideIndex >= slides.count - 1)
            }
            .padding(.bottom, DesignSystem.medium)
        }
        .background(Color.appBackground)
    }

    private func slideCard(content: String, pageIndex: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                MarkdownRendererView(content: content, isPrivate: false, onLinkTap: { _ in })
                    .padding(DesignSystem.loosePadding)
            }
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                    .fill(Color.appCard)
                    .shadow(color: .black.opacity(DesignSystem.Opacity.soft), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, DesignSystem.small)
        }
    }
}
