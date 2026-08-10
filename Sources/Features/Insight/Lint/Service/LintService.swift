//
//  LintService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：实现 Lint 模块的核心业务逻辑服务。
//
import Foundation

// MARK: - Lint Service (Health Check)
/// 对知识库进行健康检查：断裂链接、孤立页面、存根页面、陈旧内容。
/// Returns issues without side effects — caller decides what to do with results.
public final class LintService: Sendable {

    /// 知识库健康等级
    public enum HealthLevel: String, CaseIterable, Sendable {
        case excellent, good, fair, poor

        var title: String {
            switch self {
            case .excellent: return L10n.Lint.healthExcellent
            case .good: return L10n.Lint.healthGood
            case .fair: return L10n.Lint.healthFair
            case .poor: return L10n.Lint.healthPoor
            }
        }

        var colorName: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }

    /// Threshold (in days) after which an active page is considered stale.
    private static let stalePageThresholdDays = 30

    /// Run all lint checks and return the list of issues found.
    func runLint(pages: [KnowledgePage], linkService _: LinkService) async -> [LintIssue] {
        var issues: [LintIssue] = []

        // 1. 性能预优化：构建查找索引 (使用 uniquingKeysWith 避免因重复标题导致的崩溃)
        let titleMap = Dictionary(pages.map { ($0.title.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        var incomingLinksCount: [UUID: Int] = [:]
        for page in pages {
            for link in page.outgoingLinks {
                if let target = titleMap[link.lowercased()] {
                    incomingLinksCount[target.id, default: 0] += 1
                }
            }
        }

        // 2. 执行各项巡检
        issues += checkIslandsAndOrphans(pages: pages, incomingLinksCount: incomingLinksCount)
        issues += checkCircularReferences(pages: pages, titleMap: titleMap)
        issues += checkBrokenLinks(pages: pages, titleMap: titleMap)
        issues += checkStubsAndStale(pages: pages)
        issues += checkDuplicateTitles(pages: pages)

        return issues
    }

    // MARK: - 私有巡检规则

    /// 检查孤岛页面与孤立页面
    private func checkIslandsAndOrphans(pages: [KnowledgePage], incomingLinksCount: [UUID: Int]) -> [LintIssue] {
        var issues: [LintIssue] = []
        for page in pages where page.pageType != .raw {
            let inCount = incomingLinksCount[page.id] ?? 0
            let outCount = page.outgoingLinks.count

            if inCount == 0 && outCount == 0 {
                issues.append(LintIssue(
                    severity: .warning,
                    type: .island,
                    pageID: page.id,
                    message: String(format: L10n.Lint.islandMessage, page.title),
                    suggestion: L10n.Lint.islandSuggestion
                ))
            } else if inCount == 0 {
                issues.append(LintIssue(
                    severity: .info,
                    type: .orphan,
                    pageID: page.id,
                    message: String(format: L10n.Lint.orphanPage, page.title),
                    suggestion: String(format: L10n.Lint.orphanSuggestion, page.title)
                ))
            }
        }
        return issues
    }

    /// 检查循环引用 (A -> B -> A)
    private func checkCircularReferences(pages: [KnowledgePage], titleMap: [String: KnowledgePage]) -> [LintIssue] {
        var issues: [LintIssue] = []
        for pageA in pages {
            for linkTitle in pageA.outgoingLinks {
                if let pageB = titleMap[linkTitle.lowercased()] {
                    if pageB.outgoingLinks.contains(where: { $0.lowercased() == pageA.title.lowercased() }) {
                        issues.append(LintIssue(
                            severity: .info,
                            type: .cycle,
                            pageID: pageA.id,
                            message: String(format: L10n.Lint.cycleMessage, pageA.title, pageB.title),
                            suggestion: L10n.Lint.cycleSuggestion
                        ))
                    }
                }
            }
        }
        return issues
    }

    /// 检查断裂链接
    private func checkBrokenLinks(pages: [KnowledgePage], titleMap: [String: KnowledgePage]) -> [LintIssue] {
        var issues: [LintIssue] = []
        for page in pages {
            for link in page.outgoingLinks where titleMap[link.lowercased()] == nil {
                issues.append(LintIssue(
                    severity: .error,
                    type: .brokenLink,
                    pageID: page.id,
                    message: String(format: L10n.Lint.brokenLink, page.title, link),
                    suggestion: String(format: L10n.Lint.brokenLinkSuggestion, link)
                ))
            }
        }
        return issues
    }

    /// 检查存根页面与陈旧内容
    private func checkStubsAndStale(pages: [KnowledgePage]) -> [LintIssue] {
        var issues: [LintIssue] = []
        let staleThreshold = Calendar.current.date(byAdding: .day, value: -Self.stalePageThresholdDays, to: Date()) ?? Date()

        for page in pages where page.status == .active {
            // 存根检查
            if page.isStub {
                issues.append(LintIssue(
                    severity: .info,
                    type: .stub,
                    pageID: page.id,
                    message: String(format: L10n.Lint.stubContent, page.title),
                    suggestion: L10n.Lint.stubSuggestion
                ))
            }

            // 陈旧检查
            if page.updatedAt < staleThreshold {
                issues.append(LintIssue(
                    severity: .info,
                    type: .stale,
                    pageID: page.id,
                    message: String(format: L10n.Lint.outdated, page.title),
                    suggestion: L10n.Lint.outdatedSuggestion
                ))
            }
        }
        return issues
    }

    /// 检查重名的页面
    private func checkDuplicateTitles(pages: [KnowledgePage]) -> [LintIssue] {
        var issues: [LintIssue] = []
        var titleGroups: [String: [KnowledgePage]] = [:]
        for page in pages {
            let key = page.title.lowercased()
            titleGroups[key, default: []].append(page)
        }

        for (_, group) in titleGroups where group.count > 1 {
            for page in group {
                issues.append(LintIssue(
                    severity: .warning,
                    type: .generic,
                    pageID: page.id,
                    message: L10n.Lint.duplicateTitleMessage(page.title),
                    suggestion: L10n.Lint.duplicateTitleSuggestion
                ))
            }
        }
        return issues
    }

    /// 根据检查结果计算健康评分与等级
    func calculateHealthMetrics(issues: [LintIssue]) -> (score: Int, level: HealthLevel) {
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count

        // 扣分制：错误 -10，警告 -5，提示 -2
        let deduction = (errorCount * 10) + (warningCount * 5) + (infoCount * 2)
        let score = max(0, 100 - deduction)

        let level: HealthLevel
        if score >= 90 { level = .excellent } else if score >= 75 { level = .good } else if score >= 50 { level = .fair } else { level = .poor }

        return (score, level)
    }
}
