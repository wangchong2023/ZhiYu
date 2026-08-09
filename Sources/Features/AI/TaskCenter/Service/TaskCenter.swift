//
//  TaskCenter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：任务中心：后台 AI 任务调度与进度追踪。
//
import Foundation
import UFPCore
import Combine

/// 任务类型
public enum TaskType: String, CaseIterable, Sendable {
    case ai             // 通用 AI 任务
    case ingest         // 导入任务
    case aiScan         // AI 扫描
    case healthCheck    // 健康检查
    case synthesis      // 知识合成

    var icon: String {
        switch self {
        case .ai: return "sparkles"
        case .ingest: return "tray.and.arrow.down"
        case .aiScan: return "bolt.shield.fill"
        case .healthCheck: return "stethoscope"
        case .synthesis: return "wand.and.stars"
        }
    }

    var defaultColor: String {
        switch self {
        case .ingest: return "blue"
        case .healthCheck: return "red"
        case .aiScan, .ai: return "orange"
        case .synthesis: return "purple"
        }
    }
    
    var localizedName: String {
        switch self {
        case .ai: return "AI"
        case .ingest: return L10n.AI.Task.typeIngest
        case .aiScan: return L10n.AI.Task.typeAIScan
        case .healthCheck: return L10n.AI.Task.typeHealthCheck
        case .synthesis: return L10n.AI.Task.typeSynthesis
        }
    }
}

/// RAG / AI 执行阶段 (用于多维视觉反馈)
public enum TaskStage: String, Equatable, Sendable {
    case pending       // 准备阶段
    case extraction    // 文本提取/预处理 (Gray)
    case enrichment    // AI语义增强 (Indigo)
    case chunking      // 语义分块 (Cyan)
    case embedding     // 向量化/特征提取 (Teal)
    case retrieval     // 数据库检索/BM25 (Blue)
    case synthesis     // 大模型合成生成 (Purple)
    case general       // 通用执行 (Orange)
}

/// 任务执行状态
public enum TaskStatus: Equatable, Sendable {
    case pending                                      // 等待中
    case running(progress: Double, stage: TaskStage)  // 执行中（带进度与具体阶段）
    case completed                                    // 已完成
    case failed(error: String)                        // 执行失败（带错误信息）

    /// 判等比较
    public static func == (lhs: TaskStatus, rhs: TaskStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (.completed, .completed): return true
        case let (.running(p1, s1), .running(p2, s2)): return p1 == p2 && s1 == s2
        case let (.failed(e1), .failed(e2)): return e1 == e2
        default: return false
        }
    }
}

/// 全球异步任务模型
struct GlobalTask: Identifiable, Equatable {
    let id = UUID()
    let type: TaskType
    let name: String                // 任务名称
    let target: String              // 目标对象
    var status: TaskStatus          // 当前状态
    let startTime = Date()          // 启动时间
    var isRead: Bool = false        // 用户是否已读
    var associatedPageID: UUID? // 关联页面
    var subLogs: [String] = []      // 细粒度子状态日志 (消除信息真空)
}

/// 全局任务管理中心 (单例)
@MainActor
class TaskCenter: ObservableObject {
    static let shared = TaskCenter()

    /// 单个任务保留的最大子日志条数（超出后从头部丢弃）
    private static let maxSubLogCount: Int = 50

    @Published var tasks: [GlobalTask] = []
    @Published var latestStatus: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    /// 注入实时活动能力，支持跨平台解耦
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪时静默跳过，避免启动崩溃。
    private lazy var activityService: (any LiveActivityProtocol)? = ServiceContainer.shared.resolveOptional((any LiveActivityProtocol).self)

