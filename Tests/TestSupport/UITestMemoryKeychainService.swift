//
//  UITestMemoryKeychainService.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试替身
//  核心职责：无真实凭据的 UI 测试仅使用内存，避免访问系统钥匙串或弹出授权窗口。
//
import UFPCore

@MainActor
final class UITestMemoryKeychainService: KeychainService, @unchecked Sendable {
    private var values: [String: String] = [:]

    nonisolated override func store(key: String, value: String) throws {
        runOnMainSync { values[key] = value }
    }

    nonisolated override func retrieve(key: String) throws -> String? {
        runOnMainSync { values[key] }
    }

    nonisolated override func delete(key: String) throws {
        runOnMainSync { values[key] = nil }
    }
}
