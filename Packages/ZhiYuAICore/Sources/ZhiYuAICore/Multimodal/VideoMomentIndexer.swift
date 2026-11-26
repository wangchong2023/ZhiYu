//
//  VideoMomentIndexer.swift
//  ZhiYuAICore
//
//  系统层级：[ZhiYuAICore] 基础设施层 / 多模态中台
//  核心职责：基于 AVAssetImageGenerator 的端侧视频抽帧、时序打标与时刻检索聚类索引器。
//

import Foundation
import CoreGraphics
#if !os(watchOS) && canImport(AVFoundation)
import AVFoundation
#endif

/// 视频关键帧特征模型
public struct VideoMomentFrame: Identifiable, Sendable {
    public let id: String
    public let videoId: String
    public let timeOffset: Double
    public let vector: [Float]
    public let thumbnailData: Data?

    public init(
        id: String = UUID().uuidString,
        videoId: String,
        timeOffset: Double,
        vector: [Float],
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.videoId = videoId
        self.timeOffset = timeOffset
        self.vector = vector
        self.thumbnailData = thumbnailData
    }
}

/// 视频时刻检索命中模型
public struct VideoMomentResult: Identifiable, Sendable {
    public let id: String
    public let videoId: String
    public let timeOffsetSeconds: Double
    public let formattedTime: String
    public let score: Float
    public let thumbnailData: Data?

    public init(
        id: String = UUID().uuidString,
        videoId: String,
        timeOffsetSeconds: Double,
        formattedTime: String,
        score: Float,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.videoId = videoId
        self.timeOffsetSeconds = timeOffsetSeconds
        self.formattedTime = formattedTime
        self.score = score
        self.thumbnailData = thumbnailData
    }
}

/// 端侧视频时刻检索索引器
public actor VideoMomentIndexer {
    public enum Config {
        public static let defaultSampleIntervalSeconds: Double = 1.0
        public static let defaultTopK: Int = 5
        public static let preferredTimescale: Int32 = 600
        public static let clusterWindowSeconds: Double = 1.5
        public static let secondsPerMinute: Int = 60
        public static let defaultFormattedTime: String = "00:00"
        public static let maxSupportedSeconds: Double = 359_999.0
    }

    public static let shared = VideoMomentIndexer()

    private let embeddingEngine: MultimodalEmbeddingProtocol
    private var frames: [VideoMomentFrame] = []

    public init(embeddingEngine: MultimodalEmbeddingProtocol = MultimodalEmbeddingEngine.shared) {
        self.embeddingEngine = embeddingEngine
    }

    /// 对本地视频文件进行抽帧与多模态时序打标
    @discardableResult
    public func indexVideo(
        url: URL,
        videoId: String,
        sampleInterval: Double = Config.defaultSampleIntervalSeconds
    ) async throws -> Int {
        #if !os(watchOS) && canImport(AVFoundation)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return 0
        }
        let asset = AVURLAsset(url: url)
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            return 0
        }
        guard sampleInterval.isFinite, sampleInterval > 0 else { return 0 }
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else { return 0 }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // 移除旧有视频帧
        frames.removeAll { $0.videoId == videoId }

        var count = 0
        var currentOffset: Double = 0.0

        while currentOffset < durationSeconds {
            let time = CMTime(seconds: currentOffset, preferredTimescale: Config.preferredTimescale)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                let vector = try await embeddingEngine.embedImage(cgImage)
                let thumbData = MediaSearchIndexer.extractThumbnailData(from: cgImage)
                let frame = VideoMomentFrame(
                    videoId: videoId,
                    timeOffset: currentOffset,
                    vector: vector,
                    thumbnailData: thumbData
                )
                frames.append(frame)
                count += 1
            } catch {
                // 单帧失败容错，继续下一帧
            }
            currentOffset += sampleInterval
        }
        return count
        #else
        return 0
        #endif
    }

    /// 检索与自然语言查询最匹配的视频时刻
    public func searchMoments(
        videoId: String? = nil,
        query: String,
        topK: Int = Config.defaultTopK
    ) async throws -> [VideoMomentResult] {
        guard topK > 0, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let queryVector = try await embeddingEngine.embedText(query)

        let candidateFrames = frames.filter { frame in
            if let targetVideoId = videoId {
                return frame.videoId == targetVideoId
            }
            return true
        }

        var scoredFrames: [(frame: VideoMomentFrame, score: Float)] = candidateFrames.map { frame in
            let score = embeddingEngine.cosineSimilarity(queryVector, frame.vector)
            return (frame, score)
        }

        // 按得分倒序
        scoredFrames.sort { $0.score > $1.score }

        // 聚类过滤（避免同一时刻由于采样率密集重复出现，相邻 1.5 秒内取最高分）
        var filteredResults: [VideoMomentResult] = []
        for scored in scoredFrames {
            let isTooClose = filteredResults.contains { item in
                item.videoId == scored.frame.videoId && abs(item.timeOffsetSeconds - scored.frame.timeOffset) < Config.clusterWindowSeconds
            }
            if !isTooClose {
                let formatted = Self.formatTime(seconds: scored.frame.timeOffset)
                let result = VideoMomentResult(
                    videoId: scored.frame.videoId,
                    timeOffsetSeconds: scored.frame.timeOffset,
                    formattedTime: formatted,
                    score: scored.score,
                    thumbnailData: scored.frame.thumbnailData
                )
                filteredResults.append(result)
            }
            if filteredResults.count >= topK {
                break
            }
        }

        return filteredResults
    }

    /// 获取帧数量
    public func frameCount(for videoId: String? = nil) -> Int {
        if let videoId = videoId {
            return frames.filter { $0.videoId == videoId }.count
        }
        return frames.count
    }

    /// 清空指定或全部视频索引
    public func clear(videoId: String? = nil) {
        if let videoId = videoId {
            frames.removeAll { $0.videoId == videoId }
        } else {
            frames.removeAll()
        }
    }

    /// 格式化时间为 mm:ss
    public static func formatTime(seconds: Double) -> String {
        guard seconds.isFinite else { return Config.defaultFormattedTime }
        let clamped = min(max(0, seconds), Config.maxSupportedSeconds)
        let totalSeconds = Int(clamped)
        let minutes = totalSeconds / Config.secondsPerMinute
        let secs = totalSeconds % Config.secondsPerMinute
        return String(format: "%02d:%02d", minutes, secs)
    }
}
