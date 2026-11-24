//
//  StorageIsolationUITests.swift
//  ZhiYuUITests
//
//  系统层级：[Tests] UI 自动化
//  核心职责：从真实测试应用进程验证 bundle、数据库与文件目录的隔离。
//
import XCTest

@MainActor
final class StorageIsolationUITests: XCTestCase {
    private enum Expected {
        #if os(macOS)
        static let bundleID = "top.izhiyu.testing.mac.ui"
        #else
        static let bundleID = "top.izhiyu.testing.ui"
        #endif
        static let rootComponent = "ZhiYuUITestStorage"
        static let probeArgument = "--verify-storage-isolation"
        static let timeout: TimeInterval = 20
    }

    func testStorageRemainsIsolatedAcrossApplicationLaunches() {
        let app = XCUIApplication()
        app.launchArguments = [Expected.probeArgument, "--uitesting", "-UITest_MockData", "--skip-onboarding"]
        defer { app.terminate() }
        app.launch()
        let firstRoot = verifyStorage(in: app)
        app.terminate()
        app.launch()
        let secondRoot = verifyStorage(in: app)
        XCTAssertNotEqual(firstRoot, secondRoot, "每次启动必须获得新的独立临时目录")
    }

    private func verifyStorage(in app: XCUIApplication) -> String {
        let bundle = app.staticTexts["isolation.bundle"]
        XCTAssertTrue(bundle.waitForExistence(timeout: Expected.timeout))
        XCTAssertEqual(bundle.label, Expected.bundleID)
        XCTAssertEqual(app.staticTexts["isolation.keychain"].label, "memory")
        XCTAssertEqual(app.staticTexts["isolation.mode"].label, "memory")
        XCTAssertEqual(app.staticTexts["isolation.database"].label, "none")
        XCTAssertEqual(app.staticTexts["isolation.globalDatabase"].label, "none")
        let root = app.staticTexts["isolation.root"].label
        XCTAssertTrue(URL(fileURLWithPath: root).pathComponents.contains(Expected.rootComponent))
        return root
    }
}
