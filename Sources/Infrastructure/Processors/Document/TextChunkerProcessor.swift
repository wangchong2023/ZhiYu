//
//  TextChunkerProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层（兼容层）
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//           递归分块器实现已下沉 ZhiYuDomain，本文件作为 App 层兼容 re-export，供现有调用点无改动引用。
//

import Foundation
import ZhiYuDomain

/// 递归分块器 (RAG 核心：语义保真)，实现位于 ZhiYuDomain 包
typealias TextChunkerProcessor = ZhiYuDomain.TextChunkerProcessor
