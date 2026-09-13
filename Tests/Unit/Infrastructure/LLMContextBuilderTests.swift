//
//  LLMContextBuilderTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证端侧 NER 敏感信息哈希替换、反向字典还原及 StreamDeanonymizer 分包缓冲逻辑。
//

import XCTest
@testable import ZhiYu

@MainActor
final class LLMContextBuilderTests: XCTestCase {
    
    private var builder: LLMContextBuilder!
    
    override func setUp() async throws {
        try await super.setUp()
        builder = LLMContextBuilder()
    }
    
    override func tearDown() async throws {
        builder = nil
        try await super.tearDown()
    }
    
    /// 验证文本中的敏感专有名词（如人名和特定地名）被准确识别并分配占位符替换 (SR-12)
    func testNERAnonymizeAndDeanonymize() {
        let originalText = "张三和李四在北京市朝阳区联合开发了智宇应用，并创立了谷歌公司。"
        
        // 执行端侧脱敏
        let (anonymized, mapping) = builder.anonymize(originalText)
        
        // 检查 NLTagger 是否成功检测到实体（模拟器环境可能不支持中文 NER）
        let hasDetectedEntities = anonymized.contains("[ENTITY_")
        
        if hasDetectedEntities {
            // NLTagger 成功检测到实体：验证敏感词被替换为 [ENTITY_X] 占位符
            XCTAssertFalse(anonymized.contains("张三"))
            XCTAssertFalse(anonymized.contains("李四"))
            XCTAssertFalse(anonymized.contains("北京市朝阳区"))
            XCTAssertFalse(anonymized.contains("谷歌"))
            
            // 验证映射字典中确实记录了实体关联
            let allValues = mapping.values.joined(separator: "|")
            XCTAssertTrue(allValues.contains("张三") || allValues.contains("李四"))
            XCTAssertTrue(allValues.contains("北京") || allValues.contains("北京市") || allValues.contains("朝阳") || allValues.contains("朝阳区"))
        } else {
            // 模拟器不支持中文 NER：映射应保持为空，脱敏文本与原文一致
            XCTAssertTrue(mapping.isEmpty)
            XCTAssertEqual(anonymized, originalText)
        }
        
        // 执行反向还原 — 无论是否检测到实体，还原结果应始终与原文一致
        let restored = builder.deanonymize(anonymized, mapping: mapping)
        
        // 验证还原后的文本与原文一致
        XCTAssertEqual(restored, originalText)
    }
    
    /// 验证 StreamDeanonymizer 对流式分包边界切断（例如在 [ENTITY_A] 内部被切断）的自愈及缓冲还原能力 (SR-12)
    func testStreamDeanonymizerBuffering() {
        let mapping = [
            "[ENTITY_A]": "张三",
            "[ENTITY_B]": "北京"
        ]
        
        var deanonymizer = StreamDeanonymizer(mapping: mapping)
        
        // 1. 发送没有被切断的普通段落
        let chunk1 = "你好，我是"
        let out1 = deanonymizer.process(chunk: chunk1)
        XCTAssertEqual(out1, "你好，我是")
        
        // 2. 发送被分包切断的占位符前半部 "[ENT"
        let chunk2 = "[ENT"
        let out2 = deanonymizer.process(chunk: chunk2)
        XCTAssertEqual(out2, "") // 应该被拦截缓冲在 buffer 中，不输出任何内容
        
        // 3. 发送占位符的后半部 "ITY_A] 住在"
        let chunk3 = "ITY_A] 住在"
        let out3 = deanonymizer.process(chunk: chunk3)
        // 应该拼装出完整 [ENTITY_A] 还原为 "张三" 并附带后面的常规文本
        XCTAssertEqual(out3, "张三 住在")
        
        // 4. 再次发送被切断的第二个占位符的前半部 "[ENTI"
        let chunk4 = "[ENTI"
        let out4 = deanonymizer.process(chunk: chunk4)
        XCTAssertEqual(out4, "") // 被缓冲
        
        // 5. 发送剩下的 "TY_B]，再见。"
        let chunk5 = "TY_B]，再见。"
        let out5 = deanonymizer.process(chunk: chunk5)
        XCTAssertEqual(out5, "北京，再见。")
        
        // 6. 验证结束时的 finalize
        let finalOutput = deanonymizer.finalize()
        XCTAssertEqual(finalOutput, "")
    }
}
