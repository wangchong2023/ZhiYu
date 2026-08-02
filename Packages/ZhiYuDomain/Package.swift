// swift-tools-version: 5.9
//
//  Package.swift
//  ZhiYuDomain
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomain]
//  核心职责：智宇业务领域大脑包定义 (ZhiYu Domain Core Package)。
//           定义智宇领域模型 (KnowledgePage, PageChunk)、领域常量与 DIP 隔离层契约协议 (MemoryEngineProtocol)。
//

import PackageDescription

let package = Package(
    name: "ZhiYuDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "ZhiYuDomain",
            type: .static,
            targets: ["ZhiYuDomain"]
        ),
        .library(
            name: "ZhiYuDomainTestMocks",
            type: .static,
            targets: ["ZhiYuDomainTestMocks"]
        )
    ],
    dependencies: [
        .package(path: "../UFPCore")
    ],
    targets: [
        .target(
            name: "ZhiYuDomain",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore")
            ]
        ),
        .target(
            name: "ZhiYuDomainTestMocks",
            dependencies: [
                "ZhiYuDomain",
                .product(name: "UFPCoreTestMocks", package: "UFPCore")
            ]
        ),
        .testTarget(
            name: "ZhiYuDomainTests",
            dependencies: [
                "ZhiYuDomain",
                "ZhiYuDomainTestMocks"
            ]
        )
    ]
)
