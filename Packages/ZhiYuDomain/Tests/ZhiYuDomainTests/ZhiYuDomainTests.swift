//
//  ZhiYuDomainTests.swift
//  ZhiYuDomainTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：智宇业务领域大脑包 (ZhiYuDomain) 单元测试套件。
//           校验 PromptConstants 越界约束与 MemoryEngineProtocol Mock 存根行为。
//

import XCTest
@testable import ZhiYuDomain
import ZhiYuDomainTestMocks

final class ZhiYuDomainTests: XCTestCase {

    /// 校验 PromptConstants 常量限额
    func testPromptConstantsLimitsEnforcement() {
        XCTAssertEqual(PromptConstants.TokenLimits.charactersPerToken, 4)
        XCTAssertEqual(PromptConstants.TokenLimits.maxUserInputLength, 4000)
        XCTAssertEqual(PromptConstants.TokenLimits.maxSynthesisInputLength, 8000)
        XCTAssertEqual(PromptConstants.TokenLimits.defaultMaxOutputTokens, 3072)
        XCTAssertGreaterThan(PromptConstants.SynthesisWordCount.standardMaxWords, PromptConstants.SynthesisWordCount.standardMinWords)
    }

    /// 校验 MockMemoryEngine 存根处理逻辑
    func testMockMemoryEngineProcessing() async {
        let mockEngine = MockMemoryEngine(engineType: .native)
        let messages = (0..<10).map { i in
            ChatMessageDomainDTO(id: "\(i)", role: i % 2 == 0 ? "user" : "assistant", content: "Message \(i)")
        }

        let (summary, recent) = await mockEngine.processMemory(history: messages, recentCount: 3)

        XCTAssertNotNil(summary, "记忆摘要不应为空")
        XCTAssertEqual(recent.count, 3, "最近消息队列保留条数必须严格等于 recentCount")
        XCTAssertEqual(recent.first?.id, "7", "保留的最近消息第一条标识必须一致")
    }
}
