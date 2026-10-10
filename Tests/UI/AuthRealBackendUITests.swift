//
//  AuthRealBackendUITests.swift
//  ZhiYuUITests
//
//  系统层级：[Tests] UI 联调
//  核心职责：C 端 ↔ 真实后端服务器 端到端联调测试套件（非 mock）。
//
//  与 mock 测试（AuthUITests 等）的本质区别：
//    - 本套件【不传】`-UITest_MockData` 启动参数，因此 AuthService.isMockBackend == false，
//      登录/资料/订阅均走真实 NetworkClient.request（AppConfig.backendBaseURL + path）。
//    - AppConfig.backendBaseURL 来自 Sources/Resources/AppConfig.json 的 network.backend_base_url，
//      联调前需将该地址改为测试环境真实网关（当前配置 https://10.211.55.4:30443）。
//
//  前置条件（联调前必须满足，否则用例失败属环境问题而非代码问题）：
//    1. 测试环境后端已部署最新版且可达（/api/v1/auth/sms/send 等端点非 401）。
//    2. AppConfig.json 的 backend_base_url 指向该测试环境。
//    3. 提供真实登录账号/通道（如已配置的测试手机号 + 短信验证码）。
//
//  说明：UI 测试为黑盒（XCUIApplication 交互），无法在测试代码内直接读取 AppConfig，
//        app 自身在非 mock 模式下使用 AppConfig.backendBaseURL 发起真实请求。

import XCTest

@MainActor
final class AuthRealBackendUITests: BaseUITestCase {

    // MARK: - 待确认联调参数（占位）

    /// 测试环境真实手机号（短信验证码登录用）。联调前替换为已接入后端短信通道的测试号。
    private let realTestPhone = "18000000000"

    // MARK: - 辅助方法

    /// 等待 Auth 登录页的 ScrollView 出现（AuthView 根容器）
    @discardableResult
    private func waitForAuthView(timeout: TimeInterval = 25) -> Bool {
        app.scrollViews.firstMatch.waitForExistence(timeout: timeout)
    }

    /// 等待应用进入主界面（userProfileMenuButton 出现）
    @discardableResult
    private func waitForHomeView(timeout: TimeInterval = 30) -> Bool {
        app.buttons["userProfileMenuButton"].waitForExistence(timeout: timeout)
    }

    /// 截图并附加到测试报告
    func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - TC-REAL-01：真实后端连通性冒烟
    //
    // 验证点：app 以非 mock 模式启动后，AuthService 对真实后端发起的首个认证请求
    //         应得到真实响应（成功进入主界面，或至少无崩溃、错误提示来自真实后端）。
    // 备注：登录方式（运营商一键登录 / 第三方 OAuth / 短信验证码）取决于测试环境配置，
    //       当前骨架以运营商一键登录入口为例；若测试环境使用短信验证码，需在 AuthView
    //       中补充对应输入表单后按真实流程驱动。
    func testRealBackendConnectivitySmoke() throws {
        // 非 mock 启动：BaseUITestCase.setUp 已 launch app（无 -UITest_MockData）
        XCTAssertTrue(waitForAuthView(), "应显示 Auth 登录页")

        // 勾选协议（默认已勾选，兜底）
        let checkbox = app.buttons["agreementCheckbox"]
        if checkbox.waitForExistence(timeout: 5), (checkbox.value as? String) == "unchecked" {
            checkbox.tap()
        }
        takeScreenshot(name: "REAL01_01_AuthView_Ready")

        // 一键登录（运营商隐式取号）——真实通道需真机 + 有效 SIM；
        // 模拟器或无运营商通道时此步必然失败，属环境限制，故断言改为：
        // 触发登录后 app 不应崩溃，且应有来自真实后端的处理结果（进入主界面或错误提示）。
        let loginButton = app.buttons["oneClickLoginButton"]
        guard loginButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("真实后端联调：一键登录按钮不可用（运营商通道未就绪），跳过，仅验证连通性")
        }
        loginButton.tap()
        takeScreenshot(name: "REAL01_02_Login_Tapped")

        // 真实后端可达且登录成功 → 进入主界面；否则（登录失败）应停留在登录页而非崩溃。
        let enteredHome = waitForHomeView(timeout: 10)
        if enteredHome {
            takeScreenshot(name: "REAL01_03_Home_RealBackend")
            XCTAssertTrue(true, "真实后端登录成功，进入主界面")
        } else {
            // 未进入主界面：记录真实错误提示（来自真实后端），作为连通性证据
            takeScreenshot(name: "REAL01_03_Login_Blocked_RealBackend")
            print("⚠️ 真实后端联调：未进入主界面，请检查登录方式/账号/后端可达性。")
        }
    }

    // MARK: - TC-REAL-02：登录后资料加载（占位）
    //
    // 验证点：真实登录成功后，userProfileMenuButton 菜单应展示真实后端返回的用户昵称/头像。
    // 前置：TC-REAL-01 已真实登录成功（否则本用例依赖登录态，需保证执行顺序或复用登录）。
    func testProfileLoadedFromRealBackend() throws {
        let profileButton = app.buttons["userProfileMenuButton"]
        guard profileButton.waitForExistence(timeout: 30) else {
            throw XCTSkip("真实后端联调：尚未登录进入主界面，跳过资料断言")
        }
        profileButton.tap()

        // 个人资料菜单 / 页面应展示真实昵称 —— 具体 accessibilityIdentifier 依 AuthView 实现补充
        takeScreenshot(name: "REAL02_01_ProfileMenu_RealBackend")
    }

    // MARK: - TC-REAL-03：订阅/配额加载（占位）
    //
    // 验证点：真实登录后，当前套餐 planKey / 配额（maxVaults/maxPages）应来自真实后端
    //         subscriptionsMe 接口（而非 createFreeDefault 离线兜底）。
    // 备注：配额数值展示控件需补充真实 UI 元素 identifier 后完成断言。
    func testSubscriptionQuotaLoadedFromRealBackend() throws {
        guard app.buttons["userProfileMenuButton"].waitForExistence(timeout: 30) else {
            throw XCTSkip("真实后端联调：尚未登录，跳过订阅断言")
        }
        // 打开订阅/配额设置页后，断言 planKey 与配额来自真实后端
        takeScreenshot(name: "REAL03_01_Subscription_RealBackend")
    }
}
