//
//  MockStorage.swift
//  UFPStorageTestMocks
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorageTestMocks]
//  核心职责：UFPStorage 包的 Mock 存根。
//

import Foundation
import UFPStorage

public final class MockStorage: Sendable {
    public static let shared = MockStorage()
    public init() {}
}
