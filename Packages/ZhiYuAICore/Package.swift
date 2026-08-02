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

// MARK: - 开源库本地路径（通过 OPENSRC_ROOT 环境变量注入，参见 Config/.env.local）
let opensrcRoot = ProcessInfo.processInfo.environment["OPENSRC_ROOT"] ?? {
    fatalError("[ZhiYuAICore] 缺少 OPENSRC_ROOT 环境变量。请先执行: source Config/.env.local && bash Tools/Utils/bootstrap.sh")
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
