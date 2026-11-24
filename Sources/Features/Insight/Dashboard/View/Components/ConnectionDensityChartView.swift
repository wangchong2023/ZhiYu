//
//  ConnectionDensityChartView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识仪表盘连接密度水平堆叠柱状图组件，确保 iOS/iPadOS/macOS 全平台文字与柱状条间距清晰一致。
//

import SwiftUI
import UFPDesignSystem

/// 单条连接密度柱状条的归一化比例（向外关联 / 向内引用）
struct DensityBarRatios: Equatable, Sendable {
    let outbound: Double
    let inbound: Double
}

/// [L3] 表现层：连接密度水平堆叠柱状图
///
/// 采用每行独立「标题 + 水平堆叠条」垂直组合，严格拉开行间间距与行内间距，
/// 消除 Swift Charts 默认分类 Y 轴导致的标签贴条与跨行粘连问题。
struct ConnectionDensityChartView: View {
    let items: [DensityInfo]

    var body: some View {
        let maxTotal = Self.maxTotal(in: items)
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.content) {
            ForEach(items) { item in
                rowView(for: item, maxTotal: maxTotal)
            }
        }
    }

    // MARK: - 纯计算方法

    /// 计算所有密度条目中的最大总连接数（作为 100% 标尺）
    static func maxTotal(in items: [DensityInfo]) -> Double {
        items.map { max(0, $0.outbound) + max(0, $0.inbound) }.max() ?? 0
    }

    /// 计算单条记录的向外关联与向内引用归一化比例，保证非负且总和不超过 1.0
    static func ratios(for item: DensityInfo, maxTotal: Double) -> DensityBarRatios {
        guard maxTotal > 0 else {
            return DensityBarRatios(outbound: 0, inbound: 0)
        }
        let safeOutbound = max(0, item.outbound)
        let safeInbound = max(0, item.inbound)
        let outboundRatio = min(1.0, safeOutbound / maxTotal)
        let inboundRatio = min(1.0 - outboundRatio, safeInbound / maxTotal)
        return DensityBarRatios(outbound: outboundRatio, inbound: inboundRatio)
    }

    /// 根据容器总宽度与归一化比例计算各分段像素宽度
    static func segmentWidths(for ratios: DensityBarRatios, totalWidth: CGFloat) -> (outbound: CGFloat, inbound: CGFloat) {
        guard totalWidth > 0 else {
            return (0, 0)
        }
        return (totalWidth * CGFloat(ratios.outbound), totalWidth * CGFloat(ratios.inbound))
    }

    // MARK: - 私有视图构建

    private func rowView(for item: DensityInfo, maxTotal: Double) -> some View {
        let ratios = Self.ratios(for: item, maxTotal: maxTotal)
        return VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.small) {
            Text(item.name)
                .font(.system(size: DesignTokens.Typography.captionFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(.appSource)
                .lineLimit(DesignTokens.SystemLineLimit.single)
                .truncationMode(.tail)

            stackedBar(ratios: ratios)
        }
    }

    private func stackedBar(ratios: DensityBarRatios) -> some View {
        GeometryReader { proxy in
            let widths = Self.segmentWidths(for: ratios, totalWidth: proxy.size.width)
            ZStack(alignment: .leading) {
                // 极淡底轨：对齐 100% 标尺，并保证 0 关联页面不出现视觉空洞
                RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small, style: .continuous)
                    .fill(Color.appBorder.opacity(DesignTokens.SystemOpacity.glassStrong))
                    .frame(height: DesignTokens.SystemSpacing.contentMedium)

                if widths.outbound > 0 || widths.inbound > 0 {
                    HStack(spacing: DesignTokens.SystemSpacing.none) {
                        if widths.outbound > 0 {
                            Rectangle()
                                .fill(segmentGradient(color: .appAccent))
                                .frame(width: widths.outbound, height: DesignTokens.SystemSpacing.contentMedium)
                        }
                        if widths.inbound > 0 {
                            Rectangle()
                                .fill(segmentGradient(color: Color.theme.purple))
                                .frame(width: widths.inbound, height: DesignTokens.SystemSpacing.contentMedium)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small, style: .continuous))
                }
            }
        }
        .frame(height: DesignTokens.SystemSpacing.contentMedium)
    }

    private func segmentGradient(color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(DesignTokens.Opacity.dim)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
