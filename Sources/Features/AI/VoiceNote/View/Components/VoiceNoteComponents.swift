//
//  VoiceNoteComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：语音笔记：录音、转写、AI 摘要。
//
import SwiftUI

// MARK: - Save Voice Note Sheet
/// 语音笔记保存配置面板组件
/// 负责在保存语音识别结果前配置页面标题、类型，并展示转录文本预览供最终确认
struct SaveVoiceNoteSheet: View {
    // MARK: - UI 常量
    private enum UIConstants {
        static let previewMinHeight: CGFloat = 147.2
        static let previewMaxHeight: CGFloat = 368
    }
    
    var speechService: any SpeechServiceProtocol
    @Binding var title: String
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: PageType = .source
    @Environment(\.interfaceIdiom) private var idiom
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.loosePadding) { // 20
                    titleField
                    typePicker
                    previewSection
                    saveButton
                }
                .padding()
            }
            .background(PageBackgroundView(accentColor: .appAccent))
            .navigationTitle(L10n.Voice.Speech.saveTitle)
.appNavigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var titleField: some View {
        formSection(label: L10n.Voice.Speech.noteTitle) {
            TextField(L10n.Voice.Speech.noteTitlePlaceholder, text: $title)
                .roundedBorderTextFieldStyle()
        }
    }
    
    private var typePicker: some View {
        formSection(label: L10n.Ingest.OCR.pageType) {
            Picker("", selection: $selectedType) {
                // 遍历用户可见的页面类型，过滤掉内部 raw 类型
                ForEach(PageType.allVisibleCases) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .segmentedPickerStyleIfAvailable()
        }
    }
    
    private var previewSection: some View {
        formSection(label: L10n.Ingest.PDF.contentPreview) {
            makeTranscriptionEditor(
                speechService: speechService,
                idiom: idiom,
                minHeight: UIConstants.previewMinHeight,
                maxHeight: UIConstants.previewMaxHeight,
                padding: DesignSystem.small,
                cornerRadius: DesignSystem.standardRadius
            )
        }
    }

    /// 表单分区（消除重复的 VStack + Text 标签 + caption 字体链）
    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SystemSpacing.small) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)
            content()
        }
    }
    
    private var saveButton: some View {
        Button(action: saveNote) {
            Text(L10n.Voice.Speech.saveToKnowledge)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        }
    }
    
    private func saveNote() {
        let noteTitle = title.isEmpty
            ? "\(L10n.Voice.Speech.voiceNote) \(Date().formatted(Date.FormatStyle(date: .numeric, time: .shortened, locale: Localized.currentLocale)))"
            : title
        Task {
            _ = await store.createPage(
                title: noteTitle,
                pageType: selectedType,
                content: speechService.transcribedText,
                tags: [L10n.Voice.Speech.voiceTag]
            )
            
            await MainActor.run {
                _ = speechService.saveRecording(title: noteTitle)
                speechService.clearTranscription()
                title = ""
                dismiss()
            }
        }
    }
}

// MARK: - Voice Recording Row
/// 语音录音列表行组件
/// 负责展示语音笔记的摘要信息（标题、部分文本、创建日期）及波形图标
struct VoiceRecordingRow: View {
    let recording: VoiceRecording
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.waveform)
                .foregroundStyle(.appSource)
                .frame(width: DesignSystem.largeIconSize, height: DesignSystem.largeIconSize) // 32
                .background(Color.appSource.opacity(SystemOpacity.glass))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(recording.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.appText)
                    .lineLimit(1)
                Text(String(recording.text.prefix(FeatureConstants.VoiceNote.recordingTextPrefix)))
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(recording.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, SystemSpacing.elementLarge) // 10
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        .frame(maxWidth: .infinity)
    }
}
