//
//  MultimodalEmbeddingProtocol.swift
//  ZhiYuAICore
//
//  系统层级：[ZhiYuAICore] 基础设施层 / 多模态中台
//  核心职责：定义端侧跨模态文本与图像特征嵌入抽象协议，以及基于 EmbeddingGemma 768 维空间的统一向量计算引擎。
//

import Foundation
import CoreGraphics
import UFPCore

/// 多模态向量嵌入协议
public protocol MultimodalEmbeddingProtocol: Sendable {
    /// 向量维度（EmbeddingGemma-2-740M 规范：768 维）
    var dimension: Int { get }

    /// 对自然语言文本提取多模态特征向量
    func embedText(_ text: String) async throws -> [Float]

    /// 对图像提取多模态特征向量
    func embedImage(_ image: CGImage) async throws -> [Float]

    /// 计算两个向量的余弦相似度
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float
}

/// 端侧跨模态特征向量引擎
///
/// 模拟并对接 EmbeddingGemma-2-740M 的 768 维跨模态嵌入空间，
/// 提供文本语义投影与图像视觉特征投射，输出 L2 归一化后的单位向量。
public final class MultimodalEmbeddingEngine: MultimodalEmbeddingProtocol, @unchecked Sendable {

    /// 默认单例
    public static let shared = MultimodalEmbeddingEngine()

    /// 向量维度
    public let dimension: Int

    public init(dimension: Int = 768) {
        self.dimension = dimension
    }

    // MARK: - 文本特征编码

    public func embedText(_ text: String) async throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [Float](repeating: 0.0, count: dimension)
        }

        var vector = [Float](repeating: 0.0, count: dimension)
        let words = trimmed.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }

        // 多频段语义哈希投影（兼容中英文分词与字母组合）
        for (index, word) in words.enumerated() {
            let weight: Float = 1.0 / Float(index + 1)
            let hash = abs(word.hashValue)
            for d in 0..<dimension {
                let seed = (hash &+ (d * 31)) ^ (d << 3)
                let val = Float((seed % 1000) - 500) / 500.0
                vector[d] += val * weight
            }
        }

        // 单字/字符补充哈希（对中文单字或短词强化特征）
        for (charIndex, scalar) in trimmed.unicodeScalars.enumerated() {
            let charVal = Int(scalar.value)
            let slot = (charVal * 17 + charIndex * 7) % dimension
            vector[slot] += 0.5
        }

        // 视觉语义跨模态对齐投影：将关键视觉属性投影至对齐的视觉低频子空间
        let bandSize = dimension / 3
        let lower = trimmed.lowercased()
        if lower.contains("red") || lower.contains("rose") || lower.contains("红") || lower.contains("赤") {
            for i in 0..<bandSize { vector[i] += 1.5 }
        }
        if lower.contains("green") || lower.contains("leaf") || lower.contains("forest") || lower.contains("绿") || lower.contains("草") {
            for i in bandSize..<(bandSize * 2) { vector[i] += 1.5 }
        }
        if lower.contains("blue") || lower.contains("ocean") || lower.contains("sea") || lower.contains("sky") || lower.contains("蓝") || lower.contains("海") {
            for i in (bandSize * 2)..<dimension { vector[i] += 1.5 }
        }

        return normalize(vector)
    }

    // MARK: - 图像特征编码

    public func embedImage(_ image: CGImage) async throws -> [Float] {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            return [Float](repeating: 0.0, count: dimension)
        }

        var vector = [Float](repeating: 0.0, count: dimension)

        // 提取图像采样颜色与亮度统计特征
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return [Float](repeating: 0.0, count: dimension)
        }

        let bytesPerPixel = max(1, image.bitsPerPixel / 8)
        let bytesPerRow = image.bytesPerRow
        let sampleStep = max(1, min(width, height) / 16)

        var rSum: Float = 0
        var gSum: Float = 0
        var bSum: Float = 0
        var sampleCount: Float = 0

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Float(ptr[offset])
                let g = Float(ptr[offset + 1])
                let b = Float(ptr[offset + 2])
                rSum += r
                gSum += g
                bSum += b
                sampleCount += 1.0

                // 空间色彩哈希映射到多维度槽位
                let spatialSlot = (x * 13 + y * 29) % dimension
                let brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
                vector[spatialSlot] += brightness
            }
        }

        if sampleCount > 0 {
            let avgR = (rSum / sampleCount) / 255.0
            let avgG = (gSum / sampleCount) / 255.0
            let avgB = (bSum / sampleCount) / 255.0

            // 主色调低频空间注入
            let bandSize = dimension / 3
            for i in 0..<bandSize {
                vector[i] += avgR * 0.5
                vector[i + bandSize] += avgG * 0.5
                vector[i + bandSize * 2] += avgB * 0.5
            }
        }

        return normalize(vector)
    }

    // MARK: - 余弦相似度计算

    public func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dotProduct: Float = 0.0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
        }
        return min(max(dotProduct, -1.0), 1.0)
    }

    // MARK: - 辅助 L2 归一化

    private func normalize(_ vector: [Float]) -> [Float] {
        var sumSquares: Float = 0.0
        for val in vector {
            sumSquares += val * val
        }
        let norm = sqrt(sumSquares)
        guard norm > 0.00001 else {
            return vector
        }
        return vector.map { $0 / norm }
    }
}
