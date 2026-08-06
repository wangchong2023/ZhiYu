//
//  GraphClusteringServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 K-Means 聚类服务的质心初始化、聚类收敛、空输入处理等边界语义。
//

import XCTest
@testable import ZhiYu

final class GraphClusteringServiceTests: XCTestCase {

    private let service = GraphClusteringService()

    // MARK: - 空输入与边界

    func testCluster_pagesFewerThanK_returnsEmpty() {
        let pages = [KnowledgePage(title: "A")]
        let embeddings: [UUID: [Float]] = [pages[0].id: [0.1, 0.2]]
        let result = service.cluster(pages: pages, embeddings: embeddings, k: 5)
        XCTAssertTrue(result.isEmpty, "页面数 < k 时应返回空")
    }

    func testCluster_emptyPages_returnsEmpty() {
        let result = service.cluster(pages: [], embeddings: [:], k: 3)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 基本聚类

    func testCluster_twoGroups_separatesCorrectly() {
        let pageA = KnowledgePage(title: "A")
        let pageB = KnowledgePage(title: "B")
        let pageC = KnowledgePage(title: "C")
        let pageD = KnowledgePage(title: "D")

        // A/B 在原点附近，C/D 在远处
        let embeddings: [UUID: [Float]] = [
            pageA.id: [0.0, 0.0],
            pageB.id: [0.1, 0.1],
            pageC.id: [10.0, 10.0],
            pageD.id: [10.1, 10.1]
        ]
        let pages = [pageA, pageB, pageC, pageD]

        let result = service.cluster(pages: pages, embeddings: embeddings, k: 2)
        XCTAssertEqual(result.count, 2, "应产生 2 个聚类")

        // 验证 A/B 在同一聚类，C/D 在另一聚类
        let clusterAB = result.first { $0.pageIDs.contains(pageA.id) }
        let clusterCD = result.first { $0.pageIDs.contains(pageC.id) }
        XCTAssertNotNil(clusterAB)
        XCTAssertNotNil(clusterCD)
        XCTAssertNotEqual(clusterAB?.id, clusterCD?.id, "A/B 和 C/D 应在不同聚类")
        XCTAssertTrue(clusterAB?.pageIDs.contains(pageB.id) == true, "A 和 B 应在同一聚类")
        XCTAssertTrue(clusterCD?.pageIDs.contains(pageD.id) == true, "C 和 D 应在同一聚类")
    }

    // MARK: - 聚类属性

    func testCluster_resultHasNameAndColor() {
        let pages = (0..<6).map { KnowledgePage(title: "Page\($0)") }
        let embeddings: [UUID: [Float]] = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, [Float.random(in: 0...1), Float.random(in: 0...1)]) })
        let result = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        for cluster in result {
            XCTAssertFalse(cluster.name.isEmpty, "聚类名称不应为空")
            XCTAssertFalse(cluster.colorName.isEmpty, "聚类颜色不应为空")
        }
    }

    func testCluster_centroidDimensions_matchEmbedding() {
        let pages = (0..<6).map { KnowledgePage(title: "Page\($0)") }
        let embeddings: [UUID: [Float]] = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, [Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1)]) })
        let result = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        for cluster in result {
            XCTAssertEqual(cluster.centroid.count, 3, "质心维度应与嵌入维度一致")
        }
    }

    // MARK: - k 值边界

    func testCluster_kEqualsPageCount_returnsEmpty() {
        let pages = [KnowledgePage(title: "A"), KnowledgePage(title: "B")]
        let embeddings: [UUID: [Float]] = [
            pages[0].id: [0.0, 0.0],
            pages[1].id: [1.0, 1.0]
        ]
        let result = service.cluster(pages: pages, embeddings: embeddings, k: 2)
        XCTAssertTrue(result.isEmpty, "pages.count == k 时应返回空（guard pages.count > k）")
    }

    // MARK: - 聚类 ID 唯一性

    func testCluster_clusterIDsUnique() {
        let pages = (0..<10).map { KnowledgePage(title: "Page\($0)") }
        let embeddings: [UUID: [Float]] = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, [Float.random(in: 0...1), Float.random(in: 0...1)]) })
        let result = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        let ids = result.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "聚类 ID 应唯一")
    }

    // MARK: - pageIDs 覆盖

    func testCluster_allPagesAssigned() {
        let pages = (0..<8).map { KnowledgePage(title: "Page\($0)") }
        let embeddings: [UUID: [Float]] = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, [Float.random(in: 0...1), Float.random(in: 0...1)]) })
        let result = service.cluster(pages: pages, embeddings: embeddings, k: 3)
        let allAssigned = Set(result.flatMap { $0.pageIDs })
        let allPageIDs = Set(pages.map { $0.id })
        XCTAssertEqual(allAssigned, allPageIDs, "所有页面应被分配到聚类中")
    }
}
