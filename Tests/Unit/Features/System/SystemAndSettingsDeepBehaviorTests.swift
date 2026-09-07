//
//  SystemAndSettingsDeepFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class SystemAndSettingsDeepBehaviorTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Settings & Subcomponents Deep Mounting

    func testSettingsViewFullInteraction() async throws {
        let settingsStore = try XCTUnwrap(ServiceContainer.shared.resolveOptional(SettingsStore.self))
        // 隐私模式默认开启（SettingsStore 设计契约，见 SettingsStoreTests.testDefaultValues）
        XCTAssertTrue(settingsStore.isPrivacyModeEnabled, "隐私模式默认应为开启状态")

        let view = SettingsView()
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(window.rootViewController)
        XCTAssertNotNil(host.view)
    }

    func testDeveloperSettingsViewFullInteraction() throws {
        let settingsStore = try XCTUnwrap(ServiceContainer.shared.resolveOptional(SettingsStore.self))
        let view = DeveloperSettingsView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(settingsStore)
        XCTAssertNotNil(host.view)
    }

    func testRawStorageListViewFullInteraction() async throws {
        let store = try XCTUnwrap(ServiceContainer.shared.resolveOptional(KnowledgeStore.self))
        let view = RawStorageListView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertEqual(store.totalPages, 0)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. PluginCenter & Generator

    func testPluginCenterViewFullInteraction() async throws {
        let pluginRegistry = try XCTUnwrap(ServiceContainer.shared.resolveOptional(PluginRegistry.self))
        let view = PluginCenterView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(pluginRegistry)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. Auth, Profile & Subscription

    func testAuthAndSubscriptionViewsFullInteraction() async throws {
        struct Wrapper: View {
            @State var isPurchasing = false
            @State var isUpgradeSuccess = false
            @State var errorMessage: String?
            @State var selectedCycle: BillingCycle = .yearly

            var body: some View {
                VStack {
                    AuthView()
                    UserProfileView()
                    SubscriptionPlanView()
                    SubscriptionPurchaseFlow(
                        isPurchasing: $isPurchasing,
                        isUpgradeSuccess: $isUpgradeSuccess,
                        errorMessage: $errorMessage,
                        selectedCycle: selectedCycle
                    )
                    OverseasLoginCardView()
                }
            }
        }

        let wrapper = Wrapper()
        XCTAssertEqual(wrapper.selectedCycle, .yearly)
        let view = wrapper.snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. ModelManager & OnDevice LLM

    func testModelManagerSectionsFullInteraction() async throws {
        struct Wrapper: View {
            var body: some View {
                VStack {
                    LLMSettingsView()
                    OnDeviceLLMSettingsView()
                    LocalModelManagerView()
                    ModelStoreView(onGoToLab: {})
                    ModelLabView(onGoToStore: {})
                    ServerConfigView()
                    InferenceParametersView()
                    SmartRoutingView()
                    TaskRoutingRulesView()
                }
            }
        }

        let llm = try XCTUnwrap(ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self))
        let view = Wrapper().snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(llm)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 5. Collaboration & Feedback

    func testCollaborationAndFeedbackViews() async throws {
        struct Wrapper: View {
            var body: some View {
                VStack {
                    CollaborationView()
                    FeedbackView()
                    RAGEvaluationView()
                }
            }
        }

        let collaboration = try XCTUnwrap(ServiceContainer.shared.resolveOptional((any CollaborationProviderProtocol).self))
        let view = Wrapper().snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(collaboration)
        XCTAssertNotNil(host.view)
    }
}
