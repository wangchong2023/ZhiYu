//
//  MultimodalMediaSearchTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试 / 基础设施层
//  核心职责：端到端真实测试以文搜图（MediaSearchIndexer）与视频时刻定位（VideoMomentIndexer）
//  包含真实图像像素绘制、AVAssetWriter 真实视频文件合成、多模态特征提取与时刻时序检索。
//

import XCTest
import CoreGraphics
import CoreVideo
import AVFoundation
@testable import ZhiYuAICore

final class MultimodalMediaSearchTests: XCTestCase {

    // MARK: - 真实图片生成辅助

    private func createTestImage(width: Int = 64, height: Int = 64, r: CGFloat, g: CGFloat, b: CGFloat) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let color = CGColor(colorSpace: colorSpace, components: [r, g, b, 1.0]) else {
            fatalError("Failed to create test image context or color")
        }
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            fatalError("Failed to make image from context")
        }
        return image
    }

    // MARK: - 真实视频生成辅助

    private func generateTestVideo(at url: URL, frameCount: Int = 3) async throws {
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)

        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32ARGB),
            size: CVImageSize(width: 64, height: 64)
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)

        try writer.start()
        writer.startSession(atSourceTime: .zero)

        for i in 0..<frameCount {
            var mutable = try CVMutablePixelBuffer(attributes)
            let byteVal = UInt8((i + 1) * 70)
            mutable.accessUnsafeMutableRawPlaneBytes { planes in
                for plane in planes {
                    if !plane.bytes.isEmpty, let base = plane.bytes.baseAddress {
                        memset(base, Int32(byteVal), plane.bytes.count)
                    }
                }
            }

            let frameTime = CMTime(seconds: Double(i), preferredTimescale: 600)
            try await receiver.append(CVReadOnlyPixelBuffer(mutable), with: frameTime)
        }

        input.markAsFinished()
        await writer.finishWriting()
    }

    // MARK: - 测试 1: 真实图片特征导入与以文搜图检索

    func testRealImageIndexingAndTextSearch() async throws {
        let indexer = MediaSearchIndexer()
        await indexer.clear()

        // 1. 真实绘制 3 张具有不同视觉主色调的测试图片
        let redImage = createTestImage(r: 0.9, g: 0.1, b: 0.1)
        let greenImage = createTestImage(r: 0.1, g: 0.9, b: 0.1)
        let blueImage = createTestImage(r: 0.1, g: 0.1, b: 0.9)

        // 2. 真实导入并建立特征向量索引
        let redItem = try await indexer.indexImage(redImage, id: "img_red", title: "Red Rose Flower")
        _ = try await indexer.indexImage(greenImage, id: "img_green", title: "Green Leaf Forest")
        _ = try await indexer.indexImage(blueImage, id: "img_blue", title: "Blue Ocean Waves")

        let allItems = await indexer.allItems()
        XCTAssertEqual(allItems.count, 3, "成功索引 3 张真实图片")
        XCTAssertNotNil(redItem.thumbnailData, "成功提取图片缩略图")
        XCTAssertEqual(redItem.vector.count, 768, "向量维度符合 EmbeddingGemma 768 规范")

        // 3. 真实以文搜图检索
        let searchRed = try await indexer.search(query: "red rose", topK: 1)
        XCTAssertFalse(searchRed.isEmpty)
        XCTAssertEqual(searchRed.first?.item.id, "img_red", "以文搜图 Top1 精准命中红色花朵")
        XCTAssertGreaterThan(searchRed.first?.score ?? 0, 0.0, "相似度大于 0")

        let searchGreen = try await indexer.search(query: "green leaf", topK: 1)
        XCTAssertFalse(searchGreen.isEmpty)
        XCTAssertEqual(searchGreen.first?.item.id, "img_green", "以文搜图 Top1 精准命中绿色植物")

        // 4. 移除与清空
        await indexer.removeItem(id: "img_blue")
        let afterRemove = await indexer.allItems()
        XCTAssertEqual(afterRemove.count, 2)

        await indexer.clear()
        let afterClear = await indexer.allItems()
        XCTAssertTrue(afterClear.isEmpty)
    }

    // MARK: - 测试 1.5: 以图搜图向量相似度检索 (Image-to-Image Search)

    func testSearchByImageSimilarity() async throws {
        let indexer = MediaSearchIndexer()
        await indexer.clear()

        // 1. 绘制两张红色调图片（高相似）与一张蓝色调图片（低相似）
        let redImage1 = createTestImage(r: 0.95, g: 0.1, b: 0.1)
        let redImage2 = createTestImage(r: 0.90, g: 0.15, b: 0.15)
        let blueImage = createTestImage(r: 0.1, g: 0.1, b: 0.95)

        _ = try await indexer.indexImage(redImage1, id: "img_red_1", title: "Red Rose 1")
        _ = try await indexer.indexImage(redImage2, id: "img_red_2", title: "Red Rose 2")
        _ = try await indexer.indexImage(blueImage, id: "img_blue", title: "Blue Ocean")

        // 2. 以 img_red_1 作为目标进行以图搜图
        let similarResults = await indexer.searchByImage(targetId: "img_red_1", topK: 2)

        XCTAssertFalse(similarResults.isEmpty, "以图搜图结果不为空")
        // 验证自身 img_red_1 被排除
        XCTAssertFalse(similarResults.contains { $0.item.id == "img_red_1" }, "以图搜图自动剔除自身")
        // 验证 Top1 为同色调的 img_red_2
        XCTAssertEqual(similarResults.first?.item.id, "img_red_2", "视觉最相似的图片排在首位")
        XCTAssertGreaterThan(similarResults.first?.score ?? 0, 0.90, "同色系特征余弦相似度极高")

        await indexer.clear()
    }

    // MARK: - 测试 2: 真实视频合成抽帧与时刻定位检索

    func testRealVideoGenerationAndMomentSearch() async throws {
        let indexer = VideoMomentIndexer()
        await indexer.clear()

        let tempVideoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zhiyu_test_moment_\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: tempVideoURL)
        }

        // 1. 真实合成包含 3 帧不同内容的测试视频
        try await generateTestVideo(at: tempVideoURL, frameCount: 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempVideoURL.path))

        // 2. 真实调用抽帧与时序索引引擎
        let videoId = "vid_nature"
        let indexedCount = try await indexer.indexVideo(
            url: tempVideoURL,
            videoId: videoId,
            sampleInterval: 1.0
        )
        XCTAssertGreaterThanOrEqual(indexedCount, 2, "成功从真实视频中抽帧并建立特征时序索引")

        let totalFrames = await indexer.frameCount(for: videoId)
        XCTAssertEqual(totalFrames, indexedCount)

        // 3. 执行时刻检索
        let results = try await indexer.searchMoments(
            videoId: videoId,
            query: "nature frame",
            topK: 3
        )
        XCTAssertFalse(results.isEmpty, "成功检索到匹配视频时刻")
        XCTAssertEqual(results.first?.videoId, videoId)
        XCTAssertNotNil(results.first?.formattedTime, "格式化时刻不为空")

        // 4. 清除特定视频
        await indexer.clear(videoId: videoId)
        let clearedCount = await indexer.frameCount(for: videoId)
        XCTAssertEqual(clearedCount, 0)
    }

    // MARK: - 测试 3: 异常与边界路径

    func testEdgeCasesAndFaultTolerance() async throws {
        let mediaIndexer = MediaSearchIndexer()
        let videoIndexer = VideoMomentIndexer()

        // 1. 空检索词安全返回空结果
        let emptyMediaSearch = try await mediaIndexer.search(query: "   ", topK: 5)
        XCTAssertTrue(emptyMediaSearch.isEmpty)

        let emptyMomentSearch = try await videoIndexer.searchMoments(query: "", topK: 5)
        XCTAssertTrue(emptyMomentSearch.isEmpty)

        // 2. 无效视频路径安全处理
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_zhiyu_video_\(UUID().uuidString).mp4")
        let nonExistentFrames = try await videoIndexer.indexVideo(url: nonExistentURL, videoId: "missing")
        XCTAssertEqual(nonExistentFrames, 0, "无效视频路径优雅返回 0 帧")

        // 3. 时间格式化校验
        let formattedZero = VideoMomentIndexer.formatTime(seconds: 0)
        XCTAssertEqual(formattedZero, "00:00")

        let formattedMinute = VideoMomentIndexer.formatTime(seconds: 65)
        XCTAssertEqual(formattedMinute, "01:05")

        let formattedHour = VideoMomentIndexer.formatTime(seconds: 3661)
        XCTAssertEqual(formattedHour, "61:01")
    }
}
