//
//  VoiceNoteAudioPipelineBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 iOSSpeechService 语音录音管道、音量分贝计算、支持语言列表与数据模型分支。
//

#if !os(watchOS)
import XCTest
import AVFoundation
import UFPCore
@testable import ZhiYu

@MainActor
final class VoiceNoteAudioPipelineBranchTests: XCTestCase {

    // MARK: - 1. 语言列表与默认语言初始化分支

    func testLoadSupportedLanguages_PopulatesSystemLocales() {
        let service = iOSSpeechService()
        XCTAssertFalse(service.supportedLanguages.isEmpty, "支持的语言列表不应为空")
        XCTAssertEqual(service.selectedLanguage, "zh-CN", "默认识别语言应为中文 zh-CN")
    }

    // MARK: - 2. 音量波形分贝计算分支

    func testCalculateAudioLevel_WithZeroBuffer_CalculatesZero() {
        let service = iOSSpeechService()

        // 构造一个 1024 采样的静音 PCM Buffer
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("无法创建 AVAudioPCMBuffer")
            return
        }
        buffer.frameLength = 1024
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<1024 {
                channelData[i] = 0.0
            }
        }

        service.calculateAudioLevel(from: buffer)

        let exp = expectation(description: "Wait for audio level dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(service.audioLevel, 0.0, accuracy: 0.01, "静音 buffer 计算出的音量等级应趋近于 0")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - 3. 录音文件生成与目录检查分支

    func testStartAudioRecorder_CreatesDirectoryAndSetsURL() {
        let service = iOSSpeechService()
        service.startAudioRecorder()

        XCTAssertNotNil(service.currentAudioFileURL, "启动录音后应分配有效的本地音频文件 URL")
        service.stopRecording()
    }

    // MARK: - 4. 语音记录数据模型格式化分支

    func testVoiceRecordingModel_Initialization() {
        let recording = VoiceRecording(
            id: UUID(),
            title: "架构评审会议录音",
            text: "探讨了 RAG 的混合检索方案",
            language: "zh-CN",
            duration: 125.0,
            createdAt: Date()
        )

        XCTAssertEqual(recording.duration, 125.0)
        XCTAssertEqual(recording.language, "zh-CN")
    }
}
#endif
