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
    dependencies: [],
    targets: [
        .target(
            name: "UFPCore",
            dependencies: []
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
