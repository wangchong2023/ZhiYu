//
//  ModelDownloadManagerTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 ModelDownloadManager actor 的状态机分发、速率计算、checksum 注册与 SHA256 校验逻辑。
//

import XCTest
@testable import ZhiYu

final class ModelDownloadManagerTests: XCTestCase {

    private let testModelId = "test-model-batch7b"

    // MARK: - checksum 注册与查询

    func testRegisterChecksum_thenGetReturnsValue() async {
        let manager = ModelDownloadManager.shared
        let checksum = String(repeating: "a", count: 64)
        await manager.registerChecksum(for: testModelId, checksum: checksum)

        let result = await manager.getChecksum(for: testModelId)
        XCTAssertEqual(result, checksum)
    }

    func testGetChecksum_unregisteredModel_returnsNil() async {
        let manager = ModelDownloadManager.shared
        let result = await manager.getChecksum(for: "nonexistent-model-xyz")
        XCTAssertNil(result)
    }

    func testRegisterChecksum_overwritesPreviousValue() async {
        let manager = ModelDownloadManager.shared
        let first = String(repeating: "a", count: 64)
        let second = String(repeating: "b", count: 64)

        await manager.registerChecksum(for: testModelId, checksum: first)
        await manager.registerChecksum(for: testModelId, checksum: second)

        let result = await manager.getChecksum(for: testModelId)
        XCTAssertEqual(result, second)
    }

    // MARK: - updateState 状态分发

    func testUpdateState_toPending_succeeds() async {
        let manager = ModelDownloadManager.shared
        await manager.updateState(for: testModelId, to: .pending)

        let stream = await manager.observeDownloadState(for: testModelId)
        let expectation = expectation(description: "收到 pending 状态")

        Task {
            for await state in stream {
                if case .pending = state {
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testUpdateState_toFailed_succeeds() async {
        let manager = ModelDownloadManager.shared
        await manager.updateState(for: testModelId, to: .failed(error: "test error"))

        let stream = await manager.observeDownloadState(for: testModelId)
        let expectation = expectation(description: "收到 failed 状态")

        Task {
            for await state in stream {
                if case .failed(let msg) = state {
                    XCTAssertEqual(msg, "test error")
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testUpdateState_toVerifying_succeeds() async {
        let manager = ModelDownloadManager.shared
        await manager.updateState(for: testModelId, to: .verifying)

        let stream = await manager.observeDownloadState(for: testModelId)
        let expectation = expectation(description: "收到 verifying 状态")

        Task {
            for await state in stream {
                if case .verifying = state {
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - updateProgress 速率计算

    func testUpdateProgress_firstCall_initializesTracker() async {
        let manager = ModelDownloadManager.shared
        await manager.updateProgress(
            for: testModelId,
            totalBytesWritten: 100,
            totalBytesExpectedToWrite: 1000
        )

        let stream = await manager.observeDownloadState(for: testModelId)
        let expectation = expectation(description: "收到 downloading 状态")

        Task {
            for await state in stream {
                if case .downloading(let progress, _) = state {
                    XCTAssertEqual(progress, 0.1, accuracy: 0.001)
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testUpdateProgress_zeroExpectedBytes_guardSkips() async {
        let manager = ModelDownloadManager.shared
        await manager.updateProgress(
            for: testModelId,
            totalBytesWritten: 50,
            totalBytesExpectedToWrite: 0
        )

        // totalBytesExpectedToWrite == 0 时 guard 直接 return，状态不更新
        // 验证不崩溃即可
    }

    func testUpdateProgress_legacyOverload_updatesState() async {
        let manager = ModelDownloadManager.shared
        await manager.updateProgress(for: testModelId, progress: 0.5)

        let stream = await manager.observeDownloadState(for: testModelId)
        let expectation = expectation(description: "收到 downloading 50% 状态")

        Task {
            for await state in stream {
                if case .downloading(let progress, let speed) = state {
                    XCTAssertEqual(progress, 0.5, accuracy: 0.001)
                    XCTAssertEqual(speed, 0)
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - clearActiveTask

    func testClearActiveTask_doesNotCrash() async {
        let manager = ModelDownloadManager.shared
        await manager.clearActiveTask(for: testModelId)
        // 验证不崩溃即可
    }

    // MARK: - handleDownloadError

    func testHandleDownloadError_withResumeData_transitionsToPaused() async {
        let manager = ModelDownloadManager.shared
        let resumeData = Data([0x00, 0x01, 0x02])
        let userInfo: [String: Any] = [NSURLSessionDownloadTaskResumeData: resumeData]
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: userInfo)

        await manager.handleDownloadError(for: testModelId, error: error)

        let stream = await manager.observeDownloadState(for: testModelId)
        let expectation = expectation(description: "收到 paused 状态")

        Task {
            for await state in stream {
                if case .paused = state {
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testHandleDownloadError_withoutResumeData_transitionsToFailed() async {
        let manager = ModelDownloadManager.shared
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        await manager.handleDownloadError(for: testModelId, error: error)

        let stream = await manager.observeDownloadState(for: testModelId)
        let expectation = expectation(description: "收到 failed 状态")

        Task {
            for await state in stream {
                if case .failed = state {
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - observeDownloadState 初始状态

    func testObserveDownloadState_idleModel_returnsFailedIdle() async {
        let manager = ModelDownloadManager.shared
        let stream = await manager.observeDownloadState(for: "idle-model-xyz")
        let expectation = expectation(description: "收到初始 idle 状态")

        Task {
            for await state in stream {
                if case .failed(let msg) = state {
                    XCTAssertTrue(msg.contains("Idle"))
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
