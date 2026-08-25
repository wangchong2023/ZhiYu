//
//  IOSSpeechServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSSpeechService 单元测试，覆盖状态管理、录音记录持久化、转录清除等场景。
//

#if !os(watchOS)
import XCTest
@testable import ZhiYu

@MainActor
final class IOSSpeechServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let audioLevelHistoryCount: Int = 20
        static let defaultLanguage: String = "zh-CN"
        static let recordingTitle: String = "测试录音"
        static let transcribedText: String = "这是转录后的文本"
        static let secondRecordingTitle: String = "第二条录音"
        static let zeroAudioLevel: Float = 0
        static let zeroDuration: TimeInterval = 0
    }

    // MARK: - setUp

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()
    }

    // MARK: - 初始状态

    /// 服务初始化后 isRecording 应为 false
    func testInitialIsRecordingIsFalse() {
        let service = iOSSpeechService()
        XCTAssertFalse(service.isRecording, "初始 isRecording 应为 false")
    }

    /// 服务初始化后 isTranscribing 应为 false
    func testInitialIsTranscribingIsFalse() {
        let service = iOSSpeechService()
        XCTAssertFalse(service.isTranscribing, "初始 isTranscribing 应为 false")
    }

    /// 服务初始化后 transcribedText 应为空
    func testInitialTranscribedTextIsEmpty() {
        let service = iOSSpeechService()
        XCTAssertTrue(service.transcribedText.isEmpty, "初始 transcribedText 应为空")
    }

    /// 服务初始化后 audioLevel 应为 0
    func testInitialAudioLevelIsZero() {
        let service = iOSSpeechService()
        XCTAssertEqual(service.audioLevel, TestConstants.zeroAudioLevel, "初始 audioLevel 应为 0")
    }

    /// 服务初始化后 audioLevelHistory 应有 20 个零元素
    func testInitialAudioLevelHistoryHasTwentyZeros() {
        let service = iOSSpeechService()
        XCTAssertEqual(service.audioLevelHistory.count, TestConstants.audioLevelHistoryCount,
                       "audioLevelHistory 应有 20 个元素")
        XCTAssertTrue(service.audioLevelHistory.allSatisfy { $0 == TestConstants.zeroAudioLevel },
                      "audioLevelHistory 初始应全为 0")
    }

    /// 服务初始化后 selectedLanguage 应为 zh-CN（模拟器默认）
    func testInitialSelectedLanguageIsZhCN() {
        let service = iOSSpeechService()
        XCTAssertEqual(service.selectedLanguage, TestConstants.defaultLanguage,
                       "默认 selectedLanguage 应为 zh-CN")
    }

    // MARK: - clearTranscription

    /// clearTranscription 应清空 transcribedText
    func testClearTranscriptionEmptiesTranscribedText() {
        let service = iOSSpeechService()
        service.transcribedText = TestConstants.transcribedText
        XCTAssertFalse(service.transcribedText.isEmpty)
        service.clearTranscription()
        XCTAssertTrue(service.transcribedText.isEmpty, "clearTranscription 后文本应为空")
    }

    // MARK: - saveRecording / deleteRecording

    /// saveRecording 应将录音插入到 recordings 列表头部
    func testSaveRecordingInsertsAtHead() {
        let service = iOSSpeechService()
        service.transcribedText = TestConstants.transcribedText
        let recording = service.saveRecording(title: TestConstants.recordingTitle)
        XCTAssertEqual(service.recordings.first?.id, recording.id,
                       "新录音应在列表头部")
        XCTAssertEqual(recording.title, TestConstants.recordingTitle)
        XCTAssertEqual(recording.text, TestConstants.transcribedText)
    }

    /// 连续保存两条录音，最新一条应在头部
    func testSaveMultipleRecordingsKeepsLatestAtHead() {
        let service = iOSSpeechService()
        service.transcribedText = TestConstants.transcribedText
        _ = service.saveRecording(title: TestConstants.recordingTitle)
        _ = service.saveRecording(title: TestConstants.secondRecordingTitle)
        XCTAssertEqual(service.recordings.count, 2)
        XCTAssertEqual(service.recordings.first?.title, TestConstants.secondRecordingTitle,
                       "最新录音应在列表头部")
    }

    /// deleteRecording 应从列表中移除指定录音
    func testDeleteRecordingRemovesFromList() {
        let service = iOSSpeechService()
        service.transcribedText = TestConstants.transcribedText
        let recording = service.saveRecording(title: TestConstants.recordingTitle)
        XCTAssertEqual(service.recordings.count, 1)
        service.deleteRecording(recording)
        XCTAssertTrue(service.recordings.isEmpty, "删除后列表应为空")
    }

    /// deleteRecording 删除不存在的录音不应崩溃
    func testDeleteNonExistentRecordingDoesNotCrash() {
        let service = iOSSpeechService()
        let fakeRecording = VoiceRecording(title: "不存在", text: "", language: "zh-CN",
                                           duration: TestConstants.zeroDuration)
        service.deleteRecording(fakeRecording)
        XCTAssertTrue(true, "删除不存在的录音应正常执行")
    }

    // MARK: - stopRecording

    /// stopRecording 在未录制状态下不应崩溃
    func testStopRecordingWithoutStartDoesNotCrash() {
        let service = iOSSpeechService()
        service.stopRecording()
        XCTAssertFalse(service.isRecording, "stopRecording 后 isRecording 应为 false")
        XCTAssertEqual(service.audioLevel, TestConstants.zeroAudioLevel, "stopRecording 后 audioLevel 应为 0")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 SpeechServiceProtocol
    func testConformsToSpeechServiceProtocol() {
        let service: any SpeechServiceProtocol = iOSSpeechService()
        XCTAssertFalse(service.isRecording)
        XCTAssertFalse(service.isTranscribing)
        XCTAssertTrue(service.transcribedText.isEmpty)
    }

    // MARK: - transcribeFile（模拟器跳过）

    /// transcribeFile 在模拟器应跳过或返回空（不崩溃）
    func testTranscribeFileDoesNotCrashOnSimulator() async throws {
        let service = iOSSpeechService()
        let fakeURL = URL(fileURLWithPath: "/tmp/non_existent_audio_\(UUID().uuidString).m4a")
        do {
            _ = try await service.transcribeFile(url: fakeURL)
            XCTAssertTrue(true, "transcribeFile 应正常执行")
        } catch {
            XCTAssertTrue(true, "transcribeFile 抛错可接受：\(error)")
        }
    }
}
#endif
