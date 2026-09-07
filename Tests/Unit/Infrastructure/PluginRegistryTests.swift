//
//  PluginRegistryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 PluginRegistry 开展多插件拦截器顺序一致性与安全性的自动化单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - Plugin Registry Tests (Security & Consistency)
final class PluginRegistryTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    @MainActor
    override func tearDown() async throws {
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    @MainActor
    func testMultiPluginInterceptorConsistency() {
        let registry = ServiceContainer.shared.resolve(PluginRegistry.self)

        // Mock Plugin 1: Adds a prefix
        let p1 = MockPlugin(id: "p1", preProcessor: { "P1: " + $0 })
        // Mock Plugin 2: Adds a suffix
        let p2 = MockPlugin(id: "p2", preProcessor: { $0 + " :P2" })

        registry.loadPlugin(p1)
        registry.loadPlugin(p2)

        let original = "Hello"
        let processed = registry.applyPreProcess(to: original)

        XCTAssertTrue(processed.contains("P1:"), "Should contain prefix from P1")
        XCTAssertTrue(processed.contains(":P2"), "Should contain suffix from P2")
        XCTAssertEqual(processed, "P1: Hello :P2", "Plugins should be applied sequentially")

        // Clean up
        registry.unloadPlugin(id: "p1")
        registry.unloadPlugin(id: "p2")
    }
}

// MARK: - Mock Plugin Helper
@MainActor
final class MockPlugin: InterceptionPlugin {
    let manifest: PluginManifest
    var monetization: MonetizationInfo?

    var preProcessor: ((String) -> String)?

    init(id: String, preProcessor: ((String) -> String)? = nil) {
        self.manifest = PluginManifest(
            id: id,
            version: "1.0.0",
            author: "Tester",
            permissions: ["writeContent"],
            names: ["en": id],
            descriptions: ["en": "Test plugin"]
        )
        self.preProcessor = preProcessor
    }

    func onLoad(context: PluginContext) {}
    func onUnload() {}

    func preProcess(content: String) throws -> String {
        preProcessor?(content) ?? content
    }

    func postProcess(content: String) throws -> String { content }
}
