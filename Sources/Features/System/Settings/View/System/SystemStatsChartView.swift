//
//  SystemStatsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：系统监控图表子组件 — Token/请求量/延迟趋势图表渲染。
//
import SwiftUI
import Charts

// MARK: - 子视图：资源图表实现
struct ChartView: View {
    enum ChartType {
        case requests
        case tokens
    }
    
    let stats: [DailyAIUsage]
    let type: ChartType
    @Environment(ThemeManager.self) var themeManager
    @State private var selectedDate: Date?
    
    var body: some View {
        if stats.isEmpty {
            VStack(spacing: DesignSystem.small) {
                Image(systemName: DesignSystem.Icons.chartLine)
                    .font(.system(size: DesignSystem.displayFontSize))
                    .foregroundStyle(.appSecondary.opacity(DesignSystem.softOpacity))
                Text(L10n.Common.Global.noData)
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.Metrics.chartHeight - 60)
            .background(Color.appCard.opacity(DesignSystem.softOpacity))
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        } else {
            switch type {
            case .requests:
                requestsChart
            case .tokens:
                tokensChart
            }
        }
    }
    
    @ViewBuilder
    private var requestsChart: some View {
        let monthRange = currentMonthRange()
        let start = monthRange.start
        let end = monthRange.end.addingTimeInterval(86400)
        let domainX = start...end
        let domainY = 0.0...(max(100.0, maxValue() * 1.2))
        
        Chart {
            ForEach(stats) { stat in
                AreaMark(
                    x: .value(L10n.Dashboard.chartDate, stat.date, unit: .day),
                    y: .value(L10n.Dashboard.chartValue, Double(stat.requests))
                )
                .foregroundStyle(
                    LinearGradient(
                        // swiftlint:disable:next magic_numbers_opacity
                        colors: [Color.theme.blue.opacity(DesignSystem.Opacity.disabled), Color.theme.blue.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                LineMark(
                    x: .value(L10n.Dashboard.chartDate, stat.date, unit: .day),
                    y: .value(L10n.Dashboard.chartValue, Double(stat.requests))
                )
                .foregroundStyle(themeManager.accentColor)
                .lineStyle(StrokeStyle(lineWidth: SystemStroke.selected))
                .interpolationMethod(.catmullRom)
            }
            
            if let selectedDate {
                RuleMark(x: .value(L10n.Dashboard.chartSelected, selectedDate, unit: .day))
                    .foregroundStyle(Color.appSecondary.opacity(DesignSystem.Opacity.soft))
                    .lineStyle(StrokeStyle(lineWidth: SystemStroke.divider, dash: [2]))
                    .annotation(position: .automatic, alignment: .center, spacing: DesignSystem.tiny) {
                        if let stat = stats.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                            tooltipView(stat: stat)
                        }
                    }
                
                if let stat = stats.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                    PointMark(
                        x: .value(L10n.Dashboard.chartSelected, selectedDate, unit: .day),
                        y: .value(L10n.Dashboard.chartValue, Double(stat.requests))
                    )
                    .symbol {
                        Circle()
                            .stroke(themeManager.accentColor, lineWidth: SystemStroke.selected)
                            .background(Circle().fill(.white))
                            .frame(width: DesignSystem.small, height: DesignSystem.small)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis { xAxisMarks }
        .chartYAxis { yAxisMarks }
        .chartXScale(domain: domainX)
        .chartYScale(domain: domainY)
    }
    
    @ViewBuilder
    private var tokensChart: some View {
        let monthRange = currentMonthRange()
        let start = monthRange.start
        let end = monthRange.end.addingTimeInterval(86400)
        let domainX = start...end
        let domainY = 0.0...(max(100.0, maxValue() * 1.2))
        
        Chart {
            ForEach(stats) { stat in
                BarMark(
                    x: .value(L10n.Dashboard.chartDate, stat.date, unit: .day),
                    y: .value(L10n.Dashboard.chartValue, Double(stat.tokens)),
                    width: .fixed(DesignSystem.small)
                )
                .foregroundStyle(themeManager.accentColor.opacity(DesignSystem.Opacity.overlay).gradient)
                .cornerRadius(1)
            }
            
            if let selectedDate {
                RuleMark(x: .value(L10n.Dashboard.chartSelected, selectedDate, unit: .day))
                    .foregroundStyle(Color.appSecondary.opacity(DesignSystem.Opacity.soft))
                    .lineStyle(StrokeStyle(lineWidth: SystemStroke.divider, dash: [2]))
                    .annotation(position: .automatic, alignment: .center, spacing: DesignSystem.tiny) {
                        if let stat = stats.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                            tooltipView(stat: stat)
                        }
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis { xAxisMarks }
        .chartYAxis { yAxisMarks }
        .chartXScale(domain: domainX)
        .chartYScale(domain: domainY)
    }
    
    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 7)) { value in
            AxisGridLine().foregroundStyle(.appBorder.opacity(DesignSystem.softOpacity))
            AxisValueLabel(anchor: .topTrailing) {
                if let date = value.as(Date.self) {
                    Text(formatDate(date))
                        .font(.system(size: DesignSystem.microFontSize))
                        .foregroundStyle(.appSecondary)
                }
            }
        }
    }
    
    @AxisContentBuilder
    private var yAxisMarks: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine().foregroundStyle(.appBorder.opacity(DesignSystem.Opacity.soft))
            AxisValueLabel {
                if let intValue = value.as(Int.self) {
                    Text("\(intValue)")
                        .font(.system(size: DesignSystem.microFontSize))
                        .foregroundStyle(.appSecondary)
                }
            }
        }
    }
    
    private func currentMonthRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else { return (now, now) }
        return (startOfMonth, endOfMonth)
    }
    
    private func tooltipView(stat: DailyAIUsage) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            Text(stat.date, format: .dateTime.year().month().day())
                .font(.system(size: DesignSystem.captionFontSize, weight: .bold))
                .foregroundStyle(.appText)
            
            HStack(spacing: DesignSystem.tiny) {
                Text(type == .requests ? L10n.Dashboard.apiRequests : L10n.Dashboard.tokens)
                    .font(.system(size: DesignSystem.caption2FontSize))
                    .foregroundStyle(.appSecondary)
                Text("\(type == .requests ? stat.requests : stat.tokens)")
                    .font(.system(size: DesignSystem.caption2FontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.appText)
            }
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, DesignSystem.small)
        .background {
            RoundedRectangle(cornerRadius: Spacing.Chip.cornerRadius, style: .continuous)
                .fill(Color.appCard)
                .appStandardShadow()
        }
    }
    
    private func maxValue() -> Double {
        let maxVal = stats.map { type == .requests ? Double($0.requests) : Double($0.tokens) }.max() ?? 100
        return maxVal == 0 ? 100 : maxVal
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d"
        return formatter.string(from: date)
    }
}
