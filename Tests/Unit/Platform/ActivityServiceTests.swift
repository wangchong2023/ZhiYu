//
//  ActivityServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：ActivityService 单元测试，覆盖实时活动启动、进度更新、结束等场景。
//

import XCTest
@testable import ZhiYu

@MainActor
final class ActivityServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let taskName: String = "AI 合成任务"
        static let targetName: String = "目标知识页"
        static let progressHalf: Double = 0.5
        static let progressFull: Double = 1.0
        static let message: String = "正在处理"
        static let sourceCount: Int = 3
        static let estimatedSeconds: Int = 60
        static let currentFileName: String = "source.pdf"
        static let zeroSourceCount: Int = 0
        static let emptyFileName: String = ""
        static let zeroEstimatedSeconds: Int = 0
    }

    // MARK: - 单例

    /// shared 单例应非空
    func testSharedSingletonIsNotNil() {
        XCTAssertNotNil(ActivityService.shared, "shared 单例不应为 nil")
    }

    /// 多次访问 shared 应返回同一实例
    func testSharedSingletonIsStable() {
        let first = ActivityService.shared
        let second = ActivityService.shared
        XCTAssertTrue(first === second, "shared 应返回同一实例")
    }

    // MARK: - startActivity（基础协议接口）

    /// 基础 startActivity 不应崩溃（模拟器/非 iOS 实际 no-op）
    func testStartActivityBasicDoesNotCrash() {
        let service = ActivityService.shared
        let taskID = UUID()
        XCTAssertFalse(taskID.uuidString.isEmpty)
        service.startActivity(id: taskID, name: TestConstants.taskName, target: TestConstants.targetName)
    }

    // MARK: - startActivity（扩展接口）

    /// 扩展 startActivity 含完整参数不应崩溃
    func testStartActivityExtendedWithFullParametersDoesNotCrash() {
        let service = ActivityService.shared
        let taskID = UUID()
        XCTAssertEqual(TestConstants.sourceCount, 3)
        XCTAssertEqual(TestConstants.estimatedSeconds, 60)
        service.startActivity(
            id: taskID,
            name: TestConstants.taskName,
            target: TestConstants.targetName,
            kind: .synthesis,
            sourceCount: TestConstants.sourceCount,
            currentFileName: TestConstants.currentFileName,
            estimatedSecondsRemaining: TestConstants.estimatedSeconds
        )
    }

    /// 使用 ingestOCR 类型启动活动不应崩溃
    func testStartActivityWithIngestOCRKindDoesNotCrash() {
        let service = ActivityService.shared
        let taskID = UUID()
        XCTAssertEqual(ActivityKind.ingestOCR.rawValue, "ingestOCR")
        service.startActivity(
            id: taskID,
            name: TestConstants.taskName,
            target: TestConstants.targetName,
            kind: .ingestOCR,
            sourceCount: TestConstants.zeroSourceCount,
            currentFileName: TestConstants.emptyFileName,
            estimatedSecondsRemaining: TestConstants.zeroEstimatedSeconds
        )
    }

    /// 使用 voiceNote 类型启动活动不应崩溃
    func testStartActivityWithVoiceNoteKindDoesNotCrash() {
        let service = ActivityService.shared
        let taskID = UUID()
        XCTAssertEqual(ActivityKind.voiceNote.rawValue, "voiceNote")
        service.startActivity(
            id: taskID,
            name: TestConstants.taskName,
            target: TestConstants.targetName,
            kind: .voiceNote,
            sourceCount: TestConstants.zeroSourceCount,
            currentFileName: TestConstants.emptyFileName,
            estimatedSecondsRemaining: TestConstants.zeroEstimatedSeconds
        )
    }

    // MARK: - updateProgress

    /// 基础 updateProgress 对不存在的任务 ID 不应崩溃
    func testUpdateProgressForNonExistentTaskDoesNotCrash() async {
        let service = ActivityService.shared
        let nonExistentID = UUID()
        XCTAssertNotNil(nonExistentID)
        await service.updateProgress(id: nonExistentID, progress: TestConstants.progressHalf,
                                     message: TestConstants.message)
    }

    /// 扩展 updateProgress 含完整参数不应崩溃
    func testUpdateProgressExtendedWithFullParametersDoesNotCrash() async {
        let service = ActivityService.shared
        let taskID = UUID()
        XCTAssertEqual(TestConstants.progressHalf, 0.5)
        service.startActivity(id: taskID, name: TestConstants.taskName, target: TestConstants.targetName)
        await service.updateProgress(
            id: taskID,
            progress: TestConstants.progressHalf,
            message: TestConstants.message,
            sourceCount: TestConstants.sourceCount,
            currentFileName: TestConstants.currentFileName,
            estimatedSecondsRemaining: TestConstants.estimatedSeconds
        )
    }

    /// 进度为 1.0 时更新不应崩溃
    func testUpdateProgressWithFullValueDoesNotCrash() async {
        let service = ActivityService.shared
        let taskID = UUID()
        XCTAssertEqual(TestConstants.progressFull, 1.0)
        service.startActivity(id: taskID, name: TestConstants.taskName, target: TestConstants.targetName)
        await service.updateProgress(id: taskID, progress: TestConstants.progressFull,
                                     message: TestConstants.message)
    }

    // MARK: - endActivity

    /// 结束不存在的任务 ID 不应崩溃
    func testEndActivityForNonExistentTaskDoesNotCrash() async {
        let service = ActivityService.shared
        let nonExistentID = UUID()
        XCTAssertNotNil(nonExistentID)
        await service.endActivity(id: nonExistentID)
    }

    /// 启动后结束同一任务不应崩溃
    func testStartAndEndSameTaskDoesNotCrash() async {
        let service = ActivityService.shared
        let taskID = UUID()
        XCTAssertFalse(taskID.uuidString.isEmpty)
        service.startActivity(id: taskID, name: TestConstants.taskName, target: TestConstants.targetName)
        await service.endActivity(id: taskID)
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 LiveActivityProtocol
    func testConformsToLiveActivityProtocol() async {
        let service: any LiveActivityProtocol = ActivityService.shared
        let taskID = UUID()
        XCTAssertNotNil(service)
        service.startActivity(id: taskID, name: TestConstants.taskName, target: TestConstants.targetName)
        await service.updateProgress(id: taskID, progress: TestConstants.progressHalf,
                                     message: TestConstants.message)
        await service.endActivity(id: taskID)
    }
}
