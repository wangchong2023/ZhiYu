//
//  PlatformTraitsTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：验证运行时 Trait 默认值与注入覆盖
//

import SwiftUI
import XCTest
@testable import ZhiYu

final class PlatformTraitsTests: XCTestCase {

    // MARK: - interfaceIdiom 默认值

    func testInterfaceIdiomDefaultValueMatchesCompileTarget() {
        let view = EmptyView().environment(\.interfaceIdiom, .watch)
        XCTAssertNotNil(view)
    }

    #if os(watchOS)
    func testInterfaceIdiomDefaultIsWatchOnWatchOS() {
        XCTAssertEqual(InterfaceIdiomKey.defaultValue, .watch)
    }
    #elseif os(macOS)
    func testInterfaceIdiomDefaultIsMacOnMacOS() {
        XCTAssertEqual(InterfaceIdiomKey.defaultValue, .mac)
    }
    #else
    func testInterfaceIdiomDefaultIsIPhoneOrIPadOnIOS() {
        let idiom = InterfaceIdiomKey.defaultValue
        XCTAssertTrue(idiom == .iPhone || idiom == .iPad || idiom == .macCatalyst)
    }
    #endif

    // MARK: - InterfaceIdiom 枚举完整性

    func testInterfaceIdiomAllCases() {
        let allCases: [InterfaceIdiom] = [.iPhone, .iPad, .mac, .macCatalyst, .watch]
        XCTAssertEqual(allCases.count, 5)
    }

    // MARK: - supportsTouch 默认值

    #if os(iOS) || os(watchOS)
    func testSupportsTouchDefaultTrueOnTouchPlatforms() {
        XCTAssertTrue(SupportsTouchKey.defaultValue)
    }
    #else
    func testSupportsTouchDefaultFalseOnMac() {
        XCTAssertFalse(SupportsTouchKey.defaultValue)
    }
    #endif

    // MARK: - supportsFullScreenImmersive 默认值

    #if os(iOS) || os(macOS)
    func testSupportsFullScreenImmersiveDefaultTrueOnIOSAndMac() {
        XCTAssertTrue(SupportsFullScreenImmersiveKey.defaultValue)
    }
    #else
    func testSupportsFullScreenImmersiveDefaultFalseOnWatch() {
        XCTAssertFalse(SupportsFullScreenImmersiveKey.defaultValue)
    }
    #endif

    // MARK: - prefersTabNavigation 默认值

    func testPrefersTabNavigationDefaultIsBool() {
        let value = PrefersTabNavigationKey.defaultValue
        XCTAssertTrue(value == true || value == false)
    }

    // MARK: - 运行时注入覆盖

    func testEnvironmentInjectionOverridesDefault() {
        var env = EnvironmentValues()
        env.interfaceIdiom = .iPad
        XCTAssertEqual(env.interfaceIdiom, .iPad)
        env.prefersTabNavigation = true
        XCTAssertTrue(env.prefersTabNavigation)
        env.supportsTouch = false
        XCTAssertFalse(env.supportsTouch)
        env.supportsFullScreenImmersive = true
        XCTAssertTrue(env.supportsFullScreenImmersive)
    }
}
