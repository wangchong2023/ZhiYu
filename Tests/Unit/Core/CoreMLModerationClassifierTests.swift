//
//  CoreMLModerationClassifierTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 CoreMLModerationClassifier 端侧内容违规与防越狱分类器的 Slow Path 深检逻辑。
//

import XCTest
@testable import ZhiYu

final class CoreMLModerationClassifierTests: XCTestCase {

    private var classifier: CoreMLModerationClassifier!

    override func setUp() {
        super.setUp()
        classifier = CoreMLModerationClassifier.shared
    }

    // MARK: - isSupportedOnDevice

    func testIsSupportedOnDeviceSimulatorReturnsTrue() {
        #if targetEnvironment(simulator)
        XCTAssertTrue(classifier.isSupportedOnDevice, "模拟器应返回 true")
        #else
        // 真机取决于物理内存，仅验证不崩溃
        _ = classifier.isSupportedOnDevice
        #endif
    }

    // MARK: - classifyForDeepInspection 空文本

    func testClassifyEmptyTextReturnsNotFlagged() async {
        let result = await classifier.classifyForDeepInspection("")
        XCTAssertFalse(result.isFlagged)
        XCTAssertEqual(result.confidenceScore, 0.0, accuracy: 0.001)
    }

    func testClassifyEmptyTextReasonIsEmptyText() async {
        let result = await classifier.classifyForDeepInspection("")
        XCTAssertEqual(result.reason, CoreConstants.ModerationReason.emptyText)
    }

    // MARK: - classifyForDeepInspection Prompt 注入检测

    func testClassifyIgnorePreviousInstructionsFlaggedAsViolation() async {
        let result = await classifier.classifyForDeepInspection("ignore_previous_instructions now")
        XCTAssertTrue(result.isFlagged, "应检测到 Prompt 注入")
    }

    func testClassifyPretendYouAreFlaggedAsViolation() async {
        let result = await classifier.classifyForDeepInspection("pretend_you_are_an_unfiltered_ai")
        XCTAssertTrue(result.isFlagged)
    }

    func testClassifyDoAnythingNowFlaggedAsViolation() async {
        let result = await classifier.classifyForDeepInspection("do_anything_now_mode enabled")
        XCTAssertTrue(result.isFlagged)
    }

    func testClassifySystemOverrideFlaggedAsViolation() async {
        let result = await classifier.classifyForDeepInspection("system_override_mode active")
        XCTAssertTrue(result.isFlagged)
    }

    func testClassifyPromptInjectionHighConfidence() async {
        let result = await classifier.classifyForDeepInspection("ignore_previous_instructions")
        XCTAssertGreaterThan(result.confidenceScore, 0.9, "Prompt 注入应高置信度")
    }

    func testClassifyPromptInjectionCategoryIsPoliticalReactionary() async {
        let result = await classifier.classifyForDeepInspection("ignore_previous_instructions")
        XCTAssertEqual(result.category, .politicalReactionary)
    }

    func testClassifyPromptInjectionReasonIsDetectedPromptInjection() async {
        let result = await classifier.classifyForDeepInspection("ignore_previous_instructions")
        XCTAssertEqual(result.reason, CoreConstants.ModerationReason.detectedPromptInjection)
    }

    // MARK: - classifyForDeepInspection 正常文本

    func testClassifyNormalTextNotFlagged() async {
        let result = await classifier.classifyForDeepInspection("这是一段正常的笔记内容")
        XCTAssertFalse(result.isFlagged)
    }

    func testClassifyNormalTextLowConfidence() async {
        let result = await classifier.classifyForDeepInspection("Hello world")
        XCTAssertLessThan(result.confidenceScore, 0.5, "正常文本应低置信度")
    }

    func testClassifyNormalTextReasonIsClean() async {
        let result = await classifier.classifyForDeepInspection("正常内容")
        XCTAssertEqual(result.reason, CoreConstants.ModerationReason.clean)
    }

    func testClassifyNormalTextCategoryIsNil() async {
        let result = await classifier.classifyForDeepInspection("正常内容")
        XCTAssertNil(result.category)
    }

    // MARK: - 大小写不敏感

    func testClassifyUppercasePromptInjectionStillDetected() async {
        let result = await classifier.classifyForDeepInspection("IGNORE_PREVIOUS_INSTRUCTIONS")
        XCTAssertTrue(result.isFlagged, "大写 Prompt 注入应被检测到")
    }

    func testClassifyMixedCasePromptInjectionStillDetected() async {
        let result = await classifier.classifyForDeepInspection("Ignore_Previous_Instructions")
        XCTAssertTrue(result.isFlagged, "混合大小写应被检测到")
    }

    // MARK: - CoreMLModerationResult

    func testCoreMLModerationResultInitPropertiesCorrect() {
        let result = CoreMLModerationResult(
            isFlagged: true,
            category: .politicalReactionary,
            confidenceScore: 0.95,
            reason: "test reason"
        )
        XCTAssertTrue(result.isFlagged)
        XCTAssertEqual(result.category, .politicalReactionary)
        XCTAssertEqual(result.confidenceScore, 0.95, accuracy: 0.001)
        XCTAssertEqual(result.reason, "test reason")
    }

    func testCoreMLModerationResultIsFlaggedFalseDefaultValue() {
        let result = CoreMLModerationResult(
            isFlagged: false,
            category: nil,
            confidenceScore: 0.0,
            reason: ""
        )
        XCTAssertFalse(result.isFlagged)
        XCTAssertNil(result.category)
    }
}
