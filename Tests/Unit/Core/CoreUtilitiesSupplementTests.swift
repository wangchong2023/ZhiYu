//
//  CoreUtilitiesSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 Localized/SnapshotService/DependencyContainer/
//           AccessibilityService/TestModeDetector 的未覆盖分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

/// Core/Other 工具类补盲测试
///
/// 覆盖目标：
/// - Localized: tr/trf/allValues/bestMatch/languageMode/currentLanguage/isChinese
/// - SnapshotService: saveSnapshot/getHistory/rollback
/// - DependencyContainer: mock() 工厂 + 属性读写
/// - AccessibilityService: pageAnnouncement/graphNodeAnnouncement/shouldAnimate
/// - TestModeDetector: isUITesting/isUnitTesting/isMockDataMode/shouldResetUserDefaults/isAnyTesting
@MainActor
final class CoreUtilitiesSupplementTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Localized.resetForTesting()
    }

    override func tearDown() {
        Localized.resetForTesting()
        super.tearDown()
    }

    // MARK: - Localized

    /// Localized.tr 已注册 key 应返回非空字符串
    func testLocalized_tr_已注册key_返回非空() {
        let result = Localized.tr("common.testRunnerWorking")
        XCTAssertFalse(result.isEmpty, "已注册 key 应返回非空")
        XCTAssertFalse(result.contains("MISSING"), "已注册 key 不应返回 MISSING 标记")
    }

    /// Localized.tr 未注册 key 应返回 MISSING 标记
    func testLocalized_tr_未注册key_返回MISSING标记() {
        let unknownKey = "nonexistent.key.\(UUID().uuidString)"
        let result = Localized.tr(unknownKey)
        XCTAssertTrue(result.contains("MISSING"), "未注册 key 应返回 MISSING 标记")
    }

    /// Localized.tr 指定表名应不崩溃
    func testLocalized_tr_指定表名_不崩溃() {
        let result = Localized.tr("common.testRunnerWorking", table: "Common")
        XCTAssertFalse(result.isEmpty)
    }

    /// Localized.trf 带参数应不崩溃并返回字符串
    func testLocalized_trf_带参数_不崩溃() {
        let formatted = Localized.trf("common.testRunnerWorking", table: "Common", arguments: [])
        XCTAssertFalse(formatted.isEmpty, "trf 格式化结果不应为空")
    }

    /// Localized.trf 可变参数版本应不崩溃
    func testLocalized_trf_可变参数_不崩溃() {
        let formatted = Localized.trf("common.testRunnerWorking", table: "Common")
        XCTAssertFalse(formatted.isEmpty)
    }

    /// Localized.allValues 应返回数组（不崩溃）
    func testLocalized_allValues_不崩溃() {
        let values = Localized.allValues(forKey: "common.testRunnerWorking", table: "Common")
        XCTAssertNotNil(values as [String]?)
    }

    /// Localized.bestMatch 完全匹配应返回对应值
    func testLocalized_bestMatch_完全匹配() {
        Localized.languageMode = .english
        let result = Localized.bestMatch(in: ["en": "Hello", "zh-Hans": "你好"])
        XCTAssertEqual(result, "Hello", "英文模式下应返回 en 对应值")
    }

    /// Localized.bestMatch 前缀匹配应返回对应值
    func testLocalized_bestMatch_前缀匹配() {
        Localized.languageMode = .chinese
        let result = Localized.bestMatch(in: ["zh": "你好", "en": "Hello"])
        XCTAssertEqual(result, "你好", "中文模式下应通过前缀匹配返回 zh 对应值")
    }

    /// Localized.bestMatch 无匹配但字典非空应返回任意值（源码第 5 步: dict.values.first）
    func testLocalized_bestMatch_无匹配_字典非空_返回任意值() {
        Localized.languageMode = .english
        let result = Localized.bestMatch(in: ["fr": "Bonjour"], fallback: "default")
        // 源码第 5 步: return dict.values.first ?? fallback
        XCTAssertFalse(result.isEmpty, "字典非空时应返回任意值而非 fallback")
    }

    /// Localized.bestMatch 空字典应返回 fallback
    func testLocalized_bestMatch_空字典_返回fallback() {
        Localized.languageMode = .english
        let result = Localized.bestMatch(in: [:], fallback: "empty")
        XCTAssertEqual(result, "empty", "空字典应返回 fallback")
    }

    /// Localized.bestMatch en fallback 应返回 en 值
    func testLocalized_bestMatch_enFallback() {
        Localized.languageMode = .korean
        let result = Localized.bestMatch(in: ["en": "Hello", "fr": "Bonjour"])
        XCTAssertEqual(result, "Hello", "无匹配时应 fallback 到 en")
    }

    /// Localized.currentLanguage 在 auto 模式应返回非空字符串
    func testLocalized_currentLanguage_auto模式_非空() {
        Localized.languageMode = .auto
        let lang = Localized.currentLanguage
        XCTAssertFalse(lang.isEmpty, "currentLanguage 不应为空")
    }

    /// Localized.currentLanguage 在 english 模式应返回 "en"
    func testLocalized_currentLanguage_english模式() {
        Localized.languageMode = .english
        XCTAssertEqual(Localized.currentLanguage, "en")
    }

    /// Localized.currentLanguage 在 chinese 模式应返回 "zh-Hans"
    func testLocalized_currentLanguage_chinese模式() {
        Localized.languageMode = .chinese
        XCTAssertEqual(Localized.currentLanguage, "zh-Hans")
    }

    /// Localized.currentLanguage 在 traditionalChinese 模式应返回 "zh-Hant"
    func testLocalized_currentLanguage_traditionalChinese模式() {
        Localized.languageMode = .traditionalChinese
        XCTAssertEqual(Localized.currentLanguage, "zh-Hant")
    }

    /// Localized.currentLanguage 在 spanish 模式应返回 "es"
    func testLocalized_currentLanguage_spanish模式() {
        Localized.languageMode = .spanish
        XCTAssertEqual(Localized.currentLanguage, "es")
    }

    /// Localized.currentLanguage 在 french 模式应返回 "fr"
    func testLocalized_currentLanguage_french模式() {
        Localized.languageMode = .french
        XCTAssertEqual(Localized.currentLanguage, "fr")
    }

    /// Localized.currentLanguage 在 arabic 模式应返回 "ar"
    func testLocalized_currentLanguage_arabic模式() {
        Localized.languageMode = .arabic
        XCTAssertEqual(Localized.currentLanguage, "ar")
    }

    /// Localized.currentLanguage 在 russian 模式应返回 "ru"
    func testLocalized_currentLanguage_russian模式() {
        Localized.languageMode = .russian
        XCTAssertEqual(Localized.currentLanguage, "ru")
    }

    /// Localized.currentLanguage 在 korean 模式应返回 "ko"
    func testLocalized_currentLanguage_korean模式() {
        Localized.languageMode = .korean
        XCTAssertEqual(Localized.currentLanguage, "ko")
    }

    /// Localized.currentLanguage 在 japanese 模式应返回 "ja"
    func testLocalized_currentLanguage_japanese模式() {
        Localized.languageMode = .japanese
        XCTAssertEqual(Localized.currentLanguage, "ja")
    }

    /// Localized.currentLanguage 在 portuguese 模式应返回 "pt"
    func testLocalized_currentLanguage_portuguese模式() {
        Localized.languageMode = .portuguese
        XCTAssertEqual(Localized.currentLanguage, "pt")
    }

    /// Localized.isChinese 在 chinese 模式应返回 true
    func testLocalized_isChinese_chinese模式_true() {
        Localized.languageMode = .chinese
        XCTAssertTrue(Localized.isChinese, "中文模式 isChinese 应为 true")
    }

    /// Localized.isChinese 在 english 模式应返回 false
    func testLocalized_isChinese_english模式_false() {
        Localized.languageMode = .english
        XCTAssertFalse(Localized.isChinese, "英文模式 isChinese 应为 false")
    }

    /// Localized.currentLocale 应返回非 nil Locale
    func testLocalized_currentLocale_非nil() {
        Localized.languageMode = .english
        let locale = Localized.currentLocale
        XCTAssertEqual(locale.identifier, "en")
    }

    /// LanguageMode 所有 case 的 displayName 应非空
    func testLanguageMode_allCases_displayName非空() {
        for mode in LanguageMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "\(mode) 的 displayName 不应为空")
        }
    }

    /// LanguageMode.id 应等于 rawValue
    func testLanguageMode_id_等于rawValue() {
        for mode in LanguageMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue, "\(mode) 的 id 应等于 rawValue")
        }
    }

    // MARK: - SnapshotService

    /// SnapshotService saveSnapshot 应不崩溃并创建文件
    func testSnapshotService_saveSnapshot_创建文件() {
        let service = SnapshotService()
        let pageID = UUID()
        service.saveSnapshot(pageID: pageID, title: "测试标题", content: "# 测试内容")
        let history = service.getHistory(for: pageID)
        XCTAssertFalse(history.isEmpty, "保存后应能获取到历史快照")
    }

    /// SnapshotService getHistory 无快照应返回空数组
    func testSnapshotService_getHistory_无快照_返回空数组() {
        let service = SnapshotService()
        let history = service.getHistory(for: UUID())
        XCTAssertTrue(history.isEmpty, "无快照应返回空数组")
    }

    /// SnapshotService rollback 应返回内容（剥离 frontmatter）
    func testSnapshotService_rollback_返回内容() {
        let service = SnapshotService()
        let pageID = UUID()
        service.saveSnapshot(pageID: pageID, title: "标题", content: "回滚内容")
        let history = service.getHistory(for: pageID)
        guard let snapshot = history.first else {
            XCTFail("应能获取到快照")
            return
        }
        let content = service.rollback(to: snapshot)
        XCTAssertNotNil(content, "rollback 应返回非 nil 内容")
        XCTAssertTrue(content?.contains("回滚内容") ?? false, "rollback 内容应包含原始内容")
    }

    /// SnapshotService rollback 无效 URL 应返回 nil
    func testSnapshotService_rollback_无效URL_返回nil() {
        let service = SnapshotService()
        let invalidSnapshot = SnapshotInfo(
            url: URL(fileURLWithPath: "/nonexistent/path/snapshot.md"),
            date: Date()
        )
        let content = service.rollback(to: invalidSnapshot)
        XCTAssertNil(content, "无效 URL 应返回 nil")
    }

    /// SnapshotInfo.id 应等于 url.path
    func testSnapshotInfo_id_等于urlPath() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let info = SnapshotInfo(url: url, date: Date())
        XCTAssertEqual(info.id, url.path)
    }

    // MARK: - DependencyContainer

    /// DependencyContainer mock() 应返回空容器
    func testDependencyContainer_mock_返回空容器() {
        let container = DependencyContainer.mock()
        XCTAssertNil(container.routerService)
        XCTAssertNil(container.onboardingService)
        XCTAssertNil(container.themeService)
        XCTAssertNil(container.toastService)
    }

    /// DependencyContainer 属性应可读写
    func testDependencyContainer_属性_可读写() {
        let container = DependencyContainer()
        XCTAssertNil(container.routerService)
        container.routerService = "test"
        XCTAssertNotNil(container.routerService)
    }

    /// DependencyContainer init 应不崩溃
    func testDependencyContainer_init_不崩溃() {
        _ = DependencyContainer()
        // 不崩溃即通过
    }

    // MARK: - AccessibilityService

    /// AccessibilityService shouldAnimate 初始应为 true
    func testAccessibilityService_shouldAnimate_初始true() {
        let service = AccessibilityService()
        XCTAssertTrue(service.shouldAnimate, "初始 shouldAnimate 应为 true（isReduceMotionEnabled = false）")
    }

    /// AccessibilityService shouldAnimate 在 isReduceMotionEnabled=true 时应为 false
    func testAccessibilityService_shouldMotion_reduceMotion时false() {
        let service = AccessibilityService()
        service.isReduceMotionEnabled = true
        XCTAssertFalse(service.shouldAnimate, "isReduceMotionEnabled=true 时 shouldAnimate 应为 false")
    }

    /// AccessibilityService.pageAnnouncement 无标签应不崩溃
    func testAccessibilityService_pageAnnouncement_无标签_不崩溃() {
        let result = AccessibilityService.pageAnnouncement(
            title: "标题", pageTypeDisplay: "笔记",
            statusDisplay: "草稿", tags: [], wordCount: 100
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertFalse(result.contains("tags"), "无标签时不应包含 tags 字段")
    }

    /// AccessibilityService.pageAnnouncement 有标签应包含标签
    func testAccessibilityService_pageAnnouncement_有标签_包含标签() {
        let result = AccessibilityService.pageAnnouncement(
            title: "标题", pageTypeDisplay: "笔记",
            statusDisplay: "草稿", tags: ["标签1", "标签2"], wordCount: 100
        )
        XCTAssertTrue(result.contains("标签1"), "有标签时应包含标签内容")
        XCTAssertTrue(result.contains("标签2"))
    }

    /// AccessibilityService.graphNodeAnnouncement 应包含节点标题和链接数
    func testAccessibilityService_graphNodeAnnouncement_包含标题和链接数() {
        let node = GraphNode(id: UUID(), title: "测试节点", pageType: .concept, position: .zero)
        let result = AccessibilityService.graphNodeAnnouncement(node, linkCount: 5)
        XCTAssertTrue(result.contains("测试节点"), "应包含节点标题")
        XCTAssertTrue(result.contains("5"), "应包含链接数")
    }

    /// AccessibilityService @Published 属性应可读写
    func testAccessibilityService_published属性_可读写() {
        let service = AccessibilityService()
        service.isVoiceOverRunning = true
        XCTAssertTrue(service.isVoiceOverRunning)
        service.isReduceMotionEnabled = true
        XCTAssertTrue(service.isReduceMotionEnabled)
        service.isHighContrastEnabled = true
        XCTAssertTrue(service.isHighContrastEnabled)
    }

    // MARK: - TestModeDetector

    /// TestModeDetector.isUnitTesting 在单元测试环境应返回 true
    func testTestModeDetector_isUnitTesting_测试环境_true() {
        XCTAssertTrue(TestModeDetector.isUnitTesting, "单元测试环境 isUnitTesting 应为 true")
    }

    /// TestModeDetector.isAnyTesting 在测试环境应返回 true
    func testTestModeDetector_isAnyTesting_测试环境_true() {
        XCTAssertTrue(TestModeDetector.isAnyTesting, "测试环境 isAnyTesting 应为 true")
    }

    /// TestModeDetector.isUITesting 在单元测试环境应返回 false
    func testTestModeDetector_isUITesting_单元测试_false() {
        XCTAssertFalse(TestModeDetector.isUITesting, "单元测试环境 isUITesting 应为 false")
    }

    /// TestModeDetector.isMockDataMode 在非 Mock 数据环境应返回 false
    func testTestModeDetector_isMockDataMode_非Mock环境_false() {
        XCTAssertFalse(TestModeDetector.isMockDataMode, "非 Mock 数据环境 isMockDataMode 应为 false")
    }

    /// TestModeDetector.shouldResetUserDefaults 在无 launch arg 时应返回 false
    func testTestModeDetector_shouldResetUserDefaults_无arg_false() {
        XCTAssertFalse(TestModeDetector.shouldResetUserDefaults, "无 launch arg 时应为 false")
    }
}
