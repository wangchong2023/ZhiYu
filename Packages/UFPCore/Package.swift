// swift-tools-version: 5.9
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

let package = Package(
    name: "UFPCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
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
        .package(path: "../../../../opensrc/swift/swift-dependencies")
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
