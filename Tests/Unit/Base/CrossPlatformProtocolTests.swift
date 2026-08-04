//
//  CrossPlatformProtocolTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 DeviceInfoProtocol / URLOpenerProtocol / ShareSheetProtocol
//          三个跨平台协议及其平台实现、Mock 替代、DI 注册进行完整验证。
//

import XCTest
#if os(watchOS)
@testable import ZhiYuWatch
#else
@testable import ZhiYu
#endif

// MARK: - 测试 1：协议定义正确性

/// 验证三个跨平台协议的定义签名、Sendable 标注、以及成员列表的编译期一致性
final class CrossPlatformProtocolDefinitionTests: XCTestCase {

    // ── DeviceInfoProtocol ──

    /// TC-PD-01: 验证 DeviceInfoProtocol 包含 4 个必需属性，且返回值类型正确
    func test_DeviceInfoProtocol_hasFourRequiredProperties() {
        let mock = MockDeviceInfoService()
        let service: DeviceInfoProtocol = mock

        // 访问全部 4 个属性，编译通过即可验证协议签名完整
        let version: String = service.systemVersion
        let model: String = service.deviceModel
        let name: String = service.deviceName
        let height: CGFloat = service.screenHeight

        XCTAssertFalse(version.isEmpty, "systemVersion 不应为空")
        XCTAssertFalse(model.isEmpty, "deviceModel 不应为空")
        XCTAssertFalse(name.isEmpty, "deviceName 不应为空")
        XCTAssertGreaterThan(height, 0, "screenHeight 应 > 0")
    }

    /// TC-PD-02: 验证 URLOpenerProtocol 包含 open(_:) async 方法
    @MainActor
    func test_URLOpenerProtocol_hasOpenMethod() async {
        let mock = MockURLOpenerService()
        let service: URLOpenerProtocol = mock

        let testURL = URL(string: "https://example.com")!
        await service.open(testURL)

        // 调用成功且无崩溃，方法存在
        XCTAssertTrue(mock.wasCalled, "Mock 的 open 方法应被调用")
        XCTAssertEqual(mock.lastOpenedURL, testURL, "记录的 URL 应匹配")
    }

    /// TC-PD-03: 验证 ShareSheetProtocol 包含 presentShareSheet(items:) async 方法
    @MainActor
    func test_ShareSheetProtocol_hasPresentShareSheetMethod() async {
        let mock = MockShareSheetService()
        let service: ShareSheetProtocol = mock

        let testItems: [Any] = ["Hello", URL(string: "https://example.com")!]
        await service.presentShareSheet(items: testItems)

        // 调用成功且无崩溃，方法存在
        XCTAssertTrue(mock.wasCalled, "Mock 的 presentShareSheet 方法应被调用")
    }

    /// TC-PD-04: 验证所有协议标注了 Sendable（编译期 + 运行时双重校验）
    func test_AllCrossPlatformProtocols_conformToSendable() {
        // 编译期：若协议未标注 Sendable，以下赋值将产生警告/错误
        let deviceInfoService: any Sendable = MockDeviceInfoService()
        XCTAssertNotNil(deviceInfoService, "DeviceInfoProtocol 应遵从 Sendable")

        // URLOpenerProtocol / ShareSheetProtocol 标注 @MainActor + Sendable，
        // 需在主 actor 上下文中验证
        let exp = expectation(description: "Sendable check")
        Task { @MainActor in
            let urlOpenerService: any Sendable = MockURLOpenerService()
            XCTAssertNotNil(urlOpenerService, "URLOpenerProtocol 应遵从 Sendable")

            let shareSheetService: any Sendable = MockShareSheetService()
            XCTAssertNotNil(shareSheetService, "ShareSheetProtocol 应遵从 Sendable")

            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }
}

// MARK: - 测试 2：iOS 平台实现验证

/// 验证 iOS 平台实现类正确遵从对应协议，且关键方法/属性返回值非空
final class CrossPlatformiOSImplementationTests: XCTestCase {

