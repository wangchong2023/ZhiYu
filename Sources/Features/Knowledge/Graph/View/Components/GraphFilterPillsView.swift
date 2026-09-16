//
//  GraphFilterPillsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 GraphFilterPills 界面的 UI 视图层组件。
//
import SwiftUI

/// 知识图谱类型过滤器药丸视图
@MainActor
struct GraphFilterPillsView: View {
    @Binding var filterType: PageType?
    @ObservedObject var tooltipManager: TooltipManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            PageTypeFilterPills(filterType: $filterType)
                .padding(.vertical, DesignSystem.tiny)
        }
    }
}
