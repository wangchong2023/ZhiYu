//
//  TestAppEnvironment.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试基础设施
//  核心职责：显式创建前台内存环境，测试不得启动正式应用生命周期。
//
import Foundation
import UFPCore
@testable import ZhiYuUnitTestHost

@MainActor
enum TestAppEnvironment {
    static let shared: AppEnvironment = {
        ServiceContainer.shared.register(MockKeychainService(), for: KeychainService.self)
        ServiceContainer.shared.register(ApplicationStorageLocation(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)), for: ApplicationStorageLocation.self)
        ServiceContainer.shared.register(EphemeralDatabaseBootstrapStrategy() as any DatabaseBootstrapStrategy, for: (any DatabaseBootstrapStrategy).self)
        return AppEnvironment(startsBackgroundServices: false)
    }()
}
