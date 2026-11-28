//
//  MediaSearchIndexer.swift
//  ZhiYuAICore
//
//  系统层级：[ZhiYuAICore] 基础设施层 / 多模态中台
//  核心职责：管理端侧即时图片特征索引，支持图片导入、特征向量持久/内存存储与多模态以文搜图。
//

import Foundation
import CoreGraphics
#if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import ImageIO
import UniformTypeIdentifiers
#endif

/// 媒体项目
public struct MediaItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let timestamp: Date
    public let vector: [Float]
    public let thumbnailData: Data?

    public init(
        id: String = UUID().uuidString,
        title: String,
        timestamp: Date = Date(),
        vector: [Float],
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.vector = vector
        self.thumbnailData = thumbnailData
    }
}

/// 媒体检索结果
public struct MediaSearchResult: Identifiable, Sendable {
    public var id: String { item.id }
    public let item: MediaItem
    public let score: Float

    public init(item: MediaItem, score: Float) {
        self.item = item
        self.score = score
    }
}

/// 即时媒体检索索引器
public actor MediaSearchIndexer {
    public enum Defaults {
        public static let topK: Int = 10
        public static let minScore: Float = -1.0
    }

    public static let shared = MediaSearchIndexer()

    private let embeddingEngine: MultimodalEmbeddingProtocol
    private var items: [MediaItem] = []

    public init(embeddingEngine: MultimodalEmbeddingProtocol = MultimodalEmbeddingEngine.shared) {
        self.embeddingEngine = embeddingEngine
    }

    /// 导入单张图片并建立多模态特征索引
    ///
    /// - Important: 对零向量嵌入（退化图片或嵌入引擎故障）自动跳过入库，
    ///   防止零向量项与任何查询余弦相似度恒为 0 而污染 topK 检索排名。
    @discardableResult
    public func indexImage(
        _ image: CGImage,
        id: String = UUID().uuidString,
        title: String
    ) async throws -> MediaItem {
        let vector = try await embeddingEngine.embedImage(image)
        // 零向量防护：全零嵌入无语义信息，混入索引会以恒定 0.0 分干扰排名
        guard vector.contains(where: { $0 != 0.0 }) else {
            throw MediaIndexError.zeroVectorEmbedding
        }
        let thumbData = Self.extractThumbnailData(from: image)
        let item = MediaItem(id: id, title: title, timestamp: Date(), vector: vector, thumbnailData: thumbData)
        items.removeAll { $0.id == id }
        items.append(item)
        return item
    }

    /// 媒体索引错误
    public enum MediaIndexError: Error, Equatable {
        /// 嵌入引擎返回零向量，该图片不具备有效语义特征
        case zeroVectorEmbedding
    }

    /// 执行以文搜图跨模态检索
    public func search(
        query: String,
        topK: Int = Defaults.topK,
        minScore: Float = Defaults.minScore
    ) async throws -> [MediaSearchResult] {
        guard topK > 0, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let queryVector = try await embeddingEngine.embedText(query)
        let results: [MediaSearchResult] = items.compactMap { item in
            let score = embeddingEngine.cosineSimilarity(queryVector, item.vector)
            guard score >= minScore else { return nil }
            return MediaSearchResult(item: item, score: score)
        }
        return results.sorted { $0.score > $1.score }.prefix(topK).map { $0 }
    }

    /// 执行以图搜图相似度检索（根据目标图片 ID 寻找最相似的图片）
    public func searchByImage(
        targetId: String,
        topK: Int = Defaults.topK,
        minScore: Float = Defaults.minScore
    ) -> [MediaSearchResult] {
        guard topK > 0, let targetItem = items.first(where: { $0.id == targetId }) else {
            return []
        }
        let results: [MediaSearchResult] = items.compactMap { item in
            guard item.id != targetId else { return nil }
            let score = embeddingEngine.cosineSimilarity(targetItem.vector, item.vector)
            guard score >= minScore else { return nil }
            return MediaSearchResult(item: item, score: score)
        }
        return results.sorted { $0.score > $1.score }.prefix(topK).map { $0 }
    }

    /// 获取全部已索引媒体
    public func allItems() -> [MediaItem] {
        return items
    }

    /// 根据 ID 移除项目
    public func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }

    /// 清空所有已索引媒体
    public func clear() {
        items.removeAll()
    }

    /// 提取 JPEG 格式缩略图数据
    public static func extractThumbnailData(from image: CGImage) -> Data? {
        #if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
        #else
        return nil
        #endif
    }
}
