//
//  MockLogger.swift
//  UFPCoreTestMocks
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPCoreTestMocks]
//  核心职责：通用底座 Logger 的 Mock 测试存根，供其他 SPM 模块单测隔离使用。
//

import Foundation
import Combine
import UFPCore

/// MockLogger 存根，支持无磁盘 I/O 隔离测试
public final class MockLogger: @unchecked Sendable {
    public static let shared = MockLogger()
    public var logs: [String] = []

    public init() {}

    public func debug(_ message: String) {
        logs.append("[DEBUG] \(message)")
    }

    public func info(_ message: String) {
        logs.append("[INFO] \(message)")
    }

    public func warning(_ message: String) {
        logs.append("[WARNING] \(message)")
    }

    public func error(_ message: String) {
        logs.append("[ERROR] \(message)")
    }

    public func clear() {
        logs.removeAll()
    }
}
