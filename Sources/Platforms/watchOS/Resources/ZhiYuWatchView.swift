//
//  ZhiYuWatchView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：构建 ZhiYuWatch 界面的 UI 视图层组件。
//
import SwiftUI

// MARK: - 手表端专用颜色
private extension Color {
    static let watchAccent = Color.theme.blue
    static let watchText = Color.primary
    static let watchSecondary = Color.secondary
}

// MARK: - 手表端简易统计视图
/// 手表端简易统计视图
/// 负责展示知识库的核心元数据统计（页面总数、字数）及最近更新记录
struct WatchKnowledgeStatsView: View {
    @State private var totalPages = 0
    @State private var totalWords = 0
    @State private var recentTitles: [String] = []
    
    /// 允许通过参数初始化状态的构造器，专为提升单元测试可测性而设计
    /// - Parameters:
    ///   - totalPages: 页面总数
    ///   - totalWords: 总字数
    ///   - recentTitles: 最近更新页面标题列表
    init(totalPages: Int = 0, totalWords: Int = 0, recentTitles: [String] = []) {
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
                        .stroke(Color.watchAccent.opacity(DesignSystem.glassOpacity), lineWidth: DesignSystem.borderWidth * 3)
                        .frame(width: DesignSystem.huge * 2 + DesignSystem.small, height: DesignSystem.huge * 2 + DesignSystem.small)
                    
                    Circle()
                        .trim(from: 0, to: min(1.0, Double(totalPages) / 100.0))
                        .stroke(Color.watchAccent, style: StrokeStyle(lineWidth: DesignSystem.borderWidth * 3, lineCap: .round))
                        .frame(width: DesignSystem.huge * 2 + DesignSystem.small, height: DesignSystem.huge * 2 + DesignSystem.small)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: DesignSystem.atomic) {
                        Text("\(totalPages)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.watchText)
                        Text(L10n.Platform.Watch.pages)
                            .font(.caption2)
                            .foregroundStyle(Color.watchSecondary)
                    }
                }
                
                // 2. 总字数统计
                HStack(spacing: DesignSystem.small) {
                    VStack(spacing: DesignSystem.atomic) {
                        Text(formatNumber(totalWords))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.watchText)
                        Text(L10n.Platform.Watch.words)
                            .font(.caption2)
                            .foregroundStyle(Color.watchSecondary)
                    }
                }
                
                Divider()
                
                // 3. 最近更新列表
                VStack(alignment: .leading, spacing: DesignSystem.tiny + DesignSystem.atomic) {
                    Text(L10n.Platform.Watch.recentUpdates)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.watchSecondary)
                    
                    ForEach(recentTitles.prefix(5), id: \.self) { title in
                        WatchRecentUpdateRowView(title: title)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignSystem.small)
        }
        .navigationTitle("ZhiYu")
        .onAppear {
            loadData()
        }
    }
    
    /// 从 KeyStore 载入表盘所需的统计数据
    func loadData() {
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        totalPages = keyStore?.integer(forKey: AppConstants.Keys.Storage.watchTotalPages) ?? 0
        totalWords = keyStore?.integer(forKey: AppConstants.Keys.Storage.watchTotalWords) ?? 0
        recentTitles = keyStore?.object(forKey: AppConstants.Keys.Storage.watchRecentTitles) as? [String] ?? []
    }
    
    /// 将字数格式化为更易读的字符串形式
    /// - Parameter n: 原始字数
    /// - Returns: 格式化后的显示字符串（例如 "2.5"、"1.5k"、"500"）
    func formatNumber(_ n: Int) -> String {
        if n >= 10000 {
            return String(format: "%.1f" + L10n.Platform.Watch.tenThousand, Double(n) / 10000.0)
        } else if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

// MARK: - 手表端最近更新单行视图
/// 手表端最近更新单行视图，将行视图抽离以提升 SwiftUI 渲染效率与可测性
struct WatchRecentUpdateRowView: View {
    let title: String
    
    var body: some View {
        HStack(spacing: DesignSystem.tiny + DesignSystem.atomic) {
            Circle()
                .fill(Color.watchAccent)
                .frame(width: DesignSystem.tiny + DesignSystem.atomic / 2, height: DesignSystem.tiny + DesignSystem.atomic / 2)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.watchText)
                .lineLimit(1)
        }
    }
}
