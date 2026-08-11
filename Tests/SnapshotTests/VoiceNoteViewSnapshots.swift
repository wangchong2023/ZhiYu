//
//  VoiceNoteViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：VoiceNoteView 快照测试，覆盖语音笔记初始/录制中/有转录文本/有录音记录各状态。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

// MARK: - MockSpeechService

/// 语音服务 Mock，用于快照测试隔离真实音频权限与硬件依赖
@MainActor
final class MockSpeechService: SpeechServiceProtocol {
    var isRecording = false
    var isTranscribing = false
    var transcribedText = ""
    var audioLevel: Float = 0
    var audioLevelHistory: [Float] = Array(repeating: 0, count: 20)
    var statusMessage = ""
    var supportedLanguages: [(code: String, name: String)] = [
        ("zh-CN", "中文（简体）"),
        ("en-US", "English (US)")
    ]
    var selectedLanguage = "zh-CN"
    var hasPermission = true
    var recordings: [VoiceRecording] = []
    var currentAudioFileURL: URL?

    func checkPermission() {}
    func startRecording() { isRecording = true }
    func stopRecording() { isRecording = false }
    func transcribeFile(url: URL) async throws -> String { "" }
    func saveRecording(title: String) -> VoiceRecording {
        VoiceRecording(title: title, text: transcribedText, language: selectedLanguage, duration: 10.0)
    }
    func deleteRecording(_ recording: VoiceRecording) {}
    func clearTranscription() { transcribedText = "" }
}

@MainActor
final class VoiceNoteViewSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    private var mockSpeech: MockSpeechService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        mockSpeech = MockSpeechService()
        ServiceContainer.shared.register(mockSpeech, for: (any SpeechServiceProtocol).self)
    }

    // MARK: - VoiceNoteView 快照测试

    /// 测试语音笔记初始状态 — 无录制无转录
    func testVoiceNoteView_Initial() {
        let view = VoiceNoteView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试语音笔记录制中状态 — 展示波形与停止按钮
    func testVoiceNoteView_Recording() {
        mockSpeech.isRecording = true
        mockSpeech.audioLevel = 0.5
        mockSpeech.audioLevelHistory = [0.1, 0.3, 0.5, 0.7, 0.9, 0.6, 0.4, 0.2, 0.1, 0.3, 0.5, 0.7, 0.9, 0.6, 0.4, 0.2, 0.1, 0.3, 0.5, 0.7]
        let view = VoiceNoteView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试语音笔记有转录文本状态 — 展示转录结果
    func testVoiceNoteView_WithTranscription() {
        mockSpeech.transcribedText = "这是一段语音转录的测试文本，用于验证 VoiceNoteView 在有转录内容时的渲染状态。"
        let view = VoiceNoteView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试语音笔记有录音记录状态 — 展示历史录音列表
    func testVoiceNoteView_WithRecordings() {
        mockSpeech.recordings = [
            VoiceRecording(title: "会议纪要", text: "今天讨论了项目进度", language: "zh-CN", duration: 120.0, createdAt: Date(timeIntervalSince1970: 1_725_000_000)),
            VoiceRecording(title: "灵感记录", text: "关于知识图谱的新想法", language: "zh-CN", duration: 30.0, createdAt: Date(timeIntervalSince1970: 1_725_010_000))
        ]
        let view = VoiceNoteView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
