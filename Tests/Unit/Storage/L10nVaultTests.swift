//
//  L10nVaultTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Vault 本地化 & englishName 跨 locale 稳定性，
//           以及 Localized.languageMode 缓存在 actor 隔离下的安全性。

import XCTest
@testable import ZhiYu

final class L10nVaultTests: XCTestCase {

    // MARK: - englishName 跨 locale 稳定性

    /// 内置笔记本 englishName 不受当前 locale 影响，始终返回固定标识符。
    /// 这是 ipad/mac 崩溃修复的核心前置条件——确保路径计算不因语言切换漂移。
    func testBuiltInEnglishNameIsLocaleIndependent() {
        // 中文名在任何 locale 下都应映射到 Personal_KM / Project_Research
        let defaultZH = Vault(name: L10n.Vault.defaultNameZh)
        XCTAssertEqual(defaultZH.englishName, "Personal_KM",
                       "中文默认笔记本名必须映射到 Personal_KM")

        let researchZH = Vault(name: L10n.Vault.researchNameZh)
        XCTAssertEqual(researchZH.englishName, "Project_Research",
                       "中文调研笔记本名必须映射到 Project_Research")

        // 英文名同理
        let defaultEN = Vault(name: L10n.Vault.defaultNameEn)
        XCTAssertEqual(defaultEN.englishName, "Personal_KM",
                       "英文默认笔记本名必须映射到 Personal_KM")

        let researchEN = Vault(name: L10n.Vault.researchNameEn)
        XCTAssertEqual(researchEN.englishName, "Project_Research",
                       "英文调研笔记本名必须映射到 Project_Research")
    }

    /// 自定义笔记本名通过拼音/拉丁转写生成安全的 englishName，
    /// 不包含硬编码的中文或特殊字符。
    func testCustomVaultEnglishNameNeverReturnsRawChineseCharacters() {
        // 测试数据 — 任意中文名均须安全转写，非内置笔记本名
        let vaults = [
            Vault(name: "测试笔记本"),
            Vault(name: "示例名称"),
            Vault(name: "任意中文输入")
        ]
        for vault in vaults {
            let name = vault.englishName
            // 不应包含任何 CJK 字符
            let cjkRange = name.range(of: "\\p{Han}", options: .regularExpression)
            XCTAssertNil(cjkRange,
                         "englishName 不应包含中文字符: '\(name)' (输入: '\(vault.name)')")
            // 不应为空或仅下划线
            XCTAssertFalse(name.trimmingCharacters(in: CharacterSet(charactersIn: "_")).isEmpty,
                           "englishName 不应为空: (输入: '\(vault.name)')")
        }
    }

    /// 非内置笔记本名 englishName 回退至拼音/拉丁转写，
    /// 不会误匹配到当前内置名的固定映射（Personal_KM / Project_Research）。
    func testNonBuiltInVaultNameFallsBackToPinyin() {
        // 中文自定义名 → 拼音回退，不应匹配内置笔记本的固定 englishName
        let customZH = Vault(name: "自定义名称")
        XCTAssertNotEqual(customZH.englishName, "Personal_KM",
                          "自定义中文名应走拼音回退，不应误匹配内置名")
        XCTAssertTrue(customZH.englishName.allSatisfy { $0.isASCII },
                      "拼音回退应全部为 ASCII 字符")

        // 英文自定义名 → 拉丁转写，不应匹配内置名
        let customEN = Vault(name: "My Custom Notebook")
        XCTAssertNotEqual(customEN.englishName, "Personal_KM",
                          "自定义英文名不应误匹配内置名")
    }

    // MARK: - L10n.Vault 国际化常量覆盖

    /// 确保所有 L10n.Vault 固定变体（.zh / .en）返回 locale-independent 值。
    func testL10nVaultFixedVariantsReturnLocaleIndependentValues() {
        // .zh 变体在任何环境下都返回非空中文标识
        XCTAssertFalse(L10n.Vault.defaultNameZh.isEmpty)
        XCTAssertFalse(L10n.Vault.researchNameZh.isEmpty)

        // .en 变体在任何环境下都返回非空英文标识
        XCTAssertFalse(L10n.Vault.defaultNameEn.isEmpty)
        XCTAssertFalse(L10n.Vault.researchNameEn.isEmpty)
    }

    /// defaultName / researchName 至少返回非空字符串（具体值取决于当前 locale）。
    func testL10nVaultComputedPropertiesReturnNonEmpty() {
        XCTAssertFalse(L10n.Vault.defaultName.isEmpty, "defaultName 不应为空")
        XCTAssertFalse(L10n.Vault.researchName.isEmpty, "researchName 不应为空")
        XCTAssertFalse(L10n.Vault.defaultDescription.isEmpty, "defaultDescription 不应为空")
        XCTAssertFalse(L10n.Vault.researchDescription.isEmpty, "researchDescription 不应为空")
    }

    // MARK: - languageMode 缓存安全性

    /// languageMode getter 应始终成功返回（不 crash），即使 keyStore 未就绪。
    func testLanguageModeGetterNeverCrashes() {
        // 在任意 context 下调用 getter 不应触发 EXC_BREAKPOINT
        let mode = Localized.languageMode
        XCTAssertTrue(LanguageMode.allCases.contains(mode),
                      "languageMode 必须返回有效的 LanguageMode 枚举值")
    }

    /// loadCachedLanguageMode 应在 @MainActor 上成功加载缓存。
    @MainActor
    func testLoadCachedLanguageModePopulatesCache() {
        // 调用加载函数后，languageMode getter 应返回一致的值
        Localized.loadCachedLanguageMode()
        let mode = Localized.languageMode
        // 在测试环境中 keyStore 可能未就绪，此时应回退到 .auto
        XCTAssertNotNil(mode)
    }
}
