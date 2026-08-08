//
//  ModelDownloadManagerStateTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 ModelDownloadManager 下载状态机转换的边界条件与一致性。
//

import XCTest
import CommonCrypto
@testable import ZhiYu

// MARK: - ModelDownloadManager 状态机测试

final class ModelDownloadManagerStateTests: XCTestCase {

    private let manager = ModelDownloadManager.shared

    // MARK: - 状态更新与分发测试

    /// 验证 updateState 正确更新内部状态
    func testUpdateStateStoresState() async {
        let modelId = "test-state-store-\(UUID().uuidString)"

        await manager.updateState(for: modelId, to: .pending)
        let stream = await manager.observeDownloadState(for: modelId)

        // observeDownloadState 首次订阅会推送当前状态
        let state = await stream.first { _ in true }
        XCTAssertNotNil(state)
        if case .pending = state {
            // 预期 .pending
        } else {
            XCTFail("预期 .pending 状态，实际: \(String(describing: state))")
        }
    }

    // MARK: - resumeDownload 状态更新测试

    /// 验证 resumeDownload 在没有 resume data 时的状态
    /// 问题：resumeDownload 无 resume data 时设为 .failed，但错误信息不够明确
    func testResumeDownloadWithoutResumeData() async {
        let modelId = "test-resume-no-data-\(UUID().uuidString)"

        // 先设置一个初始状态
        await manager.updateState(for: modelId, to: .paused)

        // 调用 resumeDownload，但没有 resume data 文件
        try? await manager.resumeDownload(modelId: modelId)

        // 状态应更新为 .failed
        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }

