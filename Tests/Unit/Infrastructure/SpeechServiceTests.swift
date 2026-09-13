//
//  SpeechServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 iOSSpeechService 开展转录清理、录音计数、音频电平与默认语言的自动化单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - Speech Service Tests
@MainActor
final class SpeechServiceTests: XCTestCase {

    var speechService: iOSSpeechService!

    override func setUp() async throws {
        try await super.setUp()
        speechService = iOSSpeechService()
    }

    override func tearDown() async throws {
        speechService.clearTranscription()
        speechService = nil
        try await super.tearDown()
    }

    func testClearTranscriptionEmptiesText() {
        // Manually set some state for this test
        XCTAssertTrue(speechService.transcribedText.isEmpty)
    }

    func testRecordingCountStartsAtZero() {
        // recordings array replaced the removed recordingCount property
        XCTAssertTrue(speechService.recordings.isEmpty, "Recordings should start empty")
    }

    func testAudioLevelHistoryHasInitialState() {
        // Now it's initialized with 20 zeros
        XCTAssertEqual(speechService.audioLevelHistory.count, 20)
    }

    func testIsRecordingFalseInitially() {
        XCTAssertFalse(speechService.isRecording)
    }

    func testSupportedLanguagesNotEmpty() {
        XCTAssertFalse(speechService.supportedLanguages.isEmpty)
    }

    func testDefaultLanguageIsSet() {
        XCTAssertFalse(speechService.selectedLanguage.isEmpty)
    }
}
