//
//  VectorMathCosineSimilarityTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 VectorMath.cosineSimilarity 基于 Accelerate/vDSP 的余弦相似度极值边界与向量几何计算。
//

import XCTest
@testable import UFPCore

final class VectorMathCosineSimilarityTests: XCTestCase {

    // MARK: - 边界防护 (Guard Clauses)

    func testCosineSimilarity_emptyVectors_returnsZero() {
        XCTAssertEqual(VectorMath.cosineSimilarity([], []), 0.0)
    }

    func testCosineSimilarity_mismatchedVectorLengths_returnsZero() {
        let v1: [Float] = [1.0, 2.0]
        let v2: [Float] = [1.0, 2.0, 3.0]
        XCTAssertEqual(VectorMath.cosineSimilarity(v1, v2), 0.0)
    }

    func testCosineSimilarity_allZeroVector_returnsZero() {
        let zeroVector: [Float] = [0.0, 0.0, 0.0]
        let normalVector: [Float] = [1.0, 2.0, 3.0]
        XCTAssertEqual(VectorMath.cosineSimilarity(zeroVector, normalVector), 0.0)
        XCTAssertEqual(VectorMath.cosineSimilarity(normalVector, zeroVector), 0.0)
        XCTAssertEqual(VectorMath.cosineSimilarity(zeroVector, zeroVector), 0.0)
    }

    // MARK: - 几何特性与极值 (Geometric Invariants)

    func testCosineSimilarity_identicalVectors_returnsOne() {
        let v: [Float] = [3.0, -4.0, 5.0, 1.2]
        let similarity = VectorMath.cosineSimilarity(v, v)
        XCTAssertEqual(similarity, 1.0, accuracy: 1e-5, "相同非零向量的余弦相似度必须为 1.0")
    }

    func testCosineSimilarity_oppositeVectors_returnsMinusOne() {
        let v1: [Float] = [1.0, 2.0, 3.0]
        let v2: [Float] = [-1.0, -2.0, -3.0]
        let similarity = VectorMath.cosineSimilarity(v1, v2)
        XCTAssertEqual(similarity, -1.0, accuracy: 1e-5, "反向共线向量的余弦相似度必须为 -1.0")
    }

    func testCosineSimilarity_orthogonalVectors_returnsZero() {
        let v1: [Float] = [1.0, 0.0, 0.0]
        let v2: [Float] = [0.0, 1.0, 0.0]
        let similarity = VectorMath.cosineSimilarity(v1, v2)
        XCTAssertEqual(similarity, 0.0, accuracy: 1e-5, "正交正负向量的余弦相似度必须为 0.0")
    }

    func testCosineSimilarity_highDimensionalEmbeddingVectors_computesAccurately() {
        let dimension = 128
        var v1 = [Float](repeating: 0.0, count: dimension)
        var v2 = [Float](repeating: 0.0, count: dimension)

        for i in 0..<dimension {
            v1[i] = Float(i + 1)
            v2[i] = Float((i + 1) * 2)
        }

        // v2 是 v1 的标量倍数，方向完全一致
        let similarity = VectorMath.cosineSimilarity(v1, v2)
        XCTAssertEqual(similarity, 1.0, accuracy: 1e-5, "等比例高维向量方向一致，相似度应为 1.0")
    }

    // MARK: - NaN / Inf / 浮点溢出防护（缺陷 #171）

    func testCosineSimilarity_nanAndInfVectors_returnsZeroAndFinite() {
        let normal: [Float] = [1.0, 2.0, 3.0]
        let nanVec: [Float] = [1.0, .nan, 3.0]
        let infVec: [Float] = [1.0, .infinity, 3.0]
        let overflowVec: [Float] = [Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, 1.0]

        let r1 = VectorMath.cosineSimilarity(normal, nanVec)
        XCTAssertEqual(r1, 0.0)
        XCTAssertTrue(r1.isFinite, "含 NaN 向量不得返回 NaN")

        let r2 = VectorMath.cosineSimilarity(normal, infVec)
        XCTAssertEqual(r2, 0.0)
        XCTAssertTrue(r2.isFinite, "含 Inf 向量不得返回 NaN/Inf")

        let r3 = VectorMath.cosineSimilarity(overflowVec, overflowVec)
        XCTAssertEqual(r3, 0.0)
        XCTAssertTrue(r3.isFinite, "平方和溢出为 Inf 的向量应安全降级为 0")
    }
}
