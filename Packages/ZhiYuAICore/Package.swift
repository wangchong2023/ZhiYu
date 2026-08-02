// swift-tools-version: 5.9
//
//  Package.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICore]
//  核心职责：智宇 AI 中台包 (ZhiYu AI Core Package)。
//           提供 PromptSecuritySanitizer 提示词沙箱、ContextReranker 二阶段降噪重排与 Native/Swarm 记忆引擎适配器。
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
    name: "ZhiYuAICore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "ZhiYuAICore",
            type: .static,
            targets: ["ZhiYuAICore"]
        ),
        .library(
            name: "ZhiYuAICoreTestMocks",
            type: .static,
            targets: ["ZhiYuAICoreTestMocks"]
        )
    ],
    dependencies: [
        .package(path: "../UFPCore"),
        .package(path: "../UFPStorage"),
        .package(path: "../ZhiYuDomain"),
        .package(path: "\(opensrcRoot)/SwiftJSONSanitizer"),
        .package(path: "\(opensrcRoot)/PartialJSON")
    ],
    targets: [
        .target(
            name: "ZhiYuAICore",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore"),
                .product(name: "UFPStorage", package: "UFPStorage"),
                .product(name: "ZhiYuDomain", package: "ZhiYuDomain"),
                .product(name: "SwiftJSONSanitizerDynamic", package: "SwiftJSONSanitizer"),
                .product(name: "PartialJSON", package: "PartialJSON")
            ]
        ),
        .target(
            name: "ZhiYuAICoreTestMocks",
            dependencies: [
                "ZhiYuAICore",
                .product(name: "ZhiYuDomainTestMocks", package: "ZhiYuDomain")
            ]
        ),
        .testTarget(
            name: "ZhiYuAICoreTests",
            dependencies: [
                "ZhiYuAICore",
                "ZhiYuAICoreTestMocks"
            ]
        )
    ]
)
