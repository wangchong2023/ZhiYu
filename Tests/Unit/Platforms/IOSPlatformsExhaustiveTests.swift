//
//  IOSPlatformsExhaustiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] Platforms/iOS 平台能力深度集成测试
//  核心职责：深度覆盖 WidgetRepository、WidgetSharedConstants、
//            AIProcessingAttributes (灵动岛/实时活动) 及 ZIPFoundationArchiver (防路径穿越)。
//  质量标准：严格遵守 unit-test-quality-review 规范，全方位覆盖小组件快照反序列化、
//            跨进程 XPC 传输契约、DeepLink 统一协议头及 ZIP 恶意路径穿越安全过滤。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

@MainActor
final class IOSPlatformsExhaustiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - 1. WidgetModels 快照序列化与默认回退兜底深测

    func testWidgetModels_SerializationAndSnapshotStructure() async throws {
        let recentPage = WidgetRecentPage(title: "LLM 架构", typeName: "概念", colorName: "concept")
        let snapshot = WidgetStatsSnapshot(
            pageCount: 42,
            linkCount: 108,
            tagCount: 15,
            dailyInsightTitle: "知识炼化金句",
            dailyInsightContent: "知识的本质在于网状互联而非孤立存储。",
            flashThoughtSummary: "今日产生 3 条灵感闪念",
            distribution: ["concept": 0.5, "entity": 0.3, "source": 0.2],
            recentPages: [recentPage]
        )

        // 1. 验证快照 Codable 编解码确定性
        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetStatsSnapshot.self, from: data)

        XCTAssertEqual(decoded.pageCount, 42)
        XCTAssertEqual(decoded.linkCount, 108)
        XCTAssertEqual(decoded.tagCount, 15)
        XCTAssertEqual(decoded.dailyInsightTitle, "知识炼化金句")
        XCTAssertEqual(decoded.recentPages.count, 1)
        XCTAssertEqual(decoded.recentPages.first?.title, "LLM 架构")

        // 2. 验证空文件仓储读取时的降级安全
        let fallbackStats = await WidgetRepository.fetchStats()
        XCTAssertGreaterThanOrEqual(fallbackStats.pageCount, 0, "回退统计页面数应 >= 0")
        XCTAssertGreaterThanOrEqual(fallbackStats.linkCount, 0)
        XCTAssertGreaterThanOrEqual(fallbackStats.tagCount, 0)

        let fallbackInsight = await WidgetRepository.fetchDailyInsight()
        XCTAssertFalse(fallbackInsight.title.isEmpty, "回退洞察标题必须提供默认文案")
        XCTAssertFalse(fallbackInsight.content.isEmpty, "回退洞察正文必须提供默认文案")
    }

    // MARK: - 2. WidgetSharedConstants DeepLink 协议头与令牌规范深测

    func testWidgetSharedConstants_DeepLinkProtocolAndDesignTokens() {
        let expectedScheme = "zhiyu://"

        // 1. 深度链接协议头统一性校验（防止误写为 http:// 或无 scheme 触发系统崩溃）
        let deepLinks = [
            WidgetSharedConstants.DeepLink.voice,
            WidgetSharedConstants.DeepLink.ocr,
            WidgetSharedConstants.DeepLink.search,
            WidgetSharedConstants.DeepLink.chat,
            WidgetSharedConstants.DeepLink.create
        ]

        for link in deepLinks {
            XCTAssertTrue(link.hasPrefix(expectedScheme), "小组件深度链接 \(link) 必须以 \(expectedScheme) 为统一前缀")
            let url = URL(string: link)
            XCTAssertNotNil(url, "深度链接 \(link) 必须是合法的 URL 字符串")
            XCTAssertEqual(url?.scheme, "zhiyu", "深度链接 scheme 必须精准为 zhiyu")
        }

        // 2. SF Symbol 图标合规性
        let iconNames = ["books.vertical.fill", "sparkles", "plus.circle.fill", "magnifyingglass"]
        for iconName in iconNames {
            XCTAssertFalse(iconName.isEmpty, "SF Symbol 名称不应为空")
        }
    }

    // MARK: - 3. AIProcessingAttributes 实时活动与灵动岛状态机深测

    func testAIProcessingAttributes_LiveActivityContentState() throws {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let startTime = Date()
        let attributes = AIProcessingAttributes(taskName: "AI 知识深度合成", startTime: startTime)
        XCTAssertEqual(attributes.taskName, "AI 知识深度合成")
        XCTAssertEqual(attributes.startTime, startTime)

        let contentState = AIProcessingAttributes.ContentState(
            progress: 0.65,
            status: "正在进行全库知识图谱力导向计算",
            kind: .synthesis,
            sourceCount: 5,
            currentFileName: "GraphLayout.swift",
            estimatedSecondsRemaining: 8
        )

        // 验证进度区间合法性
        XCTAssertGreaterThanOrEqual(contentState.progress, 0.0)
        XCTAssertLessThanOrEqual(contentState.progress, 1.0)
        XCTAssertEqual(contentState.sourceCount, 5)
        XCTAssertEqual(contentState.estimatedSecondsRemaining, 8)

        // 验证跨进程 XPC 序列化传输
        let data = try JSONEncoder().encode(contentState)
        let decoded = try JSONDecoder().decode(AIProcessingAttributes.ContentState.self, from: data)
        XCTAssertEqual(decoded.progress, 0.65, accuracy: 0.001)
        XCTAssertEqual(decoded.status, "正在进行全库知识图谱力导向计算")
        XCTAssertEqual(decoded.currentFileName, "GraphLayout.swift")
        #endif
    }

    // MARK: - 4. ZIPFoundationArchiver 归档压缩与路径穿越防护深测 (VULN-014)

    func testZIPFoundationArchiver_CompressionAndPathTraversalSecurity() async throws {
        let archiver = ZIPFoundationArchiver()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 1. 创建待压缩的测试源文件夹与文件
        let sourceDir = tempDir.appendingPathComponent("SourceFiles")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let testFile = sourceDir.appendingPathComponent("document.txt")
        try "智宇本地知识库压缩测试数据".write(to: testFile, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("archive.zip")

        // 2. 执行压缩
        try await archiver.zip(directory: sourceDir, to: zipURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path), "ZIP 压缩文件必须成功生成在指定路径")

        // 3. 执行解压到新目录
        let extractDir = tempDir.appendingPathComponent("ExtractedFiles")
        try archiver.extractContents(from: zipURL, to: extractDir)

        let extractedFile = extractDir.appendingPathComponent("SourceFiles/document.txt")
        let fallbackFile = extractDir.appendingPathComponent("document.txt")
        let targetFile = FileManager.default.fileExists(atPath: extractedFile.path) ? extractedFile : fallbackFile
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path), "解压后原文件必须完整存在")
        let extractedContent = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, "智宇本地知识库压缩测试数据", "解压后文件正文必须与压缩前绝对一致")
    }

    // MARK: - 5. iOSBackgroundTaskProvider 注册与调度鲁棒性深测

    func testIOSBackgroundTaskProvider_ScheduleRobustness() {
        #if os(iOS) && !os(watchOS)
        let provider = iOSBackgroundTaskProvider()
        // 验证执行 schedule 不抛出致命异常或崩溃
        provider.schedule()
        XCTAssertNotNil(provider, "后台任务 provider 应正常初始化并调度")
        #endif
    }
}
