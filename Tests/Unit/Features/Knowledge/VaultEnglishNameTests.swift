//
//  VaultEnglishNameTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Vault.englishName 的内置笔记本映射、拼音转译、字符清洗、空名称兜底等边界语义。
//

import XCTest
@testable import ZhiYu

final class VaultEnglishNameTests: XCTestCase {

    // MARK: - 内置演示笔记本映射

    func testEnglishName_personalKM_returnsPersonalKM() {
        let vault = Vault(name: "Personal_KM")
        XCTAssertEqual(vault.englishName, "Personal_KM")
    }

    func testEnglishName_defaultNameLocalized_returnsPersonalKM() {
        let vault = Vault(name: L10n.Vault.defaultName)
        XCTAssertEqual(vault.englishName, "Personal_KM")
    }

    func testEnglishName_projectResearch_returnsProjectResearch() {
        let vault = Vault(name: "Project_Research")
        XCTAssertEqual(vault.englishName, "Project_Research")
    }

    func testEnglishName_researchNameLocalized_returnsProjectResearch() {
        let vault = Vault(name: L10n.Vault.researchName)
        XCTAssertEqual(vault.englishName, "Project_Research")
    }

    // MARK: - 拼音转译

    func testEnglishName_chineseName_convertsToPinyin() {
        let vault = Vault(name: "学习笔记")
        let english = vault.englishName
        XCTAssertFalse(english.isEmpty, "中文名称应转译为非空英文名")
        // 拼音转译后应只含 ASCII 字母/数字/下划线
        XCTAssertTrue(english.allSatisfy { $0.isASCII }, "转译后应只含 ASCII 字符")
    }

    // MARK: - 字符清洗

    func testEnglishName_specialCharacters_replacedWithUnderscore() {
        let vault = Vault(name: "My@Note#Book")
        let english = vault.englishName
        XCTAssertFalse(english.contains("@"), "应移除 @ 字符")
        XCTAssertFalse(english.contains("#"), "应移除 # 字符")
    }

    func testEnglishName_spacesAndHyphens_replacedWithUnderscore() {
        let vault = Vault(name: "My Note-Book")
        let english = vault.englishName
        XCTAssertFalse(english.contains(" "), "空格应替换为下划线")
        XCTAssertFalse(english.contains("-"), "连字符应替换为下划线")
    }

    func testEnglishName_multipleUnderscores_collapsed() {
        let vault = Vault(name: "A  B")
        let english = vault.englishName
        XCTAssertFalse(english.contains("__"), "连续下划线应合并为单个")
    }

    // MARK: - 空名称兜底

    func testEnglishName_emptyName_returnsVaultWithIdPrefix() {
        let id = UUID()
        let vault = Vault(id: id, name: "")
        let english = vault.englishName
        XCTAssertTrue(english.hasPrefix("Vault_"), "空名称应返回 Vault_<id前缀>")
    }

    func testEnglishName_onlySpecialChars_returnsVaultWithIdPrefix() {
        let id = UUID()
        let vault = Vault(id: id, name: "@#$%")
        let english = vault.englishName
        XCTAssertTrue(english.hasPrefix("Vault_"), "纯特殊字符名称应返回 Vault_<id前缀>")
    }

    // MARK: - 纯英文名称

    func testEnglishName_pureEnglish_keepsAsIs() {
        let vault = Vault(name: "MyNotes")
        XCTAssertEqual(vault.englishName, "MyNotes")
    }

    func testEnglishName_mixedCaseEnglish_keepsAsIs() {
        let vault = Vault(name: "My_Note_Book")
        XCTAssertEqual(vault.englishName, "My_Note_Book")
    }

    // MARK: - 确定性

    func testEnglishName_sameNameSameId_producesSameResult() {
        let id = UUID()
        let vault1 = Vault(id: id, name: "学习笔记")
        let vault2 = Vault(id: id, name: "学习笔记")
        XCTAssertEqual(vault1.englishName, vault2.englishName)
    }

    // MARK: - 前后空格

    func testEnglishName_leadingTrailingSpaces_trimmed() {
        let vault = Vault(name: "  MyNotes  ")
        let english = vault.englishName
        XCTAssertFalse(english.hasPrefix("_"), "前导空格应被 trim")
        XCTAssertFalse(english.hasSuffix("_"), "尾部空格应被 trim")
    }
}
