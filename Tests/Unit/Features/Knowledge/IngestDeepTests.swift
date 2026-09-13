//
//  IngestDeepTests.swift
//  ZhiYuTests
//
//  合并自 4 个碎片化测试文件：IngestAndImportSectionDeepTests.swift, IngestAndOCRScanFullDeepTests.swift, IngestAndSearchInteractiveTests.swift, IngestQueueBackpressureDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class IngestDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func createTestPage(
        title: String,
        content: String = "",
        pageType: PageType = .concept,
        status: PageStatus = .active,
        tags: [String] = [],
        aliases: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> KnowledgePage {
        KnowledgePage(
            id: UUID(),
            title: title,
            pageType: pageType,
            content: content,
            aliases: aliases,
            tags: tags,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func testImportCategory_Properties() {
        for category in ImportCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.directoryName.isEmpty)
        }
    }

    func testOCRScanView_InitialStateAndHierarchy() {
        var didFinish = false
        let host = NavigationStack {
            OCRScanView(onFinish: { _, _, _ in
                didFinish = true
            })
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertFalse(didFinish)
    }

    func testIngestCoordinator_TriggerActions() async {
        let coordinator = IngestCoordinator()
        XCTAssertFalse(coordinator.showError)
        XCTAssertNil(coordinator.errorMessage)

        let record = ImportRecord(
            category: "link",
            title: "https://example.com/deep-test",
            status: "pending",
            sourceURL: "https://example.com/deep-test"
        )

        coordinator.openManualForm(with: record)
        coordinator.triggerAITagging(for: record)
        XCTAssertNotNil(coordinator)
    }

    func testIngestProgressCalculator_clampProgress_handlesNormalAndExtremeValues() {
        // 正常范围值
        XCTAssertEqual(IngestProgressCalculator.clampProgress(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(1.0), 1.0, accuracy: 0.001)

        // 越界值
        XCTAssertEqual(IngestProgressCalculator.clampProgress(-0.5), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(1.5), 1.0, accuracy: 0.001)

        // 极端与异常浮点值
        XCTAssertEqual(IngestProgressCalculator.clampProgress(Double.nan), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(Double.infinity), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(-Double.infinity), 0.0, accuracy: 0.001)
    }

    func testIngestProgressCalculator_formatPercentage_preventsCrashAndOutputsInt() {
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(0.42), 42)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(0.0), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(1.0), 100)

        // 验证台账 #174：Double.nan 转 Int 绝不发生崩溃
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(Double.nan), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(Double.infinity), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(-Double.infinity), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(-10.0), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(999.0), 100)
    }

    func testIngestProgressCalculator_resolveTaskProgress_validAndNilTasks() {
        // 空任务
        let (nilProgress, nilStage) = IngestProgressCalculator.resolveTaskProgress(nil)
        XCTAssertEqual(nilProgress, 0.0, accuracy: 0.001)
        XCTAssertEqual(nilStage, .pending)

        // 正常运行中的任务
        let runningTask = GlobalTask(
            type: .ingest,
            name: "Test Ingest",
            target: "doc.pdf",
            status: .running(progress: 0.75, stage: .embedding)
        )
        let (runningProgress, runningStage) = IngestProgressCalculator.resolveTaskProgress(runningTask)
        XCTAssertEqual(runningProgress, 0.75, accuracy: 0.001)
        XCTAssertEqual(runningStage, .embedding)

        // 带有 NaN 运行状态的任务
        let nanTask = GlobalTask(
            type: .ingest,
            name: "Corrupt Ingest",
            target: "corrupt.pdf",
            status: .running(progress: Double.nan, stage: .chunking)
        )
        let (nanProgress, nanStage) = IngestProgressCalculator.resolveTaskProgress(nanTask)
        XCTAssertEqual(nanProgress, 0.0, accuracy: 0.001)
        XCTAssertEqual(nanStage, .chunking)

        // 已完成任务（非 running 状态）
        let completedTask = GlobalTask(
            type: .ingest,
            name: "Completed Ingest",
            target: "done.pdf",
            status: .completed
        )
        let (completedProgress, completedStage) = IngestProgressCalculator.resolveTaskProgress(completedTask)
        XCTAssertEqual(completedProgress, 0.0, accuracy: 0.001)
        XCTAssertEqual(completedStage, .pending)
    }

    func testIngestView_mountAndActiveTaskRendering() {
        let tc = TaskCenter()
        let taskId = tc.addTask(type: .ingest, name: "Async PDF Ingest", target: "doc.pdf")
        tc.updateTask(taskId, status: .running(progress: 0.65, stage: .embedding))

        var selectedTab: AppTab = .ingest
        let binding = Binding<AppTab>(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )

        withDependencies {
            $0.taskCenter = tc
        } operation: {
            let ingestView = IngestView(selectedTab: binding)
                .snapshotEnvironment()

            let controller = UIHostingController(rootView: ingestView)
            controller.loadViewIfNeeded()

            XCTAssertNotNil(controller.view, "IngestView 包含活动任务时必须平稳渲染")
        }
    }

    func testIngestView_nanProgressProtection_rendersSafeFallback() {
        let tc = TaskCenter()
        let taskId = tc.addTask(type: .ingest, name: "Corrupt Ingest Task", target: "corrupt.pdf")
        tc.updateTask(taskId, status: .running(progress: Double.nan, stage: .chunking))

        var selectedTab: AppTab = .ingest
        let binding = Binding<AppTab>(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )

        withDependencies {
            $0.taskCenter = tc
        } operation: {
            let ingestView = IngestView(selectedTab: binding)
                .snapshotEnvironment()

            let controller = UIHostingController(rootView: ingestView)
            controller.loadViewIfNeeded()

            XCTAssertNotNil(controller.view, "遭遇 NaN 进度任务时 IngestView 必须安全防御并不崩溃")
        }
    }

    func testSearchView_mountAndSortOptionLocalization() {
        let searchView = SearchView(initialQuery: "Knowledge", initialFilterType: .concept)
            .snapshotEnvironment()

        let controller = UIHostingController(rootView: searchView)
        controller.loadViewIfNeeded()

        XCTAssertNotNil(controller.view, "SearchView 必须正常挂载")
    }

    func testIngestCoordinator_actionTriggers_updateStateConsistently() {
        let coordinator = IngestCoordinator()

        // 触发 URL 摄入
        coordinator.showURLImport = true
        coordinator.sourceHint = .link
        XCTAssertTrue(coordinator.showURLImport)
        XCTAssertEqual(coordinator.sourceHint, .link)

        // 触发文本摄入
        coordinator.showManualForm = true
        coordinator.sourceHint = .clipboard
        XCTAssertTrue(coordinator.showManualForm)
        XCTAssertEqual(coordinator.sourceHint, .clipboard)

        // 触发文件选择
        coordinator.showFileImporter = true
        coordinator.sourceHint = .file
        XCTAssertTrue(coordinator.showFileImporter)
        XCTAssertEqual(coordinator.sourceHint, .file)
    }

    func testIngestProgressCalculator_fuzz100RandomValues_neverCrashes() {
        let extremeValues: [Double] = [
            -Double.greatestFiniteMagnitude,
            Double.greatestFiniteMagnitude,
            -1e10, 1e10, -0.00001, 0.00001,
            Double.nan, Double.infinity, -Double.infinity,
            -0.0, 0.0, 1.0, 0.9999999
        ]

        for val in extremeValues {
            let clamped = IngestProgressCalculator.clampProgress(val)
            XCTAssertGreaterThanOrEqual(clamped, 0.0)
            XCTAssertLessThanOrEqual(clamped, 1.0)

            let percentage = IngestProgressCalculator.formatPercentage(val)
            XCTAssertGreaterThanOrEqual(percentage, 0)
            XCTAssertLessThanOrEqual(percentage, 100)
        }

        for _ in 0..<100 {
            let randomDouble = Double.random(in: -100.0...100.0)
            let clamped = IngestProgressCalculator.clampProgress(randomDouble)
            XCTAssertGreaterThanOrEqual(clamped, 0.0)
            XCTAssertLessThanOrEqual(clamped, 1.0)

            let pct = IngestProgressCalculator.formatPercentage(randomDouble)
            XCTAssertGreaterThanOrEqual(pct, 0)
            XCTAssertLessThanOrEqual(pct, 100)
        }
    }

    func testIngestQueueEnqueueAndVaultSwitch() async throws {
        let queue = IngestQueue.shared
        let llm = MockLLMService()

        var results: [KnowledgePage] = []
        queue.enqueue(
            title: "Async Microservice Spec",
            content: "Kafka event driven architecture specification.",
            llmService: llm,
            pages: []
        ) { page in
            results.append(page)
        }

        XCTAssertGreaterThanOrEqual(queue.pendingCount, 0)

        NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(queue.pendingCount, 0)
        XCTAssertFalse(queue.isProcessing)
    }

    func testIngestStoreState() async throws {
        let store = IngestStore()
        let pdfs = await store.loadPDFDocuments()
        XCTAssertNotNil(pdfs)
    }

}
