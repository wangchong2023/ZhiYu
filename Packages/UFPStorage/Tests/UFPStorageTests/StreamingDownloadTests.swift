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

    /// 测试用下载器：目标文件父目录不存在（使 moveItem 必然抛错），用于验证失败路径清理。
    private func makeManagerWithNonexistentDestination() -> StreamingDownloadManager {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectory = dir
        return StreamingDownloadManager(
            sessionFactory: { _ in URLSession(configuration: .ephemeral) },
            resumeDataDirectory: { dir },
            destinationURL: { taskID in
                // 父目录 "no-such-dir" 不存在，moveItem 到此必然抛错
                dir.appendingPathComponent("no-such-dir", isDirectory: true).appendingPathComponent("\(taskID).bin")
            }
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

    /// 用独立 Task 收集流事件到数组，主测试 sleep 后 cancel 并返回已收集事件。
    /// 规避缺陷场景下 `iterator.next()` 永久挂起导致测试套件卡死的问题。
    private func collectStream(
        _ stream: AsyncStream<StreamingDownloadState>,
        for duration: Duration
    ) async -> [StreamingDownloadState] {
        let collector = Task {
            var got: [StreamingDownloadState] = []
            for await state in stream {
                got.append(state)
            }
            return got
        }
        try? await Task.sleep(for: duration)
        collector.cancel()
        return await collector.value
    }

    // MARK: - 1. SHA256 流式校验边界

    func testVerifySHA256AcceptsEmptyChecksum() async {
        let manager = makeManager()
        let file = tempDirectory.appendingPathComponent("empty.bin")
        try? Data("test content".utf8).write(to: file)

        let result = manager.verifySHA256(of: file, expectedHash: "")
        XCTAssertTrue(result, "空 checksum 应容灾放行")
    }

    func testVerifySHA256RejectsNonStandardLength() async {
        let manager = makeManager()
        let file = tempDirectory.appendingPathComponent("short.bin")
        try? Data("test content".utf8).write(to: file)

        let result = manager.verifySHA256(of: file, expectedHash: "abc123")
        XCTAssertFalse(result, "非 64 字符 checksum 应拒绝校验")
    }

    func testVerifySHA256ReturnsFalseForNonExistentFile() async {
        let manager = makeManager()
        let file = tempDirectory.appendingPathComponent("missing.bin")
        let checksum = String(repeating: "a", count: 64)

        let result = manager.verifySHA256(of: file, expectedHash: checksum)
        XCTAssertFalse(result, "不存在的文件应返回 false")
    }

    func testVerifySHA256AcceptsCorrectChecksum() async {
        let manager = makeManager()
        let file = tempDirectory.appendingPathComponent("correct.bin")
        let content = "test content for SHA256 \(UUID().uuidString)"
        try? Data(content.utf8).write(to: file)

        let hexHash = sha256Hex(of: Data(content.utf8))
        let result = manager.verifySHA256(of: file, expectedHash: hexHash)
        XCTAssertTrue(result, "正确 checksum 应通过校验")
    }

    func testVerifySHA256RejectsMismatch() async {
        let manager = makeManager()
        let file = tempDirectory.appendingPathComponent("mismatch.bin")
        try? Data("test content".utf8).write(to: file)

        let fakeHash = String(repeating: "0", count: 64)
        let result = manager.verifySHA256(of: file, expectedHash: fakeHash)
        XCTAssertFalse(result, "哈希不匹配必须被拦截")
    }

    func testVerifySHA256CaseInsensitive() async {
        let manager = makeManager()
        let file = tempDirectory.appendingPathComponent("case.bin")
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

    // MARK: - 缺陷导向：进度百分比越界

    /// 缺陷验证：`updateProgress` 未将 progress clamp 到 [0,1]。
    /// 当 `totalBytesWritten > totalBytesExpectedToWrite`（Content-Length 不准确、
    /// chunked 响应、断点续传累计字节超限）时，进度会超过 100%。
    func testUpdateProgress_WrittenExceedsExpected_ProgressStaysWithinBounds() async {
        let manager = makeManager()
        let taskID = "test-progress-exceed-\(UUID().uuidString)"

        await manager.updateProgress(for: taskID, totalBytesWritten: 1500, totalBytesExpectedToWrite: 1000)

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .downloading(let progress, _, let downloadedBytes, let totalBytes) = state {
            XCTAssertLessThanOrEqual(progress, 1.0, "进度百分比不应超过 100%")
            XCTAssertGreaterThanOrEqual(progress, 0.0, "进度百分比不应为负")
            XCTAssertLessThanOrEqual(downloadedBytes, totalBytes, "已下载字节不应超过期望总字节")
        } else {
            XCTFail("应为 .downloading，实际: \(String(describing: state))")
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

    // MARK: - 5. 下载生命周期（状态转换，无真实网络）

    /// 验证 startDownload 对已存在的 downloading 状态直接拦截。
    func testStartDownload_WhenAlreadyDownloading_IsIgnored() async throws {
        // Given — 手动置为 downloading 状态
        let manager = makeManager()
        let taskID = "test-already-\(UUID().uuidString)"
        await manager.updateState(for: taskID, to: .downloading(progress: 0.5))

        // When — 尝试再次启动
        try await manager.startDownload(taskID: taskID, remoteURL: URL(string: "https://example.com/file")!)

        // Then — 状态仍为 downloading（未被覆盖为 pending）
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .downloading(let progress, _, _, _) = state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001, "已下载中的任务不应被重新启动覆盖")
        } else {
            XCTFail("已下载中任务应保持 downloading，实际: \(String(describing: state))")
        }
    }

    /// 验证 pauseDownload 对不存在的任务静默返回。
    func testPauseDownload_WhenNoActiveTask_DoesNothing() async throws {
        // Given
        let manager = makeManager()
        let taskID = "test-pause-none-\(UUID().uuidString)"

        // When — 无活动任务
        try await manager.pauseDownload(taskID: taskID)

        // Then — 不崩溃，状态保持 Idle 语义
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("Idle"), "无活动任务 pause 不应改变状态")
        } else {
            XCTFail("无活动任务时应保持 Idle，实际: \(String(describing: state))")
        }
    }

    /// 验证 resumeDownload 在无断点数据时进入 failed("no resume data")。
    func testResumeDownload_WhenNoResumeData_Fails() async throws {
        // Given
        let manager = makeManager()
        let taskID = "test-resume-none-\(UUID().uuidString)"

        // When — 无断点续传文件
        try await manager.resumeDownload(taskID: taskID)

        // Then
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("no resume data"), "无断点数据应报 failed(\"no resume data\")")
        } else {
            XCTFail("无断点数据应进入 failed，实际: \(String(describing: state))")
        }
    }

    /// 验证 cancelDownload 清理活动任务并将状态置为 cancelled。
    func testCancelDownload_SetsCancelledState() async throws {
        // Given — 创建一个真实的下载任务
        let manager = makeManager()
        let taskID = "test-cancel-\(UUID().uuidString)"
        let remoteURL = URL(string: "https://example.com/cancel.bin")!
        try await manager.startDownload(taskID: taskID, remoteURL: remoteURL)

        // When
        try await manager.cancelDownload(taskID: taskID)

        // Then
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .cancelled = state {
            // 预期 cancelled
        } else {
            XCTFail("cancel 后状态应为 cancelled，实际: \(String(describing: state))")
        }
    }

    /// 验证 completeDownload 在 SHA256 校验失败时清理临时文件并进入 failed。
    func testCompleteDownload_WhenVerificationFails_FailsAndCleansTemp() async {
        // Given — 注册一个必然不匹配的 checksum
        let manager = makeManager()
        let taskID = "test-complete-fail-\(UUID().uuidString)"
        await manager.registerChecksum(for: taskID, checksum: String(repeating: "a", count: 64))
        let tempFile = tempDirectory.appendingPathComponent("temp.bin")
        try? Data("payload".utf8).write(to: tempFile)

        // When
        await manager.completeDownload(for: taskID, tempFileURL: tempFile, verificationFailedMessage: "verification failed")
        await pollUntilNot(idle: taskID, in: manager)

        // Then — 校验失败：进入 failed 且临时文件被清理
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("verification failed"), "校验失败应携带原因，实际: \(message)")
        } else {
            XCTFail("校验失败应进入 failed，实际: \(String(describing: state))")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path), "校验失败后临时文件应被清理")
    }

    /// 验证 completeDownload 在校验通过时将文件移入目标目录并置为 completed。
    func testCompleteDownload_WhenVerified_MovesToDestination() async {
        // Given — 注册正确 checksum
        let manager = makeManager()
        let taskID = "test-complete-ok-\(UUID().uuidString)"
        let content = "verified-content"
        let tempFile = tempDirectory.appendingPathComponent("temp-ok.bin")
        try? Data(content.utf8).write(to: tempFile)
        await manager.registerChecksum(for: taskID, checksum: sha256Hex(of: Data(content.utf8)))

        // When
        await manager.completeDownload(for: taskID, tempFileURL: tempFile, verificationFailedMessage: "verification failed")
        await pollUntilNot(idle: taskID, in: manager)

        // Then — 文件移入目标目录，状态为 completed
        let destURL = tempDirectory.appendingPathComponent("\(taskID).bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "校验通过后文件应移入目标目录")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path), "临时文件应被移走")

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .completed(let localURL) = state {
            XCTAssertEqual(localURL.path, destURL.path, "completed 应携带目标 URL")
        } else {
            XCTFail("校验通过应进入 completed，实际: \(String(describing: state))")
        }
    }

    /// 验证 completeDownload 在目标文件已存在时会先覆盖再移入。
    func testCompleteDownload_WhenDestinationExists_Overwrites() async {
        // Given — 目标文件已存在
        let manager = makeManager()
        let taskID = "test-complete-overwrite-\(UUID().uuidString)"
        let content = "new-content"
        let tempFile = tempDirectory.appendingPathComponent("temp-overwrite.bin")
        try? Data(content.utf8).write(to: tempFile)
        await manager.registerChecksum(for: taskID, checksum: sha256Hex(of: Data(content.utf8)))

        let destURL = tempDirectory.appendingPathComponent("\(taskID).bin")
        try? Data("old-stale".utf8).write(to: destURL)

        // When
        await manager.completeDownload(for: taskID, tempFileURL: tempFile, verificationFailedMessage: "verification failed")
        await pollUntilNot(idle: taskID, in: manager)

        // Then — 目标被新内容覆盖
        let destContent = (try? Data(contentsOf: destURL)).map { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(destContent, content, "目标文件应被新内容覆盖")
    }

    // MARK: - 缺陷导向：moveItem 失败路径的资源清理

    /// 缺陷验证：`completeDownload` 移入目标目录失败（catch 分支）时，
    /// 应进入 failed 并清理临时文件。
    /// 修复前 catch 分支缺失 `clearActiveTask`（与校验失败、成功分支不对称），
    /// 失败任务的 task 残留在 activeTasks；虽实际影响有限（后续 startDownload 会覆盖残留），
    /// 但资源清理不对称，已补 `clearActiveTask` 与临时文件清理。
    func testCompleteDownload_MoveItemFails_EntersFailedAndCleansTemp() async throws {
        // Given — 目标目录父路径不存在，使 moveItem 必然抛错；先 startDownload 建立活动任务
        let manager = makeManagerWithNonexistentDestination()
        let taskID = "test-moveitem-fail-\(UUID().uuidString)"
        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/move-fail.bin"))
        try await manager.startDownload(taskID: taskID, remoteURL: remoteURL)

        let content = "move-item-fail-content"
        let tempFile = tempDirectory.appendingPathComponent("temp-movefail.bin")
        try? Data(content.utf8).write(to: tempFile)
        await manager.registerChecksum(for: taskID, checksum: sha256Hex(of: Data(content.utf8)))

        // When — completeDownload 校验通过但 moveItem 失败
        await manager.completeDownload(for: taskID, tempFileURL: tempFile, verificationFailedMessage: "verification failed")
        await pollUntilNot(idle: taskID, in: manager)

        // Then — 状态进入 failed，临时文件被清理
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .failed = state {
            // 预期 failed
        } else {
            XCTFail("moveItem 失败应进入 failed，实际: \(String(describing: state))")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path), "moveItem 失败后临时文件应被清理")
    }

    /// 验证 handleDownloadError 在错误不含 resumeData 时进入 failed。
    func testHandleDownloadError_WithoutResumeData_Fails() async {
        let manager = makeManager()
        let taskID = "test-handle-error-\(UUID().uuidString)"
        let error = NSError(domain: "network", code: -1001)

        await manager.handleDownloadError(for: taskID, error: error)

        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        if case .failed(let message) = state {
            XCTAssertFalse(message.isEmpty, "失败状态应记录错误消息")
        } else {
            XCTFail("网络错误应进入 failed，实际: \(String(describing: state))")
        }
    }

    /// 缺陷导向：网络错误附带 resumeData 时，应持久化断点续传文件并进入 paused。
    /// 覆盖 `handleDownloadError` 的含 resumeData 分支与 `persistResumeData` 成功分支。
    func testHandleDownloadError_WithResumeData_PersistsAndPauses() async {
        // Given — 错误附带 NSURLSessionDownloadTaskResumeData 用户信息
        let manager = makeManager()
        let taskID = "test-handle-resume-\(UUID().uuidString)"
        let resumeData = Data("resume-payload-\(UUID().uuidString)".utf8)
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: [NSURLSessionDownloadTaskResumeData: resumeData]
        )

        // When — 触发网络错误拦截
        await manager.handleDownloadError(for: taskID, error: error)

        // Then — 状态应为 paused 且断点续传文件已原子写入
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        guard case .paused = state else {
            return XCTFail("含 resumeData 的网络错误应持久化并进入 paused，实际: \(String(describing: state))")
        }
        let resumeURL = tempDirectory.appendingPathComponent("\(taskID).resume")
        XCTAssertTrue(FileManager.default.fileExists(atPath: resumeURL.path), "resumeData 应被写入断点续传目录")
        let persisted = try? Data(contentsOf: resumeURL)
        XCTAssertEqual(persisted, resumeData, "持久化的 resumeData 应与传入一致")
    }

    /// 缺陷导向：含 resumeData 但写入断点续传文件失败时，应降级为 failed（而非误报 paused）。
    /// 覆盖 `persistResumeData` 的失败分支。
    func testHandleDownloadError_WithResumeData_WhenPersistFails_Fails() async {
        // Given — resumeDataDirectory 指向不存在的父目录，写入必然失败
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let resumeDir = dir.appendingPathComponent("no-such-parent", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = StreamingDownloadManager(
            sessionFactory: { _ in URLSession(configuration: .ephemeral) },
            resumeDataDirectory: { resumeDir },
            destinationURL: { tid in dir.appendingPathComponent("\(tid).bin") }
        )
        let taskID = "test-handle-resume-fail-\(UUID().uuidString)"
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: [NSURLSessionDownloadTaskResumeData: Data("x".utf8)]
        )

        // When — 触发网络错误拦截，persistResumeData 写文件失败
        await manager.handleDownloadError(for: taskID, error: error)

        // Then — 降级为 failed 且带沙盒分配失败前缀
        let stream = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream)
        guard case .failed(let message) = state else {
            return XCTFail("resumeData 写失败应降级为 failed，实际: \(String(describing: state))")
        }
        XCTAssertTrue(message.contains("Sandbox storage allocation failed"), "failed 消息应带沙盒分配前缀；实际: \(message)")
    }

    /// 验证 observeDownloadState 在订阅终止后清理续流通道。
    func testObserveDownloadState_OnTermination_CleansContinuation() async {
        let manager = makeManager()
        let taskID = "test-observe-terminate-\(UUID().uuidString)"

        // When — 启动一个流后立即结束
        let stream = await manager.observeDownloadState(for: taskID)
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        // 结束流（迭代器释放触发 onTermination）
        await Task.yield()

        // Then — 不崩溃且再次订阅仍可用
        let stream2 = await manager.observeDownloadState(for: taskID)
        let state = await firstState(from: stream2)
        XCTAssertNotNil(state, "订阅终止清理后再次订阅应可用")
    }

    // MARK: - 缺陷导向：多观察者订阅管理

    /// 缺陷验证：同一 taskID 有多个观察者时，覆盖逻辑会破坏新观察者。
    ///
    /// `observeDownloadState` 用 `continuations[taskID] = continuation` 直接覆盖旧续流，
    /// 且旧续流的 `onTermination` 无条件执行 `removeContinuation(for:)`。
    /// 当观察者 A 终止时，会把当前 key（观察者 B 的续流）一并删除，
    /// 导致 B 在 A 终止后收不到任何后续状态更新。
    func testObserve_MultipleSubscribers_OneTerminationDoesNotBreakOther() async {
        // Given — 同一 taskID 两个观察者 A、B
        let manager = makeManager()
        let taskID = "test-multi-observe-\(UUID().uuidString)"

        let streamA = await manager.observeDownloadState(for: taskID)
        let taskA = Task {
            for await _ in streamA {}
        }
        await Task.yield()

        let streamB = await manager.observeDownloadState(for: taskID)

        // When — 观察者 A 终止，触发 onTermination → removeContinuation
        taskA.cancel()
        _ = await taskA.value
        try? await Task.sleep(for: .milliseconds(50))

        // Then — B 应仍能收到后续状态更新
        await manager.updateState(for: taskID, to: .downloading(progress: 0.5))
        let received = await collectStream(streamB, for: .milliseconds(300))

        let hasDownloading = received.contains { state in
            if case .downloading = state { return true }
            return false
        }
        XCTAssertTrue(hasDownloading, "A 终止后 B 应仍能收到 downloading 更新；实际收到: \(received)")
    }

    // MARK: - 缺陷 #264 回归：taskID 路径清洗与 .pending 防重入

    func testSanitizedTaskFileNameStemBlocksTraversalAndHiddenFiles() {
        let traversed = StreamingDownloadManager.sanitizedTaskFileNameStem(for: "../../etc/passwd")
        XCTAssertFalse(traversed.contains(".."))
        XCTAssertFalse(traversed.contains("/"))

        let hidden = StreamingDownloadManager.sanitizedTaskFileNameStem(for: ".secret\r\n")
        XCTAssertFalse(hidden.hasPrefix("."))
        XCTAssertEqual(hidden, "secret")

        XCTAssertEqual(StreamingDownloadManager.sanitizedTaskFileNameStem(for: "   ... "), "task")
    }

    func testStartDownloadRejectsReentryWhilePending() async throws {
        let manager = makeManager()
        let taskID = "pending-reentry-guard"
        let url = try XCTUnwrap(URL(string: "https://example.com/model.bin"))

        await manager.updateState(for: taskID, to: .pending)
        try await manager.startDownload(taskID: taskID, remoteURL: url)

        let stream = await manager.observeDownloadState(for: taskID)
        let current = await firstState(from: stream)
        if case .pending = current {
            // 预期保持 pending 且未覆盖新建重复任务
        } else {
            XCTFail("处于 .pending 状态时重复 startDownload 应被拦截，实际状态: \(String(describing: current))")
        }
    }

    // MARK: - 缺陷 #279 回归：Delegate 弱引用打破 URLSession 强引用环

    func testSessionDelegateDoesNotRetainManagerAfterInvalidate() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        weak var weakManager: StreamingDownloadManager?
        do {
            let manager = StreamingDownloadManager(
                configuration: .ephemeral,
                resumeDataDirectory: { dir },
                destinationURL: { taskID in dir.appendingPathComponent("\(taskID).bin") }
            )
            weakManager = manager
            let bound = await manager.hasSessionDelegate
            XCTAssertTrue(bound, "使用默认 Delegate 桥接时 URLSession 应已绑定 delegate")
            await manager.invalidateSession()
        }

        // 等待 URLSession 异步完成 invalidate 回调并释放 delegate
        for _ in 0..<20 where weakManager != nil {
            try? await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertNil(weakManager, "invalidateSession 后 StreamingDownloadDelegateHelper 不应强持有 StreamingDownloadManager 导致内存泄漏")
    }

    // MARK: - 辅助：等待 detached 任务完成

    /// 判断是否为稳定终态（completed/failed/cancelled）。
    private func isTerminal(_ state: StreamingDownloadState) -> Bool {
        switch state {
        case .completed, .failed, .cancelled: return true
        case .pending, .downloading, .paused, .verifying: return false
        }
    }

    /// 轮询等待指定任务进入稳定终态（completeDownload 内部 Task.detached 异步执行）。
    private func pollUntilNot(idle taskID: String, in manager: StreamingDownloadManager) async {
        for _ in 0..<100 {
            let stream = await manager.observeDownloadState(for: taskID)
            let state = await firstState(from: stream)
            if let state, isTerminal(state) {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
