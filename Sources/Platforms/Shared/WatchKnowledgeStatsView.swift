//
//  WatchKnowledgeStatsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：手表端简易知识统计与最近更新列表视图 (全平台共享，支持 iOS/macOS/watchOS 及单测)。
//

import SwiftUI
import UFPCore
import Dependencies

#if os(watchOS)
// MARK: - Apple Watch Quick View
/// 手表端简易统计视图
/// 负责展示知识库的核心元数据统计（页面总数、字数）及最近更新记录
@MainActor
struct WatchKnowledgeStatsView: View {
    @State private var totalPages = 0
    @State private var totalWords = 0
    @State private var recentTitles: [String] = []
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?
    
    /// 允许传入 Mock 数据的构造器
    public init(totalPages: Int = 0, totalWords: Int = 0, recentTitles: [String] = []) {
        self._totalPages = State(initialValue: totalPages)
        self._totalWords = State(initialValue: totalWords)
        self._recentTitles = State(initialValue: recentTitles)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.medium) {
                // 1. 页面总数环形图
                ZStack {
                    Circle()
                        .stroke(Color.appAccent.opacity(SystemOpacity.glass), lineWidth: SystemStroke.heavy)
                        .frame(width: PlatformConstants.WidgetWatch.progressRingSize, height: PlatformConstants.WidgetWatch.progressRingSize)
                    
                    Circle()
                        .trim(from: 0, to: min(1.0, Double(totalPages) / PlatformConstants.WidgetWatch.progressRingDenominator))
                        .stroke(Color.appAccent, style: StrokeStyle(lineWidth: SystemStroke.heavy, lineCap: .round))
                        .frame(width: PlatformConstants.WidgetWatch.progressRingSize, height: PlatformConstants.WidgetWatch.progressRingSize)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: DesignSystem.atomic) {
                        Text("\(totalPages)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        Text(L10n.Widget.pages)
                            .font(.caption2)
                            .foregroundStyle(Color.appSecondary)
                    }
                }
                
                // 2. 总字数统计
                HStack(spacing: DesignSystem.small) {
                    VStack(spacing: DesignSystem.atomic) {
                        Text(formatNumber(totalWords))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.appText)
                        Text(L10n.Widget.words)
                            .font(.caption2)
                            .foregroundStyle(Color.appSecondary)
                    }
                }
                
                Divider()
                
                // 3. 最近更新列表
                VStack(alignment: .leading, spacing: DesignSystem.small) {
                    Text(L10n.Widget.recentUpdates)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appSecondary)
                    
                    ForEach(Array(recentTitles.prefix(PlatformConstants.WidgetWatch.maxRecentTitles).enumerated()), id: \.offset) { _, title in
                        WatchRecentUpdateRowView(title: title)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignSystem.small)
        }
        .navigationTitle(L10n.Widget.title)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        totalPages = keyStore?.integer(forKey: AppConstants.Keys.Storage.watchTotalPages) ?? 0
        totalWords = keyStore?.integer(forKey: AppConstants.Keys.Storage.watchTotalWords) ?? 0
        recentTitles = keyStore?.object(forKey: AppConstants.Keys.Storage.watchRecentTitles) as? [String] ?? []
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= PlatformConstants.WidgetWatch.tenThousandThreshold {
            return String(format: "%.1f%@", Double(n) / PlatformConstants.WidgetWatch.tenThousandDivisor, L10n.Common.unitTenThousand)
        } else if n >= PlatformConstants.WidgetWatch.thousandThreshold {
            return String(format: "%.1fk", Double(n) / PlatformConstants.WidgetWatch.thousandDivisor)
        }
        return "\(n)"
    }
}

// MARK: - 手表端最近更新单行视图
struct WatchRecentUpdateRowView: View {
    let title: String
    
    var body: some View {
        HStack(spacing: DesignSystem.small) {
            Circle()
                .fill(Color.appAccent)
                .frame(width: PlatformConstants.WidgetWatch.recentItemDotSize, height: PlatformConstants.WidgetWatch.recentItemDotSize)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.appText)
                .lineLimit(DesignSystem.LineLimit.single)
        }
    }
}
#endif
