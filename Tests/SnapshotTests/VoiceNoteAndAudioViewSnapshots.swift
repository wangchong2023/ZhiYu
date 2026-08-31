//
//  VoiceNoteAndAudioViewSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：语音笔记与音频处理模块的 SwiftUI 视觉回归与渲染一致性验证。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class VoiceNoteAndAudioViewSnapshots: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. VoiceNoteView 容器渲染

    func testVoiceNoteViewSnapshot() {
        let view = VoiceNoteView()
            .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. SaveVoiceNoteSheet 交互面板

    func testSaveVoiceNoteSheetSnapshot() {
        let mockSpeech = MockSpeechService()
        mockSpeech.transcribedText = "这是一段通过语音录制并转写后的示例文本，用于验证保存面板预览效果。"

        let view = SaveVoiceNoteSheet(
            speechService: mockSpeech,
            title: .constant("会议语音记录")
        )
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }
}
