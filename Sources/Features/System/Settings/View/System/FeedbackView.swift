//
//  FeedbackView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：用户反馈表单 + 历史记录

import SwiftUI
import UFPCore
import Dependencies
import UFPDesignSystem

struct FeedbackView: View {
    /// 嵌入 SettingsView 详情栏时为 true：复用父级 NavigationStack 与背景，避免嵌套导航栏及重复背景绘制
    var isEmbedded: Bool = false

    @Dependency(\.toastService) private var toastManager
    @Environment(ThemeManager.self) var themeManager
    @State private var selectedTab = 0
    @State private var titleText = ""
    @State private var selectedCategory = FeedbackCategory.bug
    private let maxRating = DesignTokens.Spacing.Feedback.maxRating
    @State private var rating: Int = DesignTokens.Spacing.Feedback.defaultRating
    @State private var contentText = ""
    @State private var isSubmitting = false
    @State private var history: [FeedbackEntry] = []

    @Dependency(\.feedbackRepository) private var repo: any FeedbackRepository
    @Dependency(\.deviceInfo) private var deviceInfo: any DeviceInfoProtocol

    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }()

    var body: some View {
        Group {
            if isEmbedded {
                feedbackContent
            } else {
                NavigationStack {
                    ZStack {
                        themeManager.pageBackground().ignoresSafeArea()
                        feedbackContent
                    }
                    .navigationTitle(L10n.Settings.Feedback.title)
                    .doneDismissToolbar()
                }
            }
        }
        .task { await loadHistory() }
    }

    private var feedbackContent: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $selectedTab) {
                    Text(L10n.Settings.Feedback.title).tag(0)
                    Text(L10n.Settings.Feedback.history).tag(1)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
            .padding(.top, DesignTokens.Spacing.medium)
            .padding(.bottom, DesignTokens.Spacing.small)

            if selectedTab == 0 {
                submitForm
            } else {
                historyList
            }
        }
    }

    // MARK: - 提交表单

    private var submitForm: some View {
        let isSubmitDisabled = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting
        return VStack(spacing: 0) {
            Form {
                Section(L10n.Settings.Feedback.subject) {
                    TextField(L10n.Settings.Feedback.subjectPlaceholder, text: $titleText)
                }
                .appListRowBackground()
                
                Section(L10n.Settings.Feedback.category) {
                    Picker(L10n.Settings.Feedback.category, selection: $selectedCategory) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { cat in
                            Text(FeedbackCategory.displayName(cat)).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                .appListRowBackground()
                
                Section(L10n.Settings.Feedback.rating) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        ForEach(1...maxRating, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(.appAccent)
                                .onTapGesture { rating = star }
                        }
                        Spacer()
                    }
                }
                .appListRowBackground()
                
                Section(L10n.Settings.Feedback.content) {
                    TextEditor(text: $contentText)
                        .frame(minHeight: DesignSystem.FeedbackMetrics.textEditorHeight)
                        .overlay(alignment: .topLeading) {
                            if contentText.isEmpty {
                                Text(L10n.Settings.Feedback.contentPlaceholder)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, DesignTokens.Spacing.tightPadding)
                                    .padding(.leading, DesignTokens.Spacing.atomic)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .appListRowBackground()
                
                Section {
                    HStack {
                        Text(L10n.Settings.Feedback.appVersionLabel)
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(L10n.Settings.Feedback.osVersionLabel)
                        Spacer()
                        Text(deviceInfo.systemVersion).foregroundStyle(.secondary)
                    }
                }
                .appListRowBackground()
            }
            .appGroupedFormStyle()
            .scrollContentBackground(.hidden)
            .tint(Color.appAccent)

            Divider()

            HStack {
                Spacer()
                Button(action: submit) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(L10n.Settings.Feedback.submit)
                            .font(.body.weight(.semibold))
                    }
                    .padding(.horizontal, DesignTokens.Spacing.huge)
                    .padding(.vertical, DesignTokens.SystemSpacing.element)
                    .background(isSubmitDisabled ? Color.appAccent.opacity(DesignTokens.Opacity.disabled) : Color.appAccent)
                    .foregroundStyle(Color.theme.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.card, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitDisabled)
            }
            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
            .padding(.vertical, DesignTokens.Spacing.medium)
        }
    }

    // MARK: - 历史列表

    private var historyList: some View {
        Group {
            if history.isEmpty {
                VStack(spacing: DesignTokens.Spacing.standardPadding) {
                    Image(systemName: DesignTokens.Icons.bubbleLeftAndRight)
                        .font(.largeTitle).foregroundStyle(.secondary.opacity(DesignTokens.Opacity.soft))
                    Text(L10n.Settings.Feedback.noHistory)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history, id: \.id) { entry in
                        FeedbackHistoryRow(entry: entry)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Actions

    private func loadHistory() async {
        let historyLimit = 50
        history = (try? await repo.fetchAll(limit: historyLimit)) ?? []
    }

    private func submit() {
        isSubmitting = true
        let entry = FeedbackEntry(
            title: titleText, category: selectedCategory, rating: rating,
            content: contentText, appVersion: appVersion,
            osVersion: deviceInfo.systemVersion,
            deviceModel: deviceInfo.deviceModel
        )
        Task {
            try? await repo.save(entry)
            await MainActor.run {
                isSubmitting = false
                titleText = ""; contentText = ""; rating = DesignTokens.Spacing.Feedback.defaultRating
                HapticFeedback.shared.trigger(.success)
                toastManager.show(type: .success, message: L10n.Settings.Feedback.submitted)
                Task { await loadHistory() }
                selectedTab = 1
            }
        }
    }
}

// MARK: - 历史行

private struct FeedbackHistoryRow: View {
    let entry: FeedbackEntry

    private var categoryColor: Color {
        switch entry.category {
        case FeedbackCategory.bug: return Color.theme.red
        case FeedbackCategory.feature: return Color.theme.green
        case FeedbackCategory.content: return Color.theme.yellow
        default: return Color.theme.gray
        }
    }

    private var statusIcon: String {
        switch entry.status {
        case .pending: return "icloud.and.arrow.up"
        case .synced: return "checkmark.icloud.fill"
        case .failed: return "exclamationmark.icloud.fill"
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .pending: return .secondary
        case .synced: return Color.theme.green
        case .failed: return Color.theme.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
            HStack(spacing: DesignTokens.Spacing.tightPadding) {
                // swiftlint:disable:next magic_numbers_frame
                Circle().fill(categoryColor).frame(width: 8, height: 8)
                Text(entry.title).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                Image(systemName: statusIcon)
                    .font(.caption).foregroundStyle(statusColor)
                Text(FeedbackCategory.displayName(entry.category))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: DesignTokens.Spacing.tightPadding) {
                Text(entry.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    ForEach(1...DesignTokens.Spacing.Feedback.maxRating, id: \.self) { i in
                        Image(systemName: i <= entry.rating ? "star.fill" : "star")
                            .font(.caption2).foregroundStyle(.appAccent)
                    }
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.tightPadding)
    }
}
