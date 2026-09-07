//
//  IngestViewDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：IngestViewInteractiveTests.swift, IngestViewWizardAndClipboardInteractiveTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class IngestViewDeepTests: XCTestCase {

    private var taskCenter: TaskCenter!
    private var knowledgeStore: KnowledgeStore!
    private var ingestStore: IngestStore!
    private var appStore: AppStore!
    private var router: Router!
    private var themeManager: ThemeManager!
    private var window: UIWindow!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        taskCenter = TaskCenter()
        knowledgeStore = KnowledgeStore()
        ingestStore = IngestStore()
        appStore = AppStore()
        router = Router.shared
        themeManager = ThemeManager()
        window = UIWindow(frame: UIScreen.main.bounds)
    }

    func testIngestCoordinator_cooldownGuard_blocksRapidImports() {
        let coordinator = IngestCoordinator()

        // 初始状态下未导入，冷却时间应为未就绪或未生效
        XCTAssertFalse(coordinator.isImporting, "新初始化协调器不处于导入冷却中")

        // 模拟触发导入
        coordinator.lastImportTime = Date()
        XCTAssertTrue(coordinator.isImporting, "刚刚记录导入时间后必须处于冷却保护状态")

        // 模拟冷却时间过后
        coordinator.lastImportTime = Date().addingTimeInterval(-Double(coordinator.importCooldownSeconds + 1))
        XCTAssertFalse(coordinator.isImporting, "超出冷却时间阈值后冷却状态应自动解除")
    }

    func testIngestCoordinator_prepareImportFiles_oversizedImageRejection() {
        let coordinator = IngestCoordinator()
        coordinator.sourceHint = .ocr
        coordinator.newTitle = "Test OCR Page"
        coordinator.newContent = "OCR Test Content"

        // 模拟超限大图片（超过 maxOCRImageSizeBytes）
        let oversizedBytes = Int(AppConstants.Keys.ImportLimits.maxOCRImageSizeBytes) + 1024
        coordinator.pendingImageData = Data(repeating: 0xAA, count: oversizedBytes)

        let result = coordinator.prepareImportFiles(recordID: UUID().uuidString)

        // 严格断言：超限图片必须被拦截返回 nil，并设置错误弹窗文案
        XCTAssertNil(result, "超过大小限制的 OCR 图片必须被拦截拒绝保存")
        XCTAssertTrue(coordinator.showError, "必须激活错误提示弹窗")
        XCTAssertEqual(coordinator.errorMessage, L10n.Ingest.imageTooLarge)
        XCTAssertNil(coordinator.pendingImageData, "超限图片数据必须被清空释放内存")
        XCTAssertFalse(coordinator.isIngesting, "摄取中状态必须被安全重置")
    }

    func testIngestCoordinator_resetForm_clearsAllState() {
        let coordinator = IngestCoordinator()
        coordinator.newTitle = "Draft Title"
        coordinator.newContent = "Draft Content"
        coordinator.newCustomIcon = "star.fill"
        coordinator.useSmartIngest = true

        coordinator.resetForm()

        XCTAssertTrue(coordinator.newTitle.isEmpty)
        XCTAssertTrue(coordinator.newContent.isEmpty)
        XCTAssertNil(coordinator.newCustomIcon)
        XCTAssertFalse(coordinator.useSmartIngest)
    }

    func testIngestCoordinator_openManualForm_preservesAndParsesHeaders() {
        let coordinator = IngestCoordinator()

        // 带前置引用来源头的信息
        let recordWithHeader = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "Header Page",
            status: ImportRecordStatus.done,
            rawText: "> 来源: 手工录入 | 2026/09/04\n\n正文第一行\n正文第二行"
        )
        coordinator.openManualForm(with: recordWithHeader)
        XCTAssertEqual(coordinator.newTitle, "Header Page")
        XCTAssertEqual(coordinator.sourceHint, .manual)
        XCTAssertEqual(coordinator.newContent, "正文第一行\n正文第二行")
        XCTAssertTrue(coordinator.showManualForm)

        // 普通纯文本信息
        let plainRecord = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "Plain Page",
            status: ImportRecordStatus.done,
            rawText: "没有任何来源头的正文"
        )
        coordinator.openManualForm(with: plainRecord)
        XCTAssertEqual(coordinator.newTitle, "Plain Page")
        XCTAssertEqual(coordinator.newContent, "没有任何来源头的正文")
    }

    func testIngestView_mountAndTabBarIntegration() {
        let bindingTab = Binding<AppTab>(get: { .knowledge }, set: { _ in })
        let ingestView = IngestView(selectedTab: bindingTab)
            .snapshotEnvironment()

        let hostingController = UIHostingController(rootView: ingestView)
        hostingController.loadViewIfNeeded()
        XCTAssertNotNil(hostingController.view, "IngestView 应该能够在包含环境对象的宿主中正常挂载")
    }

    func testIngestView_DefaultState_WithEmptyTasks() {
        taskCenter.tasks = []

        let view = IngestView(selectedTab: .constant(.ingest))
            .environment(knowledgeStore)
            .environment(ingestStore)
            .environment(appStore)
            .environment(router)
            .environment(themeManager)
            .environmentObject(LLMService.shared)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertTrue(taskCenter.tasks.isEmpty)
    }

    func testIngestView_ActiveRunningTask_RendersProgressPanel() {
        let task = GlobalTask(
            type: .ingest,
            name: "智能解析",
            target: TestConstants.testTaskTarget,
            status: .running(progress: TestConstants.testProgress, stage: .chunking),
            subLogs: ["提取文本完成", "分块进行中..."]
        )
        taskCenter.tasks = [task]

        let view = IngestView(selectedTab: .constant(.ingest))
            .environment(knowledgeStore)
            .environment(ingestStore)
            .environment(appStore)
            .environment(router)
            .environment(themeManager)
            .environmentObject(LLMService.shared)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(taskCenter.tasks.count, 1)

        // 导航至 TaskCenter 工具验证
        router.navigateToTool(.taskCenter)
        XCTAssertEqual(router.sidebarSelection, .tool(.taskCenter))
    }

    func testActivityRow_AllStatusAndNavigation() {
        let testPageID = UUID()

        // 1. 已完成并绑定关联页面
        let completedTask = GlobalTask(
            type: .ingest,
            name: "摄取文档",
            target: "iOS架构.md",
            status: .completed,
            associatedPageID: testPageID
        )
        let row1 = ActivityRow(task: completedTask)
            .environment(router)
        let host1 = UIHostingController(rootView: row1)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        router.navigateToPage(id: testPageID)
        XCTAssertFalse(router.path.isEmpty)

        // 2. 失败任务无关联页面
        let failedTask = GlobalTask(
            type: .ingest,
            name: "URL抓取",
            target: "https://bad.url",
            status: .failed(error: "抓取超时")
        )
        let row2 = ActivityRow(task: failedTask)
            .environment(router)
        let host2 = UIHostingController(rootView: row2)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)

        // 3. 等待与进行中任务
        let pendingTask = GlobalTask(type: .ingest, name: "", target: "仅有Target", status: .pending)
        let row3 = ActivityRow(task: pendingTask)
            .environment(router)
        let host3 = UIHostingController(rootView: row3)
        host3.view.layoutIfNeeded()
        XCTAssertNotNil(host3.view)

        let onlyNameTask = GlobalTask(
            type: .ingest,
            name: "仅有Name",
            target: "",
            status: .running(progress: TestConstants.testProgress, stage: .extraction)
        )
        let row4 = ActivityRow(task: onlyNameTask)
            .environment(router)
        let host4 = UIHostingController(rootView: row4)
        host4.view.layoutIfNeeded()
        XCTAssertNotNil(host4.view)
    }

    private enum TestConstants {
        static let testTaskTarget = "测试目标"
        static let testProgress: Double = 0.5
    }
}
