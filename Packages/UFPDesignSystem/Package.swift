// swift-tools-version: 5.9
//
//  Package.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：通用视觉设计系统包 (Universal Foundation Platform Design System)。
//           提供跨平台 UI 原子组件、设计 Token (Colors, Spacing, Typography) 与 Bundle.module 资源分发。
//

import PackageDescription
import Foundation

// MARK: - 开源库本地路径（通过 OPENSRC_ROOT 环境变量注入，参见 Config/.env.local）
let opensrcRoot = ProcessInfo.processInfo.environment["OPENSRC_ROOT"] ?? {
    fatalError("[UFPDesignSystem] 缺少 OPENSRC_ROOT 环境变量。请先执行: source Config/.env.local && bash Tools/Utils/bootstrap.sh")
}()

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
        .package(path: "../UFPCore"),
        .package(path: "\(opensrcRoot)/lottie-ios"),
        .package(path: "\(opensrcRoot)/swift-markdown-ui")
    ],
    targets: [
        .target(
            name: "UFPDesignSystem",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore"),
                .product(name: "Lottie", package: "lottie-ios", condition: .when(platforms: [.iOS, .macOS])),
                .product(name: "MarkdownUI", package: "swift-markdown-ui", condition: .when(platforms: [.iOS, .macOS]))
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
