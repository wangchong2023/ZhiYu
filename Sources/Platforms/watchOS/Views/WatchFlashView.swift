//
//  WatchFlashView.swift
//  ZhiYuWatch
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / watchOS 平台适配
//  核心职责：Apple Watch 每日洞察与闪念轮播视图（Watch Daily Insight & Flash View）
//

#if os(watchOS)
import SwiftUI

public struct WatchFlashView: View {
    @Inject private var watchSync: any WatchSyncProtocol

    @State private var selectedIndex = 0

    private var flashQuotes: [String] {
        [
            L10n.Widget.insightQuote1,
            L10n.Widget.insightQuote2,
            L10n.Widget.insightQuote3,
            L10n.Widget.llmWikiDescription
        ]
    }

    public init() {}

    public var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(0..<flashQuotes.count, id: \.self) { index in
                VStack(alignment: .leading, spacing: DesignSystem.small) {
                    HStack {
                        Image(systemName: DesignSystem.Icons.sparkles)
                            .foregroundStyle(Color.appAccent)
                            .font(.caption)
                        Text(L10n.Widget.dailyInsight)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.appSecondary)
                        Spacer()
                        Text("\(index + 1)/\(flashQuotes.count)")
                            .font(.caption2)
                            .foregroundStyle(Color.appSecondary)
                    }

                    ScrollView {
                        Text(flashQuotes[index])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .padding(DesignSystem.small)
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .navigationTitle(L10n.Widget.dailyInsight)
    }
}

#Preview(L10n.Widget.dailyInsight) {
    WatchFlashView()
}
#endif
