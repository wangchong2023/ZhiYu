//
//  OCRServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 OCRService 模块的抽象契约接口。
//
import Foundation
import Dependencies
import UFPCore

/// OCR 文字识别服务协议
public protocol OCRServiceProtocol: Sendable {
    /// 从图像中识别文本
    func recognizeText(from image: AppImage) async throws -> String
}

// MARK: - DependencyKey 注册

/// OCRServiceProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum OCRServiceKey: DependencyKey {
    public static var liveValue: any OCRServiceProtocol {
        ServiceContainer.shared.resolveOptional((any OCRServiceProtocol).self) ?? NoOpOCRService()
    }
    public static var testValue: any OCRServiceProtocol {
        ServiceContainer.shared.resolveOptional((any OCRServiceProtocol).self) ?? NoOpOCRService()
    }
    public static var previewValue: any OCRServiceProtocol { NoOpOCRService() }
}

extension DependencyValues {
    /// OCR 服务依赖
    public var ocrService: any OCRServiceProtocol {
        get { self[OCRServiceKey.self] }
        set { self[OCRServiceKey.self] = newValue }
    }
}

/// 无操作 OCR 服务（测试/预览占位，DI 未就绪时降级）
public final class NoOpOCRService: OCRServiceProtocol, @unchecked Sendable {
    public init() {}
    public func recognizeText(from image: AppImage) async throws -> String { "" }
}
