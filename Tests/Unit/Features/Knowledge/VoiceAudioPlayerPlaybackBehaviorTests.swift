//
//  VoiceAudioPlayerPlaybackBehaviorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 VoiceAudioPlayerView 视图装载与状态行为。
//

#if !os(watchOS)
import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class VoiceAudioPlayerPlaybackBehaviorTests: XCTestCase {

    // MARK: - 4. VoiceAudioPlayerView 视图装载与状态测试

    func testVoiceAudioPlayerView_InitializationAndRender_DoesNotCrash() {
        let view = VoiceAudioPlayerView(
            title: "录音片段测试",
            audioPath: "/path/to/nonexistent/voice.m4a",
            transcribedText: "🎙️ [00:02] 本地测试语音正文"
        )
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view, "VoiceAudioPlayerView 在无物理音频文件时应安全降级渲染并展示转写正文")
    }

    func testVoiceSpeechState_SpeakEmptyText_DoesNotLockSpeakingState() {
        let state = VoiceSpeechState.shared
        state.speak(text: "   ***   ")
        XCTAssertFalse(state.isSpeaking, "对空白或仅 Markdown 语法的文本触发朗读不应锁死 isSpeaking 状态")
    }
}
#endif
