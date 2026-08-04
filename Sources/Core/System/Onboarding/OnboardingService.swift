//
//  OnboardingService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 Onboarding 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Combine

/// 新手引导服务
/// 负责维护和持久化新手引导的状态，并在需要时触发引导视图
@MainActor final class OnboardingService: ObservableObject {
    static let shared = OnboardingService()
    
    private let onboardingKey = AppConstants.Keys.Storage.hasCompletedOnboarding
    /// Factory 风格：属性类型标注为可选（T?）， 自动使用 resolveOptional
     @Inject private var keyStore: (any KeyStoreProtocol)?
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            keyStore?.set(hasCompletedOnboarding, forKey: onboardingKey)
        }
    }
    
    @Published var currentStep: OnboardingStep?
    
    init() {
        // NOTE: init() 内不能使用 @Inject 属性包装器（尚未完成初始化），
        // 使用 resolveOptional 优雅降级：DI 容器未就绪时默认为 false（未完成引导）。
        self.hasCompletedOnboarding = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?
            .bool(forKey: AppConstants.Keys.Storage.hasCompletedOnboarding) ?? false
    }
    
    enum OnboardingStep: Int, CaseIterable, Identifiable {
        case graph = 0
        case aiLab = 1
        case vault = 2
        
        var id: Int { self.rawValue }
        
        var icon: String {
            switch self {
            case .graph: return "network"
            case .aiLab: return "cpu"
            case .vault: return "archivebox"
            }
        }
        
        var title: String {
            switch self {
            case .graph: return L10n.Onboarding.Step.graph.title
            case .aiLab: return L10n.Onboarding.Step.aiLab.title
            case .vault: return L10n.Onboarding.Step.vault.title
            }
        }
        
        var description: String {
            switch self {
            case .graph: return L10n.Onboarding.Step.graph.desc
            case .aiLab: return L10n.Onboarding.Step.aiLab.desc
            case .vault: return L10n.Onboarding.Step.vault.desc
            }
        }
    }
    
    /// 重置
    func reset() {
        hasCompletedOnboarding = false
        currentStep = .graph
    }
    
    /// nextStep
    func nextStep() {
        guard let current = currentStep else {
            currentStep = .graph
            return
        }
        
        if current.rawValue < OnboardingStep.allCases.count - 1 {
            currentStep = OnboardingStep(rawValue: current.rawValue + 1)
        } else {
            finish()
        }
    }
    
    /// finish
    func finish() {
        hasCompletedOnboarding = true
        currentStep = nil
    }
    
    /// completeOnboarding
    func completeOnboarding() {
        finish()
    }
}
