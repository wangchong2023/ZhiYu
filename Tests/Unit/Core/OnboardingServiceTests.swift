//
//  OnboardingServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 OnboardingService 新手引导状态机：init/reset/nextStep/finish/completeOnboarding。
//

import XCTest
@testable import ZhiYu

@MainActor
final class OnboardingServiceTests: XCTestCase {

    private var service: OnboardingService!

    override func setUp() {
        super.setUp()
        // 清理持久化状态，避免前序测试写入的 hasCompletedOnboarding 跨测试泄漏
        // （OnboardingService.init 会从共享 KeyStore 读取该值）
        UserDefaults.standard.removeObject(forKey: AppConstants.Keys.Storage.hasCompletedOnboarding)
        service = OnboardingService()
    }

    override func tearDown() {
        service = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.Keys.Storage.hasCompletedOnboarding)
        super.tearDown()
    }

    // MARK: - init

    func testInit_DI未就绪_hasCompletedOnboarding默认false() {
        let service = OnboardingService()
        XCTAssertFalse(service.hasCompletedOnboarding)
    }

    // MARK: - reset

    func testReset_设置hasCompletedOnboarding为false() {
        service.hasCompletedOnboarding = true
        service.reset()
        XCTAssertFalse(service.hasCompletedOnboarding)
    }

    func testReset_设置currentStep为graph() {
        service.currentStep = .aiLab
        service.reset()
        XCTAssertEqual(service.currentStep, .graph)
    }

    // MARK: - nextStep

    func testNextStep_currentStep为nil_设置为graph() {
        service.currentStep = nil
        service.nextStep()
        XCTAssertEqual(service.currentStep, .graph)
    }

    func testNextStep_graph_前进到aiLab() {
        service.currentStep = .graph
        service.nextStep()
        XCTAssertEqual(service.currentStep, .aiLab)
    }

    func testNextStep_aiLab_前进到vault() {
        service.currentStep = .aiLab
        service.nextStep()
        XCTAssertEqual(service.currentStep, .vault)
    }

    func testNextStep_vault_调用finish() {
        service.currentStep = .vault
        service.nextStep()
        XCTAssertTrue(service.hasCompletedOnboarding)
        XCTAssertNil(service.currentStep)
    }

    // MARK: - finish

    func testFinish_设置hasCompletedOnboarding为true() {
        service.hasCompletedOnboarding = false
        service.finish()
        XCTAssertTrue(service.hasCompletedOnboarding)
    }

    func testFinish_清空currentStep() {
        service.currentStep = .graph
        service.finish()
        XCTAssertNil(service.currentStep)
    }

    // MARK: - completeOnboarding

    func testCompleteOnboarding_等同于finish() {
        service.hasCompletedOnboarding = false
        service.currentStep = .graph
        service.completeOnboarding()
        XCTAssertTrue(service.hasCompletedOnboarding)
        XCTAssertNil(service.currentStep)
    }

    // MARK: - OnboardingStep 枚举

    func testOnboardingStep_allCases_包含3个步骤() {
        XCTAssertEqual(OnboardingService.OnboardingStep.allCases.count, 3)
    }

    func testOnboardingStep_rawValue_正确() {
        XCTAssertEqual(OnboardingService.OnboardingStep.graph.rawValue, 0)
        XCTAssertEqual(OnboardingService.OnboardingStep.aiLab.rawValue, 1)
        XCTAssertEqual(OnboardingService.OnboardingStep.vault.rawValue, 2)
    }

    func testOnboardingStep_id_等于rawValue() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertEqual(step.id, step.rawValue)
        }
    }

    func testOnboardingStep_icon_非空() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertFalse(step.icon.isEmpty, "icon 不应为空：\(step)")
        }
    }

    func testOnboardingStep_title_非空非Missing() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "title 不应为空：\(step)")
            XCTAssertFalse(step.title.contains("[MISSING"), "title 不应包含 MISSING：\(step)")
        }
    }

    func testOnboardingStep_description_非空非Missing() {
        for step in OnboardingService.OnboardingStep.allCases {
            XCTAssertFalse(step.description.isEmpty, "description 不应为空：\(step)")
            XCTAssertFalse(step.description.contains("[MISSING"), "description 不应包含 MISSING：\(step)")
        }
    }
}
