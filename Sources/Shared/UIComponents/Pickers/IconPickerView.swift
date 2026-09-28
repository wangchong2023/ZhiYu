//
//  IconPickerView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 IconPicker 界面的 UI 视图层组件。
//
import SwiftUI
import UFPDesignSystem

// MARK: - Icon Picker View
/// A reusable icon picker that presents categorized SF Symbols in a grid.
/// Returns an optional String (SF Symbol name) via binding. nil = use default type icon.
struct IconPickerView: View {
    @Binding var selectedIcon: String?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Icon Categories
    // Bug #100 修复：图标分类 key 改为强类型 L10n 属性引用，禁止动态 tr(key) 调用
    private static let iconCategories: [(label: String, icons: [String])] = [
        (L10n.Editor.iconPicker.common, [
            "person.text.rectangle.fill", "building.2.fill", "books.vertical.fill", "lightbulb.fill",
            "doc.richtext.fill", "globe", "star.fill", "heart.fill",
            "tag.fill", "folder.fill", "paperclip", "link",
            "camera.fill", "music.note", "paintpalette.fill", "hammer.fill"
        ]),
        (L10n.Editor.iconPicker.academic, [
            "graduationcap.fill", "brain.head.profile.fill", "atom", "circle.grid.hex.fill",
            "chart.bar.fill", "chart.pie.fill", "cube.box.fill", "gearshape.fill",
            "cpu", "desktopcomputer", "server.rack", "circle.hexagongrid.fill"
        ]),
        (L10n.Editor.iconPicker.nature, [
            "tree.fill", "leaf.fill", "sun.max.fill", "moon.fill",
            "cloud.fill", "drop.fill", "flame.fill", "bolt.fill",
            "mountain.2.fill", "water.waves", "wind", "snowflake"
        ]),
        (L10n.Editor.iconPicker.transport, [
            "airplane", "car.fill", "tram.fill",
            "ferry.fill", "bicycle", "sailboat.fill"
        ]),
        (L10n.Editor.iconPicker.symbols, [
            "exclamationmark.triangle.fill", "checkmark.circle.fill",
            "xmark.circle.fill", "questionmark.circle.fill",
            "info.circle.fill", "bell.fill", "flag.fill", "bookmark.fill"
        ])
    ]

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.medium), count: 6)

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.wide) {
                // Current selection preview
                currentSelectionPreview

                // Icon categories
                ForEach(Self.iconCategories, id: \.label) { category in
                    iconCategorySection(title: category.label, icons: category.icons)
                }
            }
            .padding()
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .navigationTitle(L10n.Editor.iconPicker.selectIcon)
.appNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.ok) { dismiss() }
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Current Selection Preview
    private var currentSelectionPreview: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: selectedIcon ?? "person.text.rectangle.fill")
                .font(.title)
                .foregroundStyle(.appAccent)
                .frame(width: DesignTokens.IconSize.huge, height: DesignTokens.IconSize.huge)
                .background(Color.appAccent.opacity(DesignTokens.Opacity.glass))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                Text(selectedIcon != nil ? L10n.Editor.iconPicker.customSelected : L10n.Editor.iconPicker.useDefault)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.appText)
                if let icon = selectedIcon {
                    Text(icon)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
            }

            Spacer()

            if selectedIcon != nil {
                Button(action: {
                    selectedIcon = nil
                    dismiss()
                }) {
                    Text(L10n.Common.reset)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, DesignTokens.Spacing.medium)
                        .padding(.vertical, DesignTokens.Spacing.tightPadding)
                        .background(Color.appCard)
                        .clipShape(Capsule())
                        .foregroundStyle(.appSecondary)
                }
            }
        }
        .padding()
        .appCardClip()
    }

    // MARK: - Icon Category Section
    @ViewBuilder
    private func iconCategorySection(title: String, icons: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            SectionCaptionLabel(title: title)

            LazyVGrid(columns: gridColumns, spacing: DesignTokens.Spacing.medium) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        dismiss()
                    }) {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: DesignTokens.IconSize.xlarge, height: DesignTokens.IconSize.xlarge)
                            .background(selectedIcon == icon ? Color.appAccent.opacity(DesignTokens.Opacity.medium) : Color.appCard)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius))
                            .foregroundStyle(selectedIcon == icon ? .appAccent : .appText)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius)
                                    .stroke(selectedIcon == icon ? Color.appAccent : Color.clear, lineWidth: DesignTokens.SystemStroke.selected)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
