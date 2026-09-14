//
//  InsightPageTypeIcon.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用页面类型图标，消除 BacklinksView 与 PageDetailMetadataSection 中重复的
//  displayIcon + 颜色背景 + 圆角裁剪布局链。
//

import SwiftUI

/// [L3] 表现层：通用页面类型图标
///
/// 统一封装 `displayIcon` + `Color.fromModelColorName(pageType.colorName)` 前景色 +
/// 同色 `Opacity.glass` 背景 + `RoundedRectangle(cornerRadius: DesignSystem.microRadius)` 裁剪，
/// 消除 BacklinksView、PageDetailMetadataSection 与其他列表行中重复的 5 行修饰符链。
struct InsightPageTypeIcon: View {
    let page: KnowledgePage
    var size: CGFloat = DesignSystem.IconSize.medium

    var body: some View {
        Image(systemName: page.displayIcon)
            .foregroundStyle(Color.fromModelColorName(page.pageType.colorName))
            .frame(width: size, height: size)
            .background(Color.fromModelColorName(page.pageType.colorName).opacity(DesignSystem.Opacity.glass))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.microRadius))
    }
}
