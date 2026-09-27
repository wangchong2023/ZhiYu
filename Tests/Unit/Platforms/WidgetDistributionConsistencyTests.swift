//
//  WidgetDistributionConsistencyTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests/Unit] Platforms/Widget
//  核心职责：验证 Widget 分布数据跨模块 key 与默认值一致性，暴露大小写不匹配与硬编码缺陷。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class WidgetDistributionConsistencyTests: XCTestCase {

    // MARK: - 缺陷 #1：默认分布常量 key 大小写跨模块不一致

    /// PlatformConstants.WidgetWatch.defaultDistribution（大写 key）与
    /// FeatureConstants.SourceType.defaultWidgetDistribution（小写 key）是同一概念，
    /// key 必须一致，否则跨模块传递 [String: Double] 时全部 miss fallback。
    func testDefaultDistributionKeys_consistentBetweenPlatformAndFeatureConstants() {
        let platformKeys = Set(PlatformConstants.WidgetWatch.defaultDistribution.keys)
        let featureKeys = Set(FeatureConstants.SourceType.defaultWidgetDistribution.keys)

        XCTAssertEqual(
            platformKeys, featureKeys,
            "PlatformConstants.WidgetWatch.defaultDistribution key(\(platformKeys)) 与 "
            + "FeatureConstants.SourceType.defaultWidgetDistribution key(\(featureKeys)) 必须一致"
        )
    }

    /// 两个默认分布常量的值必须一致（同一份默认分布比例不应有两套数据源）
    func testDefaultDistributionValues_consistentBetweenPlatformAndFeatureConstants() {
        let platformDist = PlatformConstants.WidgetWatch.defaultDistribution
        let featureDist = FeatureConstants.SourceType.defaultWidgetDistribution

        for key in featureDist.keys {
            let platformValue = platformDist[key] ?? -1
            let featureValue = featureDist[key] ?? -1
            XCTAssertEqual(
                platformValue, featureValue, accuracy: 0.001,
                "key=\(key) 在两个默认分布常量中值不一致: Platform=\(platformValue) vs Feature=\(featureValue)"
            )
        }
    }

    // MARK: - 缺陷 #2：WidgetRepository fallback 硬编码，未引用 PlatformConstants

    /// WidgetRepository.fetchDistribution() 在无快照时的 fallback 值应与
    /// PlatformConstants.WidgetWatch.defaultDistribution 一致，而非硬编码独立数值。
    func testWidgetRepositoryFallbackDistribution_matchesPlatformConstants() async {
        let stats = await WidgetRepository.fetchDistribution()
        let defaultDist = PlatformConstants.WidgetWatch.defaultDistribution

        // 用 FeatureConstants 的 key（小写，实际数据流标准）读取 PlatformConstants
        let expectedSource = defaultDist[FeatureConstants.SourceType.source] ?? -1
        let expectedConcept = defaultDist[FeatureConstants.SourceType.concept] ?? -1
        let expectedEntity = defaultDist[FeatureConstants.SourceType.entity] ?? -1
        let expectedMap = defaultDist[FeatureConstants.SourceType.map] ?? -1

        XCTAssertEqual(stats.sourceRatio, expectedSource, accuracy: 0.001,
            "WidgetRepository fallback sourceRatio=\(stats.sourceRatio) 与 PlatformConstants 默认值=\(expectedSource) 不一致")
        XCTAssertEqual(stats.conceptRatio, expectedConcept, accuracy: 0.001,
            "WidgetRepository fallback conceptRatio=\(stats.conceptRatio) 与 PlatformConstants 默认值=\(expectedConcept) 不一致")
        XCTAssertEqual(stats.entityRatio, expectedEntity, accuracy: 0.001,
            "WidgetRepository fallback entityRatio=\(stats.entityRatio) 与 PlatformConstants 默认值=\(expectedEntity) 不一致")
        XCTAssertEqual(stats.mapRatio, expectedMap, accuracy: 0.001,
            "WidgetRepository fallback mapRatio=\(stats.mapRatio) 与 PlatformConstants 默认值=\(expectedMap) 不一致")
    }

    // MARK: - 缺陷 #3：KnowledgeDistributionWidgetView 默认参数 key 与实际数据流不匹配

    /// KnowledgeDistributionWidgetView 默认参数用 PlatformConstants.WidgetWatch.defaultDistribution（大写 key），
    /// 但实际数据流（WidgetRepository → FeatureConstants）用小写 key。
    /// 视图遍历 distribution.keys 显示标签时，默认预览显示 "Source"，实际数据显示 "source"。
    func testKnowledgeDistributionWidgetView_defaultKeys_matchFeatureConstantsDataFlow() {
        let view = KnowledgeDistributionWidgetView()
        let viewKeys = Set(view.distribution.keys)
        let featureKeys = Set(FeatureConstants.SourceType.defaultWidgetDistribution.keys)

        XCTAssertEqual(
            viewKeys, featureKeys,
            "KnowledgeDistributionWidgetView 默认 distribution key(\(viewKeys)) 与 "
            + "实际数据流 key(\(featureKeys)) 不一致，导致 UI 标签大小写不统一"
        )
    }
}
