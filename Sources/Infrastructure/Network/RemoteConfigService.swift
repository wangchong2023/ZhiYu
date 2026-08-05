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
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }
    
    /// 异步拉取云端大模型兼容白名单列表
    public func fetchLLMManifests() async throws -> [LLMManifest] {
        Logger.shared.info("[RemoteConfigService] 直接加载本地内置离线预设大模型白名单")
        return getFallbackLLMManifests()
    }
    
    /// 异步拉取动态 Agent 智能技能（Prompt 模板及超参限制）集合
    public func fetchAgentSkills() async throws -> [AgentSkill] {
        let remoteURLString = AppConfig.backendBaseURL + "/api/ai/skills/list"
        
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
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json[CoreConstants.RemoteConfig.jsonKeyModels] as? [[String: Any]] else {
            return []
        }
        return models.compactMap { dict in
            guard let modelId = dict["modelId"] as? String,
                  let displayName = dict["displayName"] as? String,
                  let vendor = dict["vendor"] as? String else { return nil }
            let params = dict["defaultParameters"] as? [String: Any] ?? [:]
            // 提取模型所支持的核心任务类型及多语言本地化映射，以保证测试实验室兼容性检测正常
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
                    temperature: (params["temperature"] as? Double) ?? 0.7,
                    topP: (params["topP"] as? Double) ?? 0.9,
                    topK: (params["topK"] as? Int) ?? 40,
                    maxTokens: (params["maxTokens"] as? Int) ?? 2048),
                huggingfaceURLString: dict["huggingfaceURLString"] as? String,
                modelscopeURLString: dict["modelscopeURLString"] as? String,
                displayNames: dict["displayNames"] as? [String: String],
                descriptions: dict["descriptions"] as? [String: String],
                supportedTasksLocalized: tasksLoc
            )
        }
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
                customParameters: InferenceParameters(temperature: 0.2, topP: 0.95, maxTokens: 1024)
            ),
            AgentSkill(
                skillId: CoreConstants.RemoteConfig.SkillID.presentationGenerator,
                displayName: CoreConstants.RemoteConfig.SkillDisplayName.presentationGenerator,
                description: CoreConstants.RemoteConfig.SkillDescription.presentationGenerator,
                systemPromptTemplate: CoreConstants.RemoteConfig.PromptTemplate.presentationGenerator,
                tags: [CoreConstants.RemoteConfig.SkillTag.synthesis, CoreConstants.RemoteConfig.SkillTag.edgeCloud],
                customParameters: InferenceParameters(temperature: 0.6, topP: 0.9, maxTokens: 3072)
            ),
            AgentSkill(
                skillId: CoreConstants.RemoteConfig.SkillID.linkDiscovery,
                displayName: CoreConstants.RemoteConfig.SkillDisplayName.linkDiscovery,
                description: "",
                systemPromptTemplate: CoreConstants.RemoteConfig.PromptTemplate.linkDiscovery,
                tags: [CoreConstants.RemoteConfig.SkillTag.graph, CoreConstants.RemoteConfig.SkillTag.offline],
                customParameters: InferenceParameters(temperature: 0.3, topP: 0.8, maxTokens: 2048)
            )
        ]
    }
}
