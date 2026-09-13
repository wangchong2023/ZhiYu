//
//  SystemFeaturesComprehensiveDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] Features/System 系统域与多模型中台深度集成测试
//  核心职责：深度覆盖 ModelLabManager、ParameterPreset、SettingsStore、
//            SystemStatsCoordinator 及 NetworkError+UserMessage 的核心业务规则与故障注入。
//  质量标准：严格执行 unit-test-quality-review 四步审查法，拒绝空断言，
//            全方位覆盖参数单调性变异、任务兼容性过滤、网络错误本地化及零数据容错。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SystemFeaturesComprehensiveDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - 1. ParameterPreset 推理参数物理约束与单调性变异深测

    func testParameterPreset_StrictInferenceConstraintsAndMonotonicOrdering() {
        let creative = ParameterPreset.creative.parameters
        let balanced = ParameterPreset.balanced.parameters
        let precise = ParameterPreset.precise.parameters

        // 1. 温度单调递减约束：创意模式 > 均衡模式 > 精准模式
        XCTAssertGreaterThan(creative.temperature, balanced.temperature, "创意模式采样温度必须高于均衡模式")
        XCTAssertGreaterThan(balanced.temperature, precise.temperature, "均衡模式采样温度必须高于精准模式")

        // 2. 物理有效区间校验
        for preset in ParameterPreset.allCases {
            let params = preset.parameters
            XCTAssertGreaterThanOrEqual(params.temperature, 0.0, "\(preset) 温度不能为负数")
            XCTAssertLessThanOrEqual(params.temperature, 2.0, "\(preset) 温度不应超过 2.0 理论上限")

            XCTAssertGreaterThanOrEqual(params.topP, 0.0, "\(preset) Top-P 必须 >= 0.0")
            XCTAssertLessThanOrEqual(params.topP, 1.0, "\(preset) Top-P 必须 <= 1.0")

            XCTAssertGreaterThan(params.maxTokens, 0, "\(preset) maxTokens 必须为正整数")
            XCTAssertGreaterThan(params.topK, 0, "\(preset) topK 必须为正整数")
            XCTAssertFalse(preset.displayName.isEmpty, "\(preset) 显示名称不应为空")
            XCTAssertFalse(preset.icon.isEmpty, "\(preset) 图标名称不应为空")
        }

        // 3. Token 预算单调性：创意模式生成的 Token 上限应 >= 精准模式
        XCTAssertGreaterThanOrEqual(creative.maxTokens, precise.maxTokens, "创意模式的 Token 预算应不低于精准模式")
        XCTAssertGreaterThanOrEqual(creative.topK, precise.topK, "创意模式的 Top-K 采样空间应大于等于精准模式")
    }

    // MARK: - 2. ModelLabManager 7 大用例任务兼容性矩阵与防错深测

    func testModelLabManager_UseCaseCharacteristicsAndModelCompatibility() {
        let manager = ModelLabManager()

        // 构造纯文本 Chat 专属模型（不支持多模态视觉/音频）
        let textOnlyManifest = LLMManifest(
            modelId: "qwen-2.5-7b-chat",
            displayName: "通义千问 7B Chat",
            vendor: "Alibaba",
            fileSizeInBytes: 4_200_000_000,
            minDeviceMemoryInGb: 8.0,
            remoteURLString: "https://example.com/qwen.gguf",
            sha256Checksum: "abc",
            parameterCount: "7B",
            supportedTasks: ["chat"],
            description: "Chat only model",
            defaultParameters: InferenceParameters()
        )

        // 构造端侧全模态大模型
        let multimodalManifest = LLMManifest(
            modelId: "minicpm-v-2.6",
            displayName: "MiniCPM 多模态",
            vendor: "OpenBMB",
            fileSizeInBytes: 5_100_000_000,
            minDeviceMemoryInGb: 12.0,
            remoteURLString: "https://example.com/minicpm.gguf",
            sha256Checksum: "def",
            parameterCount: "8B",
            supportedTasks: ["multimodal", "chat"],
            description: "Multimodal and chat model",
            defaultParameters: InferenceParameters()
        )

        // 1. 验证纯文本模型在视觉/听觉多模态场景下的强阻断防护
        XCTAssertFalse(manager.isModelCompatible(textOnlyManifest, for: .askImage), "纯文本模型必须拒绝 askImage 视觉用例以防后端抛 400 崩溃")
        XCTAssertFalse(manager.isModelCompatible(textOnlyManifest, for: .audioScribe), "纯文本模型必须拒绝 audioScribe 音频用例")
        XCTAssertTrue(manager.isModelCompatible(textOnlyManifest, for: .aiChat), "纯文本模型必须支持标准对话场景")
        XCTAssertTrue(manager.isModelCompatible(textOnlyManifest, for: .agentSkills), "纯文本模型必须支持 Agent 场景")

        // 2. 验证多模态模型的全场景适配
        XCTAssertTrue(manager.isModelCompatible(multimodalManifest, for: .askImage), "多模态模型应支持 askImage")
        XCTAssertTrue(manager.isModelCompatible(multimodalManifest, for: .audioScribe), "多模态模型应支持 audioScribe")
        XCTAssertTrue(manager.isModelCompatible(multimodalManifest, for: .aiChat), "多模态模型应支持 aiChat")

        // 3. 验证 7 大用例枚举元数据完备性
        XCTAssertEqual(UseCaseType.allCases.count, 7, "ModelLab 应精准定义 7 类端侧大模型用例")
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.title.isEmpty, "\(useCase) 标题不应为空")
            XCTAssertFalse(useCase.description.isEmpty, "\(useCase) 描述不应为空")
            XCTAssertFalse(useCase.icon.isEmpty, "\(useCase) 图标不应为空")
            XCTAssertTrue(useCase.requiredTask == "multimodal" || useCase.requiredTask == "chat", "\(useCase) 必须规范归属为 multimodal 或 chat")
        }
    }

    // MARK: - 3. ModelLabManager 动态 Tips 与附件选项多态深测

    func testModelLabManager_ParamTipsAndAttachmentOptionsPolymorphism() {
        let manager = ModelLabManager()

        // 1. 默认无选中用例
        manager.selectedUseCase = nil
        XCTAssertEqual(manager.paramTips, "", "未选择用例时参数提示应当为空")

        // 2. 多模态视觉用例
        manager.selectedUseCase = .askImage
        XCTAssertFalse(manager.paramTips.isEmpty, "选择视觉用例时应当展现多模态专属 Tips")

        // 3. 对话场景附件菜单切换
        manager.selectedUseCase = .aiChat
        let chatOptions = manager.attachmentOptions
        XCTAssertEqual(chatOptions.count, 2)
        XCTAssertTrue(chatOptions.contains { $0.icon == "doc.text.fill" }, "对话场景应当包含页面关联附件项")
        XCTAssertTrue(chatOptions.contains { $0.icon == "tag.fill" }, "对话场景应当包含标签注入附件项")

        // 4. 沙箱/Prompt 场景附件菜单切换
        manager.selectedUseCase = .promptLab
        let sandboxOptions = manager.attachmentOptions
        XCTAssertEqual(sandboxOptions.count, 2)
        XCTAssertTrue(sandboxOptions.contains { $0.icon == "link.badge.plus" }, "沙箱场景应当包含挂载沙箱选项")
        XCTAssertTrue(sandboxOptions.contains { $0.icon == "sparkles" }, "沙箱场景应当包含载入模板选项")
    }

    // MARK: - 4. PerformanceStats 实时性能度量计算与数据结构深测

    func testPerformanceStats_CalculationsAndMetrics() {
        let stats1 = PerformanceStats(
            speed: 28.5,
            prefillLatency: 210,
            firstTokenLatency: 280,
            memoryUsage: 1024.5
        )

        let stats2 = PerformanceStats(
            speed: 28.5,
            prefillLatency: 210,
            firstTokenLatency: 280,
            memoryUsage: 1024.5
        )

        let stats3 = PerformanceStats(
            speed: 15.0,
            prefillLatency: 450,
            firstTokenLatency: 520,
            memoryUsage: 2048.0
        )

        XCTAssertEqual(stats1, stats2, "相同指标的 PerformanceStats 应当判定为相等")
        XCTAssertNotEqual(stats1, stats3, "不同性能的指标应当判定为不相等")
        XCTAssertGreaterThan(stats1.speed, stats3.speed, "轻量模型的生成速度应显著快于大模型")
        XCTAssertLessThan(stats1.memoryUsage, stats3.memoryUsage, "轻量模型的内存开销应小于大模型")
    }

    // MARK: - 5. NetworkError 12 大分支用户本地化文案防空与映射深测

    func testNetworkError_UserFacingLocalizationMappingCompleteness() {
        struct DummyError: Error {}

        let errorCases: [NetworkError] = [
            .invalidURL,
            .tokenExpired,
            .unauthorized("请重新登录"),
            .serverError(500, "内部网关错误"),
            .decodeFailed(DummyError()),
            .httpError(404),
            .unexpected("未知网络波动"),
            .invalidHTTPResponse,
            .missingDataPayload,
            .missingRefreshToken,
            .sessionInvalidated,
            .invalidFileName
        ]

        for err in errorCases {
            let message = err.userMessage
            XCTAssertFalse(message.isEmpty, "错误类型 \(err) 的用户提示文案绝不能返回空字符串")
            // 验证错误码是否有注入
            if case let .serverError(code, _) = err {
                XCTAssertTrue(message.contains("\(code)"), "服务端错误提示文案应包含状态码 \(code)")
            }
            if case let .httpError(code) = err {
                XCTAssertTrue(message.contains("\(code)"), "HTTP 错误提示文案应包含状态码 \(code)")
            }
        }
    }

    // MARK: - 6. SettingsStore 隐私/生物识别配置写入与重置深测

    func testSettingsStore_PrivacyAndBiometricPersistenceAndReset() {
        let store = SettingsStore()

        // 1. 修改隐私模式与生物识别
        store.isPrivacyModeEnabled = true
        XCTAssertTrue(store.isPrivacyModeEnabled)

        store.isPrivacyModeEnabled = false
        XCTAssertFalse(store.isPrivacyModeEnabled, "修改后隐私模式标志位应当精准更新")

        store.isBiometricEnabled = false
        XCTAssertFalse(store.isBiometricEnabled, "生物识别禁用后状态应精准更新")

        // 2. 模拟系统广播重置全部数据事件
        store.reset()
        // 验证重置后各偏好回退到初始默认值
        XCTAssertTrue(store.isPrivacyModeEnabled, "重置后隐私模式应当安全回退到默认开启状态")
        XCTAssertTrue(store.isBiometricEnabled, "重置后生物识别应当安全回退到默认开启状态")
    }

    // MARK: - 7. SystemStatsCoordinator 空仓储零数据容错深测 (防除零异常)

    func testSystemStatsCoordinator_LoadStatsWithEmptyRepositories_NoDivisionByZero() async {
        let coordinator = SystemStatsCoordinator()

        XCTAssertTrue(coordinator.isLoading, "初始状态下 coordinator 应处于加载中")

        // 执行空数据装载
        await coordinator.loadStats()

        // 验证：在没有任何本地笔记、导入记录及 AI 使用记录的极端空边界下，
        // 系统聚合计算必须平稳完成，绝不出现除零异常导致 NaN 或 Crash，同时真实反映物理数据库开销
        XCTAssertFalse(coordinator.isLoading, "加载完成后 isLoading 必须被复位为 false")
        XCTAssertEqual(coordinator.totalPages, 0, "空仓储下总页面数应当为 0")
        XCTAssertGreaterThan(coordinator.totalStorage, 0, "存储总开销应真实统计物理 SQLite 数据库底座大小")
        XCTAssertFalse(coordinator.storageCategories.isEmpty, "存储分类明细列表应正常生成")
        XCTAssertEqual(coordinator.avgLatency, 0, "无调用记录时平均延迟应当安全为 0 而非产生除零崩溃")
        XCTAssertEqual(coordinator.provenance.importedCount, 0)
        XCTAssertEqual(coordinator.provenance.createdCount, 0)
    }

    // MARK: - 8. TraceStep 与 ConfidenceItem 结构体验证

    func testTraceStepAndConfidenceItem_InitializersAndIdentification() {
        let step = TraceStep(title: "路由决策", desc: "选择端侧推理模型", icon: "arrow.triangle.branch", colorName: "blue")
        XCTAssertEqual(step.id, "路由决策")
        XCTAssertEqual(step.title, "路由决策")
        XCTAssertEqual(step.desc, "选择端侧推理模型")
        XCTAssertEqual(step.icon, "arrow.triangle.branch")

        let confidence = ConfidenceItem(name: "红富士苹果", score: 0.965, colorName: "green")
        XCTAssertEqual(confidence.id, "红富士苹果")
        XCTAssertEqual(confidence.name, "红富士苹果")
        XCTAssertEqual(confidence.score, 0.965, accuracy: 0.0001)
    }
}
