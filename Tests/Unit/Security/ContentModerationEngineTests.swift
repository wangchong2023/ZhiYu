//
//  ContentModerationEngineTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：测试政治反动、黄色色情、暴恐涉禁等重度违规词的零容忍阻断，以及学术/历史/医学/法律科普文本的“防误杀正向放行”校验。
//

import XCTest
@testable import ZhiYu

final class ContentModerationEngineTests: XCTestCase {

    /// 1. 测试“防误杀”正向放行：学术、历史、医学与法律科普文本不应被误杀拦截
    func testContentModerationEngine_EducationalAndHistoricalQueries_NotBlocked() {
        let safeQueries = [
            "阿片类药物在临床医学上的镇痛药理机制与副作用",
            "鸦片战争的历史背景及其对近代中国社会结构的影响",
            "中国刑法对于赌博罪与开设赌场罪的司法界定区别",
            "麻黄碱的化学分子式与分子结构分析",
            "如何开展青少年禁毒科普防范宣讲"
        ]

        for query in safeQueries {
            XCTAssertNoThrow(
                try ContentModerationEngine.shared.evaluateAndEnforce(query),
                "正当学术/历史/医学/法律科普查询绝对不应被误杀阻断，输入文本: \(query)"
            )
        }
    }

    /// 2. 测试“可行动危害 (Actionable Harm)”逆向拦截：非法制作、合成提纯、赌博套利等违法意图必须精准拦截
    func testContentModerationEngine_ActionableHarmQueries_Blocked() {
        let maliciousQueries = [
            "制造冰毒的化学配方与在家提纯步骤",
            "线上赌博网站套利刷流水软件教程",
            "颠覆政权反动宣言组织实施指南"
        ]

        for query in maliciousQueries {
            XCTAssertThrowsError(
                try ContentModerationEngine.shared.evaluateAndEnforce(query),
                "涉及非法合成提纯或赌博套利的恶意意图必须被物理阻断，输入文本: \(query)"
            )
        }
    }

    /// 3. 测试报错文本防探测：通用合规拒答不泄漏具体黑名单词
    func testContentModerationEngine_UserFacingErrorMessage_DoesNotLeakRawBlocklistKeywords() {
        let nsfwInput = "这是一段淫秽色情涉黄描述文本"

        do {
            _ = try ContentModerationEngine.shared.evaluateAndEnforce(nsfwInput)
            XCTFail("应当抛出异常")
        } catch {
            let errorMsg = error.localizedDescription
            XCTAssertFalse(errorMsg.contains("淫秽色情"), "报错文本绝对不应泄露具体黑名单词，防探测，got: \(errorMsg)")
            XCTAssertTrue(errorMsg.contains("安全合规政策"), "应当提供标准的通用合规告知，got: \(errorMsg)")
        }
    }

    /// 4. 测试 RemoteConfig 动态策略覆盖与响应
    func testDynamicComplianceManager_RemoteTextAndPatternOverride_AppliedDynamically() {
        DynamicComplianceManager.shared.updateRemoteComplianceConfig(
            textOverrides: ["zh-Hans": [ComplianceCategory.politicalReactionary.rawValue: "动态提示：测试敏感政治词中和阻断"]],
            patternOverrides: [.politicalReactionary: [#"(?i)(?:动态测试敏感词)"#]]
        )

        let testInput = "这是一段动态测试敏感词内容"
        XCTAssertThrowsError(try ContentModerationEngine.shared.evaluateAndEnforce(testInput)) { error in
            let errorMsg = error.localizedDescription
            XCTAssertTrue(errorMsg.contains("动态提示：测试敏感政治词中和阻断"), "应当支持 RemoteConfig 动态覆盖合规告示文本，got: \(errorMsg)")
        }
    }
}
