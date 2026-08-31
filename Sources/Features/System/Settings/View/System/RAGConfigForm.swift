//
//  RAGConfigForm.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：RAG 评估配置表单 — 时间范围选择器。
//

import SwiftUI

// MARK: - 时间范围选择器

/// RAG 评估时间窗口选项常量
private enum RAGTimeRange {
    /// 可选时间窗口（天）：7 天 / 30 天 / 90 天
    static let dayOptions: [Int] = [
        FeatureConstants.RAGEvalTimeRange.shortDays,
        FeatureConstants.RAGEvalTimeRange.mediumDays,
        FeatureConstants.RAGEvalTimeRange.longDays
    ]
}

/// RAG 评估数据的时间窗口选择器（7/30/90 天）
struct RAGTimeRangePicker: View {
    @Binding var selectedDays: Int

    private let dayOptions = RAGTimeRange.dayOptions

    var body: some View {
        HStack(spacing: DesignSystem.tightPadding) {
            ForEach(dayOptions, id: \.self) { days in
                Button {
                    selectedDays = days
                } label: {
                    Text("\(days) \(L10n.Dashboard.stats.unitDays)")
                        .font(.subheadline.weight(selectedDays == days ? .semibold : .regular))
                        .padding(.horizontal, DesignSystem.medium).padding(.vertical, DesignSystem.small)
                        .background(selectedDays == days ? Capsule().fill(Color.appAccent) : Capsule().fill(Color.appCard))
                        .foregroundStyle(selectedDays == days ? .white : .appSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
