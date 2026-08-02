//
//  WidgetSyncSnapshotTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

final class WidgetSyncSnapshotTests: XCTestCase {

    func testWidgetSnapshotJSONSerializationContract() throws {
        let snapshotPayload: [String: Any] = [
            "pageCount": 42,
            "linkCount": 128,
            "tagCount": 15,
            "dailyInsightTitle": "Karpathy LLM Wiki 架构",
            "dailyInsightContent": "语义分块 + 向量 FTS5 混合持久化存储",
            "flashThoughtSummary": "闪念随记自动挂载概念图谱",
            "distribution": ["source": 0.4, "concept": 0.3, "entity": 0.2, "map": 0.1]
        ]

        let data = try JSONSerialization.data(withJSONObject: snapshotPayload)
        XCTAssertGreaterThan(data.count, 0, "JSON 序列化 Data 绝不能为空")

        let decodedDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(decodedDict, "反序列化 JSON 字典绝不能为空")

        XCTAssertEqual(decodedDict?["pageCount"] as? Int, 42)
        XCTAssertEqual(decodedDict?["dailyInsightTitle"] as? String, "Karpathy LLM Wiki 架构")
        XCTAssertEqual(decodedDict?["dailyInsightContent"] as? String, "语义分块 + 向量 FTS5 混合持久化存储")
        
        let distribution = decodedDict?["distribution"] as? [String: Double]
        XCTAssertEqual(distribution?["source"], 0.4)
    }

    func testInvalidJSONSnapshotThrowsError() {
        let invalidData = Data("Not_A_Valid_JSON_Format".utf8)

        XCTAssertThrowsError(
            try JSONSerialization.jsonObject(with: invalidData),
            "遇到损坏的 JSON 数据必须精确抛出 Error，不得吞掉异常"
        ) { error in
            XCTAssertTrue(error is NSError, "错误必须为 NSError / JSON 异常")
        }
    }
}
