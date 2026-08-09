//
//  VoiceAudioPlayerView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：为语音笔记提供专用的音频播放器卡片，支持音频播放、暂停、进度条拖拽、波形动画与转写文本展示。
//

import SwiftUI
import AVFoundation
import NaturalLanguage
import UFPCore

/// 语音笔记时间戳定界符（首行 [00:00] 格式标记）
private enum VoiceTimestampDelimiter {
    static let openBracket: String = SystemConstants.Character.openBracket
    static let closeBracket: String = SystemConstants.Character.closeBracket
}

struct VoiceAudioPlayerView: View {
    let title: String
    let audioPath: String?
    let transcribedText: String
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 45.0
    @State private var waveformLevels: [CGFloat] = [0.3, 0.6, 0.4, 0.8, 0.5, 0.9, 0.3, 0.7, 0.4, 0.6, 0.8, 0.3, 0.5, 0.7, 0.4, 0.9, 0.6, 0.3]
    @Environment(\.interfaceIdiom) private var idiom
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            // 1. 音频播放器主卡片
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                HStack {
                    Label(L10n.Ingest.voiceNote, systemImage: "waveform")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.vertical, DesignSystem.tightPadding)
                        .background(Capsule().fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle)))
                        .foregroundStyle(.appAccent)
                    
                    Spacer()
                    
                    Text("AAC 44.1kHz")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                // 波形跳动图
                HStack(spacing: DesignSystem.tiny) {
                    ForEach(0..<waveformLevels.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: DesignSystem.tiny)
                            .fill(isPlaying ? Color.appAccent : Color.appAccent.opacity(DesignSystem.Opacity.medium))
                            .frame(height: isPlaying ? waveformLevels[index] * 32 + 8 : 12)
                            .animation(.easeInOut(duration: 0.2).repeatCount(1, autoreverses: true), value: isPlaying)
                    }
                }
                .frame(height: DesignSystem.Metrics.iconBoxSize)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.tiny)
                
                // 播放进度与控制行
                VStack(spacing: DesignSystem.tiny) {
                    Slider(value: $currentTime, in: 0...max(1, duration)) { editing in
                        if !editing, let player = audioPlayer {
                            player.currentTime = currentTime
                        }
                    }
                    .tint(.appAccent)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 控制按钮行
                HStack(spacing: DesignSystem.loosePadding) {
                    Spacer()
                    
                    Button(action: { seekBy(-5) }) {
                        Image(systemName: "gobackward.5")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48)) // Dynamic Type
                            .foregroundStyle(.appAccent)
                            .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: DesignSystem.smallRadius)
                    }
                    
                    Button(action: { seekBy(5) }) {
                        Image(systemName: "goforward.5")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                }
            }
            .padding(DesignSystem.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                    .fill(Color.appCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                            .stroke(Color.appAccent.opacity(DesignSystem.Opacity.medium), lineWidth: 1)
                    )
            )
            
            // 2. 语音转写正文
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                Label(L10n.Voice.Speech.result, systemImage: "doc.plaintext")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)
                
                FormattedMarkdownText(text: cleanText)
            }
        }
        .onAppear { setupAudioPlayer() }
        .onDisappear { stopAudioPlayer() }
        .onReceive(timer) { _ in updatePlaybackState() }
    }
    
    private var cleanText: String {
        transcribedText
            .replacingOccurrences(of: "[[", with: "「")
            .replacingOccurrences(of: "]]", with: "」")
    }
    
    private func setupAudioPlayer() {
        if idiom == .iPhone || idiom == .iPad {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        
        if let path = audioPath, FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                if let p = audioPlayer {
                    duration = p.duration
                }
            } catch {
                // Audio player fallback handled gracefully
            }
        }
    }
    
    private func togglePlayPause() {
        if idiom == .iPhone || idiom == .iPad {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        
        if isPlaying {
            if let player = audioPlayer {
                player.pause()
            } else {
                VoiceSpeechState.shared.stop()
            }
            isPlaying = false
        } else {
            if let player = audioPlayer {
                player.play()
                isPlaying = true
            } else {
                VoiceSpeechState.shared.speak(text: transcribedText)
                isPlaying = true
            }
        }
    }
    
    private func seekBy(_ seconds: TimeInterval) {
        let target = max(0, min(duration, currentTime + seconds))
        currentTime = target
        audioPlayer?.currentTime = target
    }
    
    private func stopAudioPlayer() {
        audioPlayer?.stop()
        VoiceSpeechState.shared.stop()
        isPlaying = false
    }
    
    private func updatePlaybackState() {
        guard isPlaying else { return }
        if let player = audioPlayer {
            currentTime = player.currentTime
            if !player.isPlaying {
                isPlaying = false
            }
        } else {
            if !VoiceSpeechState.shared.isSpeaking {
                isPlaying = false
            } else {
                currentTime += 0.1
            }
        }
        
        // 更新波形律动
        waveformLevels = (0..<18).map { _ in CGFloat.random(in: 0.2...1.0) }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - AVSpeechSynthesizer 中文普通话人声朗读单例
@MainActor
final class VoiceSpeechState: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceSpeechState()
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// 触发文本语音朗读并管理 AVAudioSession 声音播放会话
    /// - Parameter text: 待转换朗读的原始 Markdown 或纯文本
    func speak(text: String) {
        configurePlaybackSessionIfNeeded()
        
        stop()
        var cleanText = text
        if let firstLineEnd = cleanText.firstIndex(of: "\n") {
            let firstLine = cleanText[..<firstLineEnd]
            if firstLine.hasPrefix("🎙️") || (firstLine.contains(VoiceTimestampDelimiter.openBracket) && firstLine.contains(VoiceTimestampDelimiter.closeBracket)) {
                cleanText = String(cleanText[firstLineEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        cleanText = cleanText
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(cleanText)
        let detectedLang = recognizer.dominantLanguage?.rawValue ?? "zh-CN"
        
        let languageCode: String
        switch detectedLang {
        case "en": languageCode = "en-US"
        case "ja": languageCode = "ja-JP"
        case "ko": languageCode = "ko-KR"
        case "fr": languageCode = "fr-FR"
        case "de": languageCode = "de-DE"
        case "es": languageCode = "es-ES"
        case "zh-Hant": languageCode = "zh-TW"
        default: languageCode = "zh-CN"
        }
        
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode) ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// 在 iOS 平台配置 AVAudioSession 为播放模式
    /// - Note: macOS / watchOS 无 AVAudioSession 概念，运行时跳过。
    private func configurePlaybackSessionIfNeeded() {
        let idiom = InterfaceIdiomKey.defaultValue
        guard idiom == .iPhone || idiom == .iPad else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
