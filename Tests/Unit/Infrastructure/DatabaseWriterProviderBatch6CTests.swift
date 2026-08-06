//
//  DatabaseWriterProviderBatch6CTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 DatabaseWriterProvider 协议默认实现的错误抛出路径（Finding #17 修复后）。
//

import XCTest
import UFPStorage
@testable import ZhiYu

@MainActor
final class DatabaseWriterProviderBatch6CTests: XCTestCase {

    private var tempDir: URL!
    private var savedDbWriter: (any DatabaseWriter)?
    private var savedGlobalWriter: (any DatabaseWriter)?
    private var savedIsInTesting: Bool = false

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WriterProviderTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // 保存状态，测试后恢复，避免污染其他测试
        savedDbWriter = DatabaseManager.shared.dbWriter
        savedGlobalWriter = DatabaseManager.shared.globalWriter
        savedIsInTesting = DatabaseManager.shared.isInTesting
        DatabaseManager.shared.reset()
    }

    override func tearDown() async throws {
        // 恢复 DatabaseManager 的 writer 和测试标志
        DatabaseManager.shared.dbWriter = savedDbWriter
        DatabaseManager.shared.globalWriter = savedGlobalWriter
        DatabaseManager.shared.isInTesting = savedIsInTesting
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try await super.tearDown()
    }

    // MARK: - Finding #17 修复验证：dbWriter 为 nil 时抛 ZhiYu.DatabaseError.notReady

    /// Finding #17 修复后：dbWriter 为 nil 时抛 ZhiYu.DatabaseError.notReady，而非静默降级创建内存库。
    func testFinding17_dbWriter为Nil_抛NotReady错误() async {
        let provider = StubWriterProvider()
        XCTAssertNil(DatabaseManager.shared.dbWriter, "前置条件：dbWriter 应为 nil")

        do {
            _ = try await provider.dbWriter
            XCTFail("Finding #17 修复后：dbWriter 为 nil 时应抛 ZhiYu.DatabaseError.notReady")
        } catch ZhiYu.DatabaseError.notReady {
            // 预期行为：抛错而非静默降级
        } catch {
            XCTFail("应抛 ZhiYu.DatabaseError.notReady，实际：\(error)")
        }
    }

    /// Finding #17 修复后：连续获取 dbWriter 在 nil 时都抛错（不再每次创建新内存库）。
    func testFinding17_连续获取在Nil时都抛错() async {
        let provider = StubWriterProvider()
        XCTAssertNil(DatabaseManager.shared.dbWriter)

        for index in 0..<3 {
            do {
                _ = try await provider.dbWriter
                XCTFail("第 \(index) 次获取应抛 ZhiYu.DatabaseError.notReady")
            } catch {
                if let dbError = error as? ZhiYu.DatabaseError, case .notReady = dbError {
                    // 预期行为
                } else {
                    XCTFail("第 \(index) 次应抛 ZhiYu.DatabaseError.notReady，实际：\(error)")
                }
            }
        }
    }

    // MARK: - dbWriter 正常路径

    func testDbWriter_正常路径返回真实Writer() async throws {
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue

        let provider = StubWriterProvider()
        let writer = try await provider.dbWriter

        XCTAssertNotNil(writer, "dbWriter 正常时应返回真实 writer")
    }

    // MARK: - reset 后抛错

    func testDbWriter_reset后抛NotReady() async throws {
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue

        let provider = StubWriterProvider()
        let writer1 = try await provider.dbWriter
        XCTAssertNotNil(writer1)

        // reset 后 dbWriter 为 nil
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.dbWriter)

        // Finding #17 修复后：reset 后抛错而非降级
        do {
            _ = try await provider.dbWriter
            XCTFail("reset 后 dbWriter 为 nil 时应抛 ZhiYu.DatabaseError.notReady")
        } catch ZhiYu.DatabaseError.notReady {
            // 预期行为
        } catch {
            XCTFail("应抛 ZhiYu.DatabaseError.notReady，实际：\(error)")
        }
    }
}

/// 测试用 DatabaseWriterProvider stub
private final class StubWriterProvider: DatabaseWriterProvider {}
