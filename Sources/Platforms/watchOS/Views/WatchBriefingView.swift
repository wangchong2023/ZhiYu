//
//  WatchBriefingView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：构建 watchOS 端的每日知识语音简报播客界面。
//
#if os(watchOS)
import SwiftUI
import UFPCore
import AVFoundation

/// 手表端语音简报收听界面
@MainActor
struct WatchBriefingView: View {
    @Environment(\.dismiss) private var dismiss
    @Inject private var watchSync: any WatchSyncProtocol // inject_exempt: ObservableObject 不适合 @Dependency
    
    @State private var isPlaying = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var delegate = SpeechDelegate()
    
    var body: some View {
        VStack(spacing: SystemSpacing.medium) {
            if watchSync.isBriefingLoading {
                ProgressView(L10n.Watch.briefingSynthesizing)
                    .foregroundStyle(Color.theme.purple)
            } else if let briefing = watchSync.latestBriefing {
                ScrollView {
                    Text(briefing)
                        .font(.body)
                        .padding()
                }
                
                HStack(spacing: SystemSpacing.content) {
                    Button(action: {
                        if isPlaying {
                            synthesizer.pauseSpeaking(at: .word)
                            isPlaying = false
                        } else {
                            if synthesizer.isPaused {
                                synthesizer.continueSpeaking()
                            } else {
                                startSpeaking(text: briefing)
                            }
                            isPlaying = true
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: Reference.FontSize.hero)) // Dynamic Type
                            .foregroundStyle(Color.theme.purple)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        synthesizer.stopSpeaking(at: .immediate)
                        isPlaying = false
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: Reference.FontSize.largeTitle)) // Dynamic Type
                            .foregroundStyle(Color.theme.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, SystemSpacing.element)
            } else {
                VStack(spacing: SystemSpacing.element) {
                    Image(systemName: "headphones")
                        .font(.largeTitle)
                        .foregroundStyle(Color.theme.purple)
                    Text(L10n.Watch.briefingGetToday)
                        .font(.headline)
                    Button(L10n.Watch.briefingGenerateNow) {
                        watchSync.requestDailyBriefing()
                    }
                    .tint(.purple)
                }
            }
        }
        .navigationTitle(L10n.Watch.briefingAudioBriefing)
        .onAppear {
            setupAudioSession()
            synthesizer.delegate = delegate
            delegate.onFinish = {
                isPlaying = false
            }
        }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.shared.error("AVAudioSession_Setup_Error", error: error)
        }
    }
    
    private func startSpeaking(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }
}

final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (() -> Void)?
    
    /// speechSynthesizer回调
    /// /// - Parameter synthesizer: synthesizer
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onFinish?()
        }
    }
}
#endif
