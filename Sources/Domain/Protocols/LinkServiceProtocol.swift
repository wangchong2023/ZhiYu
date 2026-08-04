//
//  LinkServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 LinkService 模块的抽象契约接口，解耦 Domain 与具体向量化双向链接服务的强引用。
//

import Foundation

/// 双向链接与引用计算服务协议
public protocol LinkServiceProtocol: Sendable {
    
    /// 根据标题在页面列表中匹配查询页面实体
    /// - Parameters:
    ///   - title: 页面标题
    ///   - pages: 供查询的页面数据集
    /// - Returns: 匹配到的知识页面实体（若无则返回 nil）
    func pageByTitle(_ title: String, in pages: [KnowledgePage]) async -> KnowledgePage?
    
    /// 执行页面重命名前的双向引用自动更新调整
    /// - Parameters:
    ///   - page: 被修改的原始页面对象
    ///   - newTitle: 拟设定的新页面标题
    ///   - pages: 整个知识库的当前全量页面数据集
    /// - Returns: 被修改影响并重新建立反向引用关系后的新页面对象列表
    func prepareRename(page: KnowledgePage, to newTitle: String, in pages: [KnowledgePage]) async -> [KnowledgePage]
}
