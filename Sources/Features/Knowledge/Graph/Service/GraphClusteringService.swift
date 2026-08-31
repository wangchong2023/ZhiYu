//
//  GraphClusteringService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：实现 GraphClustering 模块的核心业务逻辑服务。
//
import Foundation

/// 图谱聚类服务 (Architect 视角：知识涌现)
/// 负责对知识库中的页面进行语义聚类。
public final class GraphClusteringService {

    public struct Cluster: Identifiable {
        public let id = UUID()
        public let name: String
        public let pageIDs: Set<UUID>
        public let centroid: [Float]
        public let colorName: String
    }

    /// 执行 K-Means 聚类
    func cluster(pages: [KnowledgePage], embeddings: [UUID: [Float]], k: Int = FeatureConstants.GraphClustering.defaultK) -> [Cluster] {
        // Bug #123 修复：guard embeddings.count >= k，避免 centroids.count < k 导致越界
        guard pages.count > k, embeddings.count >= k else { return [] }

        // 1. 初始化质心 (随机选 K 个)
        var centroids: [[Float]] = Array(embeddings.values.prefix(k))
        var clusters: [[UUID]] = Array(repeating: [], count: k)

        // 2. 迭代 (简单实现，实际可增加迭代次数限制)
        for _ in 0..<FeatureConstants.GraphClustering.maxIterations {
            clusters = Array(repeating: [], count: k)

            // 指派阶段
            for (id, vector) in embeddings {
                let nearestIndex = findNearestCentroid(vector: vector, centroids: centroids)
                clusters[nearestIndex].append(id)
            }

            // 更新阶段
            for i in 0..<k {
                if let newCentroid = calculateMean(vectors: clusters[i].compactMap { embeddings[$0] }) {
                    centroids[i] = newCentroid
                }
            }
        }

        // 3. 包装结果
        let clusterColors: [String] = ["blue", "purple", "orange", "green", "pink", "teal", "indigo"]

        return (0..<k).compactMap { i in
            if clusters[i].isEmpty { return nil }
            return Cluster(
                name: L10n.Graph.clusterName(i + 1),
                pageIDs: Set(clusters[i]),
                centroid: centroids[i],
                colorName: clusterColors[i % clusterColors.count]
            )
        }
    }

    private func findNearestCentroid(vector: [Float], centroids: [[Float]]) -> Int {
        var minDistance = Float.infinity
        var nearestIndex = 0
        for (i, centroid) in centroids.enumerated() {
            let dist = euclideanDistance(vector, centroid)
            if dist < minDistance {
                minDistance = dist
                nearestIndex = i
            }
        }
        return nearestIndex
    }

    private func euclideanDistance(_ v1: [Float], _ v2: [Float]) -> Float {
        // Bug #125 修复：维度不一致时按缺失维度补 0 计算，而非截断
        let maxLen = max(v1.count, v2.count)
        var sum: Float = 0
        for i in 0..<maxLen {
            let a = i < v1.count ? v1[i] : 0
            let b = i < v2.count ? v2[i] : 0
            sum += pow(a - b, 2)
        }
        return sqrt(sum)
    }

    private func calculateMean(vectors: [[Float]]) -> [Float]? {
        guard !vectors.isEmpty else { return nil }
        // Bug #124 修复：取所有向量的最小维度，避免维度不一致时越界
        let count = Float(vectors.count)
        let length = vectors.map(\.count).min() ?? 0
        guard length > 0 else { return nil }
        var mean = [Float](repeating: 0, count: length)
        for vector in vectors {
            for i in 0..<length {
                mean[i] += vector[i]
            }
        }
        return mean.map { $0 / count }
    }
}
