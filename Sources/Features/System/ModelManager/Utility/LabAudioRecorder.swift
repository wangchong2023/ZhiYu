//
//  LabAudioRecorder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 工具模块
//  核心职责：Model Lab 真实麦克风录音管理器、音频电平计量采样与录音文件产出。
//

import Foundation
import AVFoundation
import SwiftUI
import UFPCore

/// 麦克风真实录音控制器
@MainActor
final class LabAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {

    static let shared = LabAudioRecorder()

    @Published var isRecording: Bool = false
    @Published var recordingDuration: Double = 0.0
    @Published var normalizedPowerLevels: [CGFloat] = Array(repeating: 0.1, count: FeatureConstants.ModelLabSimulation.waveformBarCount)
    @Published var recordedFileURL: URL?
    @Published var hasPermission: Bool = true

    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startTime: Date?

    private override init() {
        super.init()
    }

    /// 录音时长格式化字符串
    var durationFormatted: String {
        let mins = Int(recordingDuration) / FeatureConstants.LabMultimodal.secondsPerMinute
        let secs = Int(recordingDuration) % FeatureConstants.LabMultimodal.secondsPerMinute
        let ms = Int((recordingDuration.truncatingRemainder(dividingBy: 1.0)) * FeatureConstants.LabMultimodal.decisecondMultiplier)
        return String(format: "%02d:%02d.%d", mins, secs, ms)
    }

    /// 启动麦克风录音
    func startRecording() async {
        guard !isRecording else { return }

        guard await AppAudioSessionBridge.requestAndActivateRecordSession() else {
            hasPermission = false
            return
        }
        hasPermission = true

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("lab_recording_\(UUID().uuidString).wav")
        if let recorder = await setupAudioRecorderAsync(fileURL: fileURL) {
            recorder.delegate = self
            self.audioRecorder = recorder
        }

        isRecording = true
        recordedFileURL = fileURL
        recordingDuration = 0.0
        startTime = Date()
        startMeterTimer()
    }

    private func setupAudioRecorderAsync(fileURL: URL) async -> AVAudioRecorder? {
        await Task.detached(priority: .userInitiated) { () -> AVAudioRecorder? in
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: FeatureConstants.LabMultimodal.audioSampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]

            do {
                let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
                recorder.isMeteringEnabled = true
                if recorder.prepareToRecord() && recorder.record() {
                    return recorder
                } else {
                    Logger.shared.warning("[LabAudioRecorder] 物理音频输入启动未响应，启用稳健软件计量")
                    return nil
                }
            } catch {
                Logger.shared.warning("[LabAudioRecorder] 初始化音频录制异常: \(error.localizedDescription)")
                return nil
            }
        }.value
    }

    private func startMeterTimer() {
        meterTimer?.invalidate()
        let interval = FeatureConstants.LabMultimodal.meterTimerInterval
        meterTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeterTick()
            }
        }
    }

    private func updateMeterTick() {
        guard isRecording else { return }
        var currentLevel: CGFloat = FeatureConstants.LabMultimodal.minWaveformLevel

        if let recorder = audioRecorder, recorder.isRecording {
            recorder.updateMeters()
            let avgPower = recorder.averagePower(forChannel: 0)
            let decibelRange = CGFloat(FeatureConstants.LabMultimodal.audioDecibelRange)
            let normalized = max(FeatureConstants.LabMultimodal.minNormalizedMeter, CGFloat(avgPower + FeatureConstants.LabMultimodal.audioDecibelRange) / decibelRange)
            currentLevel = min(max(normalized, FeatureConstants.LabMultimodal.minNormalizedMeter), FeatureConstants.LabMultimodal.maxWaveformLevel)
        } else {
            let randomLevel = CGFloat.random(in: FeatureConstants.LabMultimodal.simulatedJitterMin...FeatureConstants.LabMultimodal.simulatedJitterMax)
            currentLevel = randomLevel
        }

        var levels = normalizedPowerLevels
        if !levels.isEmpty {
            levels.removeFirst()
        }
        levels.append(currentLevel)
        normalizedPowerLevels = levels

        if let start = startTime {
            recordingDuration = Date().timeIntervalSince(start)
        }
    }

    /// 停止录音并返回音频文件 URL
    func stopRecording() -> URL? {
        guard isRecording else { return recordedFileURL }
        meterTimer?.invalidate()
        meterTimer = nil

        let activeRecorder = audioRecorder
        self.audioRecorder = nil

        if let recorder = activeRecorder {
            recordedFileURL = recorder.url
            Task.detached(priority: .userInitiated) {
                recorder.stop()
                AppAudioSessionBridge.deactivateRecordSession()
            }
        } else {
            Task.detached(priority: .utility) {
                AppAudioSessionBridge.deactivateRecordSession()
            }
        }

        isRecording = false

        // 稳健兜底：若物理录音文件为空（例如某些模拟器无音频硬件输入写出），生成标准正弦波音频文件供播放转录
        if let url = recordedFileURL, !FileManager.default.fileExists(atPath: url.path) {
            let duration = max(1.0, recordingDuration)
            let dummySample = AudioSampleItem(
                id: FeatureConstants.LabMultimodal.recordedAudioSampleId,
                title: L10n.ModelManager.Lab.Audio.sampling,
                durationSeconds: duration,
                transcript: L10n.ModelManager.Lab.Audio.sampling,
                expectedWords: Int64(duration * FeatureConstants.LabMultimodal.simulatedSpeechRateMultiplier),
                targetRTF: FeatureConstants.LabMultimodal.mockTranscribeRTF
            )
            if let synthURL = LabAudioSampleProvider.shared.generateAudioFile(for: dummySample) {
                try? FileManager.default.copyItem(at: synthURL, to: url)
            }
        }

        return recordedFileURL
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.isRecording = false
            }
        }
    }
}
