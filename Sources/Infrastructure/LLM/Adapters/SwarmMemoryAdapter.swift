//
//  SwarmMemoryAdapter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：开源 Swarm / Wax 框架记忆引擎适配器 (Adapter Pattern)。
//           面向 L1.5 MemoryEngineProtocol 契约，支持未来无缝切换至 Swarm 开源 Agent 框架。
//

import Foundation
import UFPCore
import os

/// 开源 Swarm / Wax 记忆框架挂载适配器
/// 继承 BaseMemoryEngine 复用通用历史切片提取与线程安全存储逻辑 (DRY)。
public final class SwarmMemoryAdapter: BaseMemoryEngine, @unchecked Sendable {
    public override var engineType: MemoryEngineType { .openSourceAdapter }

    public override var summaryPrefix: String { "Swarm Agent Memory State" }

    public override init() {
        super.init()
    }
}
