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

// MARK: - Icon Picker View
/// A reusable icon picker that presents categorized SF Symbols in a grid.
/// Returns an optional String (SF Symbol name) via binding. nil = use default type icon.
struct IconPickerView: View {
    @Binding var selectedIcon: String?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Icon Categories
    private static let iconCategories: [(String, [String])] = [
        ("iconPicker.common", [
            "person.text.rectangle.fill", "building.2.fill", "books.vertical.fill", "lightbulb.fill",
            "doc.richtext.fill", "globe", "star.fill", "heart.fill",
            "tag.fill", "folder.fill", "paperclip", "link",
            "camera.fill", "music.note", "paintpalette.fill", "hammer.fill"
        ]),
        ("iconPicker.academic", [
            "graduationcap.fill", "brain.head.profile.fill", "atom", "circle.grid.hex.fill",
            "chart.bar.fill", "chart.pie.fill", "cube.box.fill", "gearshape.fill",
            "cpu", "desktopcomputer", "server.rack", "circle.hexagongrid.fill"
        ]),
        ("iconPicker.nature", [
            "tree.fill", "leaf.fill", "sun.max.fill", "moon.fill",
            "cloud.fill", "drop.fill", "flame.fill", "bolt.fill",
            "mountain.2.fill", "water.waves", "wind", "snowflake"
        ]),
        ("iconPicker.transport", [
            "airplane", "car.fill", "tram.fill",
            "ferry.fill", "bicycle", "sailboat.fill"
        ]),
        ("iconPicker.symbols", [
            "exclamationmark.triangle.fill", "checkmark.circle.fill",
            "xmark.circle.fill", "questionmark.circle.fill",
            "info.circle.fill", "bell.fill", "flag.fill", "bookmark.fill"
        ])
    ]

    private func categoryDisplayName(_ key: String) -> String {
        L10n.Editor.tr(key)
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.medium), count: 6)

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.wide) {
                // Current selection preview
                currentSelectionPreview

                // Icon categories
                ForEach(Self.iconCategories, id: \.0) { category, icons in
                    iconCategorySection(title: categoryDisplayName(category), icons: icons)
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
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: selectedIcon ?? "person.text.rectangle.fill")
                .font(.title)
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.IconSize.huge, height: DesignSystem.IconSize.huge)
                .background(Color.appAccent.opacity(DesignSystem.Opacity.glass))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))

            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
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
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.vertical, DesignSystem.tightPadding)
                        .background(Color.appCard)
                        .clipShape(Capsule())
                        .foregroundStyle(.appSecondary)
                }
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
    }

    // MARK: - Icon Category Section
    @ViewBuilder
    private func iconCategorySection(title: String, icons: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)

            LazyVGrid(columns: gridColumns, spacing: DesignSystem.medium) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        dismiss()
                    }) {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)
                            .background(selectedIcon == icon ? Color.appAccent.opacity(DesignSystem.Opacity.medium) : Color.appCard)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
                            .foregroundStyle(selectedIcon == icon ? .appAccent : .appText)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                                    .stroke(selectedIcon == icon ? Color.appAccent : Color.clear, lineWidth: SystemStroke.selected)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
