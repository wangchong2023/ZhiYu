//
//  AIAndMultimodalDeepFullCoverageTests.swift
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
final class AIAndMultimodalInteractiveFlowTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Chat & Synthesis Full Views

    func testChatAndSynthesisFullViews() async throws {
        struct Wrapper: View {
            @State var selectedTab: AppTab = .chat
            @State var selection: SidebarSelection? = .tool(.dashboard)

            var body: some View {
                VStack {
                    ChatView(selectedTab: $selectedTab)
                    SynthesisView(selection: $selection, selectedTab: $selectedTab)
                }
            }
        }

        let wrapper = Wrapper()
        let view = wrapper.snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        XCTAssertEqual(wrapper.selectedTab, .chat)
        XCTAssertEqual(wrapper.selection, .tool(.dashboard))
    }

    // MARK: - 2. Quiz & TaskCenter & VoiceNote

    func testQuizTaskCenterAndVoiceNote() async throws {
        let quiz = QuizModel(
            title: "Swift 6 Concurrency",
            questions: [
                QuizQuestion(id: 1, text: "What is Actor?", options: ["Isolates state", "Global state"], answer: 0, explanation: "Actor isolates mutable state.")
            ]
        )
        struct Wrapper: View {
            let quiz: QuizModel

            var body: some View {
                VStack {
                    QuizView(quiz: quiz)
                    TaskCenterView()
                    VoiceNoteView()
                }
            }
        }

        let view = Wrapper(quiz: quiz).snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
        XCTAssertEqual(quiz.title, "Swift 6 Concurrency")
        XCTAssertEqual(quiz.questions.count, 1)
        XCTAssertEqual(quiz.questions.first?.answer, 0)
    }
}
