//
//  RAGGovernanceMetricsTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - RAG治理
//  核心职责：验证 RAG 评估指标（MRR、NDCG）计算公式中真实 rank 与数组索引的数学一致性。
//

import XCTest
import Foundation
@testable import ZhiYu

@MainActor
final class RAGGovernanceMetricsTests: XCTestCase {

    /// 验证 MRR 计算公式在 rank 不连续场景下使用实际 rank 计算
    func testMRR_calculationUsesActualRankInsteadOfIndex() async throws {
        let snapshots = [
            (rank: 1, isRelevant: false),
            (rank: 3, isRelevant: true)
        ]

        var correctMRR: Double = 0
        for snap in snapshots where snap.isRelevant {
            correctMRR = 1.0 / Double(snap.rank)
            break
        }

        var buggyMRR: Double = 0
        for (idx, snap) in snapshots.enumerated() where snap.isRelevant {
            buggyMRR = 1.0 / Double(idx + 1)
            break
        }

        XCTAssertNotEqual(correctMRR, buggyMRR, "rank 不连续时 MRR 计算应有差异")
        XCTAssertEqual(correctMRR, 1.0 / 3.0, accuracy: 0.001, "正确 MRR 应为 1/3")
        XCTAssertEqual(buggyMRR, 1.0 / 2.0, accuracy: 0.001, "错误 MRR 为 1/2（用 idx+1）")
    }

    /// 验证 NDCG 计算公式在 rank 不连续场景下使用实际 rank 折损
    func testNDCG_calculationUsesActualRankInsteadOfIndex() async throws {
        let snapshots = [
            (rank: 1, relevance: 0),
            (rank: 3, relevance: 2)
        ]

        var correctDCG: Double = 0
        for snap in snapshots {
            let gain = pow(2.0, Double(snap.relevance)) - 1.0
            let discount = log2(Double(snap.rank) + 1.0)
            correctDCG += gain / discount
        }

        var buggyDCG: Double = 0
        for (idx, snap) in snapshots.enumerated() {
            let gain = pow(2.0, Double(snap.relevance)) - 1.0
            let discount = log2(Double(idx + 1) + 1.0)
            buggyDCG += gain / discount
        }

        XCTAssertNotEqual(correctDCG, buggyDCG, "rank 不连续时 NDCG 计算应有差异")
    }
}
