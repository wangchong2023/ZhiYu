// swift-tools-version: 5.9
//
//  Package.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage]
//  核心职责：通用存储引擎包 (Universal Storage Package)。
//           彻底封装底层 GRDB 依赖与物理数据库迁移/算子，上层模块绝对禁止直接 import GRDB。
//

import PackageDescription

let package = Package(
    name: "UFPStorage",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "UFPStorage",
            type: .static,
            targets: ["UFPStorage"]
        ),
        .library(
            name: "UFPStorageTestMocks",
            type: .static,
            targets: ["UFPStorageTestMocks"]
        )
    ],
    dependencies: [
        .package(path: "../UFPCore")
    ],
    targets: [
        .target(
            name: "UFPStorage",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore")
            ]
        ),
        .target(
            name: "UFPStorageTestMocks",
            dependencies: [
                "UFPStorage",
                .product(name: "UFPCoreTestMocks", package: "UFPCore")
            ]
        ),
        .testTarget(
            name: "UFPStorageTests",
            dependencies: [
                "UFPStorage",
                "UFPStorageTestMocks"
            ]
        )
    ]
)
