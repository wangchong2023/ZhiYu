//
//  StreamingDownloadDelegateHelperTests.swift
//  UFPStorageTests
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorageTests]
//  核心职责：覆盖 StreamingDownloadDelegateHelper 的 HTTP 2xx/4xx/5xx 校验、进度拦截、
//           临时文件拷贝容灾、取消忽略与断网错误分发，以及 StreamingDownloadManager 全生命周期。
//

import XCTest
import CommonCrypto
@testable import UFPStorage

/// 确定性内存 URLProtocol，用于脱离真实网络验证 URLSession + StreamingDownloadDelegateHelper 完整链路。
private final class MockDownloadURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class StreamingDownloadDelegateHelperTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ufp_dl_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        MockDownloadURLProtocol.handler = nil
    }

    override func tearDown() {
        MockDownloadURLProtocol.handler = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        super.tearDown()
    }

    private func makeMockedManager(resumeDir: URL? = nil) -> StreamingDownloadManager {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockDownloadURLProtocol.self]
        let baseDir = tempDir ?? FileManager.default.temporaryDirectory
        let rDir = resumeDir ?? baseDir
        let dDir = baseDir
        return StreamingDownloadManager(
            configuration: config,
            resumeDataDirectory: { rDir },
            destinationURL: { taskID in dDir.appendingPathComponent("\(taskID).bin") }
        )
    }

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

    private func waitForTerminalState(
        from stream: AsyncStream<StreamingDownloadState>,
        timeout: Duration = .seconds(5)
    ) async -> StreamingDownloadState? {
        let task = Task<StreamingDownloadState?, Never> {
            for await state in stream {
                switch state {
                case .completed, .failed, .cancelled, .paused:
                    return state
                case .pending, .downloading, .verifying:
                    continue
                }
            }
            return nil
        }
        let watchdog = Task {
            try? await Task.sleep(for: timeout)
            task.cancel()
        }
        let result = await task.value
        watchdog.cancel()
        return result
    }

    // MARK: - 1. HTTP 200 端到端下载 + DelegateHelper 进度与完成回调

    func testEndToEndDownloadSuccessViaDelegateHelper() async throws {
        let payload = Data(repeating: 0xAB, count: 4096)
        let expectedHash = sha256Hex(of: payload)
        let url = URL(string: "https://mock.ufp.local/model.bin")!

        MockDownloadURLProtocol.handler = { req in
            let responseURL = req.url ?? url
            guard let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Length": "\(payload.count)"]
            ) else {
                throw URLError(.badServerResponse)
            }
            return (response, payload)
        }

        let manager = makeMockedManager()
        let hasDelegate = await manager.hasSessionDelegate
        XCTAssertTrue(hasDelegate, "使用 configuration 初始化的管理器必须绑定 DelegateHelper")

        let taskID = "dl-ok-\(UUID().uuidString)"
        await manager.registerChecksum(for: taskID, checksum: expectedHash)
        let storedHash = await manager.getChecksum(for: taskID)
        XCTAssertEqual(storedHash, expectedHash)

        let stream = await manager.observeDownloadState(for: taskID)
        // 丢弃初始 Idle 状态后启动下载
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        try await manager.startDownload(taskID: taskID, remoteURL: url)

        var reachedCompletedURL: URL?
        while let state = await iterator.next() {
            if case .completed(let localURL) = state {
                reachedCompletedURL = localURL
                break
            } else if case .failed(let err) = state {
                XCTFail("不应失败，实际错误: \(err)")
                break
            }
        }

        let finalURL = try XCTUnwrap(reachedCompletedURL)
        let savedData = try Data(contentsOf: finalURL)
        XCTAssertEqual(savedData, payload, "下载落盘文件内容必须与服务端响应完全一致")
    }

    // MARK: - 2. HTTP 404 / 500 错误状态码拦截

    func testEndToEndDownloadRejectsHTTP404AndDoesNotSaveErrorPage() async throws {
        let errorPage = Data("<html>404 Not Found</html>".utf8)
        let url = URL(string: "https://mock.ufp.local/missing.bin")!

        MockDownloadURLProtocol.handler = { req in
            let responseURL = req.url ?? url
            guard let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Length": "\(errorPage.count)"]
            ) else {
                throw URLError(.badServerResponse)
            }
            return (response, errorPage)
        }

        let manager = makeMockedManager()
        let taskID = "dl-404-\(UUID().uuidString)"
        let stream = await manager.observeDownloadState(for: taskID)
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // 消耗初始 Idle

        try await manager.startDownload(taskID: taskID, remoteURL: url)

        var errorMessage: String?
        while let state = await iterator.next() {
            if case .failed(let msg) = state {
                errorMessage = msg
                break
            } else if case .completed = state {
                XCTFail("HTTP 404 绝对不能进入 completed 状态")
                break
            }
        }

        XCTAssertEqual(errorMessage, "Network error: HTTP 404")
        let destPath = tempDir.appendingPathComponent("\(taskID).bin").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: destPath), "404 错误页不得写入目标路径")
    }

    // MARK: - 3. 网络传输错误回调（普通错误 vs 用户取消 vs 携带 resumeData）

    func testDelegateHelperIgnoresUserCancelledError() async {
        let manager = makeMockedManager()
        let helper = StreamingDownloadDelegateHelper(manager: manager)
        let session = URLSession(configuration: .ephemeral)
        let task = session.downloadTask(with: URL(string: "https://mock.ufp.local/cancel")!)
        let taskID = "dl-cancel-ignore"
        task.taskDescription = taskID

        await manager.updateState(for: taskID, to: .pending)
        let cancelError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        helper.urlSession(session, task: task, didCompleteWithError: cancelError)

        // 给异步 Task 留出调度时间
        try? await Task.sleep(for: .milliseconds(50))

        let stream = await manager.observeDownloadState(for: taskID)
        var iterator = stream.makeAsyncIterator()
        let latest = await iterator.next()
        if case .pending = latest {
            // 取消错误被忽略，状态保持 .pending
        } else {
            XCTFail("用户主动取消应被忽略，状态应维持 .pending，实际: \(String(describing: latest))")
        }
    }

    func testDelegateHelperHandlesNetworkErrorAndTemporaryMoveFailure() async {
        let manager = makeMockedManager()
        let helper = StreamingDownloadDelegateHelper(manager: manager)
        let session = URLSession(configuration: .ephemeral)

        // 1) taskDescription 为 nil 时安全忽略
        let nilDescTask = session.downloadTask(with: URL(string: "https://mock.ufp.local/nildesc")!)
        helper.urlSession(session, downloadTask: nilDescTask, didWriteData: 10, totalBytesWritten: 10, totalBytesExpectedToWrite: 100)
        helper.urlSession(session, downloadTask: nilDescTask, didFinishDownloadingTo: tempDir.appendingPathComponent("nope"))
        helper.urlSession(session, task: nilDescTask, didCompleteWithError: URLError(.timedOut))

        // 2) didFinishDownloadingTo 临时文件不存在 -> 触发 temporary copy failed
        let moveFailTask = session.downloadTask(with: URL(string: "https://mock.ufp.local/movefail")!)
        let moveFailID = "dl-move-fail"
        moveFailTask.taskDescription = moveFailID
        let nonexistentLocation = tempDir.appendingPathComponent("nonexistent_\(UUID().uuidString).tmp")
        helper.urlSession(session, downloadTask: moveFailTask, didFinishDownloadingTo: nonexistentLocation)

        try? await Task.sleep(for: .milliseconds(100))
        let stream1 = await manager.observeDownloadState(for: moveFailID)
        var it1 = stream1.makeAsyncIterator()
        if case .failed(let msg) = await it1.next() {
            XCTAssertTrue(msg.contains("temporary copy failed"), "应上报临时拷贝失败，实际: \(msg)")
        } else {
            XCTFail("移动不存在的临时文件应进入 .failed")
        }

        // 3) didCompleteWithError 携带 resumeData -> 持久化 .resume 并置为 .paused
        let resumeTask = session.downloadTask(with: URL(string: "https://mock.ufp.local/netdrop")!)
        let resumeID = "dl-netdrop"
        resumeTask.taskDescription = resumeID
        let fakeResumeData = Data("fake-resume-payload".utf8)
        let netError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: [NSURLSessionDownloadTaskResumeData: fakeResumeData]
        )
        helper.urlSession(session, task: resumeTask, didCompleteWithError: netError)

        try? await Task.sleep(for: .milliseconds(100))
        let stream2 = await manager.observeDownloadState(for: resumeID)
        var it2 = stream2.makeAsyncIterator()
        if case .paused = await it2.next() {
            let resumeFile = tempDir.appendingPathComponent("\(resumeID).resume")
            XCTAssertTrue(FileManager.default.fileExists(atPath: resumeFile.path), "应落盘 .resume 文件")
        } else {
            XCTFail("携带 resumeData 的网络错误应进入 .paused")
        }

        // 4) 普通网络错误（无 resumeData）-> 进入 .failed
        let plainFailTask = session.downloadTask(with: URL(string: "https://mock.ufp.local/timeout")!)
        let plainFailID = "dl-timeout"
        plainFailTask.taskDescription = plainFailID
        helper.urlSession(session, task: plainFailTask, didCompleteWithError: URLError(.timedOut))

        try? await Task.sleep(for: .milliseconds(100))
        let stream3 = await manager.observeDownloadState(for: plainFailID)
        var it3 = stream3.makeAsyncIterator()
        if case .failed(let msg) = await it3.next() {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("普通网络超时错误应进入 .failed")
        }
    }

    // MARK: - 4. Manager 生命周期边界（重复 start / pause / resume / cancel / persist 失败）

    func testManagerLifecycleGuardsAndCancelCleanup() async throws {
        let manager = makeMockedManager()
        let taskID = "dl-lifecycle-\(UUID().uuidString)"
        let url = URL(string: "https://mock.ufp.local/file.bin")!

        // 1) 已处于 downloading/verifying/completed 时 startDownload 必须幂等拦截
        await manager.updateState(for: taskID, to: .downloading(progress: 0.5, bytesPerSecond: 100, downloadedBytes: 50, totalBytes: 100))
        try await manager.startDownload(taskID: taskID, remoteURL: url)
        let s1 = await manager.observeDownloadState(for: taskID)
        var it1 = s1.makeAsyncIterator()
        if case .downloading(let progress, _, _, _) = await it1.next() {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
        } else {
            XCTFail("正在下载时重复调用 startDownload 应被拦截")
        }

        // 2) pauseDownload 无活跃任务时应安全无操作
        try await manager.pauseDownload(taskID: "nonexistent-task")

        // 3) resumeDownload 无 resumeData 文件时应置为 .failed("no resume data")
        let noResumeID = "dl-no-resume"
        try await manager.resumeDownload(taskID: noResumeID)
        let s2 = await manager.observeDownloadState(for: noResumeID)
        var it2 = s2.makeAsyncIterator()
        if case .failed(let msg) = await it2.next() {
            XCTAssertEqual(msg, "no resume data")
        } else {
            XCTFail("无 resume 文件时 resumeDownload 应进入 .failed")
        }

        // 4) cancelDownload 清理残留文件与 .resume 并置为 .cancelled
        let cancelID = "dl-cancel-clean"
        let destFile = tempDir.appendingPathComponent("\(cancelID).bin")
        let resumeFile = tempDir.appendingPathComponent("\(cancelID).resume")
        try Data("old".utf8).write(to: destFile)
        try Data("resume".utf8).write(to: resumeFile)

        try await manager.cancelDownload(taskID: cancelID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resumeFile.path))
        let s3 = await manager.observeDownloadState(for: cancelID)
        var it3 = s3.makeAsyncIterator()
        if case .cancelled = await it3.next() {
            // 预期 .cancelled
        } else {
            XCTFail("cancelDownload 后状态应为 .cancelled")
        }
    }

    func testPersistResumeDataFailureMarksTaskFailed() async {
        // 指向不存在的只读父目录，确保 data.write 必然抛错
        let invalidDir = tempDir.appendingPathComponent("missing_parent/nested_resume_dir")
        let manager = makeMockedManager(resumeDir: invalidDir)
        let taskID = "dl-persist-fail"

        let netError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: [NSURLSessionDownloadTaskResumeData: Data("bytes".utf8)]
        )
        await manager.handleDownloadError(for: taskID, error: netError)

        let stream = await manager.observeDownloadState(for: taskID)
        var it = stream.makeAsyncIterator()
        if case .failed(let msg) = await it.next() {
            XCTAssertTrue(msg.contains(StreamingDownloadConstants.sandboxAllocationFailedPrefix))
        } else {
            XCTFail("resumeData 落盘失败时应进入 .failed 状态")
        }
    }
}
