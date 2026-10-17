//
//  IngestProgressCalculator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：计算与安全格式化文档导入进度与百分比，杜绝 NaN / Infinity 闪退。
//           通用实现已下沉至 ZhiYuDomain，此处 typealias 兼容层维持调用点不变。
//

import Foundation
import ZhiYuDomain

/// 知识摄入进度安全计算器
/// 通用实现已下沉至 `ZhiYuDomain.IngestProgressCalculator`
public typealias IngestProgressCalculator = ZhiYuDomain.IngestProgressCalculator
