//
//  ExportServiceProtocolTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 ExportError 枚举的本地化描述契约与 ExportServiceProtocol 方法签名。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class ExportServiceProtocolTests: XCTestCase {

    // MARK: - errorDescription 非空

    func testErrorDescription_systemBusy_非空() {
        XCTAssertFalse(ExportError.systemBusy.errorDescription?.isEmpty ?? true)
    }

    func testErrorDescription_engineNotReady_非空() {
        XCTAssertFalse(ExportError.engineNotReady.errorDescription?.isEmpty ?? true)
    }

    func testErrorDescription_internalError_非空() {
        XCTAssertFalse(ExportError.internalError("test").errorDescription?.isEmpty ?? true)
    }

    // MARK: - internalError 关联值

    /// internalError 的 errorDescription 已包含关联值消息（finding #2 已修复：xcstrings 添加 %@ 占位符）
    func testErrorDescription_internalError_包含关联值() {
        let message = "引擎崩溃详情"
        let desc = ExportError.internalError(message).errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains(message) ?? false, "errorDescription 应包含关联值消息")
    }

    /// 不同关联值产生不同 errorDescription（finding #2 已修复）
    func testErrorDescription_internalError_不同关联值_不同描述() {
        let desc1 = ExportError.internalError("错误A").errorDescription
        let desc2 = ExportError.internalError("错误B").errorDescription
        XCTAssertNotEqual(desc1, desc2, "不同关联值应返回不同描述")
    }

    // MARK: - Error 协议遵循

    /// ExportError 应遵循 Error 协议（可被 throw）
    func testExportError_遵循Error协议() {
        func throwError(_ error: ExportError) throws {
            throw error
        }
        XCTAssertThrowsError(try throwError(.systemBusy)) { error in
            XCTAssertTrue(error is ExportError)
        }
    }

    // MARK: - LocalizedError 协议遵循

    /// ExportError 应遵循 LocalizedError（有 errorDescription）
    func testExportError_遵循LocalizedError协议() {
        let errors: [ExportError] = [.systemBusy, .engineNotReady, .internalError("msg")]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) 应有 errorDescription")
        }
    }

    // MARK: - Sendable 遵循

    /// ExportError 应遵循 Sendable（可跨 actor 传递）
    func testExportError_遵循Sendable协议() {
        // 编译时检查：Sendable 协议遵循（通过函数参数类型约束验证）
        func acceptSendable<T: Sendable>(_: T) {}
        acceptSendable(ExportError.systemBusy)
        acceptSendable(ExportError.engineNotReady)
        acceptSendable(ExportError.internalError("test"))
    }

    // MARK: - ExportServiceProtocol 方法签名验证

    /// UnsupportedExportService 应实现 ExportServiceProtocol 的 3 个方法
    func testUnsupportedExportService_实现ExportServiceProtocol() async {
        let service = UnsupportedExportService()

        // exportToPDF 应抛错
        do {
            _ = try await service.exportToPDF(markdown: "# test", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
            XCTAssertEqual(nsError.code, SystemConstants.HTTPStatusCode.notImplemented)
        }

        // exportMindmapToPDF 应抛错
        do {
            _ = try await service.exportMindmapToPDF(mermaidCode: "graph TD", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
        }

        // exportToPPTX 应抛错
        do {
            _ = try await service.exportToPPTX(markdown: "# test", fileName: "test.pptx")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
        }
    }
}
