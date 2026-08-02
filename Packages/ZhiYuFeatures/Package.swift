// swift-tools-version: 5.9
//
//  Package.swift
//  ZhiYuFeatures
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuFeatures]
//  核心职责：智宇垂直业务功能切片包 (ZhiYu Vertical Features Slices Package)。
//           提供 ZhiYuFeaturesAI (Chat/Synthesis/Voice), ZhiYuFeaturesKnowledge (Vault/Graph/Search), ZhiYuFeaturesInsight (Dashboard/Lint)。
//

import PackageDescription

let package = Package(
    name: "ZhiYuFeatures",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "ZhiYuFeatures",
            type: .static,
            targets: ["ZhiYuFeaturesAI", "ZhiYuFeaturesKnowledge", "ZhiYuFeaturesInsight"]
        ),
        .library(
            name: "ZhiYuFeaturesAI",
            type: .static,
            targets: ["ZhiYuFeaturesAI"]
        ),
        .library(
            name: "ZhiYuFeaturesKnowledge",
            type: .static,
            targets: ["ZhiYuFeaturesKnowledge"]
        ),
        .library(
            name: "ZhiYuFeaturesInsight",
            type: .static,
            targets: ["ZhiYuFeaturesInsight"]
        )
    ],
    dependencies: [
        .package(path: "../UFPCore"),
        .package(path: "../UFPDesignSystem"),
        .package(path: "../ZhiYuDomain"),
        .package(path: "../ZhiYuAICore")
    ],
    targets: [
        .target(
            name: "ZhiYuFeaturesAI",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore"),
                .product(name: "UFPDesignSystem", package: "UFPDesignSystem"),
                .product(name: "ZhiYuDomain", package: "ZhiYuDomain"),
                .product(name: "ZhiYuAICore", package: "ZhiYuAICore")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ZhiYuFeaturesKnowledge",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore"),
                .product(name: "UFPDesignSystem", package: "UFPDesignSystem"),
                .product(name: "ZhiYuDomain", package: "ZhiYuDomain")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ZhiYuFeaturesInsight",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore"),
                .product(name: "UFPDesignSystem", package: "UFPDesignSystem"),
                .product(name: "ZhiYuDomain", package: "ZhiYuDomain")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ZhiYuFeaturesTests",
            dependencies: [
                "ZhiYuFeaturesAI",
                "ZhiYuFeaturesKnowledge",
                "ZhiYuFeaturesInsight"
            ]
        )
    ]
)