    init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        AppEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .clearAllDataRequested = event {
                    self?.reset()
                }
            }
            .store(in: &cancellables)
    }

    /// 更新LatestStatus
    /// - Parameter text: text
    func updateLatestStatus(_ text: String) {
        self.latestStatus = text
        // 实时同步到当前“最活跃”的灵动岛（如果平台支持）
        if let firstRunningTask = tasks.first(where: { if case .running = $0.status { return true }; return false }) {
            Task {
                if case .running(let progress, _) = firstRunningTask.status {
                    await activityService?.updateProgress(id: firstRunningTask.id, progress: progress, message: text)
                } else {
                    await activityService?.updateProgress(id: firstRunningTask.id, progress: 0.5, message: text)
                }
            }
        }
    }

    struct TaskMetrics {
        let total: Int
        let completed: Int
        let running: Int
        let failed: Int
    }

    /// metrics
    /// - Returns: 返回值
    func metrics(for type: TaskType) -> TaskMetrics {
        let relevant = tasks.filter { $0.type == type }
        let completed = relevant.filter { $0.status == .completed }.count
        let running = relevant.filter {
            if case .running = $0.status { return true }; return false
        }.count
        let failed = relevant.filter {
            if case .failed = $0.status { return true }; return false
        }.count

        return TaskMetrics(total: relevant.count, completed: completed, running: running, failed: failed)
    }

    var unreadCount: Int {
        tasks.filter { task in
            if task.isRead { return false }
            switch task.status {
            case .completed, .failed: return true
            default: return false
            }
        }.count
    }

    /// 添加Task
    /// - Parameter type: type
    /// - Parameter name: name
    /// - Parameter target: target
    /// - Returns: 唯一标识
    func addTask(type: TaskType = .ai, name: String, target: String) -> UUID {
        let task = GlobalTask(type: type, name: name, target: target, status: .pending)
        self.tasks.insert(task, at: 0)
        self.latestStatus = L10n.AI.Task.starting( name, target)

        activityService?.startActivity(id: task.id, name: name, target: target)

        return task.id
    }

    /// 更新Task
    /// - Parameter id: id
    /// - Parameter status: status
    /// - Parameter associatedPageID: associatedPageID
    func updateTask(_ id: UUID, status: TaskStatus, associatedPageID: UUID? = nil) {
        if let index = self.tasks.firstIndex(where: { $0.id == id }) {
            self.tasks[index].status = status
            if let pageID = associatedPageID {
                self.tasks[index].associatedPageID = pageID
            }

            let task = self.tasks[index]
            switch status {
            case .running(let progress, _):
                self.latestStatus = L10n.AI.Task.running( task.name, task.target)
                Task {
                    await activityService?.updateProgress(id: task.id, progress: progress, message: self.latestStatus)
                }
            case .completed:
                self.latestStatus = L10n.AI.Task.completed( task.name)
                NotificationCenter.default.post(name: .taskCompleted, object: task)
                Task {
                    await activityService?.endActivity(id: task.id)
                }
            case .failed:
                self.latestStatus = L10n.AI.Task.failed( task.name)
                NotificationCenter.default.post(name: .taskCompleted, object: task)
                Task {
                    await activityService?.endActivity(id: task.id)
                }
            case .pending:
                break
            }

            if case .completed = status {
                if self.tasks.count > 20 {
                    self.tasks.removeLast()
                }
            }
        }
    }

    /// completeTask
    /// - Parameter id: id
    /// - Parameter associatedPageID: associatedPageID
    func completeTask(id: UUID, associatedPageID: UUID? = nil) {
        updateTask(id, status: .completed, associatedPageID: associatedPageID)
    }

    /// failTask
    /// - Parameter id: id
    /// - Parameter error: error
    func failTask(id: UUID, error: String) {
        updateTask(id, status: .failed(error: error))
    }

    /// 向指定任务追加一条细粒度子状态日志
    /// - Parameter id: 任务ID
    /// - Parameter log: 详细状态描述文本
    func addSubLog(id: UUID, log: String) {
        if let index = self.tasks.firstIndex(where: { $0.id == id }) {
            self.tasks[index].subLogs.append(log)
            if self.tasks[index].subLogs.count > Self.maxSubLogCount {
                self.tasks[index].subLogs.removeFirst()
            }
            self.objectWillChange.send()
            self.latestStatus = "\(self.tasks[index].name): \(log)"
        }
    }

    /// 向当前活跃的 Ingest 任务中快捷追加子状态日志
    /// - Parameter log: 状态描述文本
    func addIngestSubLog(_ log: String) {
        if let task = self.tasks.first(where: { $0.type == .ingest }) {
            self.addSubLog(id: task.id, log: log)
        }
    }

    /// markAsRead
    /// - Parameter id: id
    func markAsRead(_ id: UUID) {
        DispatchQueue.main.async {
            if let index = self.tasks.firstIndex(where: { $0.id == id }) {
                self.tasks[index].isRead = true
            }
        }
    }

    /// markAllAsRead
    func markAllAsRead() {
        for i in 0..<self.tasks.count {
            self.tasks[i].isRead = true
        }
    }

    /// 移除Task
    /// - Parameter id: id
    func removeTask(_ id: UUID) {
        DispatchQueue.main.async {
            self.tasks.removeAll(where: { $0.id == id })
        }
    }

    /// 重置
    func reset() {
        self.tasks.removeAll()
        self.latestStatus = ""
    }
}

extension NSNotification.Name {
    static let taskCompleted = NSNotification.Name("app_task_completed")
}
