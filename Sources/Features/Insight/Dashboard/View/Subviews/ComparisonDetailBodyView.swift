//
//  ComparisonDetailBodyView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：渲染“对比 (Comparison)”类型页面的差异化排版，包含多维对照决策矩阵网络、对比可视化滑块以及大模型结论板。
//

import SwiftUI

/// [L3] 表现层：对比页面差异化详情视图
struct ComparisonDetailBodyView: View {
    let page: KnowledgePage
    let onLinkTap: (String) -> Void
    
    @State private var frontmatter: ComparisonFrontmatter?
    @State private var bodyText: String = ""
    
    // 布局微调常数，防止魔鬼数字与 frame 写死
    private static let borderGradientWidth: CGFloat = 1.0
    private static let ratingMaxStars: Int = 5
    private static let maxSubjectsCount = 3
    
    private static let detailFontSize: CGFloat = 8
    private static let starFontSize: CGFloat = 7
    private static let rangeTextSize: CGFloat = 8
    private static let progressLineHeight: CGFloat = 3
    private static let mockProgressScale: CGFloat = 0.7
    private static let rangeBoxWidth: CGFloat = 50
    private static let badgeFontSize: CGFloat = 7
    private static let badgeHorizontalPadding: CGFloat = 4
    private static let badgeVerticalPadding: CGFloat = 2
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
            // 1. 结论板 (Recommendation Panel)
            recommendationPanelSection
            
            // 2. 多维指标对照表格 (Matrix Grid)
            if let subjects = frontmatter?.subjects, !subjects.isEmpty,
               let dimensions = frontmatter?.dimensions, !dimensions.isEmpty {
                matrixGridSection(subjects: subjects, dimensions: dimensions)
            }
            
            // 3. 详细正文渲染
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                Text(L10n.Editor.placeholder)
                    .font(.caption2.bold())
                    .foregroundStyle(.appSecondary)
                
