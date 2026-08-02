// swift-tools-version: 5.9
//
//  Package.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：通用视觉设计系统包 (Universal Design System Package)。
//           提供跨平台 UI 原子组件、设计 Token (Colors, Spacing, Typography) 与 Bundle.module 资源分发。
//

import PackageDescription

let package = Package(
    name: "UFPDesignSystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "UFPDesignSystem",
            type: .static,
            targets: ["UFPDesignSystem"]
        )
    ],
    dependencies: [
        .package(path: "../UFPCore")
    ],
    targets: [
        .target(
            name: "UFPDesignSystem",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "UFPDesignSystemTests",
            dependencies: ["UFPDesignSystem"]
        )
    ]
)
