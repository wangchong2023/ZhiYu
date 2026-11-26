//
//  VoiceRecording.swift
//  ZhiYuDomain
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomain]
//  核心职责：语音录音纯领域数据模型。
//

import Foundation

/// 语音录音数据模型
public struct VoiceRecording: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var text: String
    public var language: String
    public var duration: TimeInterval
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        text: String,
        language: String,
        duration: TimeInterval,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.language = language
        self.duration = duration
        self.createdAt = createdAt
    }
}
