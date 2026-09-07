//
//  LocalizationTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 Localization 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

final class LocalizationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated { resetPersistentTestState() }
    }

    override func tearDown() {
        MainActor.assumeIsolated { resetPersistentTestState() }
        super.tearDown()
    }

    /// 验证核心模块的 Key 是否能正确解析（而非原样返回 Key）
    func testLocalizationKeysExistence() {
        // 1. Common 模块
        print("--- DIAGNOSTICS ---")
        print("Bundle.main.bundlePath: \(Bundle.main.bundlePath)")
        let testBundle = Bundle(for: Self.self)
        print("Test Bundle Path: \(testBundle.bundlePath)")
        if let paths = Bundle.main.urls(forResourcesWithExtension: "lproj", subdirectory: nil) {
            print("Bundle.main lproj urls: \(paths.map { $0.lastPathComponent })")
        }
        if let paths = testBundle.urls(forResourcesWithExtension: "lproj", subdirectory: nil) {
            print("Test Bundle lproj urls: \(paths.map { $0.lastPathComponent })")
        }
        print("Current Language Mode: \(Localized.languageMode.rawValue)")
        print("Current Language: \(Localized.currentLanguage)")
        let lang = Localized.currentLanguage
        let pathInMain = Bundle.main.path(forResource: lang, ofType: "lproj")
        print("Path of \(lang).lproj in main: \(pathInMain ?? "nil")")
        let pathInTest = testBundle.path(forResource: lang, ofType: "lproj")
        print("Path of \(lang).lproj in test: \(pathInTest ?? "nil")")
        
        let okVal = Localized.tr("misc.ok", table: "Localizable")
        print("misc.ok in Localizable table: \(okVal)")
        
        print("--- END DIAGNOSTICS ---")
        
        XCTAssertNotEqual(L10n.Common.ok, "misc.ok", "Common.ok 应该被正确翻译")
        XCTAssertNotEqual(L10n.Common.cancel, "misc.cancel", "Common.cancel 应该被正确翻译")
        
        // 2. Settings 模块
        XCTAssertNotEqual(L10n.Settings.title, "settings.settings", "Settings.title 应该被正确翻译")
        
        // 3. Chat 模块
        XCTAssertNotEqual(L10n.Chat.title, "chat.title", "Chat.title 应该被正确翻译")
        
        // 4. Ingest 模块
        XCTAssertNotEqual(L10n.Ingest.title, "ingest.title", "Ingest.title 应该被正确翻译")
        
        // 5. Backup 模块
        XCTAssertNotEqual(L10n.Backup.title, "backup.title", "Backup.title 应该被正确翻译")
    }
    
    /// 验证不同语言环境下的切换逻辑（模拟环境）
    func testLanguageSwitchingLogic() {
        let currentMode = Localized.languageMode
        
        // 测试切换到英文
        Localized.languageMode = .english
        XCTAssertEqual(Localized.currentLanguage, "en")
        
        // 测试切换到中文
        Localized.languageMode = .chinese
        XCTAssertEqual(Localized.currentLanguage, "zh-Hans")
        
        // 测试切换到繁体中文
        Localized.languageMode = .traditionalChinese
        XCTAssertEqual(Localized.currentLanguage, "zh-Hant")
        
        // 测试切换到新增 7 种语言
        Localized.languageMode = .spanish
        XCTAssertEqual(Localized.currentLanguage, "es")
        
        Localized.languageMode = .french
        XCTAssertEqual(Localized.currentLanguage, "fr")
        
        Localized.languageMode = .arabic
        XCTAssertEqual(Localized.currentLanguage, "ar")
        
        Localized.languageMode = .russian
        XCTAssertEqual(Localized.currentLanguage, "ru")
        
        Localized.languageMode = .korean
        XCTAssertEqual(Localized.currentLanguage, "ko")
        
        Localized.languageMode = .japanese
        XCTAssertEqual(Localized.currentLanguage, "ja")
        
        Localized.languageMode = .portuguese
        XCTAssertEqual(Localized.currentLanguage, "pt")
        
        // 还原现场
        Localized.languageMode = currentMode
    }
    
    /// 验证从字典中根据当前 Locale 最佳匹配或降级回滚规则 (bestMatch)
    func testBestMatchLanguageFallback() {
        // 1. 测试当字典为空时，返回指定的 fallback 值
        let emptyDict: [String: String] = [:]
        XCTAssertEqual(Localized.bestMatch(in: emptyDict, fallback: "FallbackValue"), "FallbackValue")
        
        // 2. 测试当字典只包含英文 "en" 且当前设备 Locale 不匹配任何其他 Key 时 (通过模拟非主语言的冷门 key 传入)
        let coldDict = ["de": "German", "en": "English"]
        let bestForCold = Localized.bestMatch(in: coldDict, fallback: "FallbackValue")
        
        if Locale.current.identifier.hasPrefix("de") {
            XCTAssertEqual(bestForCold, "German")
        } else {
            // 当前非德语系统时，由于字典中含 "en"，应完美回退到英文
            XCTAssertEqual(bestForCold, "English")
        }
        
        // 3. 测试完全没有匹配且字典不含 "en" 时，返回字典首个值 (dict.values.first)
        let noEnDict = ["fr": "French", "es": "Spanish"]
        let matched = Localized.bestMatch(in: noEnDict, fallback: "FallbackValue")
        if Locale.current.identifier.hasPrefix("fr") {
            XCTAssertEqual(matched, "French")
        } else if Locale.current.identifier.hasPrefix("es") {
            XCTAssertEqual(matched, "Spanish")
        } else {
            // 其他语言则为 fr 或 es 之一 (基于 Dictionary 无序特性)
            XCTAssertTrue(matched == "French" || matched == "Spanish")
        }
    }
    
    /// 验证格式化字符串是否正常工作
    func testParameterizedLocalization() {
        // 验证 trf 接口不会崩溃且能正常注入参数
        // "aitask.status.runningFormat" 定义在 Localizable 和 AITasks xcstrings 中，接收两个参数
        let formatted = L10n.AI.Task.trf("status.runningFormat", "测试A", "测试B")
        XCTAssertTrue(formatted.contains("测试A") || formatted.contains("测试B"), "格式化调用应正常执行且包含传入参数")
    }
    
    /// 自动化全量审计：动态遍历所有 L10n 模块并验证 Key 的存在性
    func testComprehensiveLocalizationAudit() {
        // 架构说明：每个条目的 table 字段必须与实际的 .xcstrings 文件名完全一致（区分大小写），
        // key 字段必须与 xcstrings 中的 string key 完全一致（注意：各模块 L10n 扩展内部
        // 的 tr() 辅助函数会根据 tableName 路由，key 在文件中均为无前缀的原始 key）。
        struct ModuleEntry { let name: String; let table: String; let keys: [String] }
        let modules: [ModuleEntry] = [
            // Common 表：misc 系列 key
            ModuleEntry(name: "Common", table: "Common", keys: ["ok", "cancel", "done"]),
            // Settings/Auth/Lint/Coachmark 均路由到 System 表
            ModuleEntry(name: "Settings", table: "System", keys: ["aboutApp", "version", "section.about", "settings.about.developerName", "settings.about.copyright"]),
            ModuleEntry(name: "Auth", table: "System", keys: ["guestMode", "login"]),
            ModuleEntry(name: "Lint", table: "System", keys: ["noIssues", "noIssuesHint"]),
            ModuleEntry(name: "Coachmark", table: "System", keys: ["onboarding.action.next"]),
            // AI 表：Chat 和 AITask 共用
            ModuleEntry(name: "Chat", table: "AI", keys: ["chat.title", "chat.inputPlaceholder"]),
            ModuleEntry(name: "AITasks", table: "AI", keys: ["aitask.center.title", "aitask.status.thinking"]),
            // Ingest 单独一张表
            ModuleEntry(name: "Ingest", table: "Ingest", keys: ["ingest.title", "ingest.manualEntry"]),
            // Plugin 表：Collaboration 路由到此
            ModuleEntry(name: "Collaboration", table: "Plugin", keys: ["collab.title"]),
            ModuleEntry(name: "Plugin", table: "Plugin", keys: ["section.rag"]),
            // Knowledge 表：Creation/Vault 路由到此
            ModuleEntry(name: "Creation", table: "Knowledge", keys: ["pageTitle", "content"]),
            ModuleEntry(name: "Vault", table: "Knowledge", keys: ["vault.label", "editor.list", "tag.layoutBubble", "tag.expandAll", "tag.collapse"]),
            // Insight 表：Dashboard/Graph 路由到此
            // 注意：Graph 模块的 tr() 辅助函数会给 key 添加 "graph." 前缀，
            // 因此 xcstrings 中真实 key 为 "graph.title"。
            ModuleEntry(name: "Dashboard", table: "Insight", keys: ["dashboard.hotTopics", "dashboard.density", "dashboard.stats.tab.plugins", "dashboard.stats.tab.satisfactionAndEval"]),
            ModuleEntry(name: "Graph", table: "Insight", keys: ["graph.title"]),
            // Platform 表：Watch/Widget 路由到此
            ModuleEntry(name: "Watch", table: "Platform", keys: ["watch.capture"]),
            ModuleEntry(name: "Widget", table: "Platform", keys: ["widget.title"])
        ]

        var missingKeys: [String] = []

        for module in modules {
            for key in module.keys {
                let translated = Localized.tr(key, table: module.table)
                // 如果返回了 [MISSING: key] 说明翻译缺失
                if translated.contains("[MISSING:") {
                    missingKeys.append("\(module.table).\(key)")
                }
            }
        }

        XCTAssertTrue(missingKeys.isEmpty, "以下本地化 Key 缺失或未在对应的表中定义: \n\(missingKeys.joined(separator: "\n"))")
    }
}
