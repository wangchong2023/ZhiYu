//
//  IOSOCRServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSOCRService 单元测试，覆盖无效图像错误、协议一致性等场景。
//

#if canImport(Vision)
import XCTest
import UIKit
@testable import ZhiYu

@MainActor
final class IOSOCRServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let imageSize: CGFloat = 10
    }

    // MARK: - recognizeText 错误路径

    /// 传入 appCGImage 为 nil 的图像应抛出 OCRError.invalidImage
    func testRecognizeTextWithInvalidImageThrowsInvalidImage() async {
        let service = iOSOCRService()
        let invalidImage = UIImage()

        do {
            _ = try await service.recognizeText(from: invalidImage)
            XCTFail("无效图像应抛出 OCRError.invalidImage")
        } catch let ocrError as OCRError {
            XCTAssertEqual(ocrError, .invalidImage, "应抛出 invalidImage 错误")
        } catch {
            XCTFail("应抛出 OCRError，实际：\(error)")
        }
    }

    // MARK: - OCRError 描述

    /// OCRError.invalidImage 应返回非空错误描述
    func testOCRErrorInvalidImageHasLocalizedDescription() {
        XCTAssertNotNil(OCRError.invalidImage.errorDescription)
        XCTAssertFalse(OCRError.invalidImage.errorDescription?.isEmpty ?? true,
                       "invalidImage 错误描述不应为空")
    }

    /// OCRError.noResults 应返回非空错误描述
    func testOCRErrorNoResultsHasLocalizedDescription() {
        XCTAssertNotNil(OCRError.noResults.errorDescription)
        XCTAssertFalse(OCRError.noResults.errorDescription?.isEmpty ?? true,
                       "noResults 错误描述不应为空")
    }

    /// OCRError.cameraUnavailable 应返回非空错误描述
    func testOCRErrorCameraUnavailableHasLocalizedDescription() {
        XCTAssertNotNil(OCRError.cameraUnavailable.errorDescription)
        XCTAssertFalse(OCRError.cameraUnavailable.errorDescription?.isEmpty ?? true,
                       "cameraUnavailable 错误描述不应为空")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 OCRServiceProtocol
    func testConformsToOCRServiceProtocol() {
        let service: any OCRServiceProtocol = iOSOCRService()
        XCTAssertNotNil(service, "协议转型应成功")
    }

    // MARK: - 有效图像路径（模拟器跳过实际识别）

    /// 传入有效 CGImage 的图像应不抛出 invalidImage（实际识别结果在模拟器可能为空）
    func testRecognizeTextWithValidImageDoesNotThrowInvalidImage() async throws {
        let service = iOSOCRService()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: TestConstants.imageSize,
                                                            height: TestConstants.imageSize))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero,
                            size: CGSize(width: TestConstants.imageSize, height: TestConstants.imageSize)))
        }
        guard image.appCGImage != nil else {
            throw XCTSkip("当前环境无法生成有效 CGImage")
        }
        do {
            _ = try await service.recognizeText(from: image)
            XCTAssertTrue(true, "有效图像不应抛出 invalidImage")
        } catch let ocrError as OCRError {
            XCTAssertNotEqual(ocrError, .invalidImage, "有效图像不应抛出 invalidImage")
        } catch {
            XCTAssertTrue(true, "Vision 识别其他错误可接受：\(error)")
        }
    }
}
#endif
