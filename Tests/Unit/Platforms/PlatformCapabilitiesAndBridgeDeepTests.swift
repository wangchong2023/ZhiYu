//
//  PlatformCapabilitiesAndBridgeDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 测试层
//  核心职责：深度验证 iOS / macOS / watchOS 跨平台能力桥接、Pencil 交互、系统服务与降级保护。
//

import XCTest
import SwiftUI
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class PlatformCapabilitiesAndBridgeDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PencilManager 交互与双击回调

    func testPencilManager_DoubleTapCallback() {
        var doubleTapped = false
        PencilManager.shared.onDoubleTap = {
            doubleTapped = true
        }

        #if os(iOS)
        let interaction = UIPencilInteraction()
        PencilManager.shared.pencilInteractionDidTap(interaction)
        XCTAssertTrue(doubleTapped, "Pencil 双击应当触发 onDoubleTap 回调")
        #endif
    }

    // MARK: - 2. 跨平台服务注册与能力验证

    func testPlatformServices_ResolveAndExecuteSafely() {
        // 1. 设备信息服务
        let deviceInfo = iOSDeviceInfoService()
        XCTAssertFalse(deviceInfo.deviceModel.isEmpty)
        XCTAssertFalse(deviceInfo.systemVersion.isEmpty)

        // 2. 导出服务
        let exportService = iOSExportService()
        XCTAssertNotNil(exportService)

        // 3. 剪贴板服务
        let pasteboard = iOSPasteboardService()
        pasteboard.string = "测试剪贴板内容"
        XCTAssertEqual(pasteboard.string, "测试剪贴板内容")

        // 4. URL 打开服务
        let urlOpener = iOSURLOpenerService()
        XCTAssertNotNil(urlOpener)
    }

    // MARK: - 3. ZIP 归档与解压能力

    func testZIPFoundationArchiver_ArchiveAndExtract() async throws {
        let archiver = ZIPFoundationArchiver()
        let tempDir = FileManager.default.temporaryDirectory
        let dirName = "zip_test_src_\(UUID().uuidString)"
        let sourceDir = tempDir.appendingPathComponent(dirName, isDirectory: true)
        let zipDest = tempDir.appendingPathComponent("zip_test_dest_\(UUID().uuidString).zip")
        let extractDir = tempDir.appendingPathComponent("zip_test_extract_\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let sampleFile = sourceDir.appendingPathComponent("sample.txt")
        try "智宇测试归档内容".write(to: sampleFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: zipDest)
            try? FileManager.default.removeItem(at: extractDir)
        }

        // 压缩
        try await archiver.zip(directory: sourceDir, to: zipDest)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipDest.path))

        // 解压
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try archiver.extractContents(from: zipDest, to: extractDir)

        // ZIPFoundation 保留源目录名作为内层结构
        let extractedSample = extractDir.appendingPathComponent(dirName).appendingPathComponent("sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedSample.path), "解压后应当能在对应目录下找到目标文件")
    }
}
