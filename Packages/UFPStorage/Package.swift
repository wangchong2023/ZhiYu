// swift-tools-version: 5.9
//
//  Package.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage]
//  核心职责：通用存储引擎包 (Universal Foundation Platform Storage)。
//           彻底封装底层 GRDB 依赖与物理数据库迁移/算子，上层模块绝对禁止直接 import GRDB。
//

import PackageDescription
import Foundation

// MARK: - 开源库本地路径（通过 OPENSRC_ROOT 环境变量注入，参见 Config/.env.local）
let opensrcRoot = ProcessInfo.processInfo.environment["OPENSRC_ROOT"] ?? {
    fatalError("[UFPStorage] 缺少 OPENSRC_ROOT 环境变量。请先执行: source Config/.env.local && bash Tools/Utils/bootstrap.sh")
}()

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
        .package(path: "../UFPCore"),
        .package(path: "\(opensrcRoot)/GRDB.swift")
    ],
    targets: [
        .target(
            name: "UFPStorage",
            dependencies: [
                .product(name: "UFPCore", package: "UFPCore"),
                .product(name: "GRDB", package: "GRDB.swift")
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
