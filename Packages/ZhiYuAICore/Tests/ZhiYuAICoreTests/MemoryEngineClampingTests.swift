//
//  MemoryEngineClampingTests.swift
//  ZhiYuAICoreTests
//
//  Created by Antigravity on 2026/11/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：缺陷 #285 回归测试 — 验证 NativeMemoryEngine / SwarmMemoryAdapter 对
//           recentCount ≤ 0 和负数的防御性钳位，确保不丢失全部近期对话上下文。
//

import XCTest
@testable import ZhiYuAICore
import ZhiYuDomain

final class MemoryEngineClampingTests: XCTestCase {

    private let engines: [any MemoryEngineProtocol] = [NativeMemoryEngine(), SwarmMemoryAdapter()]

    private func makeHistory(count: Int) -> [ChatMessageDomainDTO] {
        (0..<count).map { i in
            ChatMessageDomainDTO(id: "msg-\(i)", role: i.isMultiple(of: 2) ? "user" : "assistant", content: "消息 \(i)")
        }
    }

    // MARK: - recentCount ≤ 0 钳位测试

    /// recentCount = 0 时必须钳位到 1，保留最近一条上下文
    func testRecentCountZeroClampsToOne() async {
        let history = makeHistory(count: 10)
        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: history, recentCount: 0)
            XCTAssertEqual(recent.count, 1, "\(engine.engineType): recentCount=0 应钳位到 1")
            XCTAssertEqual(recent.first?.id, "msg-9", "\(engine.engineType): 钳位后应保留最后一条消息")
            XCTAssertNotNil(summary, "\(engine.engineType): 钳位后仍有 older 消息应生成 summary")
        }
    }

    /// recentCount = -5 时必须钳位到 1
    func testRecentCountNegativeClampsToOne() async {
        let history = makeHistory(count: 5)
        for engine in engines {
            let (_, recent) = await engine.processMemory(history: history, recentCount: -5)
            XCTAssertEqual(recent.count, 1, "\(engine.engineType): 负数 recentCount 应钳位到 1")
            XCTAssertEqual(recent.first?.id, "msg-4")
        }
    }

    /// recentCount = Int.min 极端值不崩溃且钳位正常
    func testRecentCountIntMinClampsToOne() async {
        let history = makeHistory(count: 3)
        for engine in engines {
            let (_, recent) = await engine.processMemory(history: history, recentCount: Int.min)
            XCTAssertEqual(recent.count, 1, "\(engine.engineType): Int.min 应钳位到 1")
        }
    }

    // MARK: - recentCount 超过 history.count（确认既有行为不受影响）

    /// recentCount 大于 history 长度时返回全量 recent 且 summary 为 nil
    func testRecentCountExceedsHistoryReturnsAllNoSummary() async {
        let history = makeHistory(count: 3)
        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: history, recentCount: 100)
            XCTAssertEqual(recent.count, 3, "\(engine.engineType): recentCount 超标应返回全量")
            XCTAssertNil(summary, "\(engine.engineType): 无 older 消息时 summary 必须为 nil")
        }
    }

    // MARK: - 两个引擎对称性

    /// Native 和 Swarm 在相同参数（含边界 recentCount）下必须产生相同的 recent.count
    func testNativeAndSwarmParityOnBoundaryRecentCount() async {
        let history = makeHistory(count: 8)
        let boundaryValues = [-10, -1, 0, 1, 7, 8, 100]
        for rc in boundaryValues {
            var recentCounts: [Int] = []
            for engine in engines {
                let (_, recent) = await engine.processMemory(history: history, recentCount: rc)
                recentCounts.append(recent.count)
            }
            XCTAssertEqual(recentCounts[0], recentCounts[1], "recentCount=\(rc) 时 Native 和 Swarm 的 recent.count 必须一致")
        }
    }
}
