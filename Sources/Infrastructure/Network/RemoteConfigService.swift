//
//  RemoteConfigService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：动态拉取云端大模型白名单 Manifest 与 Agent 智能技能配置的具体服务实现。实现自 Domain 层的 RemoteConfigCapabilities 协议，提供极致的网络容灾及离线本地预设兜底。
//

import Foundation
import UFPCore

/// 远程配置拉取具体实现服务类
public final class RemoteConfigService: RemoteConfigCapabilities, Sendable {
    private enum RemoteConfigConstants {
        static let allowlistPath = "/api/ai/models/allowlist"
        static let skillsPath = "/api/ai/skills/list"
        static let allowlistTimeoutSeconds: TimeInterval = 3.0
        static let defaultTemperature: Double = 0.7
        static let defaultTopP: Double = 0.9
        static let defaultTopK: Int = 40
        static let defaultMaxTokens: Int = 2048
    }

    public static let shared = RemoteConfigService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let allowlistEndpointOverride: URL?
    
    public init(session: URLSession = .shared, allowlistEndpointOverride: URL? = nil) {
        self.session = session
        self.decoder = JSONDecoder()
        self.allowlistEndpointOverride = allowlistEndpointOverride
    }
    
    /// 异步拉取云端大模型兼容白名单列表（优先远端动态拉取，异常或空载荷时自动降级本地离线白名单）
    public func fetchLLMManifests() async throws -> [LLMManifest] {
        let endpoint = allowlistEndpointOverride ?? URL(string: AppConfig.backendBaseURL + RemoteConfigConstants.allowlistPath)
        if let url = endpoint {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = RemoteConfigConstants.allowlistTimeoutSeconds
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == SystemConstants.HTTPStatusCode.ok {
                    let parsed = parseAllowlistManifests(from: data)
                    if !parsed.isEmpty {
                        Logger.shared.info("[RemoteConfigService] 远端动态白名单拉取成功，共 \(parsed.count) 款模型")
                        return parsed
                    }
                }
            } catch {
                Logger.shared.info("[RemoteConfigService] 远端白名单不可达，降级本地离线白名单: \(error.localizedDescription)")
            }
        }
        return getFallbackLLMManifests()
    }
    
    /// 异步拉取动态 Agent 智能技能（Prompt 模板及超参限制）集合
    public func fetchAgentSkills() async throws -> [AgentSkill] {
        let remoteURLString = AppConfig.backendBaseURL + RemoteConfigConstants.skillsPath
        
        guard let url = URL(string: remoteURLString) else {
            throw NetworkError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == SystemConstants.HTTPStatusCode.ok else {
                throw NetworkError.serverError(SystemConstants.HTTPStatusCode.internalServerError, "Fetch remote skills list failed.")
            }
            
            let apiResponse = try decoder.decode(ApiResponse<[AgentSkill]>.self, from: data)
            if apiResponse.isSuccess, let list = apiResponse.data {
                return list
            }
            throw NetworkError.unexpected("Remote skills payload is empty.")
        } catch {
            // 🟢 离线预设兜底，确保日常的【语义分块】、【AI合成】核心技能完全存活
            return getFallbackAgentSkills()
        }
    }
    
    // MARK: - 离线预设与灾备机制 (High-Availability Presets)
    
    /// 从 model_allowlist.json 加载离线预设模型清单
    private func getFallbackLLMManifests() -> [LLMManifest] {
        let preferredLanguage = Locale.preferredLanguages.first ?? CoreConstants.LanguageCode.en
        let resourceName = preferredLanguage.hasPrefix(CoreConstants.LanguageCode.zh) ? CoreConstants.RemoteConfig.modelAllowlistZhHans : CoreConstants.RemoteConfig.modelAllowlist
        
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: SystemConstants.FileExtension.json) ?? Bundle.main.url(forResource: CoreConstants.RemoteConfig.modelAllowlist, withExtension: SystemConstants.FileExtension.json),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return parseAllowlistManifests(from: data)
    }

    /// 解析白名单 JSON 数据（兼容直接 `{"models":[...]}` 与 `ApiResponse<[LLMManifest]>` 两种结构）
    internal func parseAllowlistManifests(from data: Data) -> [LLMManifest] {
        if let apiResponse = try? decoder.decode(ApiResponse<[LLMManifest]>.self, from: data),
           apiResponse.isSuccess,
           let list = apiResponse.data,
           !list.isEmpty {
            return list
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json[CoreConstants.RemoteConfig.jsonKeyModels] as? [[String: Any]] else {
            return []
        }
        return models.compactMap { dict in
            guard let modelId = dict["modelId"] as? String,
                  let displayName = dict["displayName"] as? String,
                  let vendor = dict["vendor"] as? String else { return nil }
            let params = dict["defaultParameters"] as? [String: Any] ?? [:]
            let tasks = dict["supportedTasks"] as? [String] ?? []
            let tasksLoc = dict["supportedTasksLocalized"] as? [String]
            return LLMManifest(
                modelId: modelId, displayName: displayName, vendor: vendor,
                fileSizeInBytes: (dict["fileSizeInBytes"] as? Int64) ?? 0,
                minDeviceMemoryInGb: (dict["minDeviceMemoryInGb"] as? Double) ?? 0,
                remoteURLString: (dict["remoteURLString"] as? String) ?? "",
                sha256Checksum: (dict["sha256Checksum"] as? String) ?? "",
                parameterCount: (dict["parameterCount"] as? String) ?? "",
                supportedTasks: tasks,
                description: (dict["description"] as? String) ?? "",
                defaultParameters: InferenceParameters(
                    temperature: (params["temperature"] as? Double) ?? RemoteConfigConstants.defaultTemperature,
                    topP: (params["topP"] as? Double) ?? RemoteConfigConstants.defaultTopP,
                    topK: (params["topK"] as? Int) ?? RemoteConfigConstants.defaultTopK,
                    maxTokens: (params["maxTokens"] as? Int) ?? RemoteConfigConstants.defaultMaxTokens
                ),
                huggingfaceURLString: dict["huggingfaceURLString"] as? String,
                modelscopeURLString: dict["modelscopeURLString"] as? String,
                displayNames: dict["displayNames"] as? [String: String],
                descriptions: dict["descriptions"] as? [String: String],
                supportedTasksLocalized: tasksLoc
            )
        }
    }

    private enum FallbackSkillParams {
        static let chunkingTemperature: Double = 0.2
        static let chunkingTopP: Double = 0.95
        static let chunkingMaxTokens: Int = 1024

        static let presentationTemperature: Double = 0.6
        static let presentationTopP: Double = 0.9
        static let presentationMaxTokens: Int = 3072

        static let linkDiscoveryTemperature: Double = 0.3
        static let linkDiscoveryTopP: Double = 0.8
        static let linkDiscoveryMaxTokens: Int = 2048
    }

    /// 获取本地物理预设的 Agent 智能技能灾备列表
    private func getFallbackAgentSkills() -> [AgentSkill] {
        return [
            AgentSkill(
                skillId: CoreConstants.RemoteConfig.SkillID.chunkingFormatter,
                displayName: CoreConstants.RemoteConfig.SkillDisplayName.chunkingFormatter,
                description: "",
                systemPromptTemplate: CoreConstants.RemoteConfig.PromptTemplate.chunkingFormatter,
                tags: [CoreConstants.RemoteConfig.SkillTag.tagging, CoreConstants.RemoteConfig.SkillTag.offline],
                customParameters: InferenceParameters(
                    temperature: FallbackSkillParams.chunkingTemperature,
                    topP: FallbackSkillParams.chunkingTopP,
                    maxTokens: FallbackSkillParams.chunkingMaxTokens
                )
            ),
            AgentSkill(
                skillId: CoreConstants.RemoteConfig.SkillID.presentationGenerator,
                displayName: CoreConstants.RemoteConfig.SkillDisplayName.presentationGenerator,
                description: CoreConstants.RemoteConfig.SkillDescription.presentationGenerator,
                systemPromptTemplate: CoreConstants.RemoteConfig.PromptTemplate.presentationGenerator,
                tags: [CoreConstants.RemoteConfig.SkillTag.synthesis, CoreConstants.RemoteConfig.SkillTag.edgeCloud],
                customParameters: InferenceParameters(
                    temperature: FallbackSkillParams.presentationTemperature,
                    topP: FallbackSkillParams.presentationTopP,
                    maxTokens: FallbackSkillParams.presentationMaxTokens
                )
            ),
            AgentSkill(
                skillId: CoreConstants.RemoteConfig.SkillID.linkDiscovery,
                displayName: CoreConstants.RemoteConfig.SkillDisplayName.linkDiscovery,
                description: "",
                systemPromptTemplate: CoreConstants.RemoteConfig.PromptTemplate.linkDiscovery,
                tags: [CoreConstants.RemoteConfig.SkillTag.graph, CoreConstants.RemoteConfig.SkillTag.offline],
                customParameters: InferenceParameters(
                    temperature: FallbackSkillParams.linkDiscoveryTemperature,
                    topP: FallbackSkillParams.linkDiscoveryTopP,
                    maxTokens: FallbackSkillParams.linkDiscoveryMaxTokens
                )
            )
        ]
    }
}
