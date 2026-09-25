//
//  LogStatusTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 LogStatus 枚举的 rawValue 契约、Codable 往返与 localizedName 非空性。
//

import XCTest
@testable import ZhiYu

final class LogStatusTests: XCTestCase {

    // MARK: - rawValue 契约

    func testRawValueThreeCasesValuesCorrect() {
        XCTAssertEqual(LogStatus.success.rawValue, "success")
        XCTAssertEqual(LogStatus.failure.rawValue, "failure")
        XCTAssertEqual(LogStatus.processing.rawValue, "processing")
    }

    func testRawValueCaseIterableCoversAll() {
        XCTAssertEqual(LogStatus.allCases.count, 3)
        XCTAssertEqual(LogStatus.allCases, [.success, .failure, .processing])
    }

    // MARK: - Codable 往返

    func testCodableEncodeDecodeRoundtripConsistent() throws {
        for status in LogStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(LogStatus.self, from: data)
            XCTAssertEqual(decoded, status, "Codable 往返应保持一致：\(status)")
        }
    }

    func testCodableDecodeFromRawValueSuccess() throws {
        let json = Data(#""success""#.utf8)
        let decoded = try JSONDecoder().decode(LogStatus.self, from: json)
        XCTAssertEqual(decoded, .success)
    }

    // MARK: - localizedName 非空

    func testLocalizedNameAllCasesReturnsNonEmptyNonMissing() {
        for status in LogStatus.allCases {
            let name = status.localizedName
            XCTAssertFalse(name.isEmpty, "localizedName 不应为空：\(status)")
            XCTAssertFalse(name.contains("[MISSING"), "localizedName 不应包含 MISSING 占位符：\(status)")
        }
    }

    // MARK: - Sendable 约束

    func testSendableCrossActorTransferCompileTimeGuarantee() {
        // LogStatus 声明为 Sendable，此测试验证运行时可跨 actor 传递
        let expectation = expectation(description: "跨 actor 传递")
        Task {
            let status: LogStatus = .success
            await Task.detached {
                XCTAssertEqual(status, .success)
                expectation.fulfill()
            }.value
        }
        wait(for: [expectation], timeout: 5)
    }
}
