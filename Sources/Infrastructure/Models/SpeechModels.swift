//
//  SpeechModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：数据模型与状态管理，定义数据结构与 @Observable 状态。
//
import Foundation
import ZhiYuDomain

// MARK: - Speech Error
/// 语音处理模块错误定义
public enum SpeechError: LocalizedError, Sendable {
    case localeNotSupported
    case notAuthorized
    case audioEngineError

    public var errorDescription: String? {
        switch self {
        case .localeNotSupported: return L10n.Voice.Speech.Error.localeNotSupported
        case .notAuthorized: return L10n.Voice.Speech.Error.notAuthorized
        case .audioEngineError: return L10n.Voice.Speech.Error.audioEngine
        }
    }
}
