//
//  PageDetailMetaSectionView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：跨平台页面详情元信息区域 —— watchOS 使用平铺 VStack，其他平台使用可折叠 DisclosureGroup。
//

import SwiftUI

/// 页面详情元信息展示区域
///
/// watchOS 上始终展开显示为 VStack；
/// iOS / macOS 上使用 DisclosureGroup 支持折叠/展开。
public struct PageDetailMetaSectionView: View {
    let page: KnowledgePage
    @Binding var isExpanded: Bool

    public init(page: KnowledgePage, isExpanded: Binding<Bool>) {
        self.page = page
        self._isExpanded = isExpanded
    }

    public var body: some View {
        #if os(watchOS)
        watchOSLayout
        #else
        standardLayout
        #endif
    }

    // MARK: - watchOS: 平铺展开

    #if os(watchOS)
    private var watchOSLayout: some View {
        VStack(alignment: .leading) {
            metaHeaderLabel
            metaInfoContent
                .padding(.top, DesignSystem.tiny)
        }
        .metaSectionContainerStyle()
    }
    #endif

    // MARK: - iOS / macOS: 可折叠

    #if !os(watchOS)
    private var standardLayout: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                metaInfoContent
                    .padding(.top, DesignSystem.tiny)
            },
            label: {
                metaHeaderLabel
            }
        )
        .tint(.appSecondary)
        .metaSectionContainerStyle()
    }
    #endif

    // MARK: - 共享元信息组件

    /// 元信息区头部标签（消除 watchOS / standard 两处重复的 Label + font + foregroundStyle 链）
    private var metaHeaderLabel: some View {
        HStack {
            Label(L10n.Knowledge.Page.metaInfo, systemImage: DesignSystem.Icons.info)
                .font(.caption2.bold())
                .foregroundStyle(.appSecondary)
            Spacer()
        }
    }

    private var metaInfoContent: some View {
        HStack(spacing: DesignSystem.standardPadding) {
            Label(
                L10n.Knowledge.Page.createdAtFormat(page.shortFormattedCreatedDate),
                systemImage: DesignSystem.Icons.sortDate
            )
            Label(
                L10n.Knowledge.Page.updatedAtFormat(page.shortFormattedUpdatedDate),
                systemImage: DesignSystem.Icons.clock
            )
            Label(
                L10n.Knowledge.Page.wordCount(page.wordCount),
                systemImage: DesignSystem.Icons.wordCount
            )
            Label(
                L10n.Knowledge.Page.outLinksCount(page.outgoingLinks.count),
                systemImage: DesignSystem.Icons.link
            )
        }
        .font(.caption)
        .foregroundStyle(.appSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.Knowledge.Page.metaAccessibility(
                page.shortFormattedCreatedDate,
                page.wordCount,
                page.outgoingLinks.count
            )
        )
    }
}

// MARK: - KnowledgePage 日期格式化辅助
private extension KnowledgePage {
    /// 短日期格式（年月日），消除 metaInfoContent 中 3 处重复的 formatted 链
    var shortFormattedCreatedDate: String {
        createdAt.formatted(.dateTime.year().month().day().locale(Localized.currentLocale))
    }

    var shortFormattedUpdatedDate: String {
        updatedAt.formatted(.dateTime.year().month().day().locale(Localized.currentLocale))
    }
}

// MARK: - MetaSection 容器样式
private extension View {
    /// 统一应用 meta section 的内边距与卡片裁剪，消除 watchOSLayout / standardLayout 两处重复的 padding + appCardClip 链。
    func metaSectionContainerStyle() -> some View {
        self
            .padding(.horizontal, DesignSystem.medium)
            .padding(.vertical, DesignSystem.small)
            .appCardClip(cornerRadius: Spacing.smallRadius, backgroundOpacity: DesignSystem.Opacity.disabled)
    }
}
