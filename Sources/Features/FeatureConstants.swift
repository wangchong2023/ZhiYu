//
//  FeatureConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Features 模块强类型常量集，按领域拆分为 +Auth/+AI/+Knowledge/+Common 四个扩展文件。
//

import Foundation
import UFPCore

/// Features 模块业务常量集
///
/// 为遵循 SRP（单一职责原则），所有嵌套枚举已按领域拆分为独立扩展文件：
/// - `FeatureConstants+Auth.swift`：认证、OAuth、订阅相关常量
/// - `FeatureConstants+AI.swift`：AI 推理、合成、语音、模型管理相关常量
/// - `FeatureConstants+Knowledge.swift`：知识摄入、图谱、Lint、RAG 评估相关常量
/// - `FeatureConstants+Common.swift`：Mock 数据、日志、文件类型、正则、UI 装饰等跨领域常量
enum FeatureConstants {}
