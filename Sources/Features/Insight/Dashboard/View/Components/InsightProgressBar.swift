//
//  InsightProgressBar.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用进度条，消除 ComparisonDetailBodyView 与 SourceDetailBodyView 中重复的
//  GeometryReader + ZStack + 双 Capsule 渲染链。
//

import SwiftUI

/// [L3] 表现层：通用水平进度条
///
/// 统一封装 `GeometryReader + ZStack + 底色 Capsule + 前景 Capsule` 渲染链，
/// 通过 `progress`（0.0–1.0）控制前景宽度比例，消除各处重复的进度条代码。
struct InsightProgressBar: View {
    let progress: Double
    var lineHeight: CGFloat = Spacing.atomic
    var trackColor: Color = .appBorder
    var fillColor: Color = .appAccent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: lineHeight)
                Capsule()
                    .fill(fillColor)
                    .frame(width: geo.size.width * CGFloat(progress), height: lineHeight)
            }
        }
        .frame(height: lineHeight)
    }
}
