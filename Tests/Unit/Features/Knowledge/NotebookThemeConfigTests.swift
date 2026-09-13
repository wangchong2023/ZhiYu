//
//  NotebookThemeConfigTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 NotebookThemeConfig 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

final class NotebookThemeConfigTests: XCTestCase {
    
    func testNotebookThemeConfigInitialization() {
        let colors = ["#FFFFFF", "#000000"]
        let config = NotebookThemeConfig(type: .linear, colors: colors, seed: 42)
        
        XCTAssertEqual(config.type, .linear)
        XCTAssertEqual(config.colors, colors)
        XCTAssertEqual(config.seed, 42)
    }
    
    func testNotebookThemeConfigCodable() throws {
        let colors = ["#FF5733", "#C70039"]
        let config = NotebookThemeConfig(type: .mesh, colors: colors, seed: 123)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(NotebookThemeConfig.self, from: data)
        
        XCTAssertEqual(config, decodedConfig)
    }
}
