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
                .product(name: "Lottie", package: "lottie-ios", condition: .when(platforms: [.iOS, .macOS, .macCatalyst])),
                .product(name: "MarkdownUI", package: "swift-markdown-ui", condition: .when(platforms: [.iOS, .macOS, .macCatalyst]))
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
