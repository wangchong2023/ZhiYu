//
//  AppErrorView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 AppError 界面的 UI 视图层组件。
//
import SwiftUI

/// 全局通用错误反馈视图
/// 提供一致的错误提示样式，包含错误图标、错误提示语以及重试交互。
public struct AppErrorView: View {
    /// 错误显示图标的 SF Symbol 名称
    public let iconName: String
    /// 错误标题，默认为“加载失败”
    public let title: String
    /// 详细的错误描述信息
    public let message: String
    /// 点击重试时的回调闭包
    public let retryAction: (() -> Void)?
    
    /// 初始化通用错误反馈视图
    /// - Parameters:
    ///   - iconName: 图标名称，默认为 "exclamationmark.triangle.fill"
    ///   - title: 错误标题，默认为 ""
    ///   - message: 详细错误原因
    ///   - retryAction: 重试操作闭包，若为 nil 则不显示重试按钮
    public init(
        iconName: String = "exclamationmark.triangle.fill",
        title: String = L10n.Shared.errorTitle,
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    public var body: some View {
        VStack(spacing: SystemSpacing.content) {
            // 渐变质感的警告图标
            Image(systemName: iconName)
                .font(.system(size: 54)) // Dynamic Type
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.theme.red, Color.theme.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.theme.red.opacity(DesignSystem.Opacity.medium), radius: 10, x: 0, y: 5)
            
            // 标题
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded)) // Dynamic Type
                .foregroundColor(.primary)
            
            // 详细描述
            Text(message)
                .font(.system(size: 14)) // Dynamic Type
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SystemSpacing.medium)
                .lineLimit(4)
            
            // 重试按钮
            if let retryAction = retryAction {
                Button(action: {
                    // 1. 触发触觉反馈 (仅支持 iOS 平台)
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    #endif
                    // 2. 执行业务重试回调
                    retryAction()
                }) {
                    Text(L10n.Shared.retryButton)
                        .font(.system(size: 15, weight: .semibold)) // Dynamic Type
                        .foregroundColor(Color.theme.white)
                        .padding(.horizontal, SystemSpacing.medium)
                        .padding(.vertical, SystemSpacing.tight)
                        .background(
                            LinearGradient(
                                colors: [Color.theme.blue, Color.theme.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.theme.blue.opacity(DesignSystem.Opacity.shadow), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, SystemSpacing.element)
            }
        }
        .padding(DesignSystem.loosePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
