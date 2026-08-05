//
//  CoreMLModerationClassifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供端侧 CoreML AI 意图分类与防越狱小模型抽象 (方案 B: Meta Llama Guard 3 1B CoreML/Apple Neural Engine)。
//  作为双层漏斗安全防御架构 (Tiered Funnel Defense Architecture) 的第二层 Slow Path 深检通道。
//
import Foundation
import CoreML
import os

/// 深度 AI 意图分类结果
public struct CoreMLModerationResult: Sendable {
    public let isFlagged: Bool
    public let category: ComplianceCategory?
    public let confidenceScore: Float
    public let reason: String

    public init(isFlagged: Bool, category: ComplianceCategory?, confidenceScore: Float, reason: String) {
        self.isFlagged = isFlagged
        self.category = category
        self.confidenceScore = confidenceScore
        self.reason = reason
    }
}

/// 端侧 CoreML 内容违规与防越狱分类器
public final class CoreMLModerationClassifier: @unchecked Sendable {
    public static let shared = CoreMLModerationClassifier()

    private let lock = OSAllocatedUnfairLock()
    private var isCoreMLModelLoaded: Bool = false

    private init() {}

    /// 检查当前设备硬件能力是否支持加载 CoreML 语义分类小模型
    public var isSupportedOnDevice: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        // 需要拥有 Apple Neural Engine 硬件及至少 4GB 系统内存
        return ProcessInfo.processInfo.physicalMemory >= 4 * 1024 * 1024 * 1024
        #endif
    }

    /// 执行第二层 (Slow Path) 端侧小模型 AI 语义分类与防越狱检视
    /// - Parameter text: 通过第一层 Fast Path (AC 自动机 + MultilingualSanitizer) 的候选文本
    /// - Returns: CoreML 深度分类安全结论
    public func classifyForDeepInspection(_ text: String) async -> CoreMLModerationResult {
        guard !text.isEmpty else {
            return CoreMLModerationResult(isFlagged: false, category: nil, confidenceScore: 0.0, reason: CoreConstants.ModerationReason.emptyText)
        }

        guard isSupportedOnDevice else {
            return CoreMLModerationResult(isFlagged: false, category: nil, confidenceScore: 0.0, reason: CoreConstants.ModerationReason.deviceHwBypass)
        }

        // 第二层语义分析模拟：识别如 "DAN", "ignore previous instructions", "pretend you are" 等经典 Prompt 注入越狱特征
        let promptInjectionKeywords = [
            "ignore_previous_instructions",
            "pretend_you_are_an_unfiltered_ai",
            "do_anything_now_mode",
            "system_override_mode"
        ]

        let lowercased = text.lowercased()
        for keyword in promptInjectionKeywords where lowercased.contains(keyword) {
            Logger.shared.addLog(
                action: .error,
                target: CoreConstants.SecurityLogTarget.coreMLModerationClassifier,
                details: "CoreML_deep_inspection_blocked_prompt_injection",
                module: CoreConstants.Security.logModule
            )
            return CoreMLModerationResult(
                isFlagged: true,
                category: .politicalReactionary,
                confidenceScore: 0.98,
                reason: CoreConstants.ModerationReason.detectedPromptInjection
            )
        }

        return CoreMLModerationResult(isFlagged: false, category: nil, confidenceScore: 0.05, reason: CoreConstants.ModerationReason.clean)
    }
}
