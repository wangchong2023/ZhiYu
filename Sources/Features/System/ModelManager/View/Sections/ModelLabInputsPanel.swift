//
//  ModelLabInputsPanel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：各用例特有的输入源组件 —— Ask Image 图片选择器、Audio Scribe 录音控件、
//  Prompt Lab 参数滑块组。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 特有场景交互组件

extension ModelLabView {

    /// Ask Image 输入项
    var askImageInputs: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                isImageSelected.toggle()
            }) {
                VStack(spacing: DesignTokens.Spacing.standardPadding) {
                    if isImageSelected {
                        // 展现模拟工作台图片
                        Image(systemName: DesignTokens.Icons.photo)
                            .font(.largeTitle)
                            .foregroundStyle(Color.theme.cyan)
                        Text(FeatureConstants.MockData.workspaceBenchFileName)
                            .font(.caption)
                            .foregroundStyle(.appText)
                    } else {
                        Image(systemName: DesignTokens.Icons.plusViewfinder)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(L10n.ModelManager.Lab.selectImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: DesignTokens.Metrics.sourceCardWidth + DesignTokens.Spacing.tiny, height: DesignTokens.Metrics.boxHeight)
                .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
                .smallCardBorder()
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.small) {
                Text(L10n.ModelManager.Lab.visualParams)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(L10n.ModelManager.Lab.visualDesc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, DesignTokens.SystemSpacing.element)
    }

    /// Audio Scribe 输入项
    var audioScribeInputs: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                Button {
                    HapticFeedback.shared.trigger(.selection)
                    if isAudioRecording {
                        isAudioRecording = false
                        isAudioCompleted = true
                        testPrompt = L10n.ModelManager.Lab.audioReady
                    } else {
                        isAudioRecording = true
                        isAudioCompleted = false
                        labManager.generatedText = ""
                    }
                } label: {
                    HStack {
                        Image(systemName: isAudioRecording ? "stop.circle.fill" : "record.circle")
                            .foregroundStyle(isAudioRecording ? Color.theme.red : Color.theme.cyan)
                        Text(isAudioRecording ? L10n.ModelManager.Lab.stopRecording : L10n.ModelManager.Lab.recordAudio)
                    }
                    .padding(.horizontal, DesignTokens.ComponentSpacing.sectionLarge)
                    .padding(.vertical, DesignTokens.SystemSpacing.content)
                    .background(Color.appCard.opacity(DesignTokens.Opacity.subtle))
                    .cornerRadius(DesignTokens.SystemRadius.small)
                }
                .buttonStyle(.plain)

                if isAudioRecording {
                    HStack(spacing: DesignTokens.SystemSpacing.small) {
                        ForEach(0..<FeatureConstants.ModelLabSimulation.waveformBarCount, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: DesignTokens.SystemStroke.selected)
                                .fill(Color.theme.cyan)
                                .frame(width: DesignTokens.SystemStroke.heavy, height: CGFloat.random(in: DesignTokens.Spacing.standardPadding...DesignTokens.Spacing.large))
                                .animation(.easeInOut(duration: 0.25).repeatForever(), value: isAudioRecording)
                        }
                    }
                }
            }

            if isAudioCompleted {
                Text(L10n.ModelManager.Lab.audioCompleted)
                    .font(.caption)
                    .foregroundStyle(Color.theme.green)
            }
        }
        .padding(.bottom, DesignTokens.SystemSpacing.element)
    }

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
}
