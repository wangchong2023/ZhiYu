//
//  OnboardingMilestoneTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证引导里程碑系统的正确性

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class OnboardingMilestoneTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 确保 KeyStoreProtocol 在 DI 中注册，否则 markAsShown() / hasBeenShown 操作无实际存储
        if ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) == nil {
            ServiceContainer.shared.register(
                UserDefaultsKeyStore.shared as any KeyStoreProtocol,
                for: (any KeyStoreProtocol).self
            )
        }
        OnboardingMilestone.allCases.forEach {
            UserDefaults.standard.removeObject(forKey: "onboarding.milestone.\($0.rawValue)")
        }
    }

    override func tearDown() {
        OnboardingMilestone.allCases.forEach {
            UserDefaults.standard.removeObject(forKey: "onboarding.milestone.\($0.rawValue)")
        }
        super.tearDown()
    }

    // MARK: - Key 生成

    func testMilestoneKeys() {
        XCTAssertEqual(
            OnboardingMilestone.firstPageCreated.key,
            "onboarding.milestone.firstPageCreated"
        )
        XCTAssertEqual(
            OnboardingMilestone.firstAIChat.key,
            "onboarding.milestone.firstAIChat"
        )
    }

    // MARK: - 默认未触发

    func testNotShownByDefault() {
        XCTAssertFalse(OnboardingMilestone.firstPageCreated.hasBeenShown)
        XCTAssertFalse(OnboardingMilestone.pageCount10.hasBeenShown)
    }

    // MARK: - 标记后持久化

    func testMarkAsShownPersists() {
        OnboardingMilestone.firstPageCreated.markAsShown()
        XCTAssertTrue(OnboardingMilestone.firstPageCreated.hasBeenShown)
    }

    func testMarkAsShownDoesNotAffectOthers() {
        OnboardingMilestone.firstPageCreated.markAsShown()
        XCTAssertFalse(OnboardingMilestone.pageCount10.hasBeenShown)
    }

    // MARK: - 页数阈值映射

    func testCheckPageCountMilestone() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(1), .firstPageCreated)
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(10), .pageCount10)
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(50), .pageCount50)
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(100), .pageCount100)
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(5))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(0))
    }

    // MARK: - 枚举完整性

    func testAllCasesCount() {
        XCTAssertEqual(OnboardingMilestone.allCases.count, 7)
    }

    func testOnboardingPathCount() {
        XCTAssertEqual(OnboardingPath.allCases.count, 3)
    }

    // MARK: - Toast 消息非空

    func testToastMessagesNotEmpty() {
        for milestone in OnboardingMilestone.allCases {
            XCTAssertFalse(milestone.toastMessage.isEmpty, "\(milestone.rawValue) 应有 toast 消息")
        }
    }
}
