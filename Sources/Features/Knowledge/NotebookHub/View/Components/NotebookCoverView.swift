//
//  NotebookCoverView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 NotebookCover 界面的 UI 视图层组件。
//
import SwiftUI

/// 笔记本封面渲染组件
/// 支持线性渐变与动态网格材质，可嵌入至笔记本列表或详情页眉中，渲染极具吸引力的视觉封面。
public struct NotebookCoverView: View {
    /// 封面主题样式配置
    public let config: NotebookThemeConfig
    /// 笔记本名称
    public let title: String
    /// 笔记本图标（SF Symbol 名称）
    public let icon: String
    /// 笔记本内的页面数量
    public let pageCount: Int
    /// 封面是否处于激活/被按下状态
    public var isPressed: Bool = false
    
    /// 初始化笔记本封面组件
    /// - Parameters:
    ///   - config: 主题配置
    ///   - title: 封面标题
    ///   - icon: 封面图标
    ///   - pageCount: 页面计数
    ///   - isPressed: 点击微动画触发状态
    public init(
        config: NotebookThemeConfig,
        title: String,
        icon: String = "book.closed.fill",
        pageCount: Int = 0,
        isPressed: Bool = false
    ) {
        self.config = config
        self.title = title
        self.icon = icon
        self.pageCount = pageCount
        self.isPressed = isPressed
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: SystemSpacing.medium) {
            // 图标与装饰条
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold)) // Dynamic Type
                    .foregroundColor(.theme.white)
                Spacer()
                RoundedRectangle(cornerRadius: 2 /* 装饰微圆角，暂无 DesignSystem token */)
                    .fill(Color.theme.white.opacity(DesignSystem.Opacity.disabled))
                    .frame(width: DesignSystem.Metrics.notebookBadgeWidth, height: DesignSystem.tiny)
            }
            
            Spacer()
            
            // 标题与统计元数据
            VStack(alignment: .leading, spacing: SystemSpacing.tiny) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded)) // Dynamic Type
                    .foregroundColor(.theme.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(L10n.Shared.pageCountFormat(pageCount))
                    .font(.system(size: 12, weight: .medium)) // Dynamic Type
                    .foregroundColor(Color.theme.white.opacity(DesignSystem.Opacity.prominent))
            }
        }
        .padding(DesignSystem.standardPadding)
        .frame(width: DesignSystem.Metrics.notebookCardWidth, height: DesignSystem.Metrics.notebookCardHeight)
        .background(
            // 根据主题类型绘制背景
            Group {
                if config.type == .linear {
                    LinearGradient(
                        colors: parsedColors(),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    // Mesh 渐变回退或模拟网格渐变
                    RadialGradient(
                        colors: parsedColors(),
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                }
            }
        )
        .cornerRadius(12)
        .shadow(color: Color.theme.black.opacity(DesignSystem.Opacity.glass), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
    
    /// 将 16 进制颜色字符串数组解析为 SwiftUI Color 数组
    private func parsedColors() -> [Color] {
        if config.colors.isEmpty {
            return [Color.theme.blue, Color.theme.purple] // 兜底颜色
        }
        
        // 1. 尝试遍历解析所有的十六进制颜色码
        return config.colors.map { Color(hex: $0) }
    }
}
