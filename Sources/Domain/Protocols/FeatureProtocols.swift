//
//  FeatureProtocols.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议定义（Repository、Service、Strategy 等抽象）。
//
import Foundation
import Dependencies
import UFPCore

/// 身份认证服务协议
@MainActor
public protocol AuthServiceProtocol {
    /// 用户是否已通过身份验证
    var isAuthenticated: Bool { get }
    
    /// 是否以游客身份登录
    var isGuest: Bool { get }
    
    /// 当前登录的用户信息
    var currentUser: User? { get }
    
    /// 以游客身份继续
    func continueAsGuest()
    
    /// 登录
    /// - Parameters:
    ///   - identity: 账号/手机号
    ///   - password: 密码
    /// - Returns: 是否登录成功
    func login(identity: String, password: String) async -> Bool
    
    /// 注册
    /// - Parameters:
    ///   - phone: 手机号
    ///   - code: 验证码
    ///   - password: 密码
    /// - Returns: 是否注册成功
    func register(phone: String, code: String, password: String) async -> Bool
    
    /// 退出登录
    func logout()
    
    /// 自动静默登录验证
    /// - Returns: 是否成功恢复会话
    func tryAutoLogin() async -> Bool
}

/// 笔记本/库管理服务协议
@MainActor
public protocol VaultServiceProtocol {
    /// 所有可用的笔记本列表
    var vaults: [Vault] { get }
    
    /// 当前选中的笔记本 ID
    var selectedVaultID: UUID? { get }
    
    /// 当前活跃的笔记本
    var currentVault: Vault? { get }
    
    /// 切换/选择笔记本（异步等待数据库切换完成再返回）
    func selectVaultAndWait(_ vault: Vault) async throws

    /// 刷新指定笔记本的页面计数（从活跃数据库查询并写回全局元数据）
    func refreshPageCount(for vaultID: UUID) async

    /// 切换/选择笔记本（用于 UI 交互，异步执行）
    func selectVault(_ vault: Vault)
    
    /// 退出当前笔记本
    func exitVault()
    
    /// 创建新笔记本
    func createVault(name: String, icon: String?, description: String?)
    
    /// 更新笔记本信息
    func updateVault(id: UUID, name: String, icon: String?, description: String?)
    
    /// 重命名笔记本
    func renameVault(id: UUID, newName: String)
    
    /// 删除笔记本
    func deleteVault(id: UUID)
}

/// AI 知识综合服务协议
public protocol AISynthesisServiceProtocol: Sendable {
    /// 生成内容摘要
    func summarize(content: String) async throws -> String
    
    /// 生成思维导图 (Mermaid 格式)
    func generateMindMap(content: String) async throws -> String
    
    /// 生成启发式问题列表
    func generateInsightfulQuestions(pages: [KnowledgePage]) async throws -> [String]
    
    /// 根据对话上下文，预测用户可能还会问的 3 个问题
    /// - Parameters:
    ///   - history: 当前对话的历史记录
    ///   - pages: 相关知识库页面列表
    /// - Returns: 预测的 3 个问题字符串列表
    func predictFollowUpQuestions(history: [ChatMessage], pages: [KnowledgePage]) async throws -> [String]
}

/// 聊天服务协议
@MainActor
protocol ChatServiceProtocol: Sendable {
    /// 加载历史消息
    func loadHistory() -> [ChatMessage]
    
    /// 清除对话历史
    func clearHistory()
    
    /// 发起流式对话
    /// - Parameters:
    ///   - query: 用户提问
    ///   - pages: 相关上下文页面
    /// - Returns: 文本流
    func streamChat(query: String, pages: [KnowledgePage]) -> AsyncThrowingStream<String, Error>
    
    /// 保存助手消息
    func saveAssistantMessage(_ content: String)
    
    /// 保存用户消息
    func saveUserMessage(_ content: String)
}

// MARK: - DependencyKey 注册

/// VaultServiceProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum VaultServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any VaultServiceProtocol {
        ServiceContainer.shared.resolve((any VaultServiceProtocol).self)
    }

    @MainActor
    public static var testValue: any VaultServiceProtocol {
        ServiceContainer.shared.resolveOptional((any VaultServiceProtocol).self) ?? NoOpVaultService()
    }
}

/// 无操作笔记本服务（测试/预览占位，DI 未就绪时降级）
@MainActor
public final class NoOpVaultService: VaultServiceProtocol {
    public var vaults: [Vault] { [] }
    public var selectedVaultID: UUID? { nil }
    public var currentVault: Vault? { nil }
    public init() {}
    public func selectVaultAndWait(_ vault: Vault) async throws {}
    public func refreshPageCount(for vaultID: UUID) async {}
    public func selectVault(_ vault: Vault) {}
    public func exitVault() {}
    public func createVault(name: String, icon: String?, description: String?) {}
    public func updateVault(id: UUID, name: String, icon: String?, description: String?) {}
    public func renameVault(id: UUID, newName: String) {}
    public func deleteVault(id: UUID) {}
}

extension DependencyValues {
    /// Vault 服务依赖
    public var vaultService: any VaultServiceProtocol {
        get { self[VaultServiceKey.self] }
        set { self[VaultServiceKey.self] = newValue }
    }
}

/// AISynthesisServiceProtocol 的 DependencyKey
public enum AISynthesisServiceKey: DependencyKey {
    public static var liveValue: any AISynthesisServiceProtocol {
        ServiceContainer.shared.resolve((any AISynthesisServiceProtocol).self)
    }
    public static var testValue: any AISynthesisServiceProtocol {
        ServiceContainer.shared.resolveOptional((any AISynthesisServiceProtocol).self) ?? NoOpAISynthesisService()
    }
    public static var previewValue: any AISynthesisServiceProtocol { NoOpAISynthesisService() }
}

/// 无操作 AI 知识综合服务（测试/预览占位，DI 未就绪时降级）
public final class NoOpAISynthesisService: AISynthesisServiceProtocol, @unchecked Sendable {
    public init() {}
    public func summarize(content: String) async throws -> String { "" }
    public func generateMindMap(content: String) async throws -> String { "" }
    public func generateInsightfulQuestions(pages: [KnowledgePage]) async throws -> [String] { [] }
    public func predictFollowUpQuestions(history: [ChatMessage], pages: [KnowledgePage]) async throws -> [String] { [] }
}

extension DependencyValues {
    public var aiSynthesisService: any AISynthesisServiceProtocol {
        get { self[AISynthesisServiceKey.self] }
        set { self[AISynthesisServiceKey.self] = newValue }
    }
}

/// ChatServiceProtocol 的 DependencyKey
@MainActor
enum ChatServiceKey: DependencyKey {
    @MainActor
    static var liveValue: any ChatServiceProtocol {
        ServiceContainer.shared.resolve((any ChatServiceProtocol).self)
    }

    @MainActor
    static var testValue: any ChatServiceProtocol {
        ServiceContainer.shared.resolveOptional((any ChatServiceProtocol).self) ?? NoOpChatService()
    }
}

/// 无操作聊天服务（测试/预览占位，DI 未就绪时降级）
@MainActor
public final class NoOpChatService: ChatServiceProtocol {
    public init() {}
    public func loadHistory() -> [ChatMessage] { [] }
    public func clearHistory() {}
    public func streamChat(query: String, pages: [KnowledgePage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }
    public func saveAssistantMessage(_ content: String) {}
    public func saveUserMessage(_ content: String) {}
}

extension DependencyValues {
    @MainActor
    var chatService: any ChatServiceProtocol {
        get { self[ChatServiceKey.self] }
        set { self[ChatServiceKey.self] = newValue }
    }
}
