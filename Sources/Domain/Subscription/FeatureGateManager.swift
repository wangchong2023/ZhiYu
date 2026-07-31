//
//  FeatureGateManager.swift
//  ZhiYu
//
//  Created by Constantine on 2026/07/23.
//
//  系统层级：[L1.5] 领域层
//  核心职责：C 端集中式能力门禁与离线配额降级管理者，控制 Feature 门禁与离线 Quota。
//

import Foundation
import Combine

/// C 端集中式能力门禁与配额管理者 (Domain Layer L1.5)
public final class FeatureGateManager: @unchecked Sendable {

    public static let shared = FeatureGateManager()

    private let cacheKey = "zhiyu_cached_plan_quotas"
    private let userDefaults: UserDefaults

    /// 当前已激活的配额能力订阅
    public private(set) var activeQuotas: PlanQuotasVo? {
        didSet {
            notifyQuotasChanged()
        }
    }

    /// 变化通知 Publisher
    public let quotasSubject = PassthroughSubject<PlanQuotasVo?, Never>()

    // MARK: - 生产环境游客模式红线 (Guest Mode Guard)

    /// 正式上线环境开关：生产环境部署时必须置为 false 禁用匿名游客访问
    #if DEBUG
    public static let isGuestModeAllowed: Bool = true // 测试期临时允许
    #else
    public static let isGuestModeAllowed: Bool = false // 正式上线红线：禁用匿名游客
    #endif

    // MARK: - Initializer

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // 冷启动时优先从本地持久化缓存恢复上次联网成功拉取的套餐 (Cache-First)
        self.activeQuotas = loadCachedQuotas()
    }

    // MARK: - Quotas Sync & Update

    /// 联网同步成功后更新配额并刷入本地持久化缓存
    public func updateActiveQuotas(_ newQuotas: PlanQuotasVo) {
        self.activeQuotas = newQuotas
        saveQuotasToCache(newQuotas)
    }

    /// 清空配额缓存 (如用户登出)
    public func clearQuotasCache() {
        self.activeQuotas = nil
        userDefaults.removeObject(forKey: cacheKey)
    }

    // MARK: - Offline Fallback Baseline Strategy

    /// C 端纯新机未联网/未登录时的 Lite 基础保底策略 (Cold-Start Baseline)
    public static let offlineColdStartQuotas = PlanQuotasVo.createLiteDefault

    /// 获取当前生效的配额实体（优先使用本地已缓存套餐，若无缓存且允许游客模式则回退至 Lite 基础保底）
    public var currentEffectiveQuotas: PlanQuotasVo? {
        if let cached = activeQuotas {
            return cached
        }
        // 正式环境禁用游客模式时，无登录缓存则返回 nil 拦截跳转登录页
        guard Self.isGuestModeAllowed else { return nil }
        return Self.offlineColdStartQuotas
    }

    // MARK: - Feature Gate Check APIs

    /// 检查某项布尔特权能力是否开启
    public func isFeatureEnabled(_ keyPath: KeyPath<PlanQuotasVo, Bool>) -> Bool {
        guard let quotas = currentEffectiveQuotas else { return false }
        return quotas[keyPath: keyPath]
    }

    /// 获取某项数字型配额限制 (-1 表示无限)
    public func getQuotaLimit(_ keyPath: KeyPath<PlanQuotasVo, Int>) -> Int {
        guard let quotas = currentEffectiveQuotas else { return 0 }
        return quotas[keyPath: keyPath]
    }

    /// 校验当前是否超出某项数字上限
    public func isQuotaExceeded(_ keyPath: KeyPath<PlanQuotasVo, Int>, currentUsage: Int) -> Bool {
        let limit = getQuotaLimit(keyPath)
        if limit == -1 { return false } // -1 表示无限，绝不超限
        return currentUsage >= limit
    }

    // MARK: - Private Persistence Helpers

    private func loadCachedQuotas() -> PlanQuotasVo? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(PlanQuotasVo.self, from: data)
        } catch {
            return nil
        }
    }

    private func saveQuotasToCache(_ quotas: PlanQuotasVo) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(quotas)
            userDefaults.set(data, forKey: cacheKey)
        } catch {
            // Log encoding failure
        }
    }

    private func notifyQuotasChanged() {
        quotasSubject.send(activeQuotas)
    }
}
