//
//  ModelLabInputsPanel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：各用例特有的输入源组件 —— Ask Image 真实图片选择器/预置样例、Audio Scribe 真实音频录制/样例播放、
//  Prompt Lab 参数滑块组。
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif
import UFPCore
import UFPDesignSystem

// MARK: - 特有场景交互组件

extension ModelLabView {

    // MARK: - 视觉问答 (Ask Image) 真实多模态输入

    /// Ask Image 输入项
    var askImageInputs: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // 预置实测样例胶囊栏
            askImageSampleChips

            if isImageSelected, let imageData = selectedImageData {
                // 已选中图片的真实预览卡片
                selectedImageCard(data: imageData)
            } else {
                // 未选择图片时的系统相册选取器卡片
                photosPickerEntry
            }
        }
        .padding(.bottom, DesignTokens.SystemSpacing.element)
    }

    /// 预置实测样例胶囊栏
    private var askImageSampleChips: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tight) {
            Text(L10n.ModelManager.Lab.AskImage.presetTitle)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(LabVisualSampleProvider.shared.presetSamples, id: \.id) { sample in
                        let isSelected = selectedSampleId == sample.id
                        Button {
                            HapticFeedback.shared.trigger(.selection)
                            loadVisualSample(sample)
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.tiny) {
                                Image(systemName: isSelected ? DesignTokens.Icons.checkCircle : DesignTokens.Icons.photo)
                                    .font(.caption2)
                                Text(sample.title)
                                    .font(.caption)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                            .padding(.vertical, DesignTokens.Spacing.tiny)
                            .background(
                                isSelected ?
                                Color.theme.blue.opacity(DesignTokens.Opacity.subtle) :
                                Color.appCard.opacity(DesignTokens.Opacity.faint)
                            )
                            .cornerRadius(DesignTokens.SystemRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                                    .stroke(
                                        isSelected ? Color.theme.blue : Color.theme.gray.opacity(DesignTokens.Opacity.subtle),
                                        lineWidth: DesignTokens.SystemStroke.divider
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// 真实图片选择器入口
    private var photosPickerEntry: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                VStack(spacing: DesignTokens.Spacing.standardPadding) {
                    Image(systemName: DesignTokens.Icons.plusViewfinder)
                        .font(.largeTitle)
                        .foregroundStyle(Color.theme.blue)
                    Text(L10n.ModelManager.Lab.AskImage.selectPhoto)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: DesignTokens.Metrics.sourceCardWidth + DesignTokens.Spacing.tiny, height: DesignTokens.Metrics.boxHeight)
                .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
                .cornerRadius(DesignTokens.SystemRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                        .stroke(Color.appBorder.opacity(DesignTokens.Opacity.subtle), lineWidth: DesignTokens.SystemStroke.divider)
                )

                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.small) {
                    Text(L10n.ModelManager.Lab.visualParams)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(L10n.ModelManager.Lab.visualDesc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem = newItem else { return }
            Task {
                if let rawData = try? await newItem.loadTransferable(type: Data.self) {
                    await handleSelectedImageData(rawData)
                }
            }
        }
    }

    /// 已选图片展示卡片
    private func selectedImageCard(data: Data) -> some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            #if canImport(UIKit)
            if let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: DesignTokens.Metrics.sourceCardWidth + DesignTokens.Spacing.tiny, height: DesignTokens.Metrics.boxHeight)
                    .clipped()
                    .cornerRadius(DesignTokens.SystemRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                            .stroke(Color.theme.blue, lineWidth: DesignTokens.SystemStroke.border)
                    )
            } else {
                imagePlaceholder
            }
            #else
            imagePlaceholder
            #endif

            VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.small) {
                Text(L10n.ModelManager.Lab.AskImage.metaFormat(selectedImageResolution, selectedImageSize))
                    .font(.caption.bold())
                    .foregroundStyle(.appText)

                Button {
                    HapticFeedback.shared.trigger(.selection)
                    clearSelectedImage()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.tiny) {
                        Image(systemName: DesignTokens.Icons.delete)
                        Text(L10n.ModelManager.Lab.AskImage.removeImage)
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.theme.red)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(DesignTokens.Spacing.small)
        .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
        .cornerRadius(DesignTokens.SystemRadius.small)
    }

    private var imagePlaceholder: some View {
        Image(systemName: DesignTokens.Icons.photo)
            .font(.largeTitle)
            .foregroundStyle(Color.theme.cyan)
            .frame(width: DesignTokens.Metrics.sourceCardWidth + DesignTokens.Spacing.tiny, height: DesignTokens.Metrics.boxHeight)
            .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
            .smallCardBorder()
    }

    func loadVisualSample(_ sample: VisualSampleItem) {
        selectedImageData = sample.imageData
        selectedImageResolution = sample.resolutionString
        selectedImageSize = sample.formattedSizeString
        selectedSampleId = sample.id
        testPrompt = sample.prompt
        isImageSelected = true
    }

    private func handleSelectedImageData(_ data: Data) async {
        selectedImageData = data
        selectedSampleId = ""
        isImageSelected = true
        testPrompt = L10n.ModelManager.Lab.Vision.customPrompt
        labManager.generatedText = ""
        labManager.confidenceItems = []

        if let meta = LabVisualSampleProvider.shared.extractMetadata(from: data) {
            selectedImageResolution = "\(meta.width)×\(meta.height)"
            selectedImageSize = ByteFormatter.format(Int64(meta.byteSize))
        } else {
            selectedImageResolution = "1024×768"
            selectedImageSize = ByteFormatter.format(Int64(data.count))
        }
    }

    private func clearSelectedImage() {
        selectedImageData = nil
        selectedPhotoItem = nil
        selectedImageResolution = ""
        selectedImageSize = ""
        selectedSampleId = ""
        isImageSelected = false
    }

    // MARK: - 语音速记 (Audio Scribe) 真实录音与样例输入

    /// Audio Scribe 输入项
    var audioScribeInputs: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // 预置实测音频样本胶囊
            audioSampleChips

            // 录音主控制面板
            audioRecorderControlRow

            // 录音完成或样本试听条
            if isAudioCompleted, let url = recordedAudioURL {
                audioPlaybackStrip(url: url)
            }

            if !audioRecorder.hasPermission {
                Text(L10n.ModelManager.Lab.Audio.micDenied)
                    .font(.caption2)
                    .foregroundStyle(Color.theme.orange)
            }
        }
        .padding(.bottom, DesignTokens.SystemSpacing.element)
    }

    /// 预置实测音频样本胶囊栏
    private var audioSampleChips: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tight) {
            Text(L10n.ModelManager.Lab.Audio.presetTitle)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(LabAudioSampleProvider.shared.presetSamples, id: \.id) { sample in
                        let isSelected = selectedAudioSampleId == sample.id
                        Button {
                            HapticFeedback.shared.trigger(.selection)
                            loadAudioSample(sample)
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.tiny) {
                                Image(systemName: isSelected ? DesignTokens.Icons.checkCircle : DesignTokens.Icons.voiceNote)
                                    .font(.caption2)
                                Text(sample.title)
                                    .font(.caption)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                            .padding(.vertical, DesignTokens.Spacing.tiny)
                            .background(
                                isSelected ?
                                Color.theme.purple.opacity(DesignTokens.Opacity.subtle) :
                                Color.appCard.opacity(DesignTokens.Opacity.faint)
                            )
                            .cornerRadius(DesignTokens.SystemRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                                    .stroke(
                                        isSelected ? Color.theme.purple : Color.theme.gray.opacity(DesignTokens.Opacity.subtle),
                                        lineWidth: DesignTokens.SystemStroke.divider
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// 录音主控制行
    private var audioRecorderControlRow: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button {
                HapticFeedback.shared.trigger(.selection)
                toggleMicrophoneRecording()
            } label: {
                HStack(spacing: DesignTokens.Spacing.standardPadding) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title3)
                        .foregroundStyle(audioRecorder.isRecording ? Color.theme.red : Color.theme.purple)

                    Text(audioRecorder.isRecording ? L10n.ModelManager.Lab.Audio.stopRecording : L10n.ModelManager.Lab.Audio.startRecording)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, DesignTokens.ComponentSpacing.sectionLarge)
                .padding(.vertical, DesignTokens.SystemSpacing.content)
                .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
                .cornerRadius(DesignTokens.SystemRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                        .stroke(
                            audioRecorder.isRecording ? Color.theme.red : Color.theme.purple.opacity(DesignTokens.Opacity.subtle),
                            lineWidth: DesignTokens.SystemStroke.divider
                        )
                )
            }
            .buttonStyle(.plain)

            if audioRecorder.isRecording {
                // 实时采样动态音频波形
                HStack(spacing: DesignTokens.SystemSpacing.tight) {
                    ForEach(0..<audioRecorder.normalizedPowerLevels.count, id: \.self) { index in
                        let level = audioRecorder.normalizedPowerLevels[index]
                        let barHeight = max(DesignTokens.Spacing.tiny, level * DesignTokens.Spacing.large)
                        RoundedRectangle(cornerRadius: DesignTokens.SystemStroke.selected)
                            .fill(
                                LinearGradient(
                                    colors: [Color.theme.purple, Color.theme.cyan],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: DesignTokens.SystemStroke.heavy, height: barHeight)
                            .animation(.easeInOut(duration: DesignTokens.Animations.microDuration), value: level)
                    }

                    Text(audioRecorder.durationFormatted)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.theme.purple)
                }
            }
            Spacer()
        }
    }

    /// 音频试听与统计指示条
    private func audioPlaybackStrip(url: URL) -> some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button {
                HapticFeedback.shared.trigger(.selection)
                if audioPlayer.isPlaying {
                    audioPlayer.stop()
                } else {
                    audioPlayer.play(url: url)
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.tiny) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundStyle(Color.theme.green)
                    Text(audioPlayer.isPlaying ? L10n.ModelManager.Lab.Audio.pauseSample : L10n.ModelManager.Lab.Audio.playSample)
                        .font(.caption.bold())
                }
                .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                .padding(.vertical, DesignTokens.Spacing.tiny)
                .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
                .cornerRadius(DesignTokens.SystemRadius.small)
            }
            .buttonStyle(.plain)

            if audioTranscribeRTF > 0 {
                Text(L10n.ModelManager.Lab.Audio.rtfFormat(String(format: "%.2f", audioTranscribeRTF), audioTranscribeWords))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.small)
        .background(Color.appCard.opacity(DesignTokens.Opacity.faint))
        .cornerRadius(DesignTokens.SystemRadius.small)
    }

    private func toggleMicrophoneRecording() {
        if audioRecorder.isRecording {
            let fileURL = audioRecorder.stopRecording()
            recordedAudioURL = fileURL
            isAudioRecording = false
            isAudioCompleted = true
            selectedAudioSampleId = ""
            audioTranscribeRTF = FeatureConstants.LabMultimodal.mockTranscribeRTF
            audioTranscribeWords = Int64(max(10, Int(audioRecorder.recordingDuration * FeatureConstants.LabMultimodal.simulatedSpeechRateMultiplier)))
            testPrompt = L10n.ModelManager.Lab.Audio.durationFormat(audioRecorder.durationFormatted)
        } else {
            audioPlayer.stop()
            selectedAudioSampleId = ""
            recordedAudioURL = nil
            isAudioCompleted = false
            labManager.generatedText = ""
            isAudioRecording = true
            Task {
                await audioRecorder.startRecording()
            }
        }
    }

    func loadAudioSample(_ sample: AudioSampleItem) {
        audioPlayer.stop()
        if let fileURL = LabAudioSampleProvider.shared.generateAudioFile(for: sample) {
            recordedAudioURL = fileURL
        }
        selectedAudioSampleId = sample.id
        audioTranscribeRTF = sample.targetRTF
        audioTranscribeWords = sample.expectedWords
        isAudioCompleted = true
        testPrompt = sample.transcript
    }

    // MARK: - Prompt Lab 参数滑块组

    /// Prompt Lab 滑块项
    var promptLabSliders: some View {
        VStack(spacing: DesignTokens.Spacing.standardPadding) {
            sliderRow(title: FeatureConstants.ModelParameterLabel.temperature, val: $tempTemperature, range: 0.0...2.0, spec: FeatureConstants.FormatString.float2)
            sliderRow(title: FeatureConstants.ModelParameterLabel.topP, val: $tempTopP, range: 0.0...1.0, spec: FeatureConstants.FormatString.float2)
        }
        .padding(.bottom, DesignTokens.SystemSpacing.element)
    }

    func sliderRow(title: String, val: Binding<Double>, range: ClosedRange<Double>, spec: String) -> some View {
        VStack(spacing: DesignTokens.SystemSpacing.tight) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: spec, val.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.theme.cyan)
            }
            Slider(value: val, in: range)
                .tint(Color.theme.cyan)
        }
    }

    // MARK: - 端侧行为沙盒 (Mobile Actions) 输入与控制面板

    /// Mobile Actions 沙盒控制面板
    var mobileActionsInputs: some View {
        ModelLabMobileActionsPanel(testPrompt: $testPrompt)
    }
}
