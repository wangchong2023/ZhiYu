//
//  SynthesisControlSheet.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：合成前控制维度弹窗 Sheet（篇幅深度、目标受众、语气风格调节）。
//

import SwiftUI

struct SynthesisControlSheet: View {
    let type: SynthesisStore.SynthesisType
    let onConfirm: (SynthesisControlOptions) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var options = SynthesisControlOptions()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.AI.Synthesis.Control.describeSynthesisType(type.title))) {
                    TextField(type.customPromptPlaceholder, text: $options.customPrompt, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.subheadline)
                }

                Section(header: Text(L10n.AI.Synthesis.Control.depth)) {
                    Picker(L10n.AI.Synthesis.Control.depth, selection: $options.depth) {
                        Text(L10n.AI.Synthesis.Control.Depth.concise).tag(SynthesisControlOptions.Depth.concise)
                        Text(L10n.AI.Synthesis.Control.Depth.standard).tag(SynthesisControlOptions.Depth.standard)
                        Text(L10n.AI.Synthesis.Control.Depth.detailed).tag(SynthesisControlOptions.Depth.detailed)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text(L10n.AI.Synthesis.Control.audience)) {
                    Picker(L10n.AI.Synthesis.Control.audience, selection: $options.audience) {
                        Text(L10n.AI.Synthesis.Control.Audience.beginner).tag(SynthesisControlOptions.Audience.beginner)
                        Text(L10n.AI.Synthesis.Control.Audience.professional).tag(SynthesisControlOptions.Audience.professional)
                        Text(L10n.AI.Synthesis.Control.Audience.executive).tag(SynthesisControlOptions.Audience.executive)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text(L10n.AI.Synthesis.Control.tone)) {
                    Picker(L10n.AI.Synthesis.Control.tone, selection: $options.tone) {
                        Text(L10n.AI.Synthesis.Control.Tone.academic).tag(SynthesisControlOptions.Tone.academic)
                        Text(L10n.AI.Synthesis.Control.Tone.professional).tag(SynthesisControlOptions.Tone.professional)
                        Text(L10n.AI.Synthesis.Control.Tone.casual).tag(SynthesisControlOptions.Tone.casual)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.AI.Synthesis.Control.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.AI.Synthesis.Control.startSynthesis) {
                        onConfirm(options)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
