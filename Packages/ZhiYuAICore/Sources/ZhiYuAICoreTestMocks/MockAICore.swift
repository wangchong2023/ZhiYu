//
//  MockAICore.swift
//  ZhiYuAICoreTestMocks
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICoreTestMocks]
//  核心职责：ZhiYuAICore 包的 Mock 存根。
//

import Foundation
import ZhiYuAICore

public final class MockAICore: Sendable {
    public static let shared = MockAICore()
    public init() {}
}
