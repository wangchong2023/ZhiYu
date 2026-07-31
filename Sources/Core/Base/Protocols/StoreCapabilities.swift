//
//  StoreCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：跨层协议定义，建立 L0-L3 各层间的抽象契约。
//
import Foundation
@preconcurrency import GRDB

/// 具备向量化与语义嵌入检索能力的底层存储协议。
public protocol VectorIndexableStore: Sendable {
    /// 获取当前存储对应的向量嵌入管理器，用于将文本块向量化。
    var embeddingProvider: any EmbeddingProvider { get }
}

/// 具备监控与可观测性审计日志记录能力的存储协议。
public protocol MonitorableStore: Sendable {
    /// 添加一条系统监控或性能审计日志。
    ///
    /// - Parameters:
    ///   - action: 日志操作类型 (例如：创建、更新、同步、删除)。
    ///   - target: 审计目标实体标识（如页面标题或文件名）。
    ///   - details: 日志的详细内容或错误描述。
    ///   - duration: 该操作所耗费的时间长度（单位：秒）。
    ///   - startTime: 操作开始的时间戳。
    ///   - endTime: 操作完成的时间戳。
    ///   - module: 所属的子系统模块名称。
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?)
}

/// 通用页面存储操作协议 (类型抹除抽象接口)，定义知识库核心持久化契约。
public protocol AnyPageStore: Sendable {
    /// 异步获取当前内存中已缓存的全量页面镜像。
    var pages: [KnowledgePage] { get async }
    
    /// 从数据库物理源中检索并获取页面全量列表。
    ///
    /// - Returns: 检索出的全局页面列表。
    /// - Throws: 异常于数据库读取失败。
    func fetchAllPages() async throws -> [KnowledgePage]
    
    /// 从磁盘重载缓存的页面镜像。
    func reloadFromDisk() async
    
    /// 用给定的页面集合覆盖并全量替换当前内存中的页面缓存。
    ///
    /// - Parameter newPages: 新的页面数组。
    func replaceAllPages(_ newPages: [KnowledgePage]) async
    
    /// 彻底清除数据库中所有页面、分块、日志等，将其物理重置回干净状态。
    ///
    /// - Throws: 异常于重置操作失败。
    func resetDatabase() async throws
    
    /// 执行高并发且具备原子事务保护的批量数据库写入操作。
    ///
    /// - Parameter block: 包含具体数据库写操作的线程安全闭包。
    /// - Throws: 异常于事务写入失败。
    func performBatchWrite(_ block: @escaping @Sendable (Database) throws -> Void) async throws

    /// 创建一个新知识页面并持久化。
    ///
    /// - Parameters:
    ///   - title: 页面标题，需全局唯一。
    ///   - pageType: 知识页面的类型 (如概念、实体、源码等)。
    ///   - customIcon: 可选的自定义图标符号。
    ///   - content: 页面正文内容 (Markdown 格式)。
    ///   - tags: 关联的分类标签列表。
    ///   - sourceURL: 数据来源的 URL 链接路径。
    ///   - rawSnippet: 从源文件中提取出的原始文本片段预览。
    ///   - fileSize: 数据源文件的物理大小。
    ///   - sourceType: 源类型（如 PDF、DOCX 等）。
    /// - Returns: 返回成功持久化后的知识页面模型。
    /// - Throws: 异常于标题重复或数据库存储写入出错。
    func createPage(
        title: String,
        pageType: PageType,
        customIcon: String?,
        content: String,
        tags: [String],
        sourceURL: String?,
        rawSnippet: String?,
        fileSize: Int64?,
        sourceType: String?
    ) async throws -> KnowledgePage

    /// 创建一个新知识页面 (类型抹除封装版，忽略内部抛出的异常并提供默认填充)。
    ///
    /// - Parameters:
    ///   - title: 页面标题。
    ///   - pageType: 知识页面类型。
    ///   - customIcon: 自定义图标。
    ///   - content: 页面正文。
    ///   - tags: 标签集合。
    ///   - sourceURL: 数据源路径。
    ///   - rawSnippet: 原始文本片段。
    ///   - fileSize: 文件物理大小。
    ///   - sourceType: 源文件格式。
    ///   - forceDeepScan: 是否强制对内容进行深度向量化扫描和双向发现。
    /// - Returns: 返回创建完成的页面对象。
    @discardableResult

