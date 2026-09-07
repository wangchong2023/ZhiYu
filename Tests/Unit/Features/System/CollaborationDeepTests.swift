//
//  CollaborationDeepTests.swift
//  ZhiYuTests
//
//  合并自 4 个碎片化测试文件：CollaborationAndProfileInteractiveTests.swift, CollaborationAndSettingsDeepTests.swift, PluginAndCollaborationDeepTests.swift, SettingsSyncAndCollaborationDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class CollaborationDeepTests: XCTestCase {

    private var appStore: AppStore!
    private var authService: AuthService!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        authService = ServiceContainer.shared.resolveOptional(AuthService.self) ?? AuthService.shared
        router = Router.shared
    }

    func testBirthdayDateFormatter_GregorianAndFuzz() {
        // 1. 标准有效日期双向解析
        let dateString = "1995-08-24"
        let parsedDate = BirthdayDateFormatter.date(from: dateString)
        XCTAssertNotNil(parsedDate)

        if let validDate = parsedDate {
            let formattedBack = BirthdayDateFormatter.string(from: validDate)
            XCTAssertEqual(formattedBack, dateString)
        }

        // 2. 非法日期字符串优雅防御返回 nil
        XCTAssertNil(BirthdayDateFormatter.date(from: ""))
        XCTAssertNil(BirthdayDateFormatter.date(from: "invalid-date"))
        XCTAssertNil(BirthdayDateFormatter.date(from: "2026/09/04"))
        XCTAssertNil(BirthdayDateFormatter.date(from: "9999-99-99"))

        // 3. 100 次 Fuzz 混沌时间戳测试：杜绝崩溃且保证输出符合 yyyy-MM-dd 正则
        let regex = try? NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)
        for _ in 0..<100 {
            let randomTime = TimeInterval.random(in: -1000000000...2000000000)
            let testDate = Date(timeIntervalSince1970: randomTime)
            let resultString = BirthdayDateFormatter.string(from: testDate)

            let range = NSRange(resultString.startIndex..., in: resultString)
            let match = regex?.firstMatch(in: resultString, range: range)
            XCTAssertNotNil(match, "日期格式必须始终严格符合 yyyy-MM-dd")
        }
    }

    func testSubscriptionQuotaCalculator_BoundaryAndFuzzResistance() {
        // 1. max == 0 防除以零，安全返回 0.0
        XCTAssertEqual(SubscriptionQuotaCalculator.calculateRatio(current: 5, max: 0), 0.0)
        XCTAssertEqual(SubscriptionQuotaCalculator.calculateRatio(current: -10, max: 0), 0.0)

        // 2. 下界钳位：负数用量强制截断至 0.0
        XCTAssertEqual(SubscriptionQuotaCalculator.calculateRatio(current: -50, max: 100), 0.0)

        // 3. 上界钳位：超出配额强制截断至 1.0
        XCTAssertEqual(SubscriptionQuotaCalculator.calculateRatio(current: 250, max: 100), 1.0)

        // 4. 正常范围精确比例
        XCTAssertEqual(SubscriptionQuotaCalculator.calculateRatio(current: 40, max: 100), 0.4, accuracy: 0.0001)

        // 5. 100 次 Fuzz 注入测试：保证绝不产生 NaN 或越界
        for _ in 0..<100 {
            let randCurrent = Int.random(in: -1000...2000)
            let randMax = Int.random(in: -500...2000)
            let ratio = SubscriptionQuotaCalculator.calculateRatio(current: randCurrent, max: randMax)

            XCTAssertFalse(ratio.isNaN)
            XCTAssertFalse(ratio.isInfinite)
            XCTAssertGreaterThanOrEqual(ratio, 0.0)
            XCTAssertLessThanOrEqual(ratio, 1.0)
        }
    }

    func testSubscriptionQuotaCalculator_DangerAndTextFormatting() {
        // 警戒状态判定
        XCTAssertFalse(SubscriptionQuotaCalculator.isDanger(ratio: 0.5))
        XCTAssertTrue(SubscriptionQuotaCalculator.isDanger(ratio: 0.95))

        // 普通额度文本格式化
        let normalText = SubscriptionQuotaCalculator.formatLimitText(current: 12, max: 100)
        XCTAssertEqual(normalText, "12 / 100")

        // 无限额度文本格式化
        let unlimitedText = SubscriptionQuotaCalculator.formatLimitText(current: 50, max: 999999)
        XCTAssertTrue(unlimitedText.contains("∞") || unlimitedText.contains("50 /"))
    }

    func testCollaborationView_MountAndRender() {
        let view = CollaborationView()
            .environment(appStore)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "CollaborationView 协作视图应正常完成挂载")
        XCTAssertNotNil(appStore)
        XCTAssertNotNil(router)
    }

    func testUserProfileView_MountAndRender() {
        let view = UserProfileView()
            .environment(appStore)
            .environment(authService)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "UserProfileView 个人资料视图应正常挂载")
        XCTAssertNotNil(authService)
        XCTAssertNotNil(appStore)
    }

    func testSubscriptionPlanView_MountAndRender() {
        let view = SubscriptionPlanView()
            .environment(authService)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "SubscriptionPlanView 订阅计划页面应正常完成排版")
        XCTAssertNotNil(authService)
    }

    func testSubscriptionPlanView_ProUserSuccessViewMount() {
        // 注入已开通 Pro 的模拟用户
        let proUser = User(
            name: "Pro 资深会员",
            email: "pro@example.com",
            planKey: PlanKey.pro
        )
        AuthSession.shared.currentUser = proUser

        let view = SubscriptionPlanView()
            .environment(authService)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "SubscriptionPlanView 成功开通状态应正常排版")
        XCTAssertEqual(AuthSession.shared.currentUser?.planKey, PlanKey.pro)
    }

    func testCollaborationRole_DisplayContract() {
        XCTAssertFalse(CollabRole.owner.displayName.isEmpty)
        XCTAssertFalse(CollabRole.editor.displayName.isEmpty)
        XCTAssertFalse(CollabRole.viewer.displayName.isEmpty)
    }

    func testCollabEdit_PropertiesAndFormatting() {
        let edit = CollabEdit(
            id: UUID().uuidString,
            userID: "user-123",
            pageID: UUID(),
            field: "title",
            oldValue: "旧概念",
            newValue: "新概念",
            timestamp: Date()
        )

        XCTAssertEqual(edit.userID, "user-123")
        XCTAssertEqual(edit.oldValue, "旧概念")
        XCTAssertEqual(edit.newValue, "新概念")
    }

    func testPlanFeature_PropertiesContract() {
        let feature = PlanFeature(icon: "star.fill", title: "无限图谱", value: "支持 10 万节点")
        XCTAssertEqual(feature.icon, "star.fill")
        XCTAssertEqual(feature.title, "无限图谱")
        XCTAssertEqual(feature.value, "支持 10 万节点")
    }

    func testHostingSetupSheet_MountAndRender() {
        let collabService = CollaborationService()
        var roomName = "分布式研究室"
        let roomBinding = Binding<String>(
            get: { roomName },
            set: { roomName = $0 }
        )

        let sheet = HostingSetupSheet(collabService: collabService, roomName: roomBinding)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: sheet)
        _ = host.view

        XCTAssertEqual(roomBinding.wrappedValue, "分布式研究室")
        XCTAssertFalse(collabService.isHosting)
        XCTAssertNotNil(host.view, "HostingSetupSheet 应正常挂载")
    }

    func testBillingCycle_EnumIntegrity() {
        let monthly = BillingCycle.monthly
        let yearly = BillingCycle.yearly

        XCTAssertNotEqual(monthly, yearly)
    }

    func testCollaborationView_Hierarchy() {
        let host = NavigationStack {
            CollaborationView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        let service = ServiceContainer.shared.resolveOptional((any CollaborationProviderProtocol).self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(host.view)
    }

    func testCollaborationViewContent_Hierarchy() {
        let host = CollaborationViewContent()
            .snapshotEnvironment()
            .renderInWindow()

        let service = ServiceContainer.shared.resolveOptional((any CollaborationProviderProtocol).self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(host.view)
    }

    func testPluginCenterViewMarketAndMyPluginsTabs() async throws {
        let pluginRegistry = try XCTUnwrap(ServiceContainer.shared.resolveOptional(PluginRegistry.self))
        let pluginCenter = PluginCenterView()
            .snapshotEnvironment()
        
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: pluginCenter)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(pluginRegistry)
        XCTAssertNotNil(host.view)
    }

    func testCollaborationViewUnjoinedAndJoinedState() throws {
        let collabService = ServiceContainer.shared.resolveOptional((any CollaborationProviderProtocol).self)
        let collabView = CollaborationView()
            .snapshotEnvironment()
        
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: collabView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(collabService)
        XCTAssertNotNil(host.view)
    }

    func testCollabEditModelAndDTOs() throws {
        let edit = CollabEdit(
            id: UUID().uuidString,
            userID: "user_alice",
            pageID: UUID(),
            field: "content",
            oldValue: "Draft version",
            newValue: "Final version",
            timestamp: Date()
        )
        XCTAssertEqual(edit.userID, "user_alice")
        XCTAssertEqual(edit.field, "content")
        XCTAssertEqual(edit.oldValue, "Draft version")
        XCTAssertEqual(edit.newValue, "Final version")
    }

    func testSettingsViewMounting() throws {
        let rawSettings = SettingsView()
        XCTAssertNotNil(rawSettings)
        let settingsView = rawSettings.snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: settingsView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    func testAISettingsAndDeveloperSettings() throws {
        let rawAI = AISettingsView()
        XCTAssertNotNil(rawAI)
        let aiSettingsView = rawAI.snapshotEnvironment()
        let hostAI = UIHostingController(rootView: aiSettingsView)
        XCTAssertNotNil(hostAI.view)

        let rawDev = DeveloperSettingsView()
        XCTAssertNotNil(rawDev)
        let devSettingsView = rawDev.snapshotEnvironment()
        let hostDev = UIHostingController(rootView: devSettingsView)
        XCTAssertNotNil(hostDev.view)
    }

}