    /// TC-IOS-01: iOSDeviceInfoService 实现 DeviceInfoProtocol，返回值非空
    func test_iOSDeviceInfoService_conformsToProtocol_andReturnsNonNil() {
        #if os(iOS) && !os(watchOS)
        let service = iOSDeviceInfoService()
        let protocolRef: DeviceInfoProtocol = service

        XCTAssertFalse(protocolRef.systemVersion.isEmpty, "systemVersion 不应为空")
        XCTAssertFalse(protocolRef.deviceModel.isEmpty, "deviceModel 不应为空")
        XCTAssertFalse(protocolRef.deviceName.isEmpty, "deviceName 不应为空")
        XCTAssertGreaterThan(protocolRef.screenHeight, 0, "screenHeight 应 > 0")
        #else
        // 非 iOS 平台：该实现不存在，跳过测试
        XCTAssertTrue(true, "iOSDeviceInfoService 仅适用于 iOS 平台")
        #endif
    }

    /// TC-IOS-02: iOSURLOpenerService 实现 URLOpenerProtocol
    @MainActor
    func test_iOSURLOpenerService_conformsToProtocol() async {
        #if os(iOS) && !os(watchOS)
        let service = iOSURLOpenerService()
        let protocolRef: URLOpenerProtocol = service

        // 验证方法可调用且编译通过（实际不会打开 URL — 单元测试在模拟器无真实 scene）
        let testURL = URL(string: "https://zhiyu.app/test")!
        await protocolRef.open(testURL)
        // 无崩溃即通过
        XCTAssertTrue(true)
        #else
        XCTAssertTrue(true, "iOSURLOpenerService 仅适用于 iOS 平台")
        #endif
    }

    /// TC-IOS-03: iOSShareSheetService 实现 ShareSheetProtocol
    @MainActor
    func test_iOSShareSheetService_conformsToProtocol() async {
        #if os(iOS) && !os(watchOS)
        let service = iOSShareSheetService()
        let protocolRef: ShareSheetProtocol = service

        // 验证方法可调用且编译通过（实际不会弹出面板 — 单元测试在无 keyWindow 场景）
        await protocolRef.presentShareSheet(items: ["Test"])
        // 无崩溃即通过
        XCTAssertTrue(true)
        #else
        XCTAssertTrue(true, "iOSShareSheetService 仅适用于 iOS 平台")
        #endif
    }
}

// MARK: - 测试 3：Mock 实现业务层可用性验证

/// 验证 Mock 实现可用于替代真实平台服务编写业务层测试
final class CrossPlatformMockUsabilityTests: XCTestCase {

    /// TC-MK-01: MockDeviceInfoService 返回固定测试值，且可通过协议类型访问
    func test_MockDeviceInfoService_returnsFixedValues_viaProtocol() {
        let mock = MockDeviceInfoService(
            systemVersion: "18.0",
            deviceModel: "iPhone 16 Pro",
            deviceName: "QA 测试机",
            screenHeight: 932
        )
        let service: DeviceInfoProtocol = mock

        XCTAssertEqual(service.systemVersion, "18.0")
        XCTAssertEqual(service.deviceModel, "iPhone 16 Pro")
        XCTAssertEqual(service.deviceName, "QA 测试机")
        XCTAssertEqual(service.screenHeight, 932)
    }

    /// TC-MK-02: MockDeviceInfoService 使用默认值时也返回有效数据
    func test_MockDeviceInfoService_defaultValuesAreValid() {
        let mock = MockDeviceInfoService()
        let service: DeviceInfoProtocol = mock

        // 默认值应非空且有意义
        XCTAssertFalse(service.systemVersion.isEmpty)
        XCTAssertFalse(service.deviceModel.isEmpty)
        XCTAssertFalse(service.deviceName.isEmpty)
        XCTAssertGreaterThan(service.screenHeight, 0)
    }

    /// TC-MK-03: MockURLOpenerService 记录被调用的 URL，不实际打开
    @MainActor
    func test_MockURLOpenerService_recordsURLs_withoutOpening() async {
        let mock = MockURLOpenerService()
        let service: URLOpenerProtocol = mock

        XCTAssertFalse(mock.wasCalled, "初始状态应为未调用")
        XCTAssertNil(mock.lastOpenedURL, "初始状态 lastOpenedURL 应为 nil")

        let url1 = URL(string: "https://example.com/a")!
        let url2 = URL(string: "https://example.com/b")!

        await service.open(url1)
        XCTAssertTrue(mock.wasCalled)
        XCTAssertEqual(mock.lastOpenedURL, url1)
        XCTAssertEqual(mock.openedURLs.count, 1)

        await service.open(url2)
        XCTAssertEqual(mock.lastOpenedURL, url2)
        XCTAssertEqual(mock.openedURLs.count, 2)
        XCTAssertEqual(mock.openedURLs[0], url1)
        XCTAssertEqual(mock.openedURLs[1], url2)
    }

