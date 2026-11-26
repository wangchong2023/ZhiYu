//
//  MultimodalIndexerRegressionTests.swift
//  ZhiYuAICoreTests
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：以发现真实缺陷为目的，覆盖 MultimodalEmbeddingEngine（灰度图越界读防护、颜色语义对齐、
//           余弦相似度边界）、MediaSearchIndexer（topK<=0 防崩、minScore 过滤、重复 ID 覆盖、以图搜图）
//           与 VideoMomentIndexer（sampleInterval<=0 防死循环、formatTime NaN/Inf 防崩、聚类去重、真实视频抽帧）。
//

import XCTest
import CoreGraphics
#if canImport(AVFoundation)
import AVFoundation
#endif
@testable import ZhiYuAICore

final class MultimodalIndexerRegressionTests: XCTestCase {

    // MARK: - 辅助工具：构造纯色 RGBA / 灰度 CGImage 与本地真实短 MP4

    private func makeSolidImage(width: Int = 16, height: Int = 16, red: UInt8, green: UInt8, blue: UInt8) -> CGImage? {
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

    private func makeGrayscaleImage(width: Int = 8, height: Int = 8, luminance: UInt8 = 180) -> CGImage? {
        let pixels = [UInt8](repeating: luminance, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    #if !os(watchOS) && canImport(AVFoundation)
    private func createShortTestMP4(durationSeconds: Int = 2) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("moment_test_\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 64,
                kCVPixelBufferHeightKey as String: 64
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for sec in 0...durationSeconds {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
            if let buffer = pixelBuffer {
                CVPixelBufferLockBaseAddress(buffer, [])
                if let base = CVPixelBufferGetBaseAddress(buffer) {
                    let count = CVPixelBufferGetBytesPerRow(buffer) * 64
                    memset(base, sec == 0 ? 0x20 : 0xE0, count)
                }
                CVPixelBufferUnlockBaseAddress(buffer, [])
                adaptor.append(buffer, withPresentationTime: CMTime(seconds: Double(sec), preferredTimescale: 600))
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }
    #endif

    // MARK: - 1. MultimodalEmbeddingEngine 回归：灰度图越界读防护 & 跨模态色彩对齐

    func testEmbedImageGrayscaleDoesNotCrashOrOverreadBuffer() async throws {
        let engine = MultimodalEmbeddingEngine()
        let grayImage = try XCTUnwrap(makeGrayscaleImage(width: 8, height: 8, luminance: 200))
        let vector = try await engine.embedImage(grayImage)

        XCTAssertEqual(vector.count, engine.dimension)
        XCTAssertTrue(vector.allSatisfy(\.isFinite), "单通道灰度图嵌入向量不得出现 NaN/Inf")
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        XCTAssertEqual(norm, 1.0, accuracy: 0.01, "输出必须为 L2 单位向量")
    }

    func testEmbedImageAndTextColorSemanticAlignment() async throws {
        let engine = MultimodalEmbeddingEngine()
        let redImg = try XCTUnwrap(makeSolidImage(red: 250, green: 10, blue: 10))
        let blueImg = try XCTUnwrap(makeSolidImage(red: 10, green: 10, blue: 250))

        let redVec = try await engine.embedImage(redImg)
        let blueVec = try await engine.embedImage(blueImg)
        let redQuery = try await engine.embedText("red rose")
        let blueQuery = try await engine.embedText("blue ocean sky")

        let redToRed = engine.cosineSimilarity(redQuery, redVec)
        let redToBlue = engine.cosineSimilarity(redQuery, blueVec)
        let blueToBlue = engine.cosineSimilarity(blueQuery, blueVec)
        let blueToRed = engine.cosineSimilarity(blueQuery, redVec)

        XCTAssertGreaterThan(redToRed, redToBlue, "红色语义查询应更匹配红色图像")
        XCTAssertGreaterThan(blueToBlue, blueToRed, "蓝色语义查询应更匹配蓝色图像")
    }

    // MARK: - 2. MediaSearchIndexer 回归：topK<=0 防崩、以文搜图、以图搜图与覆盖删除

    func testMediaSearchIndexerSearchGuardsAndLifecycle() async throws {
        let indexer = MediaSearchIndexer(embeddingEngine: MultimodalEmbeddingEngine())
        let redImg = try XCTUnwrap(makeSolidImage(red: 255, green: 0, blue: 0))
        let greenImg = try XCTUnwrap(makeSolidImage(red: 0, green: 255, blue: 0))
        let blueImg = try XCTUnwrap(makeSolidImage(red: 0, green: 0, blue: 255))

        let item1 = try await indexer.indexImage(redImg, id: "img-red", title: "Red Rose")
        XCTAssertNotNil(item1.thumbnailData)
        _ = try await indexer.indexImage(greenImg, id: "img-green", title: "Green Forest")
        _ = try await indexer.indexImage(blueImg, id: "img-blue", title: "Blue Sea")

        // 重复 ID 必须覆盖而非累加
        _ = try await indexer.indexImage(redImg, id: "img-red", title: "Red Rose Updated")
        let all = await indexer.allItems()
        XCTAssertEqual(all.count, 3)

        // 回归测试：topK <= 0 不得崩溃且返回空数组
        let negQueryResults = try await indexer.search(query: "red", topK: -5)
        XCTAssertTrue(negQueryResults.isEmpty, "负数 topK 必须安全返回空数组而非 prefix 崩溃")
        let zeroQueryResults = try await indexer.search(query: "red", topK: 0)
        XCTAssertTrue(zeroQueryResults.isEmpty)
        let blankQueryResults = try await indexer.search(query: "   \n  ")
        XCTAssertTrue(blankQueryResults.isEmpty)

        // 正常以文搜图
        let hits = try await indexer.search(query: "red rose", topK: 2)
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits.first?.id, "img-red")

        // minScore 极高阈值过滤
        let strictHits = try await indexer.search(query: "red", minScore: 0.9999)
        XCTAssertTrue(strictHits.isEmpty)

        // 以图搜图（排除自身 + topK<=0 防护 + 不存在 ID 防护）
        let byImg = await indexer.searchByImage(targetId: "img-red", topK: 2)
        XCTAssertEqual(byImg.count, 2)
        XCTAssertFalse(byImg.contains { $0.id == "img-red" })
        let negByImg = await indexer.searchByImage(targetId: "img-red", topK: -1)
        XCTAssertTrue(negByImg.isEmpty)
        let missingByImg = await indexer.searchByImage(targetId: "unknown-id")
        XCTAssertTrue(missingByImg.isEmpty)

        // 移除与清空
        await indexer.removeItem(id: "img-green")
        let afterRemove = await indexer.allItems()
        XCTAssertEqual(afterRemove.count, 2)
        await indexer.clear()
        let afterClear = await indexer.allItems()
        XCTAssertTrue(afterClear.isEmpty)
    }

    // MARK: - 3. VideoMomentIndexer 回归：NaN/Inf 防崩、sampleInterval<=0 防死循环、真实视频抽帧与聚类去重

    func testVideoMomentIndexerFormatTimeGuardsAgainstNaNAndInfinity() {
        XCTAssertEqual(VideoMomentIndexer.formatTime(seconds: .nan), VideoMomentIndexer.Config.defaultFormattedTime)
        XCTAssertEqual(VideoMomentIndexer.formatTime(seconds: .infinity), VideoMomentIndexer.Config.defaultFormattedTime)
        XCTAssertEqual(VideoMomentIndexer.formatTime(seconds: -.infinity), VideoMomentIndexer.Config.defaultFormattedTime)
        XCTAssertEqual(VideoMomentIndexer.formatTime(seconds: -12.5), VideoMomentIndexer.Config.defaultFormattedTime)
        XCTAssertEqual(VideoMomentIndexer.formatTime(seconds: 125.9), "02:05")
    }

    #if !os(watchOS) && canImport(AVFoundation)
    func testVideoMomentIndexerEndToEndAndInvalidIntervalGuard() async throws {
        let videoURL = try await createShortTestMP4(durationSeconds: 3)
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let indexer = VideoMomentIndexer(embeddingEngine: MultimodalEmbeddingEngine())

        // 1) 不存在文件返回 0
        let missingCount = try await indexer.indexVideo(
            url: URL(fileURLWithPath: "/nonexistent/video_\(UUID().uuidString).mp4"),
            videoId: "missing"
        )
        XCTAssertEqual(missingCount, 0)

        // 2) 回归测试：sampleInterval <= 0 不得死循环，直接返回 0
        let zeroIntervalCount = try await indexer.indexVideo(url: videoURL, videoId: "v-bad", sampleInterval: 0)
        XCTAssertEqual(zeroIntervalCount, 0)
        let negIntervalCount = try await indexer.indexVideo(url: videoURL, videoId: "v-bad", sampleInterval: -1.0)
        XCTAssertEqual(negIntervalCount, 0)

        // 3) 正常抽帧与多时刻聚类去重
        let frameCount = try await indexer.indexVideo(url: videoURL, videoId: "v1", sampleInterval: 0.5)
        XCTAssertGreaterThan(frameCount, 0)
        let storedCount = await indexer.frameCount(for: "v1")
        XCTAssertEqual(storedCount, frameCount)
        let totalCount = await indexer.frameCount()
        XCTAssertEqual(totalCount, frameCount)

        // 4) 回归测试：topK <= 0 必须返回空数组（不能返回 1 条）
        let zeroTopK = try await indexer.searchMoments(videoId: "v1", query: "bright scene", topK: 0)
        XCTAssertTrue(zeroTopK.isEmpty, "topK == 0 不得错误返回 1 条结果")
        let blankQuery = try await indexer.searchMoments(videoId: "v1", query: "   ")
        XCTAssertTrue(blankQuery.isEmpty)

        // 5) 正常检索与聚类窗口去重校验（任意两条命中间隔 >= 1.5s）
        let results = try await indexer.searchMoments(videoId: "v1", query: "bright frame", topK: 5)
        XCTAssertFalse(results.isEmpty)
        for i in 0..<results.count {
            for j in (i + 1)..<results.count {
                XCTAssertGreaterThanOrEqual(
                    abs(results[i].timeOffsetSeconds - results[j].timeOffsetSeconds),
                    VideoMomentIndexer.Config.clusterWindowSeconds
                )
            }
        }

        // 6) 全局检索 + clear(videoId:) + clear()
        let allVideoResults = try await indexer.searchMoments(videoId: nil, query: "bright", topK: 2)
        XCTAssertFalse(allVideoResults.isEmpty)
        await indexer.clear(videoId: "v1")
        let countAfterClearV1 = await indexer.frameCount(for: "v1")
        XCTAssertEqual(countAfterClearV1, 0)
        await indexer.clear()
        let countAfterClearAll = await indexer.frameCount()
        XCTAssertEqual(countAfterClearAll, 0)
    }
    #endif

    /// 防御性回归：dimension <= 0 不得触发除零或负数组长度致命崩溃
    func testEmbeddingEngineClampsNonPositiveDimensionSafely() async throws {
        let zeroDimEngine = MultimodalEmbeddingEngine(dimension: 0)
        XCTAssertEqual(zeroDimEngine.dimension, 1)
        let zeroTextVec = try await zeroDimEngine.embedText("red ocean")
        XCTAssertEqual(zeroTextVec.count, 1)

        let negativeDimEngine = MultimodalEmbeddingEngine(dimension: -16)
        XCTAssertEqual(negativeDimEngine.dimension, 1)
        let negTextVec = try await negativeDimEngine.embedText("blue sky")
        XCTAssertEqual(negTextVec.count, 1)

        let moment = VideoMomentResult(
            videoId: "vid",
            timeOffsetSeconds: 12.5,
            formattedTime: VideoMomentIndexer.formatTime(seconds: 12.5),
            score: 0.9
        )
        XCTAssertEqual(moment.formattedTime, "00:12")

        // 纯黑图像像素全 0 时，L2 归一化必须触发零范数兜底，不得产生 NaN
        let blackImage = try XCTUnwrap(makeSolidImage(red: 0, green: 0, blue: 0))
        let blackVec = try await MultimodalEmbeddingEngine.shared.embedImage(blackImage)
        XCTAssertEqual(blackVec.count, MultimodalEmbeddingEngine.Constants.defaultDimension)
        XCTAssertTrue(blackVec.allSatisfy { $0.isFinite }, "全黑图像向量不得包含 NaN 或 Infinity")

        // 1x1 极小图像 + VideoMomentFrame 模型初始化边界校验
        let tinyImage = try XCTUnwrap(makeSolidImage(width: 1, height: 1, red: 255, green: 0, blue: 0))
        let tinyVec = try await MultimodalEmbeddingEngine.shared.embedImage(tinyImage)
        XCTAssertEqual(tinyVec.count, MultimodalEmbeddingEngine.Constants.defaultDimension)
        let frame = VideoMomentFrame(videoId: "vid", timeOffset: 1.0, vector: tinyVec)
        XCTAssertEqual(frame.videoId, "vid")
    }
}
