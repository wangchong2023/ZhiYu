//
//  GraphClusteringServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Knowledge
//  核心职责：验证 GraphClusteringService 聚类算法在样本不足、维度不一致与边界欧氏距离时的鲁棒性。
//

import XCTest
@testable import ZhiYu

final class GraphClusteringServiceTests: XCTestCase {

    /// 验证 embeddings 数量不足 k 时返回空数组而非崩溃
    func testCluster_insufficientEmbeddings_returnsEmpty() {
        let service = GraphClusteringService()
        let pages = (0..<10).map { i in
            KnowledgePage(id: UUID(), title: "Page\(i)", pageType: .concept, content: "content\(i)")
        }
        var embeddings: [UUID: [Float]] = [:]
        embeddings[pages[0].id] = [1.0, 2.0, 3.0]
        embeddings[pages[1].id] = [4.0, 5.0, 6.0]

        let clusters = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        XCTAssertTrue(clusters.isEmpty, "embeddings 数量不足 k 时应返回空数组")
    }

    /// 验证 embeddings 数量充足时正常聚类
    func testCluster_sufficientEmbeddings_producesClusters() {
        let service = GraphClusteringService()
        let pages = (0..<10).map { i in
            KnowledgePage(id: UUID(), title: "Page\(i)", pageType: .concept, content: "content\(i)")
        }
        var embeddings: [UUID: [Float]] = [:]
        for (i, page) in pages.enumerated() {
            embeddings[page.id] = [Float(i), Float(i + 1), Float(i + 2)]
        }

        let clusters = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        XCTAssertFalse(clusters.isEmpty, "embeddings 充足时应正常聚类")
    }

    /// 验证维度不一致的向量不会导致崩溃
    func testCluster_inconsistentDimensions_handlesGracefully() {
        let service = GraphClusteringService()
        let pages = (0..<10).map { i in
            KnowledgePage(id: UUID(), title: "Page\(i)", pageType: .concept, content: "content\(i)")
        }
        var embeddings: [UUID: [Float]] = [:]
        embeddings[pages[0].id] = [1.0, 2.0, 3.0]
        embeddings[pages[1].id] = [4.0, 5.0]
        embeddings[pages[2].id] = [7.0, 8.0, 9.0]
        for i in 3..<10 {
            embeddings[pages[i].id] = [Float(i), Float(i + 1), Float(i + 2)]
        }

        let clusters = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        XCTAssertNotNil(clusters, "维度不一致不应崩溃")
    }

    /// 验证不同维度向量的欧氏距离计算不会崩溃
    func testCluster_differingDimensions_calculatesWithoutCrash() {
        let service = GraphClusteringService()
        let pages = (0..<6).map { i in
            KnowledgePage(id: UUID(), title: "P\(i)", pageType: .concept, content: "c\(i)")
        }
        var embeddings: [UUID: [Float]] = [:]
        embeddings[pages[0].id] = [1.0, 2.0]
        embeddings[pages[1].id] = [1.0, 2.0, 3.0]
        embeddings[pages[2].id] = [1.0, 2.0, 3.0]
        embeddings[pages[3].id] = [1.0, 2.0, 3.0]
        embeddings[pages[4].id] = [1.0, 2.0, 3.0]
        embeddings[pages[5].id] = [1.0, 2.0, 3.0]

        let clusters = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        XCTAssertNotNil(clusters, "不同维度向量不应导致计算错误或崩溃")
    }
}
