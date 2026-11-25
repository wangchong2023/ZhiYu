//
//  iOSOCRService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 iOSOCR 模块的核心业务逻辑服务。
//
#if canImport(Vision)
import Foundation
import Vision

/// iOS/macOS OCR 处理实现
final class iOSOCRService: OCRServiceProtocol {

    /// 识别Text
    /// - Returns: 字符串
    func recognizeText(from image: AppImage) async throws -> String {
        guard let cgImage = image.appCGImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noResults)
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            // Support Chinese + English + Japanese + Korean
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja", "ko"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - OCR Error
enum OCRError: LocalizedError {
    case invalidImage
    case noResults
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage: return L10n.Ingest.OCR.Error.invalidImage
        case .noResults: return L10n.Ingest.OCR.Error.noResults
        case .cameraUnavailable: return L10n.Ingest.OCR.Error.cameraUnavailable
        }
    }
}
#endif
