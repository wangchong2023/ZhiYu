//
//  PromptServiceSupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 测试层
//  核心职责：补盲 Infrastructure/LLM PromptService 的未覆盖分支与边界条件
//           （ShortcutItem 编解码、languageInstruction、updateLocalizables、
//           load 解码失败、save 持久化、reset、reload）。
//

import XCTest
import UFPCore
import Dependencies
import Combine
@testable import ZhiYu

// MARK: - PromptService 补盲测试

@MainActor
final class PromptServiceSupplementTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var service: PromptService!

    override func setUp() async throws {
        try await super.setUp()
        testDefaults = UserDefaults(suiteName: "PromptServiceSupplementTestSuite")
        XCTAssertNotNil(testDefaults, "UserDefaults suite 应创建成功")
        testDefaults.removePersistentDomain(forName: "PromptServiceSupplementTestSuite")
        service = PromptService(defaults: testDefaults)
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: "PromptServiceSupplementTestSuite")
        testDefaults = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - ShortcutItem

    func testShortcutItemTextGetterWithLocalizationKey() {
        let item = ShortcutItem(text: "原始文本", localizationKey: "prompt.shortcut.deepReview")
        let resolved = item.text
        XCTAssertFalse(resolved.isEmpty, "有 localizationKey 时应通过 L10n 解析返回非空文本")
    }

    func testShortcutItemTextGetterWithoutLocalizationKey() {
        let item = ShortcutItem(text: "纯文本快捷方式", localizationKey: nil)
        XCTAssertEqual(item.text, "纯文本快捷方式", "无 localizationKey 时应返回 rawText")
    }

    func testShortcutItemTextSetterClearsLocalizationKey() {
        var item = ShortcutItem(text: "原始", localizationKey: "prompt.shortcut.deepReview")
        item.text = "用户自定义文本"
        XCTAssertNil(item.localizationKey, "setter 后 localizationKey 应被清空为 nil")
        XCTAssertEqual(item.rawText, "用户自定义文本", "setter 后 rawText 应更新为新值")
        XCTAssertEqual(item.text, "用户自定义文本", "setter 后 text getter 应返回 rawText")
    }

    func testShortcutItemCodableRoundTrip() throws {
        let original = ShortcutItem(text: "测试", localizationKey: "some.key")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutItem.self, from: encoded)
        XCTAssertEqual(decoded.rawText, original.rawText)
        XCTAssertEqual(decoded.localizationKey, original.localizationKey)
    }

    // MARK: - languageInstruction

    func testLanguageInstructionContainsLocaleCode() {
        let instruction = service.languageInstruction
        XCTAssertTrue(instruction.contains("Please reply"), "languageInstruction 应包含英文指令前缀")
        XCTAssertTrue(instruction.count > 10, "languageInstruction 应非空且包含语言代码")
    }

    // MARK: - updateLocalizables

    func testUpdateLocalizablesPopulatesDefaultShortcutsWhenEmpty() {
        service.userShortcuts = []
        service.updateLocalizables()
        XCTAssertEqual(service.userShortcuts.count, 3, "空 shortcuts 时应填充 3 个默认快捷方式")
    }

    func testUpdateLocalizablesPreservesExistingShortcuts() {
        let custom: [ShortcutItem] = [
            ShortcutItem(text: "自定义1", localizationKey: nil),
            ShortcutItem(text: "自定义2", localizationKey: nil)
        ]
        service.userShortcuts = custom
        service.updateLocalizables()
        XCTAssertEqual(service.userShortcuts.count, 2, "已有 shortcuts 时不应覆盖")
        XCTAssertEqual(service.userShortcuts[0].rawText, "自定义1")
    }

    func testUpdateLocalizablesRestoresDefaultPromptsWhenNotSaved() {
        service.mindmapPrompt = "临时修改"
        testDefaults.removeObject(forKey: "prompt_mindmap")
        service.updateLocalizables()
        XCTAssertEqual(service.mindmapPrompt, L10n.AI.Prompt.Default.mindmap, "未保存的 prompt 应恢复为默认值")
    }

    func testUpdateLocalizablesKeepsSavedPrompts() {
        service.mindmapPrompt = "用户自定义"
        testDefaults.set("用户自定义", forKey: "prompt_mindmap")
        service.updateLocalizables()
        XCTAssertEqual(service.mindmapPrompt, "用户自定义", "已保存的 prompt 应保留")
    }

    // MARK: - load 解码失败

    func testLoadHandlesCorruptedShortcutData() {
        testDefaults.set(Data("invalid json".utf8), forKey: "prompt_user_shortcuts")
        let newService = PromptService(defaults: testDefaults)
        XCTAssertEqual(newService.userShortcuts.count, 3, "解码失败后 updateLocalizables 应填充默认 shortcuts")
    }

    // MARK: - save 持久化

    func testSavePersistsShortcutsToUserDefaults() {
        let custom: [ShortcutItem] = [
            ShortcutItem(text: "保存测试", localizationKey: nil)
        ]
        service.userShortcuts = custom
        service.save()
        let savedData = testDefaults.data(forKey: "prompt_user_shortcuts")
        XCTAssertNotNil(savedData, "save 后 prompt_user_shortcuts 应有数据")
    }

    func testSavePersistsAllPromptFields() {
        service.mindmapPrompt = "自定义mindmap"
        service.quizPrompt = "自定义quiz"
        service.slidesPrompt = "自定义slides"
        service.reportPrompt = "自定义report"
        service.expansionPrompt = "自定义expansion"
        service.save()

        let newService = PromptService(defaults: testDefaults)
        XCTAssertEqual(newService.mindmapPrompt, "自定义mindmap")
        XCTAssertEqual(newService.quizPrompt, "自定义quiz")
        XCTAssertEqual(newService.slidesPrompt, "自定义slides")
        XCTAssertEqual(newService.reportPrompt, "自定义report")
        XCTAssertEqual(newService.expansionPrompt, "自定义expansion")
    }

    // MARK: - reset

    func testResetClearsAllSavedPrompts() {
        service.mindmapPrompt = "修改1"
        service.quizPrompt = "修改2"
        service.slidesPrompt = "修改3"
        service.reportPrompt = "修改4"
        service.expansionPrompt = "修改5"
        service.save()

        service.reset()

        XCTAssertEqual(service.mindmapPrompt, L10n.AI.Prompt.Default.mindmap)
        XCTAssertEqual(service.quizPrompt, L10n.AI.Prompt.Default.quiz)
        XCTAssertEqual(service.slidesPrompt, L10n.AI.Prompt.Default.slides)
        XCTAssertEqual(service.reportPrompt, L10n.AI.Prompt.Default.report)
        XCTAssertEqual(service.expansionPrompt, L10n.AI.Prompt.Default.expansion)
        XCTAssertEqual(service.userShortcuts.count, 3, "reset 后应恢复 3 个默认 shortcuts")
        XCTAssertNil(testDefaults.string(forKey: "prompt_mindmap"), "reset 后 UserDefaults 应清除")
    }

    // MARK: - reload

    func testReloadLoadsSavedDataAndUpdatesLocalizables() {
        testDefaults.set("重新加载的prompt", forKey: "prompt_mindmap")
        service.reload()
        XCTAssertEqual(service.mindmapPrompt, "重新加载的prompt", "reload 应从 UserDefaults 加载已保存值")
    }
}
