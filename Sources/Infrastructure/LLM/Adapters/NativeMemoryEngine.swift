//
//  NativeMemoryEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：自研分层对话记忆与 Episodic 摘要引擎 (Native Memory Engine)。
//

import Foundation
import UFPCore
import os

/// 自研生产级分层对话记忆引擎
/// 继承 BaseMemoryEngine 复用通用历史切片与 L10n 化摘要前缀逻辑，仅覆盖引擎类型标识。
public final class NativeMemoryEngine: BaseMemoryEngine {
    public override var engineType: MemoryEngineType { .native }

    public override init() {
        super.init()
    }
}
