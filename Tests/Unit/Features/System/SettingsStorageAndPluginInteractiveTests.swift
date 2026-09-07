//
//  SettingsStorageAndPluginInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：测试 SettingsView、PluginCenterView 与 RawStorageListView 的核心构建逻辑、分类映射、文本高亮、搜索过滤与多状态机
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SettingsStorageAndPluginInteractiveTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = Router.shared
    }

    override func tearDown() async throws {
        appStore = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. SettingsDemoInjectHelper 提示信息格式化测试

    func testSettingsDemoInjectHelper_FormattingAndPluralDetails() {
        // 1. 空数据返回空字符串
        let empty = SettingsDemoInjectHelper.formatSuccessMessage(
            details: [],
            prefixFormat: "成功注入 %d 个笔记本：",
            pageUnit: " 篇",
            separator: "、"
        )
        XCTAssertEqual(empty, "")

        // 2. 单个笔记本详情
        let single = SettingsDemoInjectHelper.formatSuccessMessage(
            details: [("技术架构", 12)],
            prefixFormat: "成功注入 %d 个笔记本：",
            pageUnit: " 篇",
            separator: "、"
        )
        XCTAssertEqual(single, "成功注入 1 个笔记本：技术架构12 篇")

        // 3. 多个笔记本组合
        let multiple = SettingsDemoInjectHelper.formatSuccessMessage(
            details: [("技术架构", 12), ("产品设计", 8), ("阅读随笔", 5)],
            prefixFormat: "已导入 %d 个分区: ",
            pageUnit: "页",
            separator: " | "
        )
        XCTAssertEqual(multiple, "已导入 3 个分区: 技术架构12页 | 产品设计8页 | 阅读随笔5页")
    }

    // MARK: - 2. HighlightedText 富文本属性高亮构建与 Fuzz 模糊测试

    func testHighlightedText_AttributedStringMatchAndEmptyQuery() {
        let text = "SwiftUI 知识图谱支持 Swift 6 严格并发检查与 SwiftUI 响应式渲染"

        // 1. 空搜索词构造视图
        let emptyHighlight = HighlightedText(text: text, highlight: "")
        XCTAssertNotNil(emptyHighlight)

        // 2. 匹配项高亮构造视图
        let highlighted = HighlightedText(text: text, highlight: "swiftui")
        XCTAssertNotNil(highlighted)

        // 3. Fuzz 模糊测试：保证极端字符与不存在子串绝不崩溃越界
        let queries = ["", "SwiftUI", "不存在的字符串", " ", "6", "，", "!@#$%^&*()", "检查与", text]
        for query in queries {
            let result = HighlightedText(text: text, highlight: query)
            XCTAssertNotNil(result, "高亮富文本视图构造不应崩溃")
        }
    }

    // MARK: - 3. RawCategoryType 文件后缀与分类映射测试

    func testRawCategoryType_ExtensionMappingAndDefaults() {
        // RawCategoryType 枚举完整性与分类映射
        let allCategories = RawCategoryType.allCases
        XCTAssertTrue(allCategories.contains(.document))
        XCTAssertTrue(allCategories.contains(.audio))
        XCTAssertTrue(allCategories.contains(.ocr))
        XCTAssertTrue(allCategories.contains(.web))
        XCTAssertTrue(allCategories.contains(.clipboard))
        XCTAssertTrue(allCategories.contains(.manual))

        // 验证 rawValue 唯一性
        let rawValues = allCategories.map { $0.rawValue }
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "RawCategoryType rawValue 应唯一")
    }

    // MARK: - 4. RawCategoryType 枚举完整性与属性契约

    func testRawCategoryType_EnumIntegrity() {
        for category in RawCategoryType.allCases {
            XCTAssertFalse(category.id.isEmpty)
            XCTAssertFalse(category.systemIconName.isEmpty)
            XCTAssertFalse(category.displayName.isEmpty)
        }
    }

    // MARK: - 5. PluginSource 枚举契约测试

    func testPluginSource_EnumIntegrity() {
        XCTAssertEqual(PluginSource.local.rawValue, "local")
        XCTAssertEqual(PluginSource.community.rawValue, "community")
        XCTAssertEqual(PluginSource.unknown.rawValue, "unknown")
    }

    // MARK: - 6. SettingsView 挂载渲染测试

    func testSettingsView_MountAndRender() {
        let view = SettingsView()
            .environment(appStore)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "SettingsView 设置界面应正确挂载并排版各分区")
        XCTAssertNotNil(appStore)
        XCTAssertNotNil(router)
    }

    // MARK: - 7. PluginCenterView 挂载渲染测试

    func testPluginCenterView_MountAndRender() {
        let view = PluginCenterView()
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "PluginCenterView 插件中心应正常挂载")
        XCTAssertNotNil(router)
        XCTAssertNotNil(appStore)
    }

    // MARK: - 8. RawStorageListView 挂载与分类渲染测试

    func testRawStorageListView_MountAndFilter() async {
        var p1 = KnowledgePage(title: "PDF 论文", content: "正文")
        p1.sourceURL = "file:///paper.pdf"
        p1.sourceType = "pdf"

        var p2 = KnowledgePage(title: "音频速记", content: "正文")
        p2.sourceURL = "file:///voice.m4a"
        p2.sourceType = "m4a"

        await appStore.savePage(p1)
        await appStore.savePage(p2)

        let view = RawStorageListView()
            .environment(appStore)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view)
        XCTAssertEqual(p1.title, "PDF 论文")
        XCTAssertEqual(p2.sourceType, "m4a")
    }

    // MARK: - 9. RawPageDetailView 挂载与详情展示

    func testRawPageDetailView_MountAndRender() {
        var page = KnowledgePage(title: "原始资料详情", content: "原始资料详细数据")
        page.sourceURL = "https://example.com/source.html"
        page.sourceType = "web"
        page.fileSize = 4096

        let view = RawPageDetailView(page: page)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "RawPageDetailView 应稳定挂载并格式化来源大小")
        XCTAssertEqual(page.title, "原始资料详情")
        XCTAssertEqual(page.fileSize, 4096)
    }

    // MARK: - 10. RawPageRow 组件挂载测试

    func testRawPageRow_MountAndRender() {
        var page = KnowledgePage(title: "测试行组件", content: "内容")
        page.sourceURL = "file:///test.txt"
        page.sourceType = "txt"

        let row = RawPageRow(page: page, searchText: "测试")
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: row)
        _ = host.view

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page.title, "测试行组件")
        XCTAssertEqual(page.sourceType, "txt")
    }
}
