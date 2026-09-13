//
//  AIProcessingAttributesTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AIProcessingAttributes 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit

final class AIProcessingAttributesTests: XCTestCase {
    
    func testAttributesInitialization() {
        let startTime = Date()
        let attributes = AIProcessingAttributes(taskName: "AI 治理扫描", startTime: startTime)
        
        XCTAssertEqual(attributes.taskName, "AI 治理扫描")
        XCTAssertEqual(attributes.startTime, startTime)
    }
    
    func testContentStateInitialization() {
        let state = AIProcessingAttributes.ContentState(progress: 0.72, status: "Extracting Entities...")
        
        XCTAssertEqual(state.progress, 0.72)
        XCTAssertEqual(state.status, "Extracting Entities...")
    }
    
    func testContentStateCodable() throws {
        let state = AIProcessingAttributes.ContentState(progress: 0.5, status: "Processing")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(AIProcessingAttributes.ContentState.self, from: data)
        
        XCTAssertEqual(decodedState.progress, 0.5)
        XCTAssertEqual(decodedState.status, "Processing")
    }
}
#endif
