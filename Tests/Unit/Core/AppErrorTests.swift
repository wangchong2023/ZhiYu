//
//  AppErrorTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 AppError 统一错误工厂的 domain/code/localizedDescription 契约。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class AppErrorTests: XCTestCase {

    // MARK: - make 工厂

    func testMake_默认code_为负一() {
        let error = AppError.make(domain: "TestDomain", description: "测试错误")
        XCTAssertEqual(error.domain, "TestDomain")
        XCTAssertEqual(error.code, -1)
        XCTAssertEqual(error.localizedDescription, "测试错误")
    }

    func testMake_自定义code_正确传递() {
        let error = AppError.make(domain: "TestDomain", code: 42, description: "自定义码")
        XCTAssertEqual(error.code, 42)
        XCTAssertEqual(error.localizedDescription, "自定义码")
    }

    func testMake_userInfo_包含LocalizedDescriptionKey() {
        let error = AppError.make(domain: "D", description: "desc")
        XCTAssertEqual(error.userInfo[NSLocalizedDescriptionKey] as? String, "desc")
    }

    // MARK: - insight 便捷方法

    func testInsight_默认code_为负一() {
        let error = AppError.insight("洞察错误")
        XCTAssertEqual(error.domain, CoreConstants.ErrorDomain.insight)
        XCTAssertEqual(error.code, -1)
        XCTAssertEqual(error.localizedDescription, "洞察错误")
    }

    func testInsight_自定义code_正确传递() {
        let error = AppError.insight("洞察错误", code: 100)
        XCTAssertEqual(error.code, 100)
    }

    // MARK: - ingest 便捷方法

    func testIngest_默认code_为负一() {
        let error = AppError.ingest("摄入错误")
        XCTAssertEqual(error.domain, CoreConstants.ErrorDomain.ingestStore)
        XCTAssertEqual(error.code, -1)
    }

    // MARK: - exportNotSupported 便捷方法

    func testExportNotSupported_默认code_为501() {
        let error = AppError.exportNotSupported()
        XCTAssertEqual(error.code, 501)
        XCTAssertEqual(error.domain, CoreConstants.ErrorDomain.export)
    }

    func testExportNotSupported_自定义描述_正确传递() {
        let error = AppError.exportNotSupported("不支持导出 PDF")
        XCTAssertEqual(error.localizedDescription, "不支持导出 PDF")
    }

    // MARK: - auth 便捷方法

    func testAuth_自定义domain_正确传递() {
        let error = AppError.auth(domain: "AuthDomain", code: 401, description: "未授权")
        XCTAssertEqual(error.domain, "AuthDomain")
        XCTAssertEqual(error.code, 401)
        XCTAssertEqual(error.localizedDescription, "未授权")
    }

    // MARK: - synthesis 便捷方法

    func testSynthesis_默认code_为负一() {
        let error = AppError.synthesis("合成错误")
        XCTAssertEqual(error.domain, CoreConstants.ErrorDomain.synthesisStore)
        XCTAssertEqual(error.code, -1)
    }

    // MARK: - security 便捷方法

    func testSecurity_默认code_为404() {
        let error = AppError.security("安全错误")
        XCTAssertEqual(error.domain, CoreConstants.ErrorDomain.securityManager)
        XCTAssertEqual(error.code, 404)
    }

    func testSecurity_自定义code_正确传递() {
        let error = AppError.security("安全错误", code: 403)
        XCTAssertEqual(error.code, 403)
    }
}
