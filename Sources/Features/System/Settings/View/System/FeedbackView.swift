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

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var titleText = ""
    @State private var selectedCategory = FeedbackCategory.bug
    private let maxRating = DesignSystem.Domain.Feedback.maxRating
    @State private var rating: Int = DesignSystem.Domain.Feedback.defaultRating
    @State private var contentText = ""
    @State private var isSubmitting = false
    @State private var history: [FeedbackEntry] = []

    @Inject private var repo: any FeedbackRepository
    @Inject private var deviceInfo: any DeviceInfoProtocol

    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.pageBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        Text(L10n.Settings.Feedback.submit).tag(0)
                    Text(L10n.Settings.Feedback.history).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    submitForm
                } else {
                    historyList
                }
            }
            .navigationTitle(L10n.Settings.Feedback.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            }
        }
        .task { await loadHistory() }
    }

    // MARK: - 提交表单

    private var submitForm: some View {
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
                .pickerStyle(.segmented)
            }
            .appListRowBackground()
            
            Section(L10n.Settings.Feedback.rating) {
                HStack {
                    Text(L10n.Settings.Feedback.rating)
                    Spacer()
                    ForEach(1...maxRating, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .foregroundStyle(.appAccent)
                            .onTapGesture { rating = star }
                    }
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
                                .padding(.top, DesignSystem.tightPadding)
                                .padding(.leading, DesignSystem.atomic)
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
            
            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if isSubmitting { ProgressView() } else { Text(L10n.Settings.Feedback.submit).bold() }
                        Spacer()
                    }
                }
                .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            .appListRowBackground()
        }
        .scrollContentBackground(.hidden)
        .tint(Color.appAccent)
    }

    // MARK: - 历史列表

    private var historyList: some View {
        Group {
            if history.isEmpty {
                VStack(spacing: DesignSystem.standardPadding) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.largeTitle).foregroundStyle(.secondary.opacity(DesignSystem.Opacity.soft))
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
            }
        }
    }

    // MARK: - Actions

    private func loadHistory() async {
        history = (try? await repo.fetchAll(limit: 50)) ?? []
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
                titleText = ""; contentText = ""; rating = DesignSystem.Domain.Feedback.defaultRating
                HapticFeedback.shared.trigger(.success)
                ToastManager.shared.show(type: .success, message: L10n.Settings.Feedback.submitted)
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
        case FeedbackCategory.bug: return .red
        case FeedbackCategory.feature: return .green
        case FeedbackCategory.content: return .yellow
        default: return .gray
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
        case .synced: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            HStack(spacing: DesignSystem.tightPadding) {
                // swiftlint:disable:next magic_numbers_frame
                Circle().fill(categoryColor).frame(width: 8, height: 8)
                Text(entry.title).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                Image(systemName: statusIcon)
                    .font(.caption).foregroundStyle(statusColor)
                Text(FeedbackCategory.displayName(entry.category))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: DesignSystem.tightPadding) {
                Text(entry.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    ForEach(1...DesignSystem.Domain.Feedback.maxRating, id: \.self) { i in
                        Image(systemName: i <= entry.rating ? "star.fill" : "star")
                            .font(.caption2).foregroundStyle(.appAccent)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.tightPadding)
    }
}
