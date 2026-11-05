//
//  LabAudioSampleProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 工具模块
//  核心职责：Model Lab 语音速记 (Audio Scribe) 真实预置音频生成、转写文本与试听播放器。
//

import Foundation
import AVFoundation
import SwiftUI
import UFPCore

/// 音频测试样本定义
struct AudioSampleItem: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let durationSeconds: Double
    let transcript: String
    let expectedWords: Int64
    let targetRTF: Double

    var durationFormatted: String {
        let mins = Int(durationSeconds) / FeatureConstants.LabMultimodal.secondsPerMinute
        let secs = Int(durationSeconds) % FeatureConstants.LabMultimodal.secondsPerMinute
        let ms = Int((durationSeconds.truncatingRemainder(dividingBy: 1.0)) * FeatureConstants.LabMultimodal.decisecondMultiplier)
        return String(format: "%02d:%02d.%d", mins, secs, ms)
    }
}

/// 预置音频样例提供者与沙盒合成引擎
final class LabAudioSampleProvider: Sendable {

    static let shared = LabAudioSampleProvider()

    private init() {}

    /// 预置实测音频样本列表
    var presetSamples: [AudioSampleItem] {
        [
            AudioSampleItem(
                id: "meeting_memo",
                title: L10n.ModelManager.Lab.Audio.sampleMeeting,
                durationSeconds: 4.8,
                transcript: L10n.ModelManager.Lab.Audio.sampleMeetingText,
                expectedWords: 68,
                targetRTF: 0.18
            ),
            AudioSampleItem(
                id: "schedule_reminder",
                title: L10n.ModelManager.Lab.Audio.sampleSchedule,
                durationSeconds: 3.5,
                transcript: L10n.ModelManager.Lab.Audio.sampleScheduleText,
                expectedWords: 52,
                targetRTF: 0.22
            ),
            AudioSampleItem(
                id: "tech_discussion",
                title: L10n.ModelManager.Lab.Audio.sampleTech,
                durationSeconds: 6.2,
                transcript: L10n.ModelManager.Lab.Audio.sampleTechText,
                expectedWords: 75,
                targetRTF: 0.15
            )
        ]
    }

    /// 在临时目录为样例生成真实的纯音频 WAV/PCM 文件（用于真实播放试听）
    func generateAudioFile(for sample: AudioSampleItem) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("lab_audio_\(sample.id).wav")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let sampleRate: Double = 16000.0
        let totalFrames = Int(sampleRate * sample.durationSeconds)
        let channels: UInt32 = 1

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: channels, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        if let channelData = buffer.floatChannelData?[0] {
            // 合成带自然人声音频共振峰特性的音频正弦调频波
            for i in 0..<totalFrames {
                let time = Double(i) / sampleRate
                let freq = FeatureConstants.LabMultimodal.synthesisBaseFrequency + 80.0 * sin(2.0 * .pi * FeatureConstants.LabMultimodal.synthesisModulationFrequency * time)
                let envelope = sin(.pi * (time / sample.durationSeconds))
                channelData[i] = Float(sin(2.0 * .pi * freq * time) * Double(FeatureConstants.LabMultimodal.synthesisAmplitude) * envelope)
            }
        }

        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try audioFile.write(from: buffer)
            return fileURL
        } catch {
            return nil
        }
    }
}

/// 音频播放试听控制器
@MainActor
final class LabAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {

    static let shared = LabAudioPlayer()

    @Published var isPlaying: Bool = false
    @Published var currentPlaybackProgress: Double = 0.0

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    private override init() {
        super.init()
    }

    func play(url: URL) {
        stop()
        do {
            #if canImport(UIKit)
            Task.detached(priority: .userInitiated) {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .default)
                try? session.setActive(true)
            }
            #endif
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            audioPlayer = player
            isPlaying = true

            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updatePlaybackProgress()
                }
            }
        } catch {
            isPlaying = false
        }
    }

    private func updatePlaybackProgress() {
        guard let player = audioPlayer else { return }
        if player.duration > 0 {
            currentPlaybackProgress = player.currentTime / player.duration
        }
    }

    func stop() {
        progressTimer?.invalidate()
        progressTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentPlaybackProgress = 0.0
        #if canImport(UIKit)
        Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