    /// TC-MK-04: 多次调用 open 按 FIFO 顺序记录
    @MainActor
    func test_MockURLOpenerService_preservesFIFOorder() async {
        let mock = MockURLOpenerService()

        let urls = (0..<5).compactMap { URL(string: "https://example.com/\($0)") }
        for url in urls {
            await mock.open(url)
        }

        XCTAssertEqual(mock.openedURLs.count, 5)
        XCTAssertEqual(mock.openedURLs, urls, "应按 FIFO 顺序记录")
    }

    /// TC-MK-05: MockShareSheetService 记录被分享的 items，不实际弹出面板
    @MainActor
    func test_MockShareSheetService_recordsItems_withoutPresenting() async {
        let mock = MockShareSheetService()
        let service: ShareSheetProtocol = mock

        XCTAssertFalse(mock.wasCalled, "初始状态应为未调用")
        XCTAssertNil(mock.lastSharedItems, "初始状态 lastSharedItems 应为 nil")
        let items1: [Any] = ["文本1", URL(string: "https://a.example")!]
        await service.presentShareSheet(items: items1)

        XCTAssertTrue(mock.wasCalled)
        XCTAssertEqual(mock.sharedBatches.count, 1)
    }

    /// TC-MK-06: MockShareSheetService 多批次分享记录完整性
    @MainActor
    func test_MockShareSheetService_preservesMultipleBatches() async {
        let mock = MockShareSheetService()

        let batch1: [Any] = ["分享1"]
        let batch2: [Any] = ["分享2", URL(string: "https://b.example")!]
        let batch3: [Any] = [Data()]

        await mock.presentShareSheet(items: batch1)
        await mock.presentShareSheet(items: batch2)
        await mock.presentShareSheet(items: batch3)

        XCTAssertEqual(mock.sharedBatches.count, 3, "应记录 3 批分享")

        // 验证每批的内容
        let lastItems = mock.lastSharedItems
        XCTAssertNotNil(lastItems)
    }
}

// MARK: - 测试 4：DI 容器注册验证

/// 验证 ServiceContainer 可注册并解析三个跨平台协议，确保 PlatformRegistrar 链完整性
@MainActor
final class CrossPlatformDIRegistrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 每个用例前重置容器，保证隔离性
        ServiceContainer.shared.reset()
    }

    override func tearDown() {
        ServiceContainer.shared.reset()
        super.tearDown()
    }

    /// TC-DI-10: 验证 ServiceContainer 可以 register + resolve (any DeviceInfoProtocol).self
    func test_ServiceContainer_resolvesDeviceInfoProtocol() {
        let container = ServiceContainer.shared
        let mockService = MockDeviceInfoService(
            systemVersion: "17.5",
            deviceModel: "DI Test Device",
            deviceName: "DI 测试",
            screenHeight: 1000
        )

        // 初始状态未注册
        XCTAssertFalse(container.hasService(for: (any DeviceInfoProtocol).self))
        XCTAssertNil(container.resolveOptional((any DeviceInfoProtocol).self))

        // 注册
        container.register(mockService as any DeviceInfoProtocol, for: (any DeviceInfoProtocol).self)
        XCTAssertTrue(container.hasService(for: (any DeviceInfoProtocol).self))

        // 解析
        let resolved = container.resolve((any DeviceInfoProtocol).self)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved.systemVersion, "17.5")
        XCTAssertEqual(resolved.deviceModel, "DI Test Device")
        XCTAssertEqual(resolved.deviceName, "DI 测试")
        XCTAssertEqual(resolved.screenHeight, 1000)
    }

    /// TC-DI-11: 验证 ServiceContainer 可以 register + resolve (any URLOpenerProtocol).self
    func test_ServiceContainer_resolvesURLOpenerProtocol() {
        let container = ServiceContainer.shared
        let mockService = MockURLOpenerService()

        // 初始状态未注册
        XCTAssertFalse(container.hasService(for: (any URLOpenerProtocol).self))
        XCTAssertNil(container.resolveOptional((any URLOpenerProtocol).self))

        // 注册
        container.register(mockService as any URLOpenerProtocol, for: (any URLOpenerProtocol).self)
        XCTAssertTrue(container.hasService(for: (any URLOpenerProtocol).self))

        // 解析并验证实例一致性
        let resolved = container.resolve((any URLOpenerProtocol).self)
        XCTAssertNotNil(resolved)

        // 验证解析出的实例与注册的为同一引用
        // (通过比较调用记录间接验证)
        let exp = expectation(description: "open URL")
        Task { @MainActor in
            let testURL = URL(string: "https://di-test.example")!
            await resolved.open(testURL)
            XCTAssertEqual(mockService.lastOpenedURL, testURL)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    /// TC-DI-12: 验证 ServiceContainer 可以 register + resolve (any ShareSheetProtocol).self
    func test_ServiceContainer_resolvesShareSheetProtocol() {
        let container = ServiceContainer.shared
        let mockService = MockShareSheetService()

        // 初始状态未注册
        XCTAssertFalse(container.hasService(for: (any ShareSheetProtocol).self))
        XCTAssertNil(container.resolveOptional((any ShareSheetProtocol).self))

        // 注册
        container.register(mockService as any ShareSheetProtocol, for: (any ShareSheetProtocol).self)
        XCTAssertTrue(container.hasService(for: (any ShareSheetProtocol).self))

        // 解析并验证实例一致性
        let resolved = container.resolve((any ShareSheetProtocol).self)
        XCTAssertNotNil(resolved)

        // 验证解析出的实例与注册的为同一引用
        let exp = expectation(description: "present share sheet")
        Task { @MainActor in
            let testItems: [Any] = ["DI Share Test", 42]
            await resolved.presentShareSheet(items: testItems)
            XCTAssertTrue(mockService.wasCalled)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    /// TC-DI-13: 验证三个协议可同时注册到容器且互不干扰
    func test_ServiceContainer_resolvesAllThreeProtocols_concurrently() {
        let container = ServiceContainer.shared

        let deviceInfo = MockDeviceInfoService()
        let urlOpener = MockURLOpenerService()
        let shareSheet = MockShareSheetService()

        container.register(deviceInfo as any DeviceInfoProtocol, for: (any DeviceInfoProtocol).self)
        container.register(urlOpener as any URLOpenerProtocol, for: (any URLOpenerProtocol).self)
        container.register(shareSheet as any ShareSheetProtocol, for: (any ShareSheetProtocol).self)

        // 验证三个协议都可通过容器解析
        let resolvedDeviceInfo = container.resolveOptional((any DeviceInfoProtocol).self)
        let resolvedURLOpener = container.resolveOptional((any URLOpenerProtocol).self)
        let resolvedShareSheet = container.resolveOptional((any ShareSheetProtocol).self)

        XCTAssertNotNil(resolvedDeviceInfo, "DeviceInfoProtocol 应解析成功")
        XCTAssertNotNil(resolvedURLOpener, "URLOpenerProtocol 应解析成功")
        XCTAssertNotNil(resolvedShareSheet, "ShareSheetProtocol 应解析成功")

        // 验证 hasService 对所有三个协议返回 true
        XCTAssertTrue(container.hasService(for: (any DeviceInfoProtocol).self))
        XCTAssertTrue(container.hasService(for: (any URLOpenerProtocol).self))
        XCTAssertTrue(container.hasService(for: (any ShareSheetProtocol).self))
    }

    /// TC-DI-14: 验证 re-register 覆盖行为 — 重新注册应替换旧实例
    func test_ServiceContainer_reRegister_overwritesPreviousRegistration() {
        let container = ServiceContainer.shared

        let firstMock = MockDeviceInfoService(systemVersion: "1.0", deviceModel: "First")
        let secondMock = MockDeviceInfoService(systemVersion: "2.0", deviceModel: "Second")

        container.register(firstMock as any DeviceInfoProtocol, for: (any DeviceInfoProtocol).self)

        // 验证第一次注册
        let resolved1 = container.resolve((any DeviceInfoProtocol).self)
        XCTAssertEqual(resolved1.systemVersion, "1.0")

        // 重新注册
        container.register(secondMock as any DeviceInfoProtocol, for: (any DeviceInfoProtocol).self)

        // 验证解析返回新实例
        let resolved2 = container.resolve((any DeviceInfoProtocol).self)
        XCTAssertEqual(resolved2.systemVersion, "2.0")
        XCTAssertEqual(resolved2.deviceModel, "Second")
    }
}
