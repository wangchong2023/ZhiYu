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
            HStack {
                Label(L10n.Knowledge.Page.metaInfo, systemImage: DesignSystem.Icons.info)
                    .font(.caption2.bold())
                    .foregroundStyle(.appSecondary)
                Spacer()
            }
            metaInfoContent
                .padding(.top, DesignSystem.tiny)
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, DesignSystem.small)
        .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
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
                HStack {
                    Label(L10n.Knowledge.Page.metaInfo, systemImage: DesignSystem.Icons.info)
                        .font(.caption2.bold())
                        .foregroundStyle(.appSecondary)
                    Spacer()
                }
            }
        )
        .tint(.appSecondary)
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, DesignSystem.small)
        .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
    }
    #endif

    // MARK: - 共享元信息内容

    private var metaInfoContent: some View {
        HStack(spacing: DesignSystem.standardPadding) {
            Label(
                L10n.Knowledge.Page.createdAtFormat(
                    page.createdAt.formatted(
                        .dateTime.year().month().day().locale(Localized.currentLocale)
                    )
                ),
                systemImage: DesignSystem.Icons.sortDate
            )
            Label(
                L10n.Knowledge.Page.updatedAtFormat(
                    page.updatedAt.formatted(
                        .dateTime.year().month().day().locale(Localized.currentLocale)
                    )
                ),
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
                page.createdAt.formatted(
                    .dateTime.year().month().day().locale(Localized.currentLocale)
                ),
                page.wordCount,
                page.outgoingLinks.count
            )
        )
    }
}
