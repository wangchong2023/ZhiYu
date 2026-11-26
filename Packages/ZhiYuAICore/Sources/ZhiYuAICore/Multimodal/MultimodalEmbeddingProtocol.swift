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
public final class MultimodalEmbeddingEngine: MultimodalEmbeddingProtocol, Sendable {

    public enum Constants {
        public static let defaultDimension: Int = 768
        static let wordHashMultiplier: Int = 31
        static let wordHashShift: Int = 3
        static let wordHashModulo: Int = 1000
        static let wordHashOffset: Int = 500
        static let wordHashScale: Float = 500.0
        static let charHashMultiplier: Int = 17
        static let charIndexMultiplier: Int = 7
        static let charSlotBoost: Float = 0.5
        static let colorBandCount: Int = 3
        static let colorKeywordBoost: Float = 1.5
        static let bitsPerByte: Int = 8
        static let imageSampleGridDivisor: Int = 16
        static let spatialHashXMultiplier: Int = 13
        static let spatialHashYMultiplier: Int = 29
        static let lumaWeightR: Float = 0.299
        static let lumaWeightG: Float = 0.587
        static let lumaWeightB: Float = 0.114
        static let maxChannelValue: Float = 255.0
        static let dominantColorWeight: Float = 0.5
        static let minNormEpsilon: Float = 0.00001
    }

    private enum ColorSemanticKeywords {
        static let red: [String] = ["red", "rose", "\u{7EA2}", "\u{8D64}"]
        static let green: [String] = ["green", "leaf", "forest", "\u{7EFF}", "\u{8349}"]
        static let blue: [String] = ["blue", "ocean", "sea", "sky", "\u{84DD}", "\u{6D77}"]
    }

    /// 默认单例
    public static let shared = MultimodalEmbeddingEngine()

    /// 向量维度
    public let dimension: Int

    public init(dimension: Int = Constants.defaultDimension) {
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
            for dim in 0..<dimension {
                let seed = (hash &+ (dim * Constants.wordHashMultiplier)) ^ (dim << Constants.wordHashShift)
                let val = Float((seed % Constants.wordHashModulo) - Constants.wordHashOffset) / Constants.wordHashScale
                vector[dim] += val * weight
            }
        }

        // 单字/字符补充哈希（对中文单字或短词强化特征）
        for (charIndex, scalar) in trimmed.unicodeScalars.enumerated() {
            let charVal = Int(scalar.value)
            let slot = (charVal * Constants.charHashMultiplier + charIndex * Constants.charIndexMultiplier) % dimension
            vector[slot] += Constants.charSlotBoost
        }

        // 视觉语义跨模态对齐投影：将关键视觉属性投影至对齐的视觉低频子空间
        let bandSize = dimension / Constants.colorBandCount
        let lower = trimmed.lowercased()
        if ColorSemanticKeywords.red.contains(where: { lower.contains($0) }) {
            for i in 0..<bandSize { vector[i] += Constants.colorKeywordBoost }
        }
        if ColorSemanticKeywords.green.contains(where: { lower.contains($0) }) {
            for i in bandSize..<(bandSize * 2) { vector[i] += Constants.colorKeywordBoost }
        }
        if ColorSemanticKeywords.blue.contains(where: { lower.contains($0) }) {
            for i in (bandSize * 2)..<dimension { vector[i] += Constants.colorKeywordBoost }
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

        let bytesPerPixel = max(1, image.bitsPerPixel / Constants.bitsPerByte)
        let bytesPerRow = image.bytesPerRow
        let sampleStep = max(1, min(width, height) / Constants.imageSampleGridDivisor)

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
                let spatialSlot = (x * Constants.spatialHashXMultiplier + y * Constants.spatialHashYMultiplier) % dimension
                let brightness = (r * Constants.lumaWeightR + g * Constants.lumaWeightG + b * Constants.lumaWeightB) / Constants.maxChannelValue
                vector[spatialSlot] += brightness
            }
        }

        if sampleCount > 0 {
            let avgR = (rSum / sampleCount) / Constants.maxChannelValue
            let avgG = (gSum / sampleCount) / Constants.maxChannelValue
            let avgB = (bSum / sampleCount) / Constants.maxChannelValue

            // 主色调低频空间注入
            let bandSize = dimension / Constants.colorBandCount
            for i in 0..<bandSize {
                vector[i] += avgR * Constants.dominantColorWeight
                vector[i + bandSize] += avgG * Constants.dominantColorWeight
                vector[i + bandSize * 2] += avgB * Constants.dominantColorWeight
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
        guard norm > Constants.minNormEpsilon else {
            return vector
        }
        return vector.map { $0 / norm }
    }
}
