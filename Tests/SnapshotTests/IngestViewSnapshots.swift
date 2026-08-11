//
//  IngestViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：Ingest 组件快照测试，覆盖导入记录卡片与摄入时间轴各阶段状态。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class IngestViewSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 测试数据工厂

    /// 构造链接类导入记录
    private func makeLinkRecord(title: String = "Swift 编程语言指南", tags: String? = "编程, Swift") -> ImportRecord {
        ImportRecord(
            category: "link",
            title: title,
            status: "done",
            sourceURL: "https://swift.org/guide",
            tags: tags,
            completedAt: Date(timeIntervalSince1970: 1_725_000_000)
        )
    }

    /// 构造文件类导入记录
    private func makeFileRecord(title: String = "论文.pdf", fileSize: Int64? = 2_400_000) -> ImportRecord {
        ImportRecord(
            category: "file",
            title: title,
            status: "done",
            filePath: "/tmp/document.pdf",
            fileSize: fileSize,
            tags: "学术, AI",
            completedAt: Date(timeIntervalSince1970: 1_725_000_000)
        )
    }

    /// 构造处理中记录
    private func makeProcessingRecord() -> ImportRecord {
        ImportRecord(
            category: "ocr",
            title: "扫描文档",
            status: "processing"
        )
    }

    /// 构造失败记录
    private func makeFailedRecord() -> ImportRecord {
        ImportRecord(
            category: "manual",
            title: "手动输入失败",
            status: "failed"
        )
    }

    // MARK: - ImportRecordCard 快照测试

    /// 测试链接类导入卡片 — 展示来源 URL 与标签
    func testImportRecordCard_Link() {
        let view = ImportRecordCard(record: makeLinkRecord())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    /// 测试文件类导入卡片 — 展示文件图标与大小
    func testImportRecordCard_File() {
        let view = ImportRecordCard(record: makeFileRecord())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    /// 测试无标签记录 — 仅展示来源类型胶囊
    func testImportRecordCard_NoTags() {
        let view = ImportRecordCard(record: makeLinkRecord(tags: nil))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    /// 测试处理中记录 — 展示处理中状态
    func testImportRecordCard_Processing() {
        let view = ImportRecordCard(record: makeProcessingRecord())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    /// 测试失败记录 — 展示失败状态
    func testImportRecordCard_Failed() {
        let view = ImportRecordCard(record: makeFailedRecord())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    // MARK: - IngestTimelineView 快照测试

    /// 测试时间轴 — 提取阶段
    func testIngestTimelineView_ExtractionStage() {
        let view = IngestTimelineView(currentStage: .extraction, subLogs: ["正在解析文档..."])
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 300)))
    }

    /// 测试时间轴 — 向量化阶段（接近完成）
    func testIngestTimelineView_EmbeddingStage() {
        let view = IngestTimelineView(currentStage: .embedding, subLogs: ["生成向量中...", "已处理 128/256"])
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 300)))
    }

    /// 测试时间轴 — 无子日志的初始状态
    func testIngestTimelineView_EmptySubLogs() {
        let view = IngestTimelineView(currentStage: .pending, subLogs: [])
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 300)))
    }
}
