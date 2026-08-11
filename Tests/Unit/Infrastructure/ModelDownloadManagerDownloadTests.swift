//
//  ModelDownloadManagerDownloadTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 ModelDownloadManager 的 startDownload/pauseDownload/completeDownload 核心下载流程、Delegate 回调、SHA256 大小写不敏感、高频采样等边界分支。
//

import XCTest
import CommonCrypto
import UFPCore
@testable import ZhiYu

// MARK: - ModelDownloadManager 下载流程测试

final class ModelDownloadManagerDownloadTests: XCTestCase {

    private let manager = ModelDownloadManager.shared

    // MARK: - startDownload 状态守卫测试

    /// 验证 startDownload 在已有 downloading 状态时直接 return（不重建 task）
    func testStartDownloadWithExistingDownloadingStateReturnsEarly() async throws {
        let modelId = "test-start-downloading-\(UUID().uuidString)"

        // 先设置 downloading 状态
        await manager.updateState(for: modelId, to: .downloading(progress: 0.5, bytesPerSecond: 1000))

        // 调用 startDownload，应直接 return 不改变状态
        // 使用无效 URL，如果 startDownload 真的尝试创建 task 会崩溃
        let invalidURL = URL(string: "https://invalid.example.com/model.bin")!
        try await manager.startDownload(modelId: modelId, remoteURL: invalidURL)

        // 状态应保持 downloading（未被覆盖为 pending）
        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }
        if case .downloading(let progress, _) = state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001, "已有 downloading 状态时 startDownload 应直接 return")
        } else {
            XCTFail("状态应保持 .downloading，实际: \(String(describing: state))")
        }
    }

    /// 验证 startDownload 在已有 verifying 状态时直接 return
    func testStartDownloadWithExistingVerifyingStateReturnsEarly() async throws {
        let modelId = "test-start-verifying-\(UUID().uuidString)"

        await manager.updateState(for: modelId, to: .verifying)

        let invalidURL = URL(string: "https://invalid.example.com/model.bin")!
        try await manager.startDownload(modelId: modelId, remoteURL: invalidURL)

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }
        if case .verifying = state {
            // 预期：状态保持 verifying
        } else {
            XCTFail("状态应保持 .verifying，实际: \(String(describing: state))")
        }
    }

    /// 验证 startDownload 在已有 completed 状态时直接 return
    func testStartDownloadWithExistingCompletedStateReturnsEarly() async throws {
        let modelId = "test-start-completed-\(UUID().uuidString)"

        await manager.updateState(for: modelId, to: .completed(localURL: URL(fileURLWithPath: "/tmp/test.bin")))

        let invalidURL = URL(string: "https://invalid.example.com/model.bin")!
        try await manager.startDownload(modelId: modelId, remoteURL: invalidURL)

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }
        if case .completed = state {
            // 预期：状态保持 completed
        } else {
            XCTFail("状态应保持 .completed，实际: \(String(describing: state))")
        }
    }

    // MARK: - pauseDownload 边界测试

    /// 验证 pauseDownload 在无 activeTask 时直接 return（不崩溃）
    func testPauseDownloadWithNoActiveTaskReturnsEarly() async throws {
        let modelId = "test-pause-no-task-\(UUID().uuidString)"

        // 无 activeTask，应直接 return 不崩溃
        try await manager.pauseDownload(modelId: modelId)

        // 状态未被修改（保持 idle 或未初始化）
        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }
        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("Idle"), "无 activeTask 时 pauseDownload 应直接 return，状态保持 idle")
        }
    }

    // MARK: - completeDownload SHA256 校验测试

    /// 验证 completeDownload 在 SHA256 校验失败时转为 failed 并删除临时文件
    func testCompleteDownloadSHA256MismatchTransitionsToFailed() async throws {
        let modelId = "test-complete-mismatch-\(UUID().uuidString)"

        // 注册一个错误的 checksum
        let wrongChecksum = String(repeating: "b", count: 64)
        await manager.registerChecksum(for: modelId, checksum: wrongChecksum)

        // 创建临时文件
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory() + "test_mismatch_\(UUID().uuidString).bin")
        try Data("test content for mismatch".utf8).write(to: tempURL)

        // 触发 completeDownload
        await manager.completeDownload(for: modelId, tempFileURL: tempURL)

        // 等待 Task.detached 完成
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒

        // 临时文件应被删除
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path), "SHA256 校验失败时应删除临时文件")

        // 状态应为 failed
        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }
        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("verification failed") || message.contains("mismatch"), "SHA256 校验失败时错误信息应包含 verification failed 或 mismatch")
        } else {
            XCTFail("SHA256 校验失败时状态应为 .failed，实际: \(String(describing: state))")
        }
    }

    /// 验证 completeDownload 在校验成功时移入 Documents 目录并转为 completed
    func testCompleteDownloadSucceedsMovesToDocuments() async throws {
        let modelId = "test-complete-success-\(UUID().uuidString)"

        // 创建临时文件并计算正确 checksum
        let content = "test content for success \(UUID().uuidString)"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory() + "test_success_\(UUID().uuidString).bin")
        try Data(content.utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let correctChecksum = sha256Hex(of: Data(content.utf8))
        await manager.registerChecksum(for: modelId, checksum: correctChecksum)

        // 清理可能存在的目标文件
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = documentDir.appendingPathComponent("\(modelId).bin")
        try? FileManager.default.removeItem(at: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        // 触发 completeDownload
        await manager.completeDownload(for: modelId, tempFileURL: tempURL)

        // 等待 Task.detached 完成
        try await Task.sleep(nanoseconds: 500_000_000)

        // 目标文件应存在
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "校验成功时文件应移入 Documents 目录")

        // 状态应为 completed
        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }
        if case .completed = state {
            // 预期：completed
        } else {
            XCTFail("校验成功时状态应为 .completed，实际: \(String(describing: state))")
        }
    }

    /// 验证 completeDownload 在目标文件已存在时先删除再 move
    func testCompleteDownloadOverwritesExistingDestinationFile() async throws {
        let modelId = "test-complete-overwrite-\(UUID().uuidString)"

        let content = "new content \(UUID().uuidString)"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory() + "test_overwrite_\(UUID().uuidString).bin")
        try Data(content.utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let correctChecksum = sha256Hex(of: Data(content.utf8))
        await manager.registerChecksum(for: modelId, checksum: correctChecksum)

        // 预先创建目标文件（旧内容）
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = documentDir.appendingPathComponent("\(modelId).bin")
        try Data("old content".utf8).write(to: destURL)
        defer { try? FileManager.default.removeItem(at: destURL) }

        // 触发 completeDownload
        await manager.completeDownload(for: modelId, tempFileURL: tempURL)

        // 等待 Task.detached 完成
        try await Task.sleep(nanoseconds: 500_000_000)

        // 目标文件应被覆盖为新内容
        let finalContent = try? String(contentsOf: destURL, encoding: .utf8)
        XCTAssertEqual(finalContent, content, "目标文件应被覆盖为新内容")
    }

    // MARK: - verifySHA256 大小写不敏感测试

    /// 验证 verifySHA256 支持大写/混合大小写 checksum
    func testVerifySHA256CaseInsensitiveComparison() async {
        let tempFile = NSTemporaryDirectory() + "test_sha256_case_\(UUID().uuidString)"
        let content = "test content for case"
        try? Data(content.utf8).write(to: URL(fileURLWithPath: tempFile))
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let digest = sha256(of: Data(content.utf8))
        let lowerHex = digest.map { String(format: "%02x", $0) }.joined()
        let upperHex = digest.map { String(format: "%02X", $0) }.joined()

        XCTAssertTrue(manager.verifySHA256(of: URL(fileURLWithPath: tempFile), expectedHash: lowerHex), "小写 checksum 应通过")
        XCTAssertTrue(manager.verifySHA256(of: URL(fileURLWithPath: tempFile), expectedHash: upperHex), "大写 checksum 应通过")
    }

    // MARK: - updateProgress 高频采样测试

    /// 验证 updateProgress 在高频采样时（timeDiff < sampleInterval）沿用旧 currentSpeed
    func testUpdateProgressHighFrequencySamplingKeepsOldSpeed() async {
        let modelId = "test-high-freq-\(UUID().uuidString)"

        // 第一次更新：初始化 tracker
        await manager.updateProgress(for: modelId, totalBytesWritten: 0, totalBytesExpectedToWrite: 1000)

        // 立即第二次更新（timeDiff < 0.5 秒采样间隔）
        await manager.updateProgress(for: modelId, totalBytesWritten: 100, totalBytesExpectedToWrite: 1000)

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }
        if case .downloading(_, let speed) = state {
            // 高频采样时 speed 应为 0（沿用初始化时的 currentSpeed）
            XCTAssertEqual(speed, 0, accuracy: 0.001, "高频采样时应沿用旧 currentSpeed")
        }
    }

    // MARK: - 测试用访问器常量验证

    /// 验证 sha256BufferSizeForTesting 返回 1MB
    func testSha256BufferSizeForTestingConstant() {
        let expected = Int(SystemConstants.bytesPerKB) * Int(SystemConstants.bytesPerKB)
        XCTAssertEqual(ModelDownloadManager.sha256BufferSizeForTesting, expected, "sha256BufferSize 应为 1MB")
    }

    /// 验证 sandboxAllocationFailedPrefixForTesting 返回正确前缀
    func testSandboxAllocationFailedPrefixForTestingConstant() {
        let prefix = ModelDownloadManager.sandboxAllocationFailedPrefixForTesting
        XCTAssertFalse(prefix.isEmpty, "sandboxAllocationFailedPrefix 不应为空")
        XCTAssertTrue(prefix.contains("Sandbox"), "sandboxAllocationFailedPrefix 应包含 Sandbox")
    }

    // MARK: - cleanPreviousFiles 间接验证

    /// 验证 cancelDownload 清理目标 .bin 文件
    func testCancelDownloadCleansPreviousFiles() async throws {
        let modelId = "test-cancel-clean-\(UUID().uuidString)"

        // 预先创建目标文件
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = documentDir.appendingPathComponent("\(modelId).bin")
        try Data("test".utf8).write(to: destURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "测试前置：目标文件应存在")

        // 调用 cancelDownload
        try await manager.cancelDownload(modelId: modelId)

        // 目标文件应被删除
        XCTAssertFalse(FileManager.default.fileExists(atPath: destURL.path), "cancelDownload 应清理目标 .bin 文件")
    }

    // MARK: - 辅助方法

    /// 计算 SHA256 哈希
    private func sha256(of data: Data) -> [UInt8] {
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256_Update(&context, buffer.baseAddress, CC_LONG(data.count))
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest
    }

    /// 计算 SHA256 十六进制字符串
    private func sha256Hex(of data: Data) -> String {
        let digest = sha256(of: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
