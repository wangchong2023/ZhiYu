//
//  SampleChipBar.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：快捷检索词胶囊栏通用组件，供即时媒体检索与视频时刻检索面板复用，以强调色统一选中态与胶囊样式。
//

import SwiftUI
import UFPDesignSystem

/// 快捷检索词胶囊栏组件
/// 参数化胶囊文案、选中词、强调色、禁用态与点选回调，供不同搜索面板复用。
@MainActor
struct SampleChipBar: View {
    /// 胶囊文案列表
    let items: [String]
    /// 当前选中词（用于高亮选中态）
    let selectedID: String
    /// 强调色（选中态/胶囊底色）
    let accentColor: Color
    /// 是否禁用（禁用时胶囊置灰不可点）
    var isDisabled: Bool = false
    /// 点选回调
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                ForEach(items, id: \.self) { sample in
                    Button(action: {
                        onSelect(sample)
                    }) {
                        Text(sample)
                            .font(.caption2.bold())
                            .foregroundStyle(selectedID == sample ? Color.theme.white : accentColor)
                            .padding(.horizontal, DesignTokens.SystemSpacing.small)
                            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                            .background(selectedID == sample ? accentColor : accentColor.opacity(DesignTokens.Opacity.disabled))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? DesignTokens.Opacity.disabled : DesignTokens.Opacity.solid)
                }
            }
            .padding(.horizontal, DesignTokens.SystemSpacing.atomic)
        }
    }
}