    /// any创建Page
    func anyCreatePage(
        title: String,
        pageType: PageType,
        customIcon: String?,
        content: String,
        tags: [String],
        sourceURL: String?,
        rawSnippet: String?,
        fileSize: Int64?,
        sourceType: String?,
        forceDeepScan: Bool
    ) async -> KnowledgePage
    
    /// 更新已存在的知识页面元数据与正文。
    ///
    /// - Parameter page: 包含最新数据的页面模型。
    /// - Throws: 异常于指定页面 ID 找不到或数据库写入失败。
    func updatePage(_ page: KnowledgePage) async throws
    
    /// 更新已存在的知识页面 (类型抹除封装版，内部自愈错误)。
    ///
    /// - Parameters:
    ///   - page: 最新的页面模型。
    ///   - forceDeepScan: 是否强制重新运行语义分块和向量提取。
    func anyUpdatePage(_ page: KnowledgePage, forceDeepScan: Bool) async
    
    /// 从数据库中物理删除指定的知识页面，并同步级联删除其关联的所有 PageChunks 与链接。
    ///
    /// - Parameter page: 待删除的页面。
    /// - Throws: 异常于数据库删除失败。
    func deletePage(_ page: KnowledgePage) async throws
    
    /// 从数据库中删除指定的知识页面 (类型抹除封装版)。
    ///
    /// - Parameter page: 待删除的页面。
    func anyDeletePage(_ page: KnowledgePage) async
    
    /// 同步并持久化远程接收到的页面状态镜像。
    ///
    /// - Parameter page: 从网络端或多端同步回来的最新页面模型。
    func syncRemotePage(_ page: KnowledgePage) async

    /// 获取反向引用当前页面的所有来源知识页面列表。
    ///
    /// - Parameter id: 目标页面的 UUID 唯一标识。
    /// - Returns: 反向引用当前页面的源页面数组。
    func fetchBacklinksByID(for id: UUID) async -> [KnowledgePage]

    /// 基于 SQLite FTS5 全文检索和内存模糊匹配检索页面。
    ///
    /// - Parameter query: 检索匹配词。
    /// - Returns: 检索匹配成功的页面列表。
    func searchPages(query: String) async -> [KnowledgePage]

    /// 对全局标签进行重命名，级联修改所有关联页面的标签集合。
    ///
    /// - Parameters:
    ///   - oldTag: 旧标签字面量。
    ///   - newTag: 目标新标签字面量。
    func renameTag(_ oldTag: String, to newTag: String) async
    
    /// 从整个知识库中物理清除指定标签，解除所有页面的绑定关系。
    ///
    /// - Parameter tag: 待删除的标签字面量。
    func deleteTag(_ tag: String) async

    /// 当知识库为空时，为其填充系统预设的默认引导与说明页内容。
    ///
    /// - Parameter logger: 用于实时回调写入进度的审计日志闭包。
    func seedDefaultContent(logger: @escaping @Sendable (LogAction, String, String) -> Void) async

    /// 记录一条数据库审计日志，满足可观测性要求。
    ///
    /// - Parameters:
    ///   - action: 日志动作类型。
    ///   - target: 目标实体。
    ///   - details: 详情。
    ///   - duration: 耗时。
    ///   - startTime: 开始时间。
    ///   - endTime: 结束时间。
    ///   - module: 所属模块。
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?)
    
    /// 获取当前应用各持久化目录所占用的物理存储空间统计信息。
    ///
    /// - Returns: 返回包含数据库物理文件大小、日志文件大小、以及导出缓存大小的元组。
    func getStorageStats() async -> StorageStats
}

/// 存储资源统计信息
public struct StorageStats: Sendable, Equatable {
    public let databaseSize: Int64
    public let logsSize: Int64
    public let exportsSize: Int64
    public let modelsSize: Int64
    public let pluginsSize: Int64
    public let cachesSize: Int64

    public init(
        databaseSize: Int64,
        logsSize: Int64,
        exportsSize: Int64,
        modelsSize: Int64 = 0,
        pluginsSize: Int64 = 0,
        cachesSize: Int64 = 0
    ) {
        self.databaseSize = databaseSize
        self.logsSize = logsSize
        self.exportsSize = exportsSize
        self.modelsSize = modelsSize
        self.pluginsSize = pluginsSize
        self.cachesSize = cachesSize
    }
}

/// 聚合了页面存取与语义向量检索的复合存储能力协议 (L0-Base 核心大脑)。
public typealias AnyPageStoreCapabilities = AnyPageStore & VectorIndexableStore
