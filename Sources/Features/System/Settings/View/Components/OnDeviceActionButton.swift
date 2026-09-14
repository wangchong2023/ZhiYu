//
//  OnDeviceActionButton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：设备端 LLM 操作按钮组件，消除 OnDeviceComponents 与 OnDeviceLLMSettingsView 中重复的 HStack + ProgressView/Image + Text + font + foregroundStyle + frame + padding + background + clipShape 链。
//

import SwiftUI

/// 设备端 LLM 操作按钮
///
/// 消除 `OnDeviceComponents.generateButton`、`OnDeviceLLMSettingsView.loadModelButton`、`OnDeviceLLMSettingsView.testSection` 中重复的
/// `Button { HStack { if isGenerating { ProgressView } else { Image }; Text }.font(.subheadline.weight(.semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical).background(...).clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius)) }` 模式。
@MainActor
struct OnDeviceActionButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    var loadingIcon: String = DesignSystem.Icons.sparkles
    var background: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.small) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.medium)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
        }
        .disabled(isDisabled)
    }
}
