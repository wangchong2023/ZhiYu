//
//  DetailBodyFrontmatterHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：为差异化详情视图（Concept/Entity/Comparison/Source）提供统一的 Frontmatter 解析与正文拆分逻辑，
//  消除 4 个 DetailBodyView 中重复的 parseMarkdownData() 实现。
//

import SwiftUI

/// [L3] 表现层：详情页 Frontmatter 解析辅助
///
/// 统一封装 `FrontmatterParser.split` + `FrontmatterParser.parse` 两步流程，
/// 返回 `(frontmatter, bodyText)` 二元组，供各 DetailBodyView 在 `onAppear` 中一次性消费。
enum DetailBodyFrontmatterHelper {

    /// 解析页面内容，拆分 Frontmatter 与正文
    /// - Parameters:
    ///   - content: 页面原始 Markdown 内容
    ///   - frontmatterType: Frontmatter 解码目标类型（需符合 `Decodable`）
    /// - Returns: `(解析后的 Frontmatter, 剥离 Frontmatter 后的正文)`；若无法解析则 Frontmatter 为 `nil`
    static func parse<F: Decodable>(content: String, frontmatterType: F.Type) -> (frontmatter: F?, bodyText: String) {
        let (fmStr, bodyPart) = FrontmatterParser.split(content: content)
        let decoded: F? = {
            guard let fm = fmStr else { return nil }
            return FrontmatterParser.parse(F.self, from: fm)
        }()
        return (decoded, bodyPart)
    }
}

/// [L3] 表现层：详情页 onAppear Frontmatter 解析修饰符
///
/// 统一 4 个 DetailBodyView 中重复的 `onAppear { parse + assign bodyText + assign frontmatter }` 链，
/// 通过 Binding 回写解析结果，消除各视图间的 onAppear 样板代码。
struct DetailBodyOnAppearModifier<F: Decodable>: ViewModifier {
    let content: String
    let frontmatterType: F.Type
    @Binding var bodyText: String
    @Binding var frontmatter: F?

    func body(content: Content) -> some View {
        content.onAppear {
            let result = DetailBodyFrontmatterHelper.parse(content: self.content, frontmatterType: frontmatterType)
            bodyText = result.bodyText
            frontmatter = result.frontmatter
        }
    }
}

extension View {
    /// 在 onAppear 时解析页面 Frontmatter 并回写 bodyText / frontmatter
    func detailBodyOnAppear<F: Decodable>(
        content: String,
        frontmatterType: F.Type,
        bodyText: Binding<String>,
        frontmatter: Binding<F?>
    ) -> some View {
        modifier(DetailBodyOnAppearModifier(
            content: content,
            frontmatterType: frontmatterType,
            bodyText: bodyText,
            frontmatter: frontmatter
        ))
    }
}

/// [L3] 表现层：详情页正文容器修饰符
///
/// 统一 4 个 DetailBodyView 底部 `Divider + DetailBodyMarkdownSection` 的收尾布局，
/// 消除重复的 `Divider().opacity(DesignSystem.softOpacity)` 与 `bodyText.isEmpty ? page.content : bodyText` 三元判断。
struct DetailBodyEpilogue: View {
    let page: KnowledgePage
    let bodyText: String
    let onLinkTap: (String) -> Void
    var sectionTitle: String = L10n.Editor.placeholder

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
            Divider()
                .opacity(DesignSystem.softOpacity)

            DetailBodyMarkdownSection(
                title: sectionTitle,
                content: bodyText.isEmpty ? page.content : bodyText,
                isPrivate: page.isPrivate,
                onLinkTap: onLinkTap
            )
        }
    }
}
