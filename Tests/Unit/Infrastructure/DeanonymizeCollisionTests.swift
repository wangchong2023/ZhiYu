//
//  DeanonymizeCollisionTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMContextBuilder.deanonymize 的字面量碰撞问题（问题 #13）。
//

import XCTest
@testable import ZhiYu

@MainActor
final class DeanonymizeCollisionTests: XCTestCase {

    private var builder: LLMContextBuilder!

    override func setUp() async throws {
        try await super.setUp()
        builder = LLMContextBuilder()
    }

    override func tearDown() async throws {
        builder = nil
        try await super.tearDown()
    }

    // MARK: - 字面量碰撞：LLM 生成与占位符格式相同的文本

    func testDeanonymizeLiteralCollisionLeaksSensitiveData() {
        // 场景：脱敏后 mapping 为 [ENTITY_A] -> "张三"
        // LLM 在回复中讨论占位符本身，生成了字面量 [ENTITY_A]
        // 注意：这个文本中没有真实脱敏占位符，只有 LLM 讨论占位符的字面量
        let mapping = ["[ENTITY_A]": "张三"]
        let llmResponse = "我注意到你使用了 [ENTITY_A] 来脱敏用户姓名。"

        let result = builder.deanonymize(llmResponse, mapping: mapping)

        // 问题：deanonymize 会把 LLM 讨论占位符的 [ENTITY_A] 也替换为"张三"
        // 导致敏感数据"张三"泄露到 LLM 讨论占位符的语境中
        // 验证问题存在：结果中"张三"出现了（不应该出现，因为这不是真实脱敏占位符）
        XCTAssertTrue(result.contains("张三"), "字面量碰撞：LLM 讨论占位符的 [ENTITY_A] 被误替换为敏感数据'张三'，泄露到非预期位置")
        XCTAssertFalse(result.contains("[ENTITY_A]"), "占位符被替换为敏感数据，证明 deanonymize 无法区分真实占位符和 LLM 生成的字面量")
    }

    func testDeanonymizeLiteralCollisionWithMultiplePlaceholders() {
        // 场景：多个占位符 + LLM 生成多个字面量
        let mapping = [
            "[ENTITY_A]": "张三",
            "[ENTITY_B]": "李四"
        ]
        let llmResponse = """
        脱敏说明：
        - [ENTITY_A] 代表用户姓名
        - [ENTITY_B] 代表同事姓名
        实际对话：[ENTITY_A] 和 [ENTITY_B] 讨论了项目。
        """

        let result = builder.deanonymize(llmResponse, mapping: mapping)

        // 前 3 行的 [ENTITY_A] 和 [ENTITY_B] 是 LLM 讨论占位符的字面量
        // 最后一行的 [ENTITY_A] 和 [ENTITY_B] 是真实脱敏占位符
        // deanonymize 无法区分，全部替换
        // 验证：结果中"张三"出现 2 次（1 次字面量碰撞 + 1 次真实还原）
        let zhangSanCount = result.components(separatedBy: "张三").count - 1
        XCTAssertGreaterThan(zhangSanCount, 1, "多个占位符字面量碰撞：LLM 讨论占位符的文本被误还原")
    }

    // MARK: - 真实脱敏场景验证

    func testRealAnonymizeDeanonymizeRoundTripNoCollision() {
        // 正常场景：LLM 回复中不包含占位符字面量
        let original = "张三在北京市工作。"
        let (anonymized, mapping) = builder.anonymize(original)

        // 模拟 LLM 回复（引用脱敏后的内容，不生成字面量）
        let llmResponse = "根据记录，\(anonymized) 这是相关信息。"

        let result = builder.deanonymize(llmResponse, mapping: mapping)

        // 正常场景：应正确还原
        XCTAssertTrue(result.contains("张三") || result.contains("北京市"), "正常脱敏还原应包含原始实体")
    }

    // MARK: - 问题影响范围验证

    func testDeanonymizeCollisionAffectsChatLLMServiceChatPath() {
        // 验证 ChatLLMService.chat 使用 deanonymize 还原响应
        // 如果 LLM 在响应中引用占位符字面量，敏感数据会泄露
        let mapping = ["[ENTITY_A]": "王五"]
        // 模拟 LLM 响应：包含真实占位符 + 字面量讨论
        let llmResponse = "[ENTITY_A] 是用户，我理解 [ENTITY_A] 这个占位符的含义。"

        let result = builder.deanonymize(llmResponse, mapping: mapping)

        // 验证：两个 [ENTITY_A] 都被替换为"王五"
        let wangWuCount = result.components(separatedBy: "王五").count - 1
        XCTAssertEqual(wangWuCount, 2, "两个 [ENTITY_A]（1 真实 + 1 字面量）都被替换为敏感数据'王五'")
    }

    // MARK: - 修复方向验证（当前实现的问题确认）

    func testCurrentDeanonymizeImplementationHasCollisionRisk() {
        // 确认当前实现使用 replacingOccurrences 全局替换，无法区分真实占位符和字面量
        let mapping = ["[ENTITY_A]": "赵六"]
        let text = "[ENTITY_A] 是真实占位符，而 [ENTITY_A] 是 LLM 生成的字面量"

        let result = builder.deanonymize(text, mapping: mapping)

        // 两个 [ENTITY_A] 都被替换——无法区分
        XCTAssertFalse(result.contains("[ENTITY_A]"), "当前实现无法区分真实占位符和 LLM 生成的字面量，全部被替换")
        let zhaoLiuCount = result.components(separatedBy: "赵六").count - 1
        XCTAssertEqual(zhaoLiuCount, 2, "两个 [ENTITY_A] 都被替换为'赵六'，证明字面量碰撞问题存在")
    }
}
