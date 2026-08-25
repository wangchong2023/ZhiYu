//
//  IOSURLOpenerServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSURLOpenerService 单元测试，覆盖 URL 打开与协议一致性场景。
//
//  D-35 修复：使用闭包注入模式，避免模拟器触发真实 UIApplication.open 阻塞。
//

#if os(iOS) && !os(watchOS)
import XCTest
@testable import ZhiYu

@MainActor
final class IOSURLOpenerServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let httpsURL: String = "https://www.apple.com"
        static let invalidSchemeURL: String = "zhiyu://nonexistent/path"
    }

    // MARK: - 可变引用容器（解决闭包捕获值类型问题）

    /// 使用引用类型包装，确保闭包内的 append 对外部可见
    private final class URLRecorder: @unchecked Sendable {
        private var urls: [URL] = []
        func append(_ url: URL) { urls.append(url) }
        var recorded: [URL] { urls }
    }

    // MARK: - 测试工厂方法

    /// 构造使用 Mock 闭包的 iOSURLOpenerService，记录被调用的 URL
    private func makeService() -> (iOSURLOpenerService, URLRecorder) {
        let recorder = URLRecorder()
        let service = iOSURLOpenerService { url in
            recorder.append(url)
        }
        return (service, recorder)
    }

    // MARK: - open

    /// 打开 HTTPS URL 应将 URL 传递给 openHandler
    func testOpenHTTPSURLPassesURLToHandler() async {
        let (service, recorder) = makeService()
        guard let url = URL(string: TestConstants.httpsURL) else {
            XCTFail("测试 URL 构造失败")
            return
        }
        await service.open(url)
        XCTAssertEqual(recorder.recorded, [url], "open 应将 URL 传递给 handler")
    }

    /// 打开自定义 scheme URL 应将 URL 传递给 openHandler
    func testOpenCustomSchemeURLPassesURLToHandler() async {
        let (service, recorder) = makeService()
        guard let url = URL(string: TestConstants.invalidSchemeURL) else {
            XCTFail("测试 URL 构造失败")
            return
        }
        await service.open(url)
        XCTAssertEqual(recorder.recorded, [url], "open 应将自定义 scheme URL 传递给 handler")
    }

    /// 多次调用 open 应按顺序记录所有 URL
    func testOpenMultipleURLsRecordsAllInOrder() async {
        let (service, recorder) = makeService()
        guard let url1 = URL(string: TestConstants.httpsURL) else {
            XCTFail("测试 URL 构造失败")
            return
        }
        guard let url2 = URL(string: TestConstants.invalidSchemeURL) else {
            XCTFail("测试 URL 构造失败")
            return
        }
        await service.open(url1)
        await service.open(url2)
        XCTAssertEqual(recorder.recorded, [url1, url2], "应按顺序记录所有打开的 URL")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 URLOpenerProtocol
    func testConformsToURLOpenerProtocol() async {
        let recorder = URLRecorder()
        let service: any URLOpenerProtocol = iOSURLOpenerService { url in
            recorder.append(url)
        }
        guard let url = URL(string: TestConstants.httpsURL) else {
            XCTFail("测试 URL 构造失败")
            return
        }
        await service.open(url)
        XCTAssertEqual(recorder.recorded, [url], "协议转型与调用应成功")
    }

    /// NoOpURLOpener 调用应不崩溃
    func testNoOpURLOpenerDoesNotCrash() async {
        let noOp = NoOpURLOpener()
        guard let url = URL(string: TestConstants.httpsURL) else {
            XCTFail("测试 URL 构造失败")
            return
        }
        await noOp.open(url)
        XCTAssertTrue(true, "NoOpURLOpener 应正常执行")
    }

    /// 生产环境 init() 应可正常实例化（不调用 open，避免触发系统进程）
    func testProductionInitDoesNotCrash() {
        _ = iOSURLOpenerService()
    }
}
#endif
