// swift-tools-version: 6.4
//
//  Package.swift
//  UFPCore
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPCore]
//  核心职责：通用集成平台底座包定义 (Universal Foundation Platform Core Package)。
//           提供核心 DI 容器、系统日志、触感反馈、安全防护与基础底层协议。
//

import PackageDescription
import Foundation

// MARK: - 开源库本地路径自动智能推导（环境变量优先 -> 向上解析 Config/.env.local -> 默认降级路径）
let opensrcRoot: String = {
    if let env = ProcessInfo.processInfo.environment["OPENSRC_ROOT"], !env.isEmpty {
        return env
    }
    let envFile = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Config/.env.local")
    if let content = try? String(contentsOf: envFile, encoding: .utf8) {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OPENSRC_ROOT=") {
                let val = trimmed.replacingOccurrences(of: "OPENSRC_ROOT=", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !val.isEmpty { return val }
            }
        }
    }
    return "/Users/constantine/Documents/work/code/opensrc/swift"
}()

let package = Package(
    name: "UFPCore",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .watchOS(.v27)
    ],
    products: [
        .library(
            name: "UFPCore",
            type: .static,
            targets: ["UFPCore"]
        ),
        .library(
            name: "UFPCoreTestMocks",
            type: .static,
            targets: ["UFPCoreTestMocks"]
        )
    ],
    dependencies: [
        // swift-dependencies：@Dependency 属性包装器 + DependencyKey 注册体系
        // 离线优先：本地克隆到 ${OPENSRC_ROOT}/swift-dependencies
        // 传递依赖：combine-schedulers, swift-clocks, swift-concurrency-extras,
        //          xctest-dynamic-overlay, swift-syntax（均已本地克隆）
        .package(path: "\(opensrcRoot)/swift-dependencies")
    ],
    targets: [
        .target(
            name: "UFPCore",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "UFPCoreTestMocks",
            dependencies: ["UFPCore"]
        ),
        .testTarget(
            name: "UFPCoreTests",
            dependencies: ["UFPCore", "UFPCoreTestMocks"]
        )
    ]
)
