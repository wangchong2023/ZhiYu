//
//  PromptTemplateEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层 / 服务实现
//  核心职责：实现动态提示词模板插值与解析。支持基于沙盒的文件系统缓存热更新、静默网络拉取外部复杂 Prompt 与平滑灾备兜底。
//

import Foundation
import CryptoKit

/// 动态提示词解析引擎，使用 Actor 隔离保证并发安全
public actor PromptTemplateEngine: PromptTemplateEngineCapabilities {
    
    /// 网络请求 Session，用于拉取远程外部提示词 Markdown 文本
    private let session: URLSession
    
    /// 缓存存放的沙盒目录路径
    private let cacheDirectoryURL: URL
    
    /// 初始化解析引擎
    /// - Parameter session: 用于远程请求的 URLSession，默认为 shared
    public init(session: URLSession = .shared) {
        self.session = session
        
        // 初始化沙盒缓存目录
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDirectory = paths[0]
        self.cacheDirectoryURL = cachesDirectory.appendingPathComponent("AgentPrompts", isDirectory: true)
        
        // 确保缓存目录存在
        try? FileManager.default.createDirectory(at: self.cacheDirectoryURL, withIntermediateDirectories: true)
    }
    
    // MARK: - PromptTemplateEngineCapabilities
    
    /// 解析并插值替换系统提示词模板中的变量 (非隔离同步方法，无需等待，提供极速响应)
    /// - Parameters:
    ///   - template: 提示词模板内容
    ///   - variables: 参数字典
    /// - Returns: 插值后的提示词
    nonisolated public func parse(template: String, with variables: [String: String]) -> String {
        var result = template
        
        // 遍历变量字典，将 {{key}} 替换为 value
        for (key, value) in variables {
            let placeholder = "{{\(key)}}"
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        
        return result
    }
    
    /// 渲染指定的 Agent 智能体技能提示词
    /// - Parameters:
    ///   - skill: 智能体技能领域实体模型
    ///   - variables: 待插值替换的参数字典
    /// - Returns: 最终装配完成的提示词文本
    public func renderPrompt(for skill: AgentSkill, with variables: [String: String]) async -> String {
        var rawPrompt = skill.systemPromptTemplate
        
        // 1. 检查是否存在外部托管的 Markdown Prompt
        if let remoteURLString = skill.remotePromptURLString, let url = URL(string: remoteURLString) {
            let cachedFileURL = cacheDirectoryURL.appendingPathComponent("\(skill.skillId)_\(skill.version).md")
            
            // 2. 尝试从本地缓存读取
            if FileManager.default.fileExists(atPath: cachedFileURL.path),
               let cachedContent = try? String(contentsOf: cachedFileURL, encoding: .utf8) {
                // 审查修复 MED-3: 缓存读取路径同样校验 SHA256，防止缓存被篡改
                if let expectedHash = skill.remotePromptSHA256 {
                    let computedHash = SHA256.hash(data: Data(cachedContent.utf8))
                    let computedHex = computedHash.map { String(format: "%02x", $0) }.joined()
                    if computedHex != expectedHash.lowercased() {
                        // 缓存哈希不匹配，删除缓存并降级到本地模板
                        Logger.shared.error("[PromptTemplateEngine] \(skill.skillId): 缓存哈希不匹配，删除缓存并降级到本地模板")
                        try? FileManager.default.removeItem(at: cachedFileURL)
                    } else {
                        // 缓存校验通过，直接采用
                        rawPrompt = cachedContent
                    }
                } else {
                    // 未配置哈希校验，保持兼容行为
                    rawPrompt = cachedContent
                }
            } else {
                // 3. 本地无缓存，发起静默网络请求热更新拉取
                do {
                    // 设置网络超时时间
                    var request = URLRequest(url: url)
                    request.timeoutInterval = PromptConstants.PromptTemplate.remoteFetchTimeout
                    
                    let (data, response) = try await session.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == SystemConstants.HTTPStatusCode.ok,
                       let fetchedContent = String(data: data, encoding: .utf8) {
                        // 校验拉取到的内容是否非空，若有效则写入沙盒缓存
                        if !fetchedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // VULN-009 修复：远程 Prompt 完整性校验
                            // 若配置了 SHA256 哈希，必须匹配才能使用，否则降级到本地模板
                            if let expectedHash = skill.remotePromptSHA256 {
                                let computedHash = SHA256.hash(data: Data(fetchedContent.utf8))
                                let computedHex = computedHash.map { String(format: "%02x", $0) }.joined()
                                if computedHex != expectedHash.lowercased() {
                                    Logger.shared.error("[PromptTemplateEngine] \(skill.skillId): 远程 Prompt 哈希不匹配，降级到本地模板 (expected: \(expectedHash.prefix(PromptConstants.PromptTemplate.hashLogPrefixLength))..., got: \(computedHex.prefix(PromptConstants.PromptTemplate.hashLogPrefixLength))...)")
                                    // 哈希不匹配，使用本地模板
                                } else {
                                    rawPrompt = fetchedContent
                                    try? fetchedContent.write(to: cachedFileURL, atomically: true, encoding: .utf8)
                                }
                            } else {
                                // 未配置哈希校验，保持兼容行为（但记录警告）
                                Logger.shared.warning("[PromptTemplateEngine] \(skill.skillId): 远程 Prompt 未配置 SHA256 校验，存在篡改风险")
                                rawPrompt = fetchedContent
                                try? fetchedContent.write(to: cachedFileURL, atomically: true, encoding: .utf8)
                            }
                        }
                    }
                } catch {
                    // 4. 网络拉取失败（如断网、超时），100% 自动平滑降级为本地预设的 systemPromptTemplate
                    // 打印警告日志以供调试，生产环境无感知保活
                    Logger.shared.error(" [PromptTemplateEngine]  \(skill.skillId) (v\(skill.version))", error: error)
                }
            }
        }
        
        // 5. 对最终文本进行占位符插值解析
        return parse(template: rawPrompt, with: variables)
    }
    
    /// 清除所有本地缓存的外部 Prompt 文本
    public func clearCache() async {
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