                MarkdownRendererView(
                    content: bodyText.isEmpty ? page.content : bodyText,
                    isPrivate: page.isPrivate,
                    onLinkTap: onLinkTap
                )
            }
        }
        .onAppear {
            parseMarkdownData()
        }
    }
    
    /// 解析 Markdown 及头部 Frontmatter
    private func parseMarkdownData() {
        let (fmStr, bodyPart) = FrontmatterParser.split(content: page.content)
        self.bodyText = bodyPart
        if let fm = fmStr, let decoded = FrontmatterParser.parse(ComparisonFrontmatter.self, from: fm) {
            self.frontmatter = decoded
        }
    }
    
    // MARK: - 1. 结论板 (Recommendation Panel)
    private var recommendationPanelSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: Spacing.small) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.headline)
                    .foregroundStyle(Color.theme.purple)
                
                Text(L10n.Onboarding.featureList) // 决策推荐
                    .font(.headline.bold())
                    .foregroundStyle(.appText)
            }
            
            // 尝试从正文首行抓取总结，若无则展示通用决策占位文本
            let summary = extractFirstLineSummary()
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.standardPadding)
        .background(Color.appCard.opacity(DesignSystem.Opacity.ghost))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.theme.purple.opacity(DesignSystem.Opacity.disabled), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: Self.borderGradientWidth
                )
        )
    }
    
    private func extractFirstLineSummary() -> String {
        let cleanText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty {
            return L10n.Vault.comparison.recommendationDefault
        }
        let lines = cleanText.components(separatedBy: .newlines)
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && !t.hasPrefix("#") && !t.hasPrefix("-") && !t.hasPrefix("*") {
                return t
            }
        }
        return L10n.Vault.comparison.recommendationFallback
    }
    
    // MARK: - 2. 多维指标对照表格 (Matrix Grid)
    private func matrixGridSection(
        subjects: [ComparisonFrontmatter.ComparisonSubject],
        dimensions: [ComparisonFrontmatter.ComparisonDimension]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Label(L10n.Dashboard.stats.title, systemImage: "grid") // 对比指标网格标签
                .font(.subheadline.bold())
                .foregroundStyle(.appSecondary)
            
            // 只取前 3 个 Subjects 进行网格排列，防止横向溢出
            let displaySubjects = subjects.prefix(Self.maxSubjectsCount)
            
            VStack(spacing: Spacing.small) {
                // 表头
                HStack(spacing: Spacing.medium) {
                    Text(L10n.Dashboard.totalStorage) // 左上角首列标签
                        .font(.caption2.bold())
                        .foregroundStyle(.appSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(displaySubjects) { sub in
                        Text(sub.name)
                            .font(.caption.bold())
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.bottom, Spacing.atomic)
                
                Divider()
                    .opacity(DesignSystem.softOpacity)
                
                // 表体：每一行渲染一个 Dimension
                ForEach(dimensions) { dim in
                    HStack(spacing: Spacing.medium) {
                        // 维度名称与单位
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dim.name)
                                .font(.caption.bold())
                                .foregroundStyle(.appSecondary)
                            if let unit = dim.unit, !unit.isEmpty {
                                Text("(\(unit))")
                                    .font(.system(size: Self.detailFontSize))
                                    .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 对照格子数据
                        ForEach(displaySubjects) { sub in
                            let cellValue = getCellValue(subjectID: sub.id, dimensionID: dim.id)
                            cellContentView(value: cellValue)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.vertical, Spacing.tiny)
                    Divider()
                        .opacity(DesignSystem.softOpacity)
                }
            }
            .padding()
            .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                    .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
            )
        }
    }
    
    private func getCellValue(subjectID: String, dimensionID: String) -> MatrixValue {
        guard let cells = frontmatter?.matrix else { return .null }
        if let match = cells.first(where: { $0.subjectID == subjectID && $0.dimensionID == dimensionID }) {
            return match.value
        }
        return .null
    }
    
    // MARK: - 3. 单元格灵活内容分发渲染
    @ViewBuilder
    private func cellContentView(value: MatrixValue) -> some View {
        switch value {
        case .text(let str):
            Text(str)
                .font(.caption2)
                .foregroundStyle(.appText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
        case .rating(let val):
            // 渲染精致的小评分
            HStack(spacing: 1) {
                let rounded = Int(val.rounded())
                ForEach(1...Self.ratingMaxStars, id: \.self) { star in
                    Image(systemName: star <= rounded ? "star.fill" : "star")
                        .font(.system(size: Self.starFontSize))
                        .foregroundStyle(star <= rounded ? .yellow : .appSecondary.opacity(DesignSystem.Opacity.disabled))
                }
            }
            
        case .range(let minVal, let maxVal):
            // 渲染迷你渐变横条
            VStack(spacing: 2) {
                Text(L10n.Dashboard.stats.rawPageCountFormat(Int(minVal), "\(Int(maxVal))")) // 借用格式化展示区间
                    .font(.system(size: Self.rangeTextSize, weight: .bold))
                    .foregroundStyle(.appAccent)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appBorder)
                            .frame(height: Self.progressLineHeight)
                        Capsule()
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width * Self.mockProgressScale, height: Self.progressLineHeight) // 模拟一个长度占位
                    }
                }
                .frame(height: Self.progressLineHeight)
            }
            .frame(width: Self.rangeBoxWidth)
            
        case .imageList(let items):
            // 渲染气泡徽章列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.system(size: Self.badgeFontSize, weight: .bold))
                            .foregroundStyle(Color.theme.purple)
                            .padding(.horizontal, Self.badgeHorizontalPadding)
                            .padding(.vertical, Self.badgeVerticalPadding)
                            .background(Color.theme.purple.opacity(DesignSystem.subtleFillOpacity))
                            .clipShape(Capsule())
                    }
                }
            }
            
        case .null:
            Text("--")
                .font(.caption2)
                .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.disabled))
        }
    }
}
