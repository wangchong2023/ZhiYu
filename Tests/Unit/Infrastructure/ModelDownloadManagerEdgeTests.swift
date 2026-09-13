//
//  ModelDownloadManagerEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 ModelDownloadManager 的 SHA256 指纹校验、网络中断断点持久化与状态机流式分发边界。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class ModelDownloadManagerEdgeTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - 1. SHA256 校验边界与异常拦截

    func testVerifySHA256WithEmptyAndInvalidLengths() async {
        let manager = ModelDownloadManager(sessionFactory: { _ in
            URLSession(configuration: .ephemeral)
        })

        let dummyFile = tempDirectory.appendingPathComponent("test_model.bin")
        let dummyData = Data("hello zhiyu model weights".utf8)
        try? dummyData.write(to: dummyFile)

        // 1. 空 Hash 拒绝
        let emptyResult = manager.verifySHA256(of: dummyFile, expectedHash: "")
        XCTAssertFalse(emptyResult, "未注册或空 SHA256 必须拒绝通过")

        // 2. 非 64 字符长度 Hash 拒绝
        let shortHashResult = manager.verifySHA256(of: dummyFile, expectedHash: "abc1234")
        XCTAssertFalse(shortHashResult, "非 64 位 SHA256 必须直接拦截")

        // 3. 错误 64 字符 Hash 篡改拒绝
        let fake64Hash = String(repeating: "0", count: 64)
        let mismatchResult = manager.verifySHA256(of: dummyFile, expectedHash: fake64Hash)
        XCTAssertFalse(mismatchResult, "哈希不匹配必须被拦截")
    }

    // MARK: - 2. 网络错误携带 ResumeData 自动转为 Paused

    func testHandleDownloadErrorWithResumeData() async {
        let manager = ModelDownloadManager(sessionFactory: { _ in
            URLSession(configuration: .ephemeral)
        })

        let modelId = "deepseek-r1-q4"
        let resumePayload = Data("fake_resume_chunk_data".utf8)
        let nsErrorWithResume = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: [NSURLSessionDownloadTaskResumeData: resumePayload]
        )

        await manager.handleDownloadError(for: modelId, error: nsErrorWithResume)

        let stream = await manager.observeDownloadState(for: modelId)
        var observedState: DownloadState?
        for await state in stream {
            observedState = state
            break
        }

        if case .paused = observedState {
            // 符合预期：有断点续传数据时自动转为 paused
        } else {
            XCTFail("携带 resumeData 的网络中断应转为 paused 状态，实际为: \(String(describing: observedState))")
        }
    }

    // MARK: - 3. 下载进度速率采样计算

    func testUpdateProgressSpeedCalculation() async {
        let manager = ModelDownloadManager(sessionFactory: { _ in
            URLSession(configuration: .ephemeral)
        })

        let modelId = "qwen-2.5-7b"
        let totalExpected: Int64 = 100 * 1024 * 1024

        // 首次写入 10MB
        await manager.updateProgress(for: modelId, totalBytesWritten: 10 * 1024 * 1024, totalBytesExpectedToWrite: totalExpected)

        let stream = await manager.observeDownloadState(for: modelId)
        var firstProgress: Double = 0
        for await state in stream {
            if case let .downloading(progress, _) = state {
                firstProgress = progress
                break
            }
        }

        XCTAssertEqual(firstProgress, 0.1, accuracy: 0.001)
    }
}
