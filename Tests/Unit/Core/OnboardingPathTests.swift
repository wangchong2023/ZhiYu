//
//  OnboardingPathTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 OnboardingPath 引导路径枚举与 OnboardingMilestone 里程碑触发系统。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class OnboardingPathTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // P2-1 迁移：强制清理 DI，确保 hasBeenShown 在 DI 未就绪时返回 false
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    // MARK: - OnboardingPath 枚举

    func testOnboardingPathAllCasesContainsThreePaths() {
        XCTAssertEqual(OnboardingPath.allCases.count, 3)
        XCTAssertTrue(OnboardingPath.allCases.contains(.quickStart))
        XCTAssertTrue(OnboardingPath.allCases.contains(.importData))
        XCTAssertTrue(OnboardingPath.allCases.contains(.explore))
    }

    func testOnboardingPathRawValueCorrect() {
        XCTAssertEqual(OnboardingPath.quickStart.rawValue, "quickStart")
        XCTAssertEqual(OnboardingPath.importData.rawValue, "importData")
        XCTAssertEqual(OnboardingPath.explore.rawValue, "explore")
    }

    func testOnboardingPathIconNonEmpty() {
        for path in OnboardingPath.allCases {
            XCTAssertFalse(path.icon.isEmpty, "icon 不应为空：\(path)")
        }
    }

    func testOnboardingPathColorDifferentPerPath() {
        let colors = Set([
            OnboardingPath.quickStart.color,
            OnboardingPath.importData.color,
            OnboardingPath.explore.color
        ].map { "\($0)" })
        // SwiftUI Color 可能描述相同，但语义上应不同
        XCTAssertEqual(colors.count, 3, "三个路径的 color 应各不相同")
    }

    // MARK: - OnboardingMilestone 枚举

    func testOnboardingMilestoneAllCasesContainsSevenMilestones() {
        XCTAssertEqual(OnboardingMilestone.allCases.count, 7)
    }

    func testOnboardingMilestoneKeyContainsPrefix() {
        for milestone in OnboardingMilestone.allCases {
            XCTAssertTrue(milestone.key.hasPrefix("onboarding.milestone."), "key 应包含前缀：\(milestone)")
        }
    }

    func testOnboardingMilestoneToastMessageNonEmptyNonMissing() {
        for milestone in OnboardingMilestone.allCases {
            XCTAssertFalse(milestone.toastMessage.isEmpty, "toastMessage 不应为空：\(milestone)")
            XCTAssertFalse(milestone.toastMessage.contains("[MISSING"), "toastMessage 不应包含 MISSING：\(milestone)")
        }
    }

    // MARK: - checkPageCountMilestone

    func testCheckPageCountMilestone1ReturnsFirstPageCreated() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(1), .firstPageCreated)
    }

    func testCheckPageCountMilestone10ReturnsPageCount10() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(10), .pageCount10)
    }

    func testCheckPageCountMilestone50ReturnsPageCount50() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(50), .pageCount50)
    }

    func testCheckPageCountMilestone100ReturnsPageCount100() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(100), .pageCount100)
    }

    func testCheckPageCountMilestoneNonThresholdReturnsNil() {
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(0))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(2))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(11))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(99))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(101))
    }

    // MARK: - hasBeenShown / markAsShown

    func testHasBeenShownDINotReadyReturnsFalse() {
        for milestone in OnboardingMilestone.allCases {
            XCTAssertFalse(milestone.hasBeenShown, "DI 未就绪时应返回 false：\(milestone)")
        }
    }

    func testMarkAsShownDINotReadyNoCrash() {
        for milestone in OnboardingMilestone.allCases {
            milestone.markAsShown()
        }
    }
}
