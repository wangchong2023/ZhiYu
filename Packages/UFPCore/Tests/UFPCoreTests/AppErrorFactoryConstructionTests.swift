//
//  AppErrorFactoryConstructionTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 AppErrorFactory 通用错误工厂构造能力、默认错误码与本地化描述映射。
//

import XCTest
@testable import UFPCore

final class AppErrorFactoryConstructionTests: XCTestCase {

    func testMake_customParameters_createsNSErrorWithDomainCodeAndDescription() {
        let testDomain = "com.zhiyu.test.domain"
        let testCode = 4041
        let testDescription = "找不到指定的目标资源实体"

        let error = AppErrorFactory.make(
            domain: testDomain,
            code: testCode,
            description: testDescription
        )

        XCTAssertEqual(error.domain, testDomain, "NSError domain 必须与传入参数完全一致")
        XCTAssertEqual(error.code, testCode, "NSError code 必须与传入参数完全一致")
        XCTAssertEqual(error.localizedDescription, testDescription, "NSError 本地化描述必须与传入说明一致")
        XCTAssertEqual(
            error.userInfo[NSLocalizedDescriptionKey] as? String,
            testDescription,
            "userInfo 中 NSLocalizedDescriptionKey 必须包含对应描述"
        )
    }

    func testMake_defaultCode_usesSystemConstantsDefaultCode() {
        let testDomain = "com.zhiyu.default.domain"
        let testDescription = "常规默认异常说明"

        let error = AppErrorFactory.make(
            domain: testDomain,
            description: testDescription
        )

        XCTAssertEqual(error.domain, testDomain)
        XCTAssertEqual(
            error.code,
            SystemConstants.ErrorCode.default,
            "未指定 code 时必须使用 SystemConstants.ErrorCode.default"
        )
        XCTAssertEqual(error.localizedDescription, testDescription)
    }

    func testMake_emptyDescription_preservesEmptyString() {
        let error = AppErrorFactory.make(domain: "empty", description: "")
        XCTAssertEqual(error.localizedDescription, "")
        XCTAssertEqual(error.userInfo[NSLocalizedDescriptionKey] as? String, "")
    }
}
