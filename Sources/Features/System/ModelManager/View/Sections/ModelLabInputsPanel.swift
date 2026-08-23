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

// MARK: - 特有场景交互组件

extension ModelLabView {

    /// Ask Image 输入项
    var askImageInputs: some View {
        HStack(spacing: DesignSystem.medium) {
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                isImageSelected.toggle()
            }) {
                VStack(spacing: DesignSystem.standardPadding) {
                    if isImageSelected {
                        // 展现模拟工作台图片
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.cyan)
                        Text("workspace_bench.jpg")
                            .font(.caption)
                            .foregroundStyle(.appText)
                    } else {
                        Image(systemName: "plus.viewfinder")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(L10n.ModelManager.Lab.selectImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: DesignSystem.Metrics.sourceCardWidth + DesignSystem.tiny, height: DesignSystem.Metrics.boxHeight)
                .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
                .cornerRadius(SystemRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: SystemRadius.small)
                        .stroke(Color.appBorder.opacity(DesignSystem.Opacity.subtle), lineWidth: SystemStroke.divider)
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: DesignSystem.standardPadding / 2) {
                Text(L10n.ModelManager.Lab.visualParams)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(L10n.ModelManager.Lab.visualDesc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, DesignSystem.standardPadding - 2)
    }

    /// Audio Scribe 输入项
    var audioScribeInputs: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            HStack(spacing: DesignSystem.medium) {
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
                            .foregroundStyle(isAudioRecording ? .red : .cyan)
                        Text(isAudioRecording ? L10n.ModelManager.Lab.stopRecording : L10n.ModelManager.Lab.recordAudio)
                    }
                    .padding(.horizontal, DesignSystem.standardPadding + 8)
                    .padding(.vertical, DesignSystem.standardPadding + 2)
                    .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
                    .cornerRadius(SystemRadius.small)
                }
                .buttonStyle(.plain)

                if isAudioRecording {
                    HStack(spacing: DesignSystem.standardPadding / 2) {
                        ForEach(0..<6) { _ in
                            RoundedRectangle(cornerRadius: SystemStroke.selected)
                                .fill(Color.theme.cyan)
                                .frame(width: SystemStroke.heavy, height: CGFloat.random(in: DesignSystem.standardPadding...DesignSystem.large))
                                .animation(.easeInOut(duration: 0.25).repeatForever(), value: isAudioRecording)
                        }
                    }
                }
            }

            if isAudioCompleted {
                Text(L10n.ModelManager.Lab.audioCompleted)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.bottom, DesignSystem.standardPadding - 2)
    }

    /// Prompt Lab 滑块项
    var promptLabSliders: some View {
        VStack(spacing: DesignSystem.standardPadding) {
            sliderRow(title: "Temperature", val: $tempTemperature, range: 0.0...2.0, spec: "%.2f")
            sliderRow(title: "Top-P", val: $tempTopP, range: 0.0...1.0, spec: "%.2f")
        }
        .padding(.bottom, DesignSystem.standardPadding - 2)
    }

    func sliderRow(title: String, val: Binding<Double>, range: ClosedRange<Double>, spec: String) -> some View {
        VStack(spacing: DesignSystem.standardPadding / 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: spec, val.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.cyan)
            }
            Slider(value: val, in: range)
                .tint(.cyan)
        }
    }
}
