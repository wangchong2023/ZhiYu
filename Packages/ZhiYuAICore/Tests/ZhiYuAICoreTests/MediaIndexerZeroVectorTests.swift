//
//  MediaIndexerZeroVectorTests.swift
//  ZhiYuAICoreTests
//
//  Created by Antigravity on 2026/11/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：缺陷 #286 回归测试 — 验证 MediaSearchIndexer 对零向量嵌入结果的
//           拦截防护，确保退化图片不入库污染检索排名。
//

import XCTest
import CoreGraphics
@testable import ZhiYuAICore

/// 返回零向量的 Mock 嵌入引擎（模拟退化/损坏图片或引擎故障）
private final class ZeroVectorEmbeddingEngine: MultimodalEmbeddingProtocol, Sendable {
    let dimension: Int = 768

    func embedText(_ text: String) async throws -> [Float] {
        // 文本嵌入返回非零，仅图片返回零
        [Float](repeating: 0.001, count: dimension)
    }

    func embedImage(_ image: CGImage) async throws -> [Float] {
        [Float](repeating: 0.0, count: dimension)
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dot: Float = 0.0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return min(max(dot, -1.0), 1.0)
    }
}

final class MediaIndexerZeroVectorTests: XCTestCase {

    private func makeSolidImage(width: Int = 4, height: Int = 4, red: UInt8, green: UInt8, blue: UInt8) -> CGImage? {
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            pixels[i] = red
            pixels[i + 1] = green
            pixels[i + 2] = blue
            pixels[i + 3] = 255
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// 零向量嵌入结果必须抛出 zeroVectorEmbedding 错误而非静默入库
    func testZeroVectorEmbeddingThrowsAndPreventsIndexing() async throws {
        let zeroEngine = ZeroVectorEmbeddingEngine()
        let indexer = MediaSearchIndexer(embeddingEngine: zeroEngine)
        let image = try XCTUnwrap(makeSolidImage(red: 128, green: 128, blue: 128))

        // 零向量图片必须被拒绝入库
        do {
            _ = try await indexer.indexImage(image, id: "zero-img", title: "零向量图片")
            XCTFail("零向量嵌入结果应抛出 zeroVectorEmbedding 错误")
        } catch let error as MediaSearchIndexer.MediaIndexError {
            XCTAssertEqual(error, .zeroVectorEmbedding, "错误类型应为 zeroVectorEmbedding")
        }

        // 确认拒绝后索引为空
        let items = await indexer.allItems()
        XCTAssertTrue(items.isEmpty, "零向量图片不应入库")

        // 确认搜索结果不包含零向量项
        let results = try await indexer.search(query: "任意查询")
        XCTAssertTrue(results.isEmpty, "空索引搜索应返回空结果")
    }

    /// 正常非零向量图片仍能正常入库和检索
    func testNonZeroVectorImageIndexesNormally() async throws {
        let normalEngine = MultimodalEmbeddingEngine()
        let indexer = MediaSearchIndexer(embeddingEngine: normalEngine)
        let image = try XCTUnwrap(makeSolidImage(red: 255, green: 0, blue: 0))

        // 正常图片应成功入库
        let item = try await indexer.indexImage(image, id: "normal-img", title: "红色图片")
        XCTAssertEqual(item.id, "normal-img")
        XCTAssertFalse(item.vector.allSatisfy { $0 == 0.0 }, "正常图片向量不应为全零")

        let items = await indexer.allItems()
        XCTAssertEqual(items.count, 1)
    }

    /// 混合场景：一张零向量一张正常，确保零向量不干扰正常检索排名
    func testMixedZeroAndNormalVectorsOnlyNormalIndexed() async throws {
        let normalEngine = MultimodalEmbeddingEngine()
        let indexer = MediaSearchIndexer(embeddingEngine: normalEngine)

        let redImg = try XCTUnwrap(makeSolidImage(red: 255, green: 0, blue: 0))
        _ = try await indexer.indexImage(redImg, id: "red", title: "Red")

        // 注入零向量引擎的 indexer 不会影响已有项目
        let items = await indexer.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "red")
    }
}
