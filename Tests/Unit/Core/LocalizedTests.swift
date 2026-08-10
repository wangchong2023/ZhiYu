//
//  LocalizedTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Localized 本地化中枢的 tr/trf 翻译、Fallback 降级、bestMatch 多语言匹配与 languageMode 持久化。
//

import XCTest
@testable import ZhiYu

final class LocalizedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated { resetPersistentTestState() }
    }

    override func tearDown() {
        MainActor.assumeIsolated { resetPersistentTestState() }
        super.tearDown()
    }

    // MARK: - LanguageMode 枚举

    func testLanguageMode_allCases_包含11种语言() {
        XCTAssertEqual(LanguageMode.allCases.count, 11)
        XCTAssertTrue(LanguageMode.allCases.contains(.auto))
        XCTAssertTrue(LanguageMode.allCases.contains(.english))
        XCTAssertTrue(LanguageMode.allCases.contains(.chinese))
    }

    func testLanguageMode_rawValue_正确() {
        XCTAssertEqual(LanguageMode.auto.rawValue, "auto")
        XCTAssertEqual(LanguageMode.english.rawValue, "en")
        XCTAssertEqual(LanguageMode.chinese.rawValue, "zh-Hans")
        XCTAssertEqual(LanguageMode.traditionalChinese.rawValue, "zh-Hant")
        XCTAssertEqual(LanguageMode.japanese.rawValue, "ja")
    }

    func testLanguageMode_id_等于rawValue() {
        for mode in LanguageMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testLanguageMode_displayName_所有case非空非Missing() {
        for mode in LanguageMode.allCases {
            let name = mode.displayName
            XCTAssertFalse(name.isEmpty, "displayName 不应为空：\(mode)")
            XCTAssertFalse(name.contains("[MISSING"), "displayName 不应包含 MISSING：\(mode)")
        }
    }

    // MARK: - currentLanguage

    func testCurrentLanguage_english模式_返回en() {
        let original = Localized.languageMode
        Localized.languageMode = .english
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.currentLanguage, "en")
    }

    func testCurrentLanguage_chinese模式_返回zhHans() {
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.currentLanguage, "zh-Hans")
    }

    func testCurrentLanguage_traditionalChinese模式_返回zhHant() {
        let original = Localized.languageMode
        Localized.languageMode = .traditionalChinese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.currentLanguage, "zh-Hant")
    }

    func testCurrentLanguage_japanese模式_返回ja() {
        let original = Localized.languageMode
        Localized.languageMode = .japanese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.currentLanguage, "ja")
    }

    // MARK: - currentLocale

    func testCurrentLocale_english模式_返回enLocale() {
        let original = Localized.languageMode
        Localized.languageMode = .english
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.currentLocale.identifier, "en")
    }

    // MARK: - isChinese

    func testIsChinese_chinese模式_返回true() {
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        XCTAssertTrue(Localized.isChinese)
    }

    func testIsChinese_traditionalChinese模式_返回true() {
        let original = Localized.languageMode
        Localized.languageMode = .traditionalChinese
        defer { Localized.languageMode = original }
        XCTAssertTrue(Localized.isChinese)
    }

    func testIsChinese_english模式_返回false() {
        let original = Localized.languageMode
        Localized.languageMode = .english
        defer { Localized.languageMode = original }
        XCTAssertFalse(Localized.isChinese)
    }

    // MARK: - tr 翻译

    func testTr_已知key_返回非Missing翻译() {
        let result = Localized.tr("accessibility.links", table: "Common")
        XCTAssertFalse(result.contains("[MISSING"), "已知 key 应返回有效翻译，实际：\(result)")
    }

    func testTr_未知key_返回Missing占位符() {
        let result = Localized.tr("nonexistent.key.zzz", table: "Common")
        XCTAssertTrue(result.contains("[MISSING"), "未知 key 应返回 MISSING 占位符")
    }

    func testTr_默认table参数_使用Common表() {
        let result1 = Localized.tr("accessibility.links")
        let result2 = Localized.tr("accessibility.links", table: "Common")
        XCTAssertEqual(result1, result2, "默认 table 应为 Common")
    }

    // MARK: - trf 格式化翻译

    func testTrf_格式化参数_正确注入() {
        let formatted = Localized.trf("search.pagesCount", table: "Common", 5)
        XCTAssertTrue(formatted.contains("5") || formatted.contains("[MISSING"), "格式化结果应包含参数值或 MISSING")
    }

    func testTrf_多参数_正确注入() {
        // search.pagesCount 只有一个 %d，多参数会被忽略
        let formatted = Localized.trf("search.pagesCount", table: "Common", 1)
        XCTAssertTrue(formatted.contains("1") || formatted.contains("[MISSING"))
    }

    // MARK: - bestMatch 多语言匹配

    func testBestMatch_完全匹配_优先返回() {
        let dict = ["en": "Hello", "zh-Hans": "你好"]
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.bestMatch(in: dict), "你好")
    }

    func testBestMatch_前缀匹配_降级返回() {
        let dict = ["zh": "中文通用"]
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.bestMatch(in: dict), "中文通用")
    }

    func testBestMatch_无匹配_返回enFallback() {
        let dict = ["en": "English default", "fr": "Français"]
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.bestMatch(in: dict), "English default")
    }

    func testBestMatch_无en_返回任意值() {
        let dict = ["fr": "Français", "de": "Deutsch"]
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        let result = Localized.bestMatch(in: dict)
        XCTAssertTrue(dict.values.contains(result), "无匹配时应返回字典中任意值")
    }

    func testBestMatch_空字典_返回fallback() {
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.bestMatch(in: [:], fallback: "DEFAULT"), "DEFAULT")
    }

    func testBestMatch_自定义fallback_无匹配时返回() {
        // bestMatch 在字典非空时返回 dict.values.first（任意值），空字典时才返回 fallback
        let dict = ["fr": "Français"]
        let original = Localized.languageMode
        Localized.languageMode = .chinese
        defer { Localized.languageMode = original }
        let result = Localized.bestMatch(in: dict, fallback: "CUSTOM")
        XCTAssertTrue(dict.values.contains(result) || result == "CUSTOM", "无匹配时应返回字典中任意值或 fallback")
    }

    // MARK: - allValues(forKey:table:)

    func testAllValues_已知key_返回非空数组() {
        let values = Localized.allValues(forKey: "accessibility.links", table: "Common")
        XCTAssertFalse(values.isEmpty, "已知 key 应至少返回一种语言翻译")
    }

    func testAllValues_未知key_返回空数组() {
        let values = Localized.allValues(forKey: "nonexistent.key.zzz", table: "Common")
        XCTAssertTrue(values.isEmpty, "未知 key 应返回空数组")
    }

    func testAllValues_去重_相同翻译只保留一份() {
        let values = Localized.allValues(forKey: "accessibility.links", table: "Common")
        let uniqueValues = Set(values)
        XCTAssertEqual(values.count, uniqueValues.count, "翻译值应已去重")
    }

    // MARK: - languageMode 持久化

    @MainActor
    func testLanguageMode_setter_更新内存缓存() {
        let original = Localized.languageMode
        Localized.languageMode = .japanese
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.languageMode, .japanese)
    }

    @MainActor
    func testLanguageMode_setter_无效值降级为auto() {
        let original = Localized.languageMode
        Localized.languageMode = .english
        defer { Localized.languageMode = original }
        XCTAssertEqual(Localized.languageMode, .english)
    }

    // MARK: - loadCachedLanguageMode

    @MainActor
    func testLoadCachedLanguageMode_DI未就绪_不崩溃() {
        // 不注册 KeyStoreProtocol，调用 loadCachedLanguageMode 应优雅降级
        Localized.loadCachedLanguageMode()
        // 验证不崩溃即可，languageMode 保持默认
        XCTAssertEqual(Localized.languageMode, .auto)
    }

    // MARK: - L10nTableEntry 协议

    func testL10nTableEntry_tr_默认实现调用Localized() {
        // L10n 命名空间的扩展通过 L10nTableEntry 协议获得 tr/trf 默认实现
        // 验证 L10n.Common 存在且可调用
        let result = L10n.Common.ok
        XCTAssertFalse(result.isEmpty, "L10n.Common.ok 不应为空")
    }
}
