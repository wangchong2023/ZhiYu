//
//  VoiceNoteView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 VoiceNote 界面的 UI 视图层组件。
//
import SwiftUI
import Combine
import UFPCore
import Dependencies
import UFPDesignSystem

// MARK: - 语音笔记入口
/// 语音笔记功能主视图
/// 负责语音输入的实时采集、波形可视化展示、流式语音转文字（STT）及知识摘要提取
struct VoiceNoteView: View {
    // MARK: - UI 常量
    private enum UIConstants {
        static let waveformBarCount: Int = Int(DesignTokens.ComponentSpacing.section)
    }
    
    @Dependency(\.speechService) private var speechService: any SpeechServiceProtocol
    @Environment(AppStore.self) var store
    @State private var noteTitle = ""
    @State private var showSaveSheet = false
    @State private var recordingStartTime: Date?
    @State private var elapsedSeconds: Int = 0
    @Environment(\.dismiss) private var dismiss
    var onFinish: ((String, String, URL?) -> Void)?
    @Environment(\.interfaceIdiom) private var idiom

    private let maxDuration = AppConstants.Keys.ImportLimits.maxVoiceDurationSeconds
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = (noteTitle, showSaveSheet)
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.standardPadding) {
                headerSection
                languagePicker
                recordingSection
                
                if speechService.isRecording {
                    waveformSection
                }
                
                if !speechService.transcribedText.isEmpty {
                    transcriptionSection
                }
                
                if !speechService.recordings.isEmpty {
                    recordingsSection
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
            .padding(.top, DesignTokens.Spacing.medium)
            .padding(.bottom, DesignTokens.Spacing.giant)
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .navigationTitle(L10n.Voice.Speech.title)
        .inlineNavigationBarTitleIfAvailable()
        .hideNavigationBarIfIOS(true)
        .sheet(isPresented: $showSaveSheet) {
            SaveVoiceNoteSheet(speechService: speechService, title: $noteTitle)
        }
        .onReceive(timer) { _ in
            guard speechService.isRecording, let start = recordingStartTime else { return }
            elapsedSeconds = Int(Date().timeIntervalSince(start))
            if TimeInterval(elapsedSeconds) >= maxDuration {
                speechService.stopRecording()
                recordingStartTime = nil
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            Image(systemName: DesignTokens.Icons.waveformCircleFill)
                .font(.system(size: DesignTokens.Reference.FontSize.mega))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appAccent, .appSource],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(L10n.Voice.Speech.subtitle)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignTokens.Spacing.medium)
    }
    
    // MARK: - Language Picker
    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(L10n.Voice.Speech.Language)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)
            
            Picker(L10n.Voice.Speech.Language, selection: Binding(
                get: { speechService.selectedLanguage },
                set: { speechService.selectedLanguage = $0 }
            )) {
                ForEach(speechService.supportedLanguages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .skipOnWatch { $0.pickerStyle(.menu).tint(.appAccent) }
        }
        .appContainer(cornerRadius: DesignTokens.Spacing.cardRadius, padding: true)
    }
    
    // MARK: - 录音控制板块
    private var recordingSection: some View {
        VStack(spacing: DesignSystem.Domain.Voice.recordingSectionSpacing) {
            if !speechService.hasPermission {
                permissionSection
            } else {
                recordButton
                recordingStatusText
            }
        }
    }
    
    private var permissionSection: some View {
        VStack(spacing: DesignSystem.Domain.Voice.permissionSectionSpacing) {
            Image(systemName: DesignTokens.Icons.micSlashFill)
                .font(.title)
                .foregroundStyle(Color.theme.red)
            
            Text(L10n.Voice.Speech.needPermission)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { speechService.checkPermission() }) {
                Text(L10n.Voice.Speech.requestPermission)
                    .font(.subheadline.weight(.medium))
                    .voiceAccentButton(horizontalPadding: DesignTokens.Spacing.wide, cornerRadius: DesignTokens.Spacing.standardRadius)
            }
        }
        .appContainer(cornerRadius: DesignTokens.Spacing.cardRadius, padding: true)
    }
    
    private var recordButton: some View {
        Button(action: {
            if speechService.isRecording {
                speechService.stopRecording()
                recordingStartTime = nil
            } else {
                speechService.startRecording()
                recordingStartTime = Date()
                elapsedSeconds = 0
            }
        }) {
            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.appRecording.opacity(DesignTokens.SystemOpacity.glass) : Color.appAccent.opacity(DesignTokens.Opacity.glass))
                    .frame(width: DesignSystem.Domain.Voice.recordButtonSize, height: DesignSystem.Domain.Voice.recordButtonSize)
                
                if speechService.isRecording {
                    RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                        .fill(Color.appRecording)
                        .frame(width: DesignTokens.ComponentSpacing.huge, height: DesignTokens.ComponentSpacing.huge)
                } else {
                    Image(systemName: DesignTokens.Icons.micFill)
                        .font(.system(size: DesignTokens.Typography.displayFontSize))
                        .foregroundStyle(.appAccent)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var recordingStatusText: some View {
        VStack(spacing: DesignSystem.Domain.Voice.statusTextSpacing) {
            Text(speechService.isRecording ? L10n.Voice.Speech.tapToStop : L10n.Voice.Speech.tapToRecord)
                .font(.caption)
                .foregroundStyle(.appSecondary)
            
            Text(speechService.statusMessage)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
                .padding(.horizontal, DesignSystem.Domain.Voice.statusLabelHorizontalPadding)
                .padding(.vertical, DesignSystem.Domain.Voice.statusLabelVerticalPadding)
                .appCardClip(cornerRadius: DesignTokens.Spacing.smallRadius)
        }
    }
    
    // MARK: - 波形展示
    private var waveformSection: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Text(L10n.Voice.Speech.audioLevel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)

            HStack(spacing: DesignSystem.Domain.Voice.waveBarSpacing) {
                ForEach(0..<UIConstants.waveformBarCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: DesignTokens.Spacing.tiny)
                        .fill(Color.appAccent)
                        .frame(width: DesignSystem.Domain.Voice.waveBarWidth, height: max(DesignSystem.Domain.Voice.waveBarMinHeight, CGFloat(speechService.audioLevelHistory[i]) * DesignSystem.Domain.Voice.waveScale))
                }
            }
            .frame(height: DesignSystem.Domain.Voice.waveformHeight)
        }
        .appContainer(cornerRadius: DesignTokens.Spacing.cardRadius, padding: true)
    }
    
    // MARK: - 转写结果
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            HStack {
                Text(L10n.Voice.Speech.result)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)
                
                Spacer()
                
                Button(action: { AppPasteboard.string = speechService.transcribedText }) {
                    Image(systemName: DesignTokens.Icons.docOnDocFill)
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                }
                
                Button(action: { speechService.clearTranscription() }) {
                    Image(systemName: DesignTokens.Icons.errorCircle)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
            }
            
            makeTranscriptionEditor(
                speechService: speechService,
                idiom: idiom,
                minHeight: DesignSystem.Domain.Voice.transcriptionEditorMinHeight,
                maxHeight: DesignSystem.Domain.Voice.transcriptionEditorMaxHeight,
                padding: DesignTokens.Spacing.medium,
                cornerRadius: DesignTokens.Spacing.smallRadius
            )
            
            if idiom == .watch {
                HStack {
                    Text("\(speechService.transcribedText.count) \(L10n.Voice.Speech.characters)")
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                    
                    Spacer()
                    
                    Button(action: { 
                        onFinish?(L10n.Voice.Speech.defaultTitle, speechService.transcribedText, speechService.currentAudioFileURL)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: DesignTokens.Icons.squareAndPencil)
                            Text(L10n.Voice.Speech.confirmAndEdit)
                        }
                        .font(.subheadline.weight(.medium))
                        .voiceAccentButton(horizontalPadding: DesignTokens.Spacing.standardPadding, cornerRadius: DesignTokens.Spacing.standardRadius)
                    }
                }
            }
        }
        .appContainer(cornerRadius: DesignTokens.Spacing.cardRadius, padding: true)
    }
    
    // MARK: - Recordings History
    private var recordingsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack {
                Text(L10n.Voice.Speech.history)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)
                
                Text("\(speechService.recordings.count)")
                    .font(.caption2.weight(.medium))
                    .voiceAccentButton(horizontalPadding: DesignTokens.Spacing.small, cornerRadius: DesignTokens.Spacing.microRadius)
            }
            
            VStack(spacing: DesignTokens.Spacing.small) {
                ForEach(Array(speechService.recordings.prefix(FeatureConstants.VoiceNote.maxRecordingPreview))) { recording in
                    VoiceRecordingRow(recording: recording)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - VoiceNote Accent 按钮样式辅助
private extension View {
    /// VoiceNote 专用 Accent 按钮：白字 + 水平内边距 + appAccent 背景 + 圆角
    func voiceAccentButton(horizontalPadding: CGFloat, cornerRadius: CGFloat) -> some View {
        self
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .background(Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - TranscriptionEditor 构造辅助
/// 消除 VoiceNoteView 与 VoiceNoteComponents 重复的 TranscriptionEditor Binding 构造
@MainActor
func makeTranscriptionEditor(
    speechService: any SpeechServiceProtocol,
    idiom: InterfaceIdiom,
    minHeight: CGFloat,
    maxHeight: CGFloat,
    padding: CGFloat,
    cornerRadius: CGFloat
) -> TranscriptionEditor {
    TranscriptionEditor(
        text: Binding(
            get: { speechService.transcribedText },
            set: { speechService.transcribedText = $0 }
        ),
        idiom: idiom,
        minHeight: minHeight,
        maxHeight: maxHeight,
        padding: padding,
        cornerRadius: cornerRadius
    )
}
