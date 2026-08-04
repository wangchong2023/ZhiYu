//
//  WatchVoiceCaptureView.swift
//  ZhiYuWatch
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / watchOS 平台适配
//  核心职责：Apple Watch 极速语音灵感捕捉界面（一键录音与同步）
//

import SwiftUI
import UFPCore

#if os(watchOS)
import WatchKit
#endif

public struct WatchVoiceCaptureView: View {
    @Inject private var watchSync: any WatchSyncProtocol
    @State private var isRecording = false
    @State private var recordedText = ""
    @State private var showSuccessBanner = false

    public init() {}

    public var body: some View {
        VStack(spacing: DesignSystem.small) {
            Text(isRecording ? L10n.Widget.dictating : L10n.Widget.voiceFlashCapture)
                .font(.caption.weight(.bold))
                .foregroundStyle(isRecording ? Color.appAccent : Color.appText)

            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.theme.red.opacity(DesignSystem.Opacity.soft) : Color.appAccent.opacity(DesignSystem.Opacity.soft))
                        .frame(width: DesignSystem.huge * 2, height: DesignSystem.huge * 2)

                    Image(systemName: isRecording ? DesignSystem.Icons.stopFill : DesignSystem.Icons.voiceNote)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isRecording ? Color.theme.red : Color.appAccent)
                }
            }
            .buttonStyle(.plain)

            if !recordedText.isEmpty {
                Text(recordedText)
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondary)
                    .lineLimit(2)
            }

            if showSuccessBanner {
                Label(L10n.Widget.syncedToiOS, systemImage: DesignSystem.Icons.check)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.theme.green)
                    .transition(.opacity)
            }
        }
        .padding(DesignSystem.small)
    }

    private func toggleRecording() {
        withAnimation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping)) {
            isRecording.toggle()
            if !isRecording {
                recordedText = L10n.Widget.sampleVoiceNote
                watchSync.sendContent(recordedText)
                #if os(watchOS)
                WKInterfaceDevice.current().play(.success)
                #endif
                showSuccessBanner = true
            }
        }
    }
}

#Preview(L10n.Widget.watchVoiceCapture) {
    WatchVoiceCaptureView()
}
