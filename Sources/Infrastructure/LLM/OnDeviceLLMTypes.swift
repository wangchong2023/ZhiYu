//
//  OnDeviceLLMTypes.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：定义端侧大模型元数据 DTO（OnDeviceModel）与本地化错误类型（OnDeviceError）。
//

import Foundation

// MARK: - On-Device Model DTO

/// 设备端本地大语言模型元数据结构
public struct OnDeviceModel: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: URL?
    public let size: Int64
    public let type: ModelType

    public enum ModelType: Sendable {
        /// 应用预装打包内置模型
        case bundled
        /// 用户后续导入下载的自定义模型
        case downloaded
        /// 系统内置 Apple Intelligence 基础大模型
        case system
    }

    public var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var icon: String {
        switch type {
        case .bundled: return LLMConstants.OnDeviceIcon.bundled
        case .downloaded: return LLMConstants.OnDeviceIcon.downloaded
        case .system: return LLMConstants.OnDeviceIcon.system
        }
    }
}

// MARK: - On-Device LLM 专属本地化错误类型

public enum OnDeviceError: LocalizedError, Equatable {
    case modelNotFound
    case modelNotLoaded
    case notSupported
    case inferenceFailed(String)
    case compilationFailed
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return L10n.AI.OnDevice.Error.modelNotFound
        case .modelNotLoaded:
            return L10n.AI.OnDevice.Error.modelNotLoaded
        case .notSupported:
            return L10n.AI.OnDevice.Error.notSupported
        case .inferenceFailed(let msg):
            return "\(L10n.AI.OnDevice.Error.inferenceFailed): \(msg)"
        case .compilationFailed:
            return L10n.AI.OnDevice.Error.compilationFailed
        case .emptyResponse:
            return L10n.AI.OnDevice.Error.emptyResponse
        }
    }
}
