//
//  OnboardingServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 OnboardingService 新手引导状态机：init/reset/nextStep/finish/completeOnboarding。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class OnboardingServiceTests: XCTestCase {

    private var service: OnboardingService!

    override func setUp() {
        super.setUp()
        // P2-1 迁移：强制清理 DI，确保 testInit_DI未就绪 测试语义正确。
        //           OnboardingService.init 从 ServiceContainer 解析 KeyStoreProtocol，
        //           若前序测试注册了有状态的 KeyStore，hasCompletedOnboarding 会继承残留。
        ServiceContainer.shared.resetForTesting()
        service = OnboardingService()
    }

    override func tearDown() {
        service = nil
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    // MARK: - init

    func testInitDINotReadyHasCompletedOnboardingDefaultFalse() {
        let service = OnboardingService()
        XCTAssertFalse(service.hasCompletedOnboarding)
    }

    // MARK: - reset

    func testResetSetsHasCompletedOnboardingToFalse() {
        service.hasCompletedOnboarding = true
        service.reset()
        XCTAssertFalse(service.hasCompletedOnboarding)
    }

    func testResetSetsCurrentStepToGraph() {
        service.currentStep = .aiLab
        service.reset()
        XCTAssertEqual(service.currentStep, .graph)
    }

    // MARK: - nextStep

    func testNextStepCurrentStepNilSetsToGraph() {
        service.currentStep = nil
        service.nextStep()
        XCTAssertEqual(service.currentStep, .graph)
    }

    func testNextStepGraphAdvancesToAiLab() {
        service.currentStep = .graph
        service.nextStep()
        XCTAssertEqual(service.currentStep, .aiLab)
    }

    func testNextStepAiLabAdvancesToVault() {
        service.currentStep = .aiLab
        service.nextStep()
        XCTAssertEqual(service.currentStep, .vault)
    }

    func testNextStepVaultCallsFinish() {
        service.currentStep = .vault
        service.nextStep()
        XCTAssertTrue(service.hasCompletedOnboarding)
        XCTAssertNil(service.currentStep)
    }

    // MARK: - finish

    func testFinishSetsHasCompletedOnboardingToTrue() {
        service.hasCompletedOnboarding = false
        service.finish()
        XCTAssertTrue(service.hasCompletedOnboarding)
    }

    func testFinishClearsCurrentStep() {
        service.currentStep = .graph
        service.finish()
        XCTAssertNil(service.currentStep)
    }

    // MARK: - completeOnboarding

    func testCompleteOnboardingEqualsFinish() {
        service.hasCompletedOnboarding = false
        service.currentStep = .graph
        service.completeOnboarding()
        XCTAssertTrue(service.hasCompletedOnboarding)
        XCTAssertNil(service.currentStep)
    }

    // MARK: - OnboardingStep 枚举

    func testOnboardingStepAllCasesContainsThreeSteps() {
        XCTAssertEqual(OnboardingService.OnboardingStep.allCases.count, 3)
    }

    func testOnboardingStepRawValueCorrect() {
        XCTAssertEqual(OnboardingService.OnboardingStep.graph.rawValue, 0)
        XCTAssertEqual(OnboardingService.OnboardingStep.aiLab.rawValue, 1)
        XCTAssertEqual(OnboardingService.OnboardingStep.vault.rawValue, 2)
    }

    func testOnboardingStepIdEqualsRawValue() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertEqual(step.id, step.rawValue)
        }
    }

    func testOnboardingStepIconNonEmpty() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertFalse(step.icon.isEmpty, "icon 不应为空：\(step)")
        }
    }

    func testOnboardingStepTitleNonEmptyNonMissing() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "title 不应为空：\(step)")
            XCTAssertFalse(step.title.contains("[MISSING"), "title 不应包含 MISSING：\(step)")
        }
    }

    func testOnboardingStepDescriptionNonEmptyNonMissing() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertFalse(step.description.isEmpty, "description 不应为空：\(step)")
            XCTAssertFalse(step.description.contains("[MISSING"), "description 不应包含 MISSING：\(step)")
        }
    }
}
