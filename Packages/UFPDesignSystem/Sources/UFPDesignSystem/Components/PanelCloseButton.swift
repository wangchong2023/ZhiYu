//
//  PanelCloseButton.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：通用面板关闭按钮原子组件，统一 Sheet/Popover 右上角关闭交互。
//

import SwiftUI

/// 面板关闭按钮
public struct PanelCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: DesignTokens.Icons.errorCircle)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
