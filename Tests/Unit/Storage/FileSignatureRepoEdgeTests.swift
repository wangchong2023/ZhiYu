//
//  FileSignatureRepoEdgeTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 SQLiteFileSignatureRepository 的 saveSignature/fetchSignature/
//           fetchSignatureCount 边界条件，包括同路径覆盖、空字符串、特殊字符等。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class FileSignatureRepoEdgeTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var repo: SQLiteFileSignatureRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        // SQLiteFileSignatureRepository 持有传入的 dbWriter
        let writer = await DatabaseManager.shared.globalWriter
        guard let unwrappedWriter = writer else {
            XCTFail("globalWriter 不应为 nil")
            return
        }
        repo = SQLiteFileSignatureRepository(dbWriter: unwrappedWriter)
    }

    override func tearDownWithError() throws {
        repo = nil
        dbQueue = nil
    }

    // MARK: - fetchSignatureCount

    /// 验证：空表时 fetchSignatureCount 返回 0。
    func testFetchSignatureCountEmpty() async throws {
        let count = try await repo.fetchSignatureCount()
        XCTAssertEqual(count, 0, "空表应返回 0")
    }

    /// 验证：插入后 fetchSignatureCount 正确递增。
    func testFetchSignatureCountIncrements() async throws {
        try await repo.saveSignature("sig1", forFilePath: "/path/1", salt: "salt1")
        let count1 = try await repo.fetchSignatureCount()
        XCTAssertEqual(count1, 1)

        try await repo.saveSignature("sig2", forFilePath: "/path/2", salt: "salt2")
        let count2 = try await repo.fetchSignatureCount()
        XCTAssertEqual(count2, 2)
    }

    // MARK: - saveSignature / fetchSignature

    /// 验证：saveSignature 后 fetchSignature 能检索到。
    func testSaveAndFetchSignature() async throws {
        try await repo.saveSignature("hmac-sha256-abc", forFilePath: "/var/file.txt", salt: "NaCl")

        let fetched = try await repo.fetchSignature(forFilePath: "/var/file.txt")
        XCTAssertEqual(fetched, "hmac-sha256-abc", "应能检索到保存的签名")
    }

    /// 验证：同 filePath 再次 saveSignature 执行覆盖（GRDB save 语义）。
    func testSaveSignatureOverwritesSamePath() async throws {
        try await repo.saveSignature("old-sig", forFilePath: "/path/same", salt: "salt1")
        try await repo.saveSignature("new-sig", forFilePath: "/path/same", salt: "salt2")

        let fetched = try await repo.fetchSignature(forFilePath: "/path/same")
        XCTAssertEqual(fetched, "new-sig", "同路径应覆盖")
        let count = try await repo.fetchSignatureCount()
        XCTAssertEqual(count, 1, "覆盖不应增加记录数")
    }

    /// 验证：fetchSignature 对不存在的路径返回 nil。
    func testFetchSignatureNonExistentReturnsNil() async throws {
        let fetched = try await repo.fetchSignature(forFilePath: "/nonexistent")
        XCTAssertNil(fetched, "不存在的路径应返回 nil")
    }

    // MARK: - 边界值与特殊字符

    /// 验证：空字符串作为 filePath/signature/salt 也能保存。
    func testEmptyStringsSaved() async throws {
        try await repo.saveSignature("", forFilePath: "", salt: "")

        let fetched = try await repo.fetchSignature(forFilePath: "")
        XCTAssertEqual(fetched, "", "空字符串签名应能保存和检索")
    }

    /// 验证：filePath 含 SQL 注入字符（单引号、分号、注释）能安全保存。
    func testSQLInjectionCharsInFilePath() async throws {
        let maliciousPath = "/path/'; DROP TABLE file_signatures; --"
        try await repo.saveSignature("sig", forFilePath: maliciousPath, salt: "salt")

        let fetched = try await repo.fetchSignature(forFilePath: maliciousPath)
        XCTAssertEqual(fetched, "sig", "SQL 注入字符应被参数化查询安全处理")

        // 表应仍然存在
        let count = try await repo.fetchSignatureCount()
        XCTAssertEqual(count, 1, "表不应被 DROP")
    }

    /// 验证：signature 含特殊字符（引号、Unicode、emoji）能完整存取。
    func testSpecialCharsInSignature() async throws {
        let specialSig = "sig'with\"quotes\\backslash and emoji 🔐"
        try await repo.saveSignature(specialSig, forFilePath: "/path/special", salt: "salt")

        let fetched = try await repo.fetchSignature(forFilePath: "/path/special")
        XCTAssertEqual(fetched, specialSig, "特殊字符应完整存取")
    }

    /// 验证：超长 filePath（10KB）能正常存取。
    func testVeryLongFilePath() async throws {
        let longPath = String(repeating: "a", count: 10_000)
        try await repo.saveSignature("sig", forFilePath: longPath, salt: "salt")

        let fetched = try await repo.fetchSignature(forFilePath: longPath)
        XCTAssertEqual(fetched, "sig", "超长路径应能存取")
    }

    /// 验证：filePath 含中文、日文、韩文等 Unicode 能正常存取。
    func testUnicodeFilePath() async throws {
        let unicodePaths = ["/路径/文件.txt", "/パス/ファイル.txt", "/경로/파일.txt"]
        for (idx, path) in unicodePaths.enumerated() {
            try await repo.saveSignature("sig\(idx)", forFilePath: path, salt: "salt")
        }

        for (idx, path) in unicodePaths.enumerated() {
            let fetched = try await repo.fetchSignature(forFilePath: path)
            XCTAssertEqual(fetched, "sig\(idx)", "Unicode 路径应能存取")
        }

        let count = try await repo.fetchSignatureCount()
        XCTAssertEqual(count, unicodePaths.count)
    }

    // MARK: - 并发写入（语义验证）

    /// 验证：并发写入不同路径不丢失数据（GRDB 串行化）。
    func testConcurrentWritesToDifferentPaths() async throws {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask { [self] in
                    try? await repo.saveSignature("sig\(i)", forFilePath: "/path/\(i)", salt: "salt")
                }
            }
        }

        let count = try await repo.fetchSignatureCount()
        XCTAssertEqual(count, 20, "并发写入不应丢失数据")

        // 抽样验证
        let fetched = try await repo.fetchSignature(forFilePath: "/path/10")
        XCTAssertEqual(fetched, "sig10")
    }
}
