//
//  IngestServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 IngestService 模块的抽象契约接口。
//
import Foundation

/// 文件导入服务协议 (L1.5-Domain)
/// 抽象文件导入能力，使 Domain 层无需直接依赖 L2 IngestService
public protocol IngestServiceProtocol: Sendable {

    /// 导入指定文件夹下的内容并完成数据落盘与向量化
    /// - Parameters:
    ///   - url: 目标沙盒路径或用户挑选的外部文件夹 URL
    ///   - type: 生成页面的默认实体类型
    ///   - pageStore: 目标持久化网关
    /// - Returns: 新生成的知识库页面列表
    func ingestFolder(at url: URL, type: PageType, pageStore: any AnyPageStore) async -> [KnowledgePage]
}

// MARK: - DependencyKey
import Dependencies
import UFPCore

/// IngestServiceProtocol 依赖注入键
public enum IngestServiceKey: DependencyKey {
    public static var liveValue: any IngestServiceProtocol {
        ServiceContainer.shared.resolve((any IngestServiceProtocol).self)
    }

    public static var testValue: any IngestServiceProtocol {
        ServiceContainer.shared.resolveOptional((any IngestServiceProtocol).self) ?? NoOpIngestService()
    }
}

/// 无操作导入服务（测试/预览占位，DI 未就绪时降级）
public final class NoOpIngestService: IngestServiceProtocol, Sendable {
    public init() {}
    public func ingestFolder(at url: URL, type: PageType, pageStore: any AnyPageStore) async -> [KnowledgePage] { [] }
}

extension DependencyValues {
    public var ingestService: any IngestServiceProtocol {
        get { self[IngestServiceKey.self] }
        set { self[IngestServiceKey.self] = newValue }
    }
}
