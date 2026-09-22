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
@preconcurrency import Speech
import AVFoundation
import Foundation

/// 线程安全包装器，用于在 @Sendable 闭包中持有非 Sendable 的 iOSSpeechService 引用
private final class SpeechServiceBox: @unchecked Sendable {
    let value: iOSSpeechService
    init(_ value: iOSSpeechService) { self.value = value }
}

extension iOSSpeechService {

    /// 检查Permission
    /// - Note: 必须为 `nonisolated`。`iOSSpeechService` 是 `@Observable` 类（Swift 6.4 默认 `@MainActor` 隔离），
    ///   若本方法继承 `@MainActor`，则 `SFSpeechRecognizer.requestAuthorization` 的 `@Sendable` handler 闭包
    ///   也会继承 `@MainActor` 隔离；而该 handler 在后台线程执行，Swift 6.4 运行时会在闭包入口插入
    ///   `_swift_task_checkIsolatedSwift` 隔离检查，后台线程不在 MainActor → `dispatch_assert_queue_fail` 崩溃。
    ///   `nonisolated` 使 handler 闭包不继承隔离，内部通过 `Task { @MainActor in }` 显式调度到 MainActor。
    nonisolated func checkPermission() {
        let box = SpeechServiceBox(self)
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                let service = box.value
                service.hasPermission = status == .authorized
                switch status {
                case .authorized:
                    service.statusMessage = L10n.Voice.Speech.Status.ready
                case .denied:
                    service.statusMessage = L10n.Voice.Speech.Status.denied
                case .restricted:
                    service.statusMessage = L10n.Voice.Speech.Status.restricted
                case .notDetermined:
                    service.statusMessage = L10n.Voice.Speech.Status.notDetermined
                @unknown default:
                    service.statusMessage = L10n.Voice.Speech.Status.unknown
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
        // iOS 27.0 废弃 installTap(onBus:bufferSize:format:block:)，改为 installAudioTap(throwing 版本)
        // 新 API 回调返回 AVReadOnlyAudioPCMBuffer，需用 AVAudioPCMBuffer(copying:) 转换给 SFSpeech
        do {
            try inputNode.installAudioTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] readOnlyBuffer, _ in
                let buffer = AVAudioPCMBuffer(copying: readOnlyBuffer)
                self?.recognitionRequest?.append(buffer)
                self?.calculateAudioLevel(from: buffer)
            }
        } catch {
            Logger.shared.warning("SpeechService_AudioTapInstallFailed: \(error.localizedDescription)")
        }
    }

    /// 启动识别任务
    /// - Note: 必须为 `nonisolated`，原因同 `checkPermission()`。`recognitionTask` 的 handler 在后台线程执行，
    ///   若本方法继承 `@MainActor`，handler 闭包入口的隔离检查会触发 `dispatch_assert_queue_fail` 崩溃。
    ///   `SFSpeechRecognitionResult` 不是 `Sendable`，不能跨 actor 传递；在 handler 内同步提取
    ///   `Sendable` 数据（`String`/`Bool`/`Error`），再传到 `Task { @MainActor in }`。
    nonisolated func startRecognitionTask(recognizer: SFSpeechRecognizer) {
        let box = SpeechServiceBox(self)
        let request = MainActor.assumeIsolated { box.value.recognitionRequest }
        guard let request = request else { return }
        let task = recognizer.recognitionTask(with: request) { result, error in
            // 在后台线程同步提取 Sendable 数据，避免跨 actor 传递非 Sendable 的 result/error
            let transcribedText: String? = result?.bestTranscription.formattedString
            let isFinal: Bool = result?.isFinal ?? false
            let errorMessage: String? = error?.localizedDescription
            Task { @MainActor in
                let service = box.value
                if let text = transcribedText {
                    service.transcribedText = text
                    if isFinal { service.stopRecording() }
                }
                if let message = errorMessage {
                    service.statusMessage = "\(L10n.Voice.Speech.Status.error): \(message)"
                    service.stopRecording()
                }
            }
        }
        MainActor.assumeIsolated { box.value.recognitionTask = task }
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
