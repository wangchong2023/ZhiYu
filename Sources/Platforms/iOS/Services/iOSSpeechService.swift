//
//  iOSSpeechService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 iOSSpeech 模块的核心业务逻辑服务。
//             Speech 框架相关方法拆分至 iOSSpeechService+Speech.swift 以降低宏密度。
//
#if !os(watchOS)
import Foundation
import UFPCore
#if canImport(Speech)
import Speech
#endif
import AVFoundation
import Combine
import Observation
import Dependencies

/// iOS 语音处理实现
@Observable
final class iOSSpeechService: NSObject, SpeechServiceProtocol {
    var isRecording = false
    var isTranscribing = false
    var transcribedText = ""
    var audioLevel: Float = 0
    var audioLevelHistory: [Float] = Array(repeating: 0, count: 20)
    var statusMessage: String = ""
    var supportedLanguages: [(code: String, name: String)] = []
    var selectedLanguage: String = "zh-CN"
    var hasPermission: Bool = false
    var recordings: [VoiceRecording] = []

#if canImport(Speech)
    internal var speechRecognizer: SFSpeechRecognizer?
    internal var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    internal var recognitionTask: SFSpeechRecognitionTask?
#endif
    internal var audioEngine: AVAudioEngine?
    internal var audioRecorder: AVAudioRecorder?
    internal var lastRecordingDuration: TimeInterval = 0
    var currentAudioFileURL: URL? {
        audioRecorder?.url
    }

    override init() {
        super.init()
        loadSupportedLanguages()
        checkPermission()
        loadRecordings()
    }

    // MARK: - 非 Speech 相关方法

    func startAudioRecorder() {
        let fm = FileManager.default
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let recordsDir = docDir.appendingPathComponent("import_records", isDirectory: true)
        try? fm.createDirectory(at: recordsDir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let ts = formatter.string(from: Date())
        let fileName = "voice_\(ts).m4a"
        let fileURL = recordsDir.appendingPathComponent(fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        audioRecorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record()
    }

    func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData?[0]
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let avgPower = 20 * log10(max(rms, 1e-8))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.audioLevel = max(0, min(1, (avgPower + 50) / 50))
            self.audioLevelHistory.removeFirst()
            self.audioLevelHistory.append(max(0, min(1, (avgPower + 50) / 50)))
        }
    }

    func startAudioEngine(_ audioEngine: AVAudioEngine) {
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            statusMessage = L10n.Voice.Speech.Status.recording
        } catch {
            statusMessage = L10n.Voice.Speech.Status.audioError
        }
    }

    /// 停止Recording
    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
#if canImport(Speech)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
#endif
        lastRecordingDuration = audioRecorder?.currentTime ?? 0
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0
        audioLevelHistory = Array(repeating: 0, count: 20)
        statusMessage = transcribedText.isEmpty ? L10n.Voice.Speech.Status.ready : L10n.Voice.Speech.Status.complete
    }

    /// 保存Recording
    /// - Parameter title: title
    /// - Returns: 返回值
    func saveRecording(title: String) -> VoiceRecording {
        let recording = VoiceRecording(id: UUID(), title: title, text: transcribedText, language: selectedLanguage, duration: lastRecordingDuration, createdAt: Date())
        recordings.insert(recording, at: 0)
        saveRecordingsToDisk()
        return recording
    }

    /// 删除Recording
    /// - Parameter recording: recording
    func deleteRecording(_ recording: VoiceRecording) {
        recordings.removeAll { $0.id == recording.id }
        saveRecordingsToDisk()
    }

    /// 清除Transcription
    func clearTranscription() {
        transcribedText = ""
        statusMessage = L10n.Voice.Speech.Status.ready
    }

    // MARK: - 持久化

    private let recordingsKey = AppConstants.Keys.Storage.voiceRecordings
    @ObservationIgnored @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?
    private func loadRecordings() {
        guard let keyStore = keyStore else { return }
        if let data = keyStore.data(forKey: recordingsKey), let decoded = try? JSONDecoder().decode([VoiceRecording].self, from: data) { recordings = decoded }
    }
    private func saveRecordingsToDisk() {
        guard let keyStore = keyStore else { return }
        if let data = try? JSONEncoder().encode(recordings) { keyStore.set(data, forKey: recordingsKey) }
    }

    /// 根据系统首选语言自动推导录音识别语言标识
    static func detectPreferredSpeechLanguage(from supported: [(code: String, name: String)] = []) -> String {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") {
            return "zh-CN"
        }
        if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") {
            return "zh-TW"
        }
        if let match = supported.first(where: { preferred.hasPrefix($0.code) }) {
            return match.code
        }
        return "en-US"
    }

    // MARK: - no-op 回退（非 Speech 平台）

#if !canImport(Speech)
    func checkPermission() {}
    func loadSupportedLanguages() {
        selectedLanguage = Self.detectPreferredSpeechLanguage()
    }
    func startRecording() {
        statusMessage = L10n.Voice.Speech.Status.denied
    }
    func transcribeFile(url: URL) async throws -> String {
        return ""
    }
#endif
}
#endif