        if case .failed = state {
            // 预期 .failed
        } else {
            XCTFail("无 resume data 时应更新为 .failed，实际: \(String(describing: state))")
        }
    }

    // MARK: - cancelDownload 状态测试

    /// 验证 cancelDownload 正确设置 .cancelled 状态
    func testCancelDownloadSetsCancelledState() async {
        let modelId = "test-cancel-\(UUID().uuidString)"

        await manager.updateState(for: modelId, to: .downloading(progress: 0.5, bytesPerSecond: 1000))
        try? await manager.cancelDownload(modelId: modelId)

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }

        if case .cancelled = state {
            // 预期 .cancelled
        } else {
            XCTFail("cancelDownload 后应为 .cancelled，实际: \(String(describing: state))")
        }
    }

    // MARK: - observeDownloadState 初始状态测试

    /// 验证 observeDownloadState 对未初始化模型返回 .failed("Idle")
    func testObserveInitialStateIsIdleFailed() async {
        let modelId = "test-idle-\(UUID().uuidString)"

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }

        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("Idle"), "未初始化模型应返回 .failed(\"Idle\")")
        } else {
            XCTFail("未初始化模型应返回 .failed(\"Idle\")，实际: \(String(describing: state))")
        }
    }

    // MARK: - registerChecksum 测试

    /// 验证 registerChecksum 正确存储 checksum
    func testRegisterChecksum() async {
        let modelId = "test-checksum-\(UUID().uuidString)"
        let checksum = String(repeating: "a", count: 64)

        await manager.registerChecksum(for: modelId, checksum: checksum)
        let retrieved = await manager.getChecksum(for: modelId)
        XCTAssertEqual(retrieved, checksum, "registerChecksum 应正确存储 checksum")
    }

    /// 验证未注册 checksum 时 getChecksum 返回 nil
    func testGetChecksumReturnsNilForUnregistered() async {
        let modelId = "test-no-checksum-\(UUID().uuidString)"
        let retrieved = await manager.getChecksum(for: modelId)
        XCTAssertNil(retrieved, "未注册的 modelId 应返回 nil")
    }

    // MARK: - verifySHA256 边界测试

    /// 验证 verifySHA256 对空 checksum 返回 false（已修复的问题 #2）
    func testVerifySHA256RejectsEmptyChecksum() async {
        let tempFile = NSTemporaryDirectory() + "test_sha256_empty_\(UUID().uuidString)"
        try? Data("test content".utf8).write(to: URL(fileURLWithPath: tempFile))
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let result = manager.verifySHA256(of: URL(fileURLWithPath: tempFile), expectedHash: "")
        XCTAssertFalse(result, "空 checksum 应拒绝校验（已修复的问题 #2）")
    }

    /// 验证 verifySHA256 对非 64 字符 checksum 返回 false
    func testVerifySHA256RejectsNonStandardLength() async {
        let tempFile = NSTemporaryDirectory() + "test_sha256_short_\(UUID().uuidString)"
        try? Data("test content".utf8).write(to: URL(fileURLWithPath: tempFile))
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let result = manager.verifySHA256(of: URL(fileURLWithPath: tempFile), expectedHash: "abc123")
        XCTAssertFalse(result, "非 64 字符 checksum 应拒绝校验")
    }

    /// 验证 verifySHA256 对不存在的文件返回 false
    func testVerifySHA256ReturnsFalseForNonExistentFile() async {
        let nonExistentFile = "/dev/null/nonexistent_\(UUID().uuidString).bin"
        let checksum = String(repeating: "a", count: 64)

        let result = manager.verifySHA256(of: URL(fileURLWithPath: nonExistentFile), expectedHash: checksum)
        XCTAssertFalse(result, "不存在的文件应返回 false")
    }

    /// 验证 verifySHA256 对正确 checksum 返回 true
    func testVerifySHA256AcceptsCorrectChecksum() async {
        let tempFile = NSTemporaryDirectory() + "test_sha256_correct_\(UUID().uuidString)"
        let content = "test content for SHA256"
        try? Data(content.utf8).write(to: URL(fileURLWithPath: tempFile))
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        // 计算正确的 SHA256
        let digest = sha256(of: Data(content.utf8))
        let hexHash = digest.map { String(format: "%02x", $0) }.joined()

        let result = manager.verifySHA256(of: URL(fileURLWithPath: tempFile), expectedHash: hexHash)
        XCTAssertTrue(result, "正确 checksum 应通过校验")
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

    // MARK: - updateProgress 边界测试

    /// 验证 updateProgress 对 totalBytesExpectedToWrite = 0 的处理
    func testUpdateProgressWithZeroExpectedBytes() async {
        let modelId = "test-zero-expected-\(UUID().uuidString)"

        // 不应崩溃，应静默忽略
        await manager.updateProgress(for: modelId, totalBytesWritten: 100, totalBytesExpectedToWrite: 0)

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }

        // 状态应保持 .failed("Idle")，因为 updateProgress 被忽略
        if case .failed(let message) = state {
            XCTAssertTrue(message.contains("Idle"), "totalBytesExpectedToWrite=0 时应忽略更新")
        }
    }

    /// 验证 updateProgress 正常更新下载进度
    func testUpdateProgressUpdatesDownloadingState() async {
        let modelId = "test-progress-\(UUID().uuidString)"

        await manager.updateProgress(for: modelId, totalBytesWritten: 500, totalBytesExpectedToWrite: 1000)

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }

        if case .downloading(let progress, _) = state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.001, "进度应为 0.5")
        } else {
            XCTFail("应为 .downloading 状态，实际: \(String(describing: state))")
        }
    }

    // MARK: - 速度计算测试

    /// 验证下载速度计算逻辑
    func testDownloadSpeedCalculation() async {
        let modelId = "test-speed-\(UUID().uuidString)"

        // 第一次更新：初始化 tracker
        await manager.updateProgress(for: modelId, totalBytesWritten: 0, totalBytesExpectedToWrite: 1000)

        // 等待超过采样间隔
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 秒 > 0.5 秒采样间隔

        // 第二次更新：计算速度
        await manager.updateProgress(for: modelId, totalBytesWritten: 500, totalBytesExpectedToWrite: 1000)

        let stream = await manager.observeDownloadState(for: modelId)
        let state = await stream.first { _ in true }

        if case .downloading(_, let speed) = state {
            // 500 bytes / 0.6 seconds ≈ 833 bytes/sec
            XCTAssertGreaterThan(speed, 0, "速度应大于 0")
        }
    }
}
