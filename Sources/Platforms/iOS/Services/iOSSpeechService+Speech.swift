//
//  iOSSpeechService+Speech.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOSSpeechService 的 Speech 框架相关扩展，降低主文件宏密度。
//

#if canImport(Speech)
import Speech
import AVFoundation
import Foundation

extension iOSSpeechService {

    /// 检查Permission
    func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.hasPermission = status == .authorized
                switch status {
                case .authorized:
                    self.statusMessage = L10n.Voice.Speech.Status.ready
                case .denied:
                    self.statusMessage = L10n.Voice.Speech.Status.denied
                case .restricted:
                    self.statusMessage = L10n.Voice.Speech.Status.restricted
                case .notDetermined:
                    self.statusMessage = L10n.Voice.Speech.Status.notDetermined
                @unknown default:
                    self.statusMessage = L10n.Voice.Speech.Status.unknown
                }
            }
        }
    }

    internal func loadSupportedLanguages() {
        let locales: [(String, String)] = [
            ("zh-CN", L10n.Voice.Speech.Lang.zhHans),
            ("zh-TW", L10n.Voice.Speech.Lang.zhHant),
            ("en-US", L10n.Voice.Speech.Lang.enUS),
            ("en-GB", L10n.Voice.Speech.Lang.enGB),
            ("ja-JP", L10n.Voice.Speech.Lang.jaJP),
            ("ko-KR", L10n.Voice.Speech.Lang.koKR),
            ("fr-FR", L10n.Voice.Speech.Lang.frFR),
            ("de-DE", L10n.Voice.Speech.Lang.deDE),
            ("es-ES", L10n.Voice.Speech.Lang.esES),
            ("pt-BR", L10n.Voice.Speech.Lang.ptBR)
        ]

        supportedLanguages = locales.filter { locale in
            SFSpeechRecognizer(locale: Locale(identifier: locale.0)) != nil
        }

        selectedLanguage = Self.detectPreferredSpeechLanguage(from: supportedLanguages)
    }

    /// 启动Recording
    func startRecording() {
        guard hasPermission else {
            statusMessage = L10n.Voice.Speech.Status.denied
            return
        }

        let locale = Locale(identifier: selectedLanguage)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            statusMessage = L10n.Voice.Speech.Status.localeNotSupported
            return
        }

        speechRecognizer = recognizer
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        #if targetEnvironment(simulator)
        statusMessage = L10n.Voice.Speech.Status.simulatorNotSupported
        #else
        setupRecognitionRequest()
        guard recognitionRequest != nil else { return }

        setupAudioTap(inputNode: audioEngine.inputNode)
        startAudioEngine(audioEngine)
        startRecognitionTask(recognizer: recognizer)
        #endif

        // 并行录制原始音频到文件
        startAudioRecorder()
    }

    func setupRecognitionRequest() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
    }

    internal func setupAudioTap(inputNode: AVAudioInputNode) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.calculateAudioLevel(from: buffer)
        }
    }

    func startRecognitionTask(recognizer: SFSpeechRecognizer) {
        guard let request = recognitionRequest else { return }
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal { self.stopRecording() }
                }
                if let error = error {
                    self.statusMessage = "\(L10n.Voice.Speech.Status.error): \(error.localizedDescription)"
                    self.stopRecording()
                }
            }
        }
    }

    /// transcribeFile
    /// - Parameter url: url
    /// - Returns: 字符串
    func transcribeFile(url: URL) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }
        let locale = Locale(identifier: selectedLanguage)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else { throw SpeechError.localeNotSupported }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error { continuation.resume(throwing: error); return }
                if let result = result, result.isFinal { continuation.resume(returning: result.bestTranscription.formattedString) }
            }
        }
    }
}
#endif
