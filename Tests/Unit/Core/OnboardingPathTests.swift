//
//  OnboardingPathTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 OnboardingPath 引导路径枚举与 OnboardingMilestone 里程碑触发系统。
//

import XCTest
@testable import ZhiYu

@MainActor
final class OnboardingPathTests: XCTestCase {

    // MARK: - OnboardingPath 枚举

    func testOnboardingPath_allCases_包含3个路径() {
        XCTAssertEqual(OnboardingPath.allCases.count, 3)
        XCTAssertTrue(OnboardingPath.allCases.contains(.quickStart))
        XCTAssertTrue(OnboardingPath.allCases.contains(.importData))
        XCTAssertTrue(OnboardingPath.allCases.contains(.explore))
    }

    func testOnboardingPath_rawValue_正确() {
        XCTAssertEqual(OnboardingPath.quickStart.rawValue, "quickStart")
        XCTAssertEqual(OnboardingPath.importData.rawValue, "importData")
        XCTAssertEqual(OnboardingPath.explore.rawValue, "explore")
    }

    func testOnboardingPath_icon_非空() {
        for path in OnboardingPath.allCases {
            XCTAssertFalse(path.icon.isEmpty, "icon 不应为空：\(path)")
        }
    }

    func testOnboardingPath_color_各路径不同() {
        let colors = Set([
            OnboardingPath.quickStart.color,
            OnboardingPath.importData.color,
            OnboardingPath.explore.color
        ].map { "\($0)" })
        // SwiftUI Color 可能描述相同，但语义上应不同
        XCTAssertEqual(colors.count, 3, "三个路径的 color 应各不相同")
    }

    // MARK: - OnboardingMilestone 枚举

    func testOnboardingMilestone_allCases_包含7个里程碑() {
        XCTAssertEqual(OnboardingMilestone.allCases.count, 7)
    }

    func testOnboardingMilestone_key_包含前缀() {
        for milestone in OnboardingMilestone.allCases {
            XCTAssertTrue(milestone.key.hasPrefix("onboarding.milestone."), "key 应包含前缀：\(milestone)")
        }
    }

    func testOnboardingMilestone_toastMessage_非空非Missing() {
        for milestone in OnboardingMilestone.allCases {
            XCTAssertFalse(milestone.toastMessage.isEmpty, "toastMessage 不应为空：\(milestone)")
            XCTAssertFalse(milestone.toastMessage.contains("[MISSING"), "toastMessage 不应包含 MISSING：\(milestone)")
        }
    }

    // MARK: - checkPageCountMilestone

    func testCheckPageCountMilestone_1_返回firstPageCreated() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(1), .firstPageCreated)
    }

    func testCheckPageCountMilestone_10_返回pageCount10() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(10), .pageCount10)
    }

    func testCheckPageCountMilestone_50_返回pageCount50() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(50), .pageCount50)
    }

    func testCheckPageCountMilestone_100_返回pageCount100() {
        XCTAssertEqual(OnboardingMilestone.checkPageCountMilestone(100), .pageCount100)
    }

    func testCheckPageCountMilestone_非阈值_返回nil() {
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(0))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(2))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(11))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(99))
        XCTAssertNil(OnboardingMilestone.checkPageCountMilestone(101))
    }

    // MARK: - hasBeenShown / markAsShown

    func testHasBeenShown_DI未就绪_返回false() {
        for milestone in OnboardingMilestone.allCases {
            XCTAssertFalse(milestone.hasBeenShown, "DI 未就绪时应返回 false：\(milestone)")
        }
    }

    func testMarkAsShown_DI未就绪_不崩溃() {
        for milestone in OnboardingMilestone.allCases {
            milestone.markAsShown()
        }
    }
}
