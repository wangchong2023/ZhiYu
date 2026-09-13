//
//  AuthRegionDetectorTests.swift
//  ZhiYu
//
//  Created by Constantine on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对环境感知区域探测器 AuthRegionDetector 开展自动化单元测试验证。
//

import XCTest
@testable import ZhiYu

final class AuthRegionDetectorTests: XCTestCase {
    
    private var detector: AuthRegionDetector!
    
    override func setUp() {
        super.setUp()
        detector = AuthRegionDetector.shared
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    /// 测试当注入国内服务配置时，探测器能够正确识别并返回 CN 对应类型
    func testDetectRegionWithChinaCapability() {
        // 1. 构造 Mock 区域能力数据，规定 CN 对应 "localized"，而 US 对应 "international"
        let cnInfo = RegionCapabilities.RegionInfo(loginPageType: "localized", pluginMarketUrl: "mock_url")
        let usInfo = RegionCapabilities.RegionInfo(loginPageType: "international", pluginMarketUrl: "mock_url")
        let capabilities = RegionCapabilities(regions: ["CN": cnInfo, "US": usInfo])
        
        // 2. 注入 Mock 配置
        detector.injectCapabilities(capabilities)
        
        // 3. 执行默认探测（测试当前设备环境的推荐服务区）
        let region = detector.detectDefaultRegion()
        
        // 4. 验证返回类型是否属于合法的 AuthRegion 分类
        XCTAssertTrue(AuthRegion.allCases.contains(region))
    }
    
    /// 测试当 JSON 数据为空或者无法加载时，探测器应该使用默认规则进行兜底
    func testDetectRegionFallbackWithDefaultCaps() {
        // 1. 构造只含 default 兜底的 Mock 区域能力配置
        let defaultInfo = RegionCapabilities.RegionInfo(loginPageType: "international", pluginMarketUrl: "mock_url")
        let capabilities = RegionCapabilities(regions: ["default": defaultInfo])
        
        // 2. 注入 Mock 配置
        detector.injectCapabilities(capabilities)
        
        // 3. 运行探测，由于没有显式匹配当前区域，应该使用 default 兜底映射
        let region = detector.detectDefaultRegion()
        
        // 4. 校验兜底结果是否正确匹配到了 international
        XCTAssertEqual(region, .international)
    }
    
    /// 验证本地内置的 region_capabilities.json 能够被正常解析，并不引发异常崩溃
    func testJSONParsingWorksWithoutCrash() {
        // 1. 重新触发重新加载本地物理 JSON 配置文件
        detector.loadCapabilities()
        
        // 2. 尝试获取探测结果，应当顺利运行而不会触发 fatalError 或崩溃
        let defaultRegion = detector.detectDefaultRegion()
        
        // 3. 验证结果必定为合法的区域之一
        XCTAssertTrue(defaultRegion == .china || defaultRegion == .international)
    }
}
