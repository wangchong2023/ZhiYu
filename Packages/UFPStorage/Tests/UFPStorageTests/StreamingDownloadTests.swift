//
//  StreamingDownloadTests.swift
//  UFPStorageTests
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorageTests]
//  核心职责：测试通用 StreamingDownloadManager 的 SHA256 流式校验、速率采样、状态流与进度更新。
//

import XCTest
import CommonCrypto
@testable import UFPStorage

final class StreamingDownloadTests: XCTestCase {

    private var tempDirectory: URL!

    /// 测试用下载器：注入 ephemeral session 与临时目录，避免触网与沙盒污染。
    private func makeManager() -> StreamingDownloadManager {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectory = dir
        return StreamingDownloadManager(
            sessionFactory: { _ in URLSession(configuration: .ephemeral) },
            resumeDataDirectory: { dir },
            destinationURL: { taskID in dir.appendingPathComponent("\(taskID).bin") }
        )
    }

    override func setUp() {
        super.setUp()
        tempDirectory = nil
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - 辅助方法

    private func sha256Hex(of data: Data) -> String {
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256_Update(&context, buffer.baseAddress, CC_LONG(data.count))
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func firstState(from stream: AsyncStream<StreamingDownloadState>) async -> StreamingDownloadState? {
        for await state in stream {
            return state
        }
        return nil
    }

    // MARK: - 1. SHA256 流式校验边界

    func testVerifySHA256AcceptsEmptyChecksum() async {
        let manager = makeManager()
        let file = tempDirectory!.appendingPathComponent("empty.bin")
        try? Data("test content".utf8).write(to: file)

        let result = manager.verifySHA256(of: file, expectedHash: "")
        XCTAssertTrue(result, "空 checksum 应容灾放行")
    }

    func testVerifySHA256RejectsNonStandardLength() async {
        let manager = makeManager()
        let file = tempDirectory!.appendingPathComponent("short.bin")
        try? Data("test content".utf8).write(to: file)

        let result = manager.verifySHA256(of: file, expectedHash: "abc123")
        XCTAssertFalse(result, "非 64 字符 checksum 应拒绝校验")
    }

    func testVerifySHA256ReturnsFalseForNonExistentFile() async {
        let manager = makeManager()
        let file = tempDirectory!.appendingPathComponent("missing.bin")
        let checksum = String(repeating: "a", count: 64)

        let result = manager.verifySHA256(of: file, expectedHash: checksum)
        XCTAssertFalse(result, "不存在的文件应返回 false")
    }

    func testVerifySHA256AcceptsCorrectChecksum() async {
        let manager = makeManager()
        let file = tempDirectory!.appendingPathComponent("correct.bin")
        let content = "test content for SHA256 \(UUID().uuidString)"
        try? Data(content.utf8).write(to: file)

        let hexHash = sha256Hex(of: Data(content.utf8))
        let result = manager.verifySHA256(of: file, expectedHash: hexHash)
        XCTAssertTrue(result, "正确 checksum 应通过校验")
    }

    func testVerifySHA256RejectsMismatch() async {
        let manager = makeManager()
        let file = tempDirectory!.appendingPathComponent("mismatch.bin")
        try? Data("test content".utf8).write(to: file)

        let fakeHash = String(repeating: "0", count: 64)
        let result = manager.verifySHA256(of: file, expectedHash: fakeHash)
        XCTAssertFalse(result, "哈希不匹配必须被拦截")
    }

    func testVerifySHA256CaseInsensitive() async {
        let manager = makeManager()
        let file = tempDirectory!.appendingPathComponent("case.bin")
        let content = "case insensitive check"
        try? Data(content.utf8).write(to: file)

        let lowerHex = sha256Hex(of: Data(content.utf8))
        let upperHex = lowerHex.uppercased()
        let result = manager.verifySHA256(of: file, expectedHash: upperHex)
        XCTAssertTrue(result, "SHA256 校验应大小写不敏感")
    }

    // MARK: - 2. 状态更新与分发

    func testUpdateStateStoresAndBroadcasts() async {
        let manager = makeManager()
        let taskID = "test-state-\(UUID().uuidString)"

        await manager.updateState(for: taskID, to: .pending)
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)

        XCTAssertNotNil(state)
        if case .pending = state {
            // 预期 .pending
        } else {
            XCTFail("预期 .pending，实际: \(String(describing: state))")
        }
    }

    func testObserveUninitializedReturnsFailedIdle() async {
        let manager = makeManager()
        let taskID = "test-idle-\(UUID().uuidString)"

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)

        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("Idle"), "未初始化任务应返回 .failed(\"Idle\")")
        } else {
            XCTFail("未初始化任务应返回 .failed(\"Idle\")，实际: \(String(describing: state))")
        }
    }

    // MARK: - 3. 速率采样与进度更新

    func testUpdateProgressWithZeroExpectedBytesIgnored() async {
        let manager = makeManager()
        let taskID = "test-zero-\(UUID().uuidString)"

        await manager.updateProgress(for: taskID, totalBytesWritten: 100, totalBytesExpectedToWrite: 0)

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("Idle"), "totalBytesExpectedToWrite=0 时应忽略更新")
        }
    }

    func testUpdateProgressUpdatesDownloadingState() async {
        let manager = makeManager()
        let taskID = "test-progress-\(UUID().uuidString)"

        await manager.updateProgress(for: taskID, totalBytesWritten: 500, totalBytesExpectedToWrite: 1000)

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .downloading(let progress, _, let downloadedBytes, let totalBytes) = state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001, "进度应为 0.5")
            XCTAssertEqual(downloadedBytes, 500, "已下载字节应为 500")
            XCTAssertEqual(totalBytes, 1000, "期望总字节应为 1000")
        } else {
            XCTFail("应为 .downloading，实际: \(String(describing: state))")
        }
    }

    func testUpdateProgressSpeedCalculation() async {
        let manager = makeManager()
        let taskID = "test-speed-\(UUID().uuidString)"
        let totalExpected: Int64 = 100 * 1024 * 1024

        await manager.updateProgress(for: taskID, totalBytesWritten: 10 * 1024 * 1024, totalBytesExpectedToWrite: totalExpected)

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .downloading(let progress, _, _, _) = state {
            XCTAssertEqual(progress, 0.1, accuracy: 0.001, "进度应为 0.1")
        } else {
            XCTFail("应为 .downloading，实际: \(String(describing: state))")
        }
    }

    func testHighFrequencySamplingKeepsOldSpeed() async {
        let manager = makeManager()
        let taskID = "test-highfreq-\(UUID().uuidString)"

        await manager.updateProgress(for: taskID, totalBytesWritten: 0, totalBytesExpectedToWrite: 1000)
        await manager.updateProgress(for: taskID, totalBytesWritten: 100, totalBytesExpectedToWrite: 1000)

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .downloading(_, let speed, _, _) = state {
            XCTAssertEqual(speed, 0, accuracy: 0.001, "高频采样时应沿用初始化时的 currentSpeed")
        }
    }

    // MARK: - 4. Checksum 注册

    func testRegisterChecksumAndGet() async {
        let manager = makeManager()
        let taskID = "test-checksum-\(UUID().uuidString)"
        let checksum = String(repeating: "a", count: 64)

        await manager.registerChecksum(for: taskID, checksum: checksum)
        let retrieved = await manager.getChecksum(for: taskID)
        XCTAssertEqual(retrieved, checksum)
    }

    func testGetChecksumReturnsNilForUnregistered() async {
        let manager = makeManager()
        let taskID = "test-nochecksum-\(UUID().uuidString)"
        let retrieved = await manager.getChecksum(for: taskID)
        XCTAssertNil(retrieved)
    }
}